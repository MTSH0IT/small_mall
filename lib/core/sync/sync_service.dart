import 'dart:async';
import 'dart:convert';

import 'package:small_mall/core/database/app_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
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
    const url = 'https://xkhmfkrdwuupfqrecfzj.supabase.co';
    const anonKey = 'sb_publishable__1btQ5ObojRmxcBCx1DRzw_RW0yVrXx';

    try {
      await Supabase.initialize(url: url, publishableKey: anonKey, debug: false);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Supabase init failed: $e');
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

  // Removed saveCredentials as it is no longer used.

  Future<void> clearCredentials() async {
    _isInitialized = false;
    status.value = SyncStatus.idle;
  }

  Future<bool> hasCredentials() async {
    return true;
  }

  Future<void> updatePendingCount() async {
    final list = await _db.select(_db.syncQueue).get();
    pendingCount.value = list.where((item) => item.status == 'pending' || item.status == 'failed').length;
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

      // Fetch pending items (including previously failed ones for retry)
      final pendingItems =
          await (_db.select(_db.syncQueue)
                ..where((t) => t.status.equals('pending') | t.status.equals('failed'))
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();

      if (pendingItems.isEmpty) {
        status.value = SyncStatus.success;
        _isSyncing = false;
        return;
      }

      final client = Supabase.instance.client;
      bool hasErrors = false;

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
          hasErrors = true;
        }
      }

      await updatePendingCount();
      status.value = hasErrors ? SyncStatus.error : SyncStatus.success;
    } catch (e) {
      debugPrint('Sync failed: $e');
      status.value = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> fetchAllFromServer() async {
    if (_isSyncing) return;
    _isSyncing = true;
    status.value = SyncStatus.syncing;

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        status.value = SyncStatus.offline;
        _isSyncing = false;
        return;
      }

      if (!_isInitialized) {
        status.value = SyncStatus.error;
        _isSyncing = false;
        return;
      }

      final client = Supabase.instance.client;

      // Step 1: Fetch ALL data from Supabase (outside of transaction)
      final Map<String, List<dynamic>> serverData = {};
      final tableNames = [
        'categories', 'suppliers', 'customers', 'products',
        'product_prices', 'stock_movements', 'invoices', 'invoice_items',
        'debts', 'debt_payments', 'purchase_invoices', 'purchase_items',
      ];

      for (final tableName in tableNames) {
        try {
          final response = await client.from(tableName).select();
          serverData[tableName] = response as List<dynamic>;
          debugPrint('Fetched ${serverData[tableName]!.length} rows for $tableName');
        } catch (e) {
          debugPrint('Failed to fetch $tableName: $e');
          rethrow;
        }
      }

      // Step 2: Clear local DB and insert all data (inside transaction, no network calls)
      await _db.transaction(() async {
        // Delete all existing data (reverse dependency order, keep syncQueue)
        for (final table in [
          _db.debtPayments, _db.debts, _db.purchaseItems,
          _db.purchaseInvoices, _db.invoiceItems, _db.invoices,
          _db.stockMovements, _db.productPrices, _db.products,
          _db.categories, _db.suppliers, _db.customers,
        ]) {
          await _db.delete(table as dynamic).go();
        }

        // Insert categories
        for (final row in serverData['categories']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.categories).insert(CategoriesCompanion.insert(
            id: json['id'] as String,
            name: json['name'] as String,
          ));
        }

        // Insert suppliers
        for (final row in serverData['suppliers']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.suppliers).insert(SuppliersCompanion.insert(
            id: json['id'] as String,
            name: json['name'] as String,
            phone: Value(json['phone'] as String?),
            notes: Value(json['notes'] as String?),
          ));
        }

        // Insert customers
        for (final row in serverData['customers']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.customers).insert(CustomersCompanion.insert(
            id: json['id'] as String,
            name: json['name'] as String,
            phone: Value(json['phone'] as String?),
            notes: Value(json['notes'] as String?),
            createdAt: DateTime.parse(json['created_at'] as String),
          ));
        }

        // Insert products
        for (final row in serverData['products']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.products).insert(ProductsCompanion.insert(
            id: json['id'] as String,
            name: json['name'] as String,
            categoryId: Value(json['category_id'] as String?),
            costPrice: Value((json['cost_price'] as num).toDouble()),
            isActive: Value(json['is_active'] as bool? ?? true),
            minStockAlert: Value((json['min_stock_alert'] as num?)?.toDouble() ?? 0),
            createdAt: DateTime.parse(json['created_at'] as String),
            updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
            syncedAt: Value(json['synced_at'] != null ? DateTime.parse(json['synced_at'] as String) : null),
          ));
        }

        // Insert product_prices
        for (final row in serverData['product_prices']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.productPrices).insert(ProductPricesCompanion.insert(
            id: json['id'] as String,
            productId: json['product_id'] as String,
            priceLabel: json['price_label'] as String,
            priceValue: (json['price_value'] as num).toDouble(),
          ));
        }

        // Insert stock_movements
        for (final row in serverData['stock_movements']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.stockMovements).insert(StockMovementsCompanion.insert(
            id: json['id'] as String,
            productId: json['product_id'] as String,
            type: json['type'] as String,
            quantity: (json['quantity'] as num).toDouble(),
            referenceId: Value(json['reference_id'] as String?),
            createdAt: DateTime.parse(json['created_at'] as String),
          ));
        }

        // Insert invoices
        for (final row in serverData['invoices']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.invoices).insert(InvoicesCompanion.insert(
            id: json['id'] as String,
            type: json['type'] as String,
            customerId: Value(json['customer_id'] as String?),
            totalAmount: (json['total_amount'] as num).toDouble(),
            discount: Value((json['discount'] as num?)?.toDouble() ?? 0),
            paymentType: json['payment_type'] as String,
            createdAt: DateTime.parse(json['created_at'] as String),
            syncedAt: Value(json['synced_at'] != null ? DateTime.parse(json['synced_at'] as String) : null),
          ));
        }

        // Insert invoice_items
        for (final row in serverData['invoice_items']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.invoiceItems).insert(InvoiceItemsCompanion.insert(
            id: json['id'] as String,
            invoiceId: json['invoice_id'] as String,
            productId: json['product_id'] as String,
            priceUsed: (json['price_used'] as num).toDouble(),
            quantity: (json['quantity'] as num).toDouble(),
            discount: Value((json['discount'] as num?)?.toDouble() ?? 0),
          ));
        }

        // Insert debts
        for (final row in serverData['debts']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.debts).insert(DebtsCompanion.insert(
            id: json['id'] as String,
            customerId: json['customer_id'] as String,
            invoiceId: Value(json['invoice_id'] as String?),
            amount: (json['amount'] as num).toDouble(),
            remainingAmount: (json['remaining_amount'] as num).toDouble(),
            status: json['status'] as String,
            createdAt: DateTime.parse(json['created_at'] as String),
          ));
        }

        // Insert debt_payments
        for (final row in serverData['debt_payments']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.debtPayments).insert(DebtPaymentsCompanion.insert(
            id: json['id'] as String,
            debtId: json['debt_id'] as String,
            amountPaid: (json['amount_paid'] as num).toDouble(),
            paidAt: DateTime.parse(json['paid_at'] as String),
          ));
        }

        // Insert purchase_invoices
        for (final row in serverData['purchase_invoices']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.purchaseInvoices).insert(PurchaseInvoicesCompanion.insert(
            id: json['id'] as String,
            supplierId: json['supplier_id'] as String,
            totalAmount: (json['total_amount'] as num).toDouble(),
            createdAt: DateTime.parse(json['created_at'] as String),
          ));
        }

        // Insert purchase_items
        for (final row in serverData['purchase_items']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.purchaseItems).insert(PurchaseItemsCompanion.insert(
            id: json['id'] as String,
            purchaseInvoiceId: json['purchase_invoice_id'] as String,
            productId: json['product_id'] as String,
            quantity: (json['quantity'] as num).toDouble(),
            unitCost: (json['unit_cost'] as num).toDouble(),
          ));
        }
      });

      await updatePendingCount();
      status.value = SyncStatus.success;
    } catch (e) {
      debugPrint('Fetch from server failed: $e');
      status.value = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
