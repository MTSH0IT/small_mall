import 'dart:async';
import 'dart:convert';

import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SyncStatus { idle, syncing, success, error, offline }

class SyncService {
  SyncService(this._db);
  final AppDatabase _db;
  final ValueNotifier<SyncStatus> status = ValueNotifier<SyncStatus>(
    SyncStatus.idle,
  );
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  bool _isInitialized = false;
  bool _isSyncing = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('supabase_url') ?? '';
    final anonKey = prefs.getString('supabase_anon_key') ?? '';

    if (url.isNotEmpty && anonKey.isNotEmpty) {
      try {
        await Supabase.initialize(url: url, publishableKey: anonKey, debug: false);
        _isInitialized = true;
      } catch (e) {
        debugPrint('Supabase init failed: $e');
      }
    }

    // Monitor connectivity
    final connectivity = Connectivity();
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      result,
    ) {
      final hasConnection = result != ConnectivityResult.none;
      if (hasConnection) {
        sync();
      } else {
        status.value = SyncStatus.offline;
      }
    });

    await updatePendingCount();
    // Attempt initial sync
    sync();
  }

  Future<void> saveCredentials(String url, String anonKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('supabase_url', url);
    await prefs.setString('supabase_anon_key', anonKey);

    // Re-initialize
    try {
      // Supabase already initialized, it cannot be re-initialized in the same process usually.
      // We can dispose or let the user restart the app, or attempt direct client replacement.
      // In Flutter, to avoid crash we can try direct replacement or show restart needed.
    } catch (_) {
      try {
        await Supabase.initialize(url: url, publishableKey: anonKey);
        _isInitialized = true;
      } catch (e) {
        debugPrint('Supabase init failed: $e');
        rethrow;
      }
    }
    sync();
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('supabase_url');
    await prefs.remove('supabase_anon_key');
    _isInitialized = false;
    status.value = SyncStatus.idle;
  }

  Future<bool> hasCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('supabase_url') ?? '';
    return url.isNotEmpty;
  }

  Future<void> updatePendingCount() async {
    final list = await _db.select(_db.syncQueue).get();
    pendingCount.value = list.where((item) => item.status == 'pending').length;
  }

  // Queue a database operation
  Future<void> enqueue(
    String tableName,
    String recordId,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    final queueItem = SyncQueueCompanion.insert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      targetTable: tableName,
      recordId: recordId,
      operation: operation,
      payload: jsonEncode(payload),
      status: 'pending',
      createdAt: DateTime.now(),
    );
    await _db.into(_db.syncQueue).insert(queueItem);
    await updatePendingCount();
    sync();
  }

  // Perform synchronization
  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    status.value = SyncStatus.syncing;

    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;
      if (!hasConnection) {
        status.value = SyncStatus.offline;
        _isSyncing = false;
        return;
      }

      if (!_isInitialized) {
        // Without Supabase configured, we just mark queue items as 'synced' in a mock fashion
        // if user hasn't set up Supabase yet, to keep local experience smooth.
        // Or keep them pending until they add Supabase. Let's keep them pending but show idle.
        status.value = SyncStatus.idle;
        _isSyncing = false;
        return;
      }

      // Fetch pending items ordered by date
      final pendingItems =
          await (_db.select(_db.syncQueue)
                ..where((t) => t.status.equals('pending'))
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();

      if (pendingItems.isEmpty) {
        status.value = SyncStatus.success;
        _isSyncing = false;
        return;
      }

      final client = Supabase.instance.client;

      for (final item in pendingItems) {
        try {
          final payload = jsonDecode(item.payload) as Map<String, dynamic>;
          final tableName = item.targetTable;
          final recordId = item.recordId;
          final op = item.operation;

          if (op == 'insert' || op == 'update') {
            // Convert payloads to Supabase expected formats (snake_case column mapping if necessary,
            // but our local tables are already named and matches Supabase since we mirrored them).
            // Let's perform upsert.
            await client.from(tableName).upsert(payload);
          } else if (op == 'delete') {
            await client.from(tableName).delete().eq('id', recordId);
          }

          // Mark as synced in local DB
          await (_db.update(_db.syncQueue)..where((t) => t.id.equals(item.id)))
              .write(const SyncQueueCompanion(status: Value('synced')));
        } catch (e) {
          debugPrint('Failed to sync item ${item.id}: $e');
          await (_db.update(_db.syncQueue)..where((t) => t.id.equals(item.id)))
              .write(const SyncQueueCompanion(status: Value('failed')));
        }
      }

      await updatePendingCount();
      status.value = SyncStatus.success;
    } catch (e) {
      debugPrint('Sync failed: $e');
      status.value = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
