import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SyncStatus { idle, syncing, success, error, offline }

class SyncService {
  SyncService(this._db, this._logger);
  final AppDatabase _db;
  final AppLogger _logger;
  final ValueNotifier<SyncStatus> status = ValueNotifier<SyncStatus>(
    SyncStatus.idle,
  );
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  bool _isInitialized = false;
  bool _isSyncing = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  Future<void> initialize() async {
    _logger.info('Initializing SyncService', context: LogContext.syncQueue);
    const url = 'https://xkhmfkrdwuupfqrecfzj.supabase.co';
    const anonKey = 'sb_publishable__1btQ5ObojRmxcBCx1DRzw_RW0yVrXx';

    try {
      await Supabase.initialize(
        url: url,
        publishableKey: anonKey,
        debug: false,
      );
      _isInitialized = true;
      _logger.info(
        'Supabase initialized successfully',
        context: LogContext.supabase,
      );
    } catch (e) {
      _logger.error(
        'Supabase init failed',
        error: e,
        context: LogContext.supabase,
      );
    }

    final connectivity = Connectivity();
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      result,
    ) {
      final hasConnection = result != ConnectivityResult.none;
      if (hasConnection) {
        _logger.info(
          'Connectivity restored, triggering sync',
          context: LogContext.connectivity,
        );
        sync();
      } else {
        _logger.warning('No connectivity', context: LogContext.connectivity);
        status.value = SyncStatus.offline;
      }
    });

    await updatePendingCount();
    sync();
  }

  Future<void> updatePendingCount() async {
    try {
      final counts = await Future.wait<int>([
        (_db.selectOnly(_db.deletedRecords)
              ..addColumns([_db.deletedRecords.id.count()]))
            .map((r) => r.read(_db.deletedRecords.id.count()) ?? 0)
            .getSingle(),
        (_db.selectOnly(_db.categories)
              ..addColumns([_db.categories.id.count()])
              ..where(_db.categories.syncedAt.isNull()))
            .map((r) => r.read(_db.categories.id.count()) ?? 0)
            .getSingle(),
        (_db.selectOnly(_db.products)
              ..addColumns([_db.products.id.count()])
              ..where(_db.products.syncedAt.isNull()))
            .map((r) => r.read(_db.products.id.count()) ?? 0)
            .getSingle(),
        (_db.selectOnly(_db.customers)
              ..addColumns([_db.customers.id.count()])
              ..where(_db.customers.syncedAt.isNull()))
            .map((r) => r.read(_db.customers.id.count()) ?? 0)
            .getSingle(),
        (_db.selectOnly(_db.suppliers)
              ..addColumns([_db.suppliers.id.count()])
              ..where(_db.suppliers.syncedAt.isNull()))
            .map((r) => r.read(_db.suppliers.id.count()) ?? 0)
            .getSingle(),
        (_db.selectOnly(_db.invoices)
              ..addColumns([_db.invoices.id.count()])
              ..where(_db.invoices.syncedAt.isNull()))
            .map((r) => r.read(_db.invoices.id.count()) ?? 0)
            .getSingle(),
        (_db.selectOnly(_db.debts)
              ..addColumns([_db.debts.id.count()])
              ..where(_db.debts.syncedAt.isNull()))
            .map((r) => r.read(_db.debts.id.count()) ?? 0)
            .getSingle(),
        (_db.selectOnly(_db.debtPayments)
              ..addColumns([_db.debtPayments.id.count()])
              ..where(_db.debtPayments.syncedAt.isNull()))
            .map((r) => r.read(_db.debtPayments.id.count()) ?? 0)
            .getSingle(),
        (_db.selectOnly(_db.purchaseInvoices)
              ..addColumns([_db.purchaseInvoices.id.count()])
              ..where(_db.purchaseInvoices.syncedAt.isNull()))
            .map((r) => r.read(_db.purchaseInvoices.id.count()) ?? 0)
            .getSingle(),
        (_db.selectOnly(_db.stockMovements)
              ..addColumns([_db.stockMovements.id.count()])
              ..where(_db.stockMovements.syncedAt.isNull()))
            .map((r) => r.read(_db.stockMovements.id.count()) ?? 0)
            .getSingle(),
      ]);

      pendingCount.value = counts.fold<int>(0, (sum, count) => sum + count);
    } catch (_) {
      // Ignore count calculation errors gracefully
    }
  }

  // Perform clean batch synchronization using syncedAt / Dirty Flag
  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    status.value = SyncStatus.syncing;
    _logger.info('Sync started (Batch Mode)', context: LogContext.syncQueue);

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;
      if (!hasConnection) {
        _logger.warning(
          'Sync skipped - no connectivity',
          context: LogContext.connectivity,
        );
        status.value = SyncStatus.offline;
        _isSyncing = false;
        return;
      }

      if (!_isInitialized) {
        _logger.warning(
          'Sync skipped - Supabase not initialized',
          context: LogContext.supabase,
        );
        status.value = SyncStatus.idle;
        _isSyncing = false;
        return;
      }

      final client = Supabase.instance.client;
      bool hasErrors = false;

      // 1. Process Deletions
      try {
        final deletions = await _db.select(_db.deletedRecords).get();
        for (final d in deletions) {
          try {
            await client.from(d.targetTable).delete().eq('id', d.recordId);
            await (_db.delete(_db.deletedRecords)..where((t) => t.id.equals(d.id))).go();
          } catch (e) {
            _logger.error('Failed to sync deletion: ${d.targetTable}/${d.recordId}', error: e, context: LogContext.syncQueue);
            hasErrors = true;
          }
        }
      } catch (e) {
        hasErrors = true;
      }

      // 2. Sync Categories
      try {
        final unsynced = await (_db.select(_db.categories)..where((t) => t.syncedAt.isNull())).get();
        if (unsynced.isNotEmpty) {
          final payload = unsynced.map((c) => {'id': c.id, 'name': c.name}).toList();
          await client.from('categories').upsert(payload);
          final now = DateTime.now();
          final ids = unsynced.map((c) => c.id).toList();
          await (_db.update(_db.categories)..where((t) => t.id.isIn(ids)))
              .write(CategoriesCompanion(syncedAt: Value(now)));
        }
      } catch (e) {
        _logger.error('Failed to sync categories', error: e, context: LogContext.syncQueue);
        hasErrors = true;
      }

      // 3. Sync Products & Product Prices
      try {
        final unsynced = await (_db.select(_db.products)..where((t) => t.syncedAt.isNull())).get();
        if (unsynced.isNotEmpty) {
          final prodIds = unsynced.map((p) => p.id).toList();
          final payload = unsynced.map((p) => {
            'id': p.id,
            'serial_number': p.serialNumber,
            'code': p.code,
            'name': p.name,
            'category_id': p.categoryId,
            'cost_price': p.costPrice,
            'is_active': p.isActive,
            'min_stock_alert': p.minStockAlert,
            'created_at': p.createdAt.toIso8601String(),
            'updated_at': p.updatedAt.toIso8601String(),
          }).toList();
          await client.from('products').upsert(payload);

          final prices = await (_db.select(_db.productPrices)..where((t) => t.productId.isIn(prodIds))).get();
          if (prices.isNotEmpty) {
            await client.from('product_prices').upsert(prices.map((pr) => {
              'id': pr.id,
              'product_id': pr.productId,
              'price_label': pr.priceLabel,
              'price_value': pr.priceValue,
            }).toList());
          }

          final now = DateTime.now();
          await (_db.update(_db.products)..where((t) => t.id.isIn(prodIds)))
              .write(ProductsCompanion(syncedAt: Value(now)));
        }
      } catch (e) {
        _logger.error('Failed to sync products', error: e, context: LogContext.syncQueue);
        hasErrors = true;
      }

      // 4. Sync Customers
      try {
        final unsynced = await (_db.select(_db.customers)..where((t) => t.syncedAt.isNull())).get();
        if (unsynced.isNotEmpty) {
          final payload = unsynced.map((c) => {
            'id': c.id,
            'name': c.name,
            'phone': c.phone,
            'notes': c.notes,
            'created_at': c.createdAt.toIso8601String(),
          }).toList();
          await client.from('customers').upsert(payload);
          final now = DateTime.now();
          final ids = unsynced.map((c) => c.id).toList();
          await (_db.update(_db.customers)..where((t) => t.id.isIn(ids)))
              .write(CustomersCompanion(syncedAt: Value(now)));
        }
      } catch (e) {
        _logger.error('Failed to sync customers', error: e, context: LogContext.syncQueue);
        hasErrors = true;
      }

      // 5. Sync Suppliers
      try {
        final unsynced = await (_db.select(_db.suppliers)..where((t) => t.syncedAt.isNull())).get();
        if (unsynced.isNotEmpty) {
          final payload = unsynced.map((s) => {
            'id': s.id,
            'name': s.name,
            'phone': s.phone,
            'notes': s.notes,
          }).toList();
          await client.from('suppliers').upsert(payload);
          final now = DateTime.now();
          final ids = unsynced.map((s) => s.id).toList();
          await (_db.update(_db.suppliers)..where((t) => t.id.isIn(ids)))
              .write(SuppliersCompanion(syncedAt: Value(now)));
        }
      } catch (e) {
        _logger.error('Failed to sync suppliers', error: e, context: LogContext.syncQueue);
        hasErrors = true;
      }

      // 6. Sync Invoices & Invoice Items
      try {
        final unsynced = await (_db.select(_db.invoices)..where((t) => t.syncedAt.isNull())).get();
        if (unsynced.isNotEmpty) {
          final invIds = unsynced.map((i) => i.id).toList();
          final payload = unsynced.map((i) => {
            'id': i.id,
            'type': i.type,
            'customer_id': i.customerId,
            'total_amount': i.totalAmount,
            'discount': i.discount,
            'payment_type': i.paymentType,
            'created_at': i.createdAt.toIso8601String(),
          }).toList();
          await client.from('invoices').upsert(payload);

          final items = await (_db.select(_db.invoiceItems)..where((t) => t.invoiceId.isIn(invIds))).get();
          if (items.isNotEmpty) {
            await client.from('invoice_items').upsert(items.map((it) => {
              'id': it.id,
              'invoice_id': it.invoiceId,
              'product_id': it.productId,
              'price_used': it.priceUsed,
              'quantity': it.quantity,
              'discount': it.discount,
            }).toList());
          }

          final now = DateTime.now();
          await (_db.update(_db.invoices)..where((t) => t.id.isIn(invIds)))
              .write(InvoicesCompanion(syncedAt: Value(now)));
        }
      } catch (e) {
        _logger.error('Failed to sync invoices', error: e, context: LogContext.syncQueue);
        hasErrors = true;
      }

      // 7. Sync Purchase Invoices & Items
      try {
        final unsynced = await (_db.select(_db.purchaseInvoices)..where((t) => t.syncedAt.isNull())).get();
        if (unsynced.isNotEmpty) {
          final purIds = unsynced.map((p) => p.id).toList();
          final payload = unsynced.map((p) => {
            'id': p.id,
            'supplier_id': p.supplierId,
            'total_amount': p.totalAmount,
            'created_at': p.createdAt.toIso8601String(),
          }).toList();
          await client.from('purchase_invoices').upsert(payload);

          final items = await (_db.select(_db.purchaseItems)..where((t) => t.purchaseInvoiceId.isIn(purIds))).get();
          if (items.isNotEmpty) {
            await client.from('purchase_items').upsert(items.map((pi) => {
              'id': pi.id,
              'purchase_invoice_id': pi.purchaseInvoiceId,
              'product_id': pi.productId,
              'quantity': pi.quantity,
              'unit_cost': pi.unitCost,
            }).toList());
          }

          final now = DateTime.now();
          await (_db.update(_db.purchaseInvoices)..where((t) => t.id.isIn(purIds)))
              .write(PurchaseInvoicesCompanion(syncedAt: Value(now)));
        }
      } catch (e) {
        _logger.error('Failed to sync purchase invoices', error: e, context: LogContext.syncQueue);
        hasErrors = true;
      }

      // 8. Sync Stock Movements
      try {
        final unsynced = await (_db.select(_db.stockMovements)..where((t) => t.syncedAt.isNull())).get();
        if (unsynced.isNotEmpty) {
          final payload = unsynced.map((m) => {
            'id': m.id,
            'product_id': m.productId,
            'type': m.type,
            'quantity': m.quantity,
            'created_at': m.createdAt.toIso8601String(),
            'reference_id': m.referenceId,
          }).toList();
          await client.from('stock_movements').upsert(payload);

          final now = DateTime.now();
          final ids = unsynced.map((m) => m.id).toList();
          await (_db.update(_db.stockMovements)..where((t) => t.id.isIn(ids)))
              .write(StockMovementsCompanion(syncedAt: Value(now)));
        }
      } catch (e) {
        _logger.error('Failed to sync stock movements', error: e, context: LogContext.syncQueue);
        hasErrors = true;
      }

      // 9. Sync Debts
      try {
        final unsynced = await (_db.select(_db.debts)..where((t) => t.syncedAt.isNull())).get();
        if (unsynced.isNotEmpty) {
          final payload = unsynced.map((d) => {
            'id': d.id,
            'customer_id': d.customerId,
            'invoice_id': d.invoiceId,
            'amount': d.amount,
            'remaining_amount': d.remainingAmount,
            'status': d.status,
            'created_at': d.createdAt.toIso8601String(),
          }).toList();
          await client.from('debts').upsert(payload);

          final now = DateTime.now();
          final ids = unsynced.map((d) => d.id).toList();
          await (_db.update(_db.debts)..where((t) => t.id.isIn(ids)))
              .write(DebtsCompanion(syncedAt: Value(now)));
        }
      } catch (e) {
        _logger.error('Failed to sync debts', error: e, context: LogContext.syncQueue);
        hasErrors = true;
      }

      // 10. Sync Debt Payments
      try {
        final unsynced = await (_db.select(_db.debtPayments)..where((t) => t.syncedAt.isNull())).get();
        if (unsynced.isNotEmpty) {
          final payload = unsynced.map((p) => {
            'id': p.id,
            'debt_id': p.debtId,
            'amount_paid': p.amountPaid,
            'paid_at': p.paidAt.toIso8601String(),
          }).toList();
          await client.from('debt_payments').upsert(payload);

          final now = DateTime.now();
          final ids = unsynced.map((p) => p.id).toList();
          await (_db.update(_db.debtPayments)..where((t) => t.id.isIn(ids)))
              .write(DebtPaymentsCompanion(syncedAt: Value(now)));
        }
      } catch (e) {
        _logger.error('Failed to sync debt payments', error: e, context: LogContext.syncQueue);
        hasErrors = true;
      }

      await updatePendingCount();
      status.value = hasErrors ? SyncStatus.error : SyncStatus.success;
      if (hasErrors) {
        _logger.warning('Sync completed with errors', context: LogContext.syncQueue);
      } else {
        _logger.info('Sync completed successfully', context: LogContext.syncQueue);
      }
    } catch (e) {
      _logger.error('Sync failed', error: e, context: LogContext.syncQueue);
      status.value = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  // Restore all data from server and mark it fully synced
  Future<void> fetchAllFromServer() async {
    if (_isSyncing) return;
    _isSyncing = true;
    status.value = SyncStatus.syncing;
    _logger.info('Fetching all data from server', context: LogContext.supabase);

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _logger.warning(
          'Fetch skipped - no connectivity',
          context: LogContext.connectivity,
        );
        status.value = SyncStatus.offline;
        _isSyncing = false;
        return;
      }

      if (!_isInitialized) {
        _logger.warning(
          'Fetch skipped - Supabase not initialized',
          context: LogContext.supabase,
        );
        status.value = SyncStatus.error;
        _isSyncing = false;
        return;
      }

      final client = Supabase.instance.client;

      final Map<String, List<dynamic>> serverData = {};
      final tableNames = [
        'categories',
        'suppliers',
        'customers',
        'products',
        'product_prices',
        'stock_movements',
        'invoices',
        'invoice_items',
        'debts',
        'debt_payments',
        'purchase_invoices',
        'purchase_items',
      ];

      for (final tableName in tableNames) {
        final response = await client.from(tableName).select();
        serverData[tableName] = response as List<dynamic>;
        _logger.debug(
          'Fetched ${serverData[tableName]!.length} rows from $tableName',
          context: LogContext.supabase,
        );
      }

      final now = DateTime.now();

      // Clear local DB and insert all data (inside transaction, no network calls)
      await _db.transaction(() async {
        // Delete all tracking queues
        await _db.delete(_db.deletedRecords).go();

        // Delete all existing data in reverse dependency order
        for (final table in [
          _db.debtPayments,
          _db.debts,
          _db.purchaseItems,
          _db.purchaseInvoices,
          _db.invoiceItems,
          _db.invoices,
          _db.stockMovements,
          _db.productPrices,
          _db.products,
          _db.categories,
          _db.suppliers,
          _db.customers,
        ]) {
          await _db.delete(table as dynamic).go();
        }

        // Insert categories (marked synced)
        for (final row in serverData['categories']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.categories).insert(
                CategoriesCompanion.insert(
                  id: json['id'] as String,
                  name: json['name'] as String,
                  syncedAt: Value(now),
                ),
              );
        }

        // Insert suppliers (marked synced)
        for (final row in serverData['suppliers']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.suppliers).insert(
                SuppliersCompanion.insert(
                  id: json['id'] as String,
                  name: json['name'] as String,
                  phone: Value(json['phone'] as String?),
                  notes: Value(json['notes'] as String?),
                  syncedAt: Value(now),
                ),
              );
        }

        // Insert customers (marked synced)
        for (final row in serverData['customers']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.customers).insert(
                CustomersCompanion.insert(
                  id: json['id'] as String,
                  name: json['name'] as String,
                  phone: Value(json['phone'] as String?),
                  notes: Value(json['notes'] as String?),
                  createdAt: DateTime.parse(json['created_at'] as String),
                  syncedAt: Value(now),
                ),
              );
        }

        // Insert products (marked synced)
        for (final row in serverData['products']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.products).insert(
                ProductsCompanion.insert(
                  id: json['id'] as String,
                  serialNumber: Value(json['serial_number'] as int?),
                  code: Value(json['code'] as String?),
                  name: json['name'] as String,
                  categoryId: Value(json['category_id'] as String?),
                  costPrice: Value((json['cost_price'] as num).toDouble()),
                  isActive: Value(json['is_active'] as bool? ?? true),
                  minStockAlert: Value(
                    (json['min_stock_alert'] as num?)?.toDouble() ?? 0,
                  ),
                  createdAt: DateTime.parse(json['created_at'] as String),
                  updatedAt: json['updated_at'] != null
                      ? DateTime.parse(json['updated_at'] as String)
                      : now,
                  syncedAt: Value(now),
                ),
              );
        }

        // Insert product_prices
        for (final row in serverData['product_prices']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.productPrices).insert(
                ProductPricesCompanion.insert(
                  id: json['id'] as String,
                  productId: json['product_id'] as String,
                  priceLabel: json['price_label'] as String,
                  priceValue: (json['price_value'] as num).toDouble(),
                ),
              );
        }

        // Insert stock_movements (marked synced)
        for (final row in serverData['stock_movements']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.stockMovements).insert(
                StockMovementsCompanion.insert(
                  id: json['id'] as String,
                  productId: json['product_id'] as String,
                  type: json['type'] as String,
                  quantity: (json['quantity'] as num).toDouble(),
                  referenceId: Value(json['reference_id'] as String?),
                  createdAt: DateTime.parse(json['created_at'] as String),
                  syncedAt: Value(now),
                ),
              );
        }

        // Insert invoices (marked synced)
        for (final row in serverData['invoices']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.invoices).insert(
                InvoicesCompanion.insert(
                  id: json['id'] as String,
                  type: json['type'] as String,
                  customerId: Value(json['customer_id'] as String?),
                  totalAmount: (json['total_amount'] as num).toDouble(),
                  discount: Value((json['discount'] as num?)?.toDouble() ?? 0),
                  paymentType: json['payment_type'] as String,
                  createdAt: DateTime.parse(json['created_at'] as String),
                  syncedAt: Value(now),
                ),
              );
        }

        // Insert invoice_items
        for (final row in serverData['invoice_items']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.invoiceItems).insert(
                InvoiceItemsCompanion.insert(
                  id: json['id'] as String,
                  invoiceId: json['invoice_id'] as String,
                  productId: json['product_id'] as String,
                  priceUsed: (json['price_used'] as num).toDouble(),
                  quantity: (json['quantity'] as num).toDouble(),
                  discount: Value((json['discount'] as num?)?.toDouble() ?? 0),
                ),
              );
        }

        // Insert debts (marked synced)
        for (final row in serverData['debts']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.debts).insert(
                DebtsCompanion.insert(
                  id: json['id'] as String,
                  customerId: json['customer_id'] as String,
                  invoiceId: Value(json['invoice_id'] as String?),
                  amount: (json['amount'] as num).toDouble(),
                  remainingAmount: (json['remaining_amount'] as num).toDouble(),
                  status: json['status'] as String,
                  createdAt: DateTime.parse(json['created_at'] as String),
                  syncedAt: Value(now),
                ),
              );
        }

        // Insert debt_payments (marked synced)
        for (final row in serverData['debt_payments']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.debtPayments).insert(
                DebtPaymentsCompanion.insert(
                  id: json['id'] as String,
                  debtId: json['debt_id'] as String,
                  amountPaid: (json['amount_paid'] as num).toDouble(),
                  paidAt: DateTime.parse(json['paid_at'] as String),
                  syncedAt: Value(now),
                ),
              );
        }

        // Insert purchase_invoices (marked synced)
        for (final row in serverData['purchase_invoices']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.purchaseInvoices).insert(
                PurchaseInvoicesCompanion.insert(
                  id: json['id'] as String,
                  supplierId: json['supplier_id'] as String,
                  totalAmount: (json['total_amount'] as num).toDouble(),
                  createdAt: DateTime.parse(json['created_at'] as String),
                  syncedAt: Value(now),
                ),
              );
        }

        // Insert purchase_items
        for (final row in serverData['purchase_items']!) {
          final json = row as Map<String, dynamic>;
          await _db.into(_db.purchaseItems).insert(
                PurchaseItemsCompanion.insert(
                  id: json['id'] as String,
                  purchaseInvoiceId: json['purchase_invoice_id'] as String,
                  productId: json['product_id'] as String,
                  quantity: (json['quantity'] as num).toDouble(),
                  unitCost: (json['unit_cost'] as num).toDouble(),
                ),
              );
        }
      });

      await updatePendingCount();
      _logger.info('Fetch from server completed', context: LogContext.supabase);
      status.value = SyncStatus.success;
    } catch (e) {
      _logger.error(
        'Fetch from server failed',
        error: e,
        context: LogContext.supabase,
      );
      status.value = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _logger.info('Disposing SyncService', context: LogContext.syncQueue);
    _connectivitySubscription?.cancel();
  }
}
