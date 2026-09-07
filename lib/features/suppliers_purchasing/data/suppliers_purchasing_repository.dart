import 'package:drift/drift.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:uuid/uuid.dart';

class SupplierWithPurchases {
  SupplierWithPurchases({
    required this.supplier,
    required this.totalPurchasesAmount,
    required this.invoicesCount,
  });
  final Supplier supplier;
  final double totalPurchasesAmount;
  final int invoicesCount;
}

class SuppliersPurchasingRepository {
  SuppliersPurchasingRepository(this._db, this._sync, this._logger);
  final AppDatabase _db;
  final SyncService _sync;
  final AppLogger _logger;
  final _uuid = const Uuid();

  // --- Suppliers ---

  Future<List<SupplierWithPurchases>> getSuppliers() async {
    _logger.debug('Fetching suppliers', context: LogContext.inventory);
    final suppliers = await _db.select(_db.suppliers).get();
    final purchaseInvoices = await _db.select(_db.purchaseInvoices).get();

    return suppliers.map((sup) {
      final supplierInvoices = purchaseInvoices
          .where((p) => p.supplierId == sup.id)
          .toList();
      final totalAmount = supplierInvoices.fold<double>(
        0.0,
        (sum, p) => sum + p.totalAmount,
      );

      return SupplierWithPurchases(
        supplier: sup,
        totalPurchasesAmount: totalAmount,
        invoicesCount: supplierInvoices.length,
      );
    }).toList();
  }

  Future<Supplier> addSupplier({
    required String name,
    required String? phone,
    required String? notes,
  }) async {
    _logger.info(
      'Adding supplier: $name, phone=$phone',
      context: LogContext.inventory,
    );
    final id = _uuid.v4();
    final supplier = Supplier(id: id, name: name, phone: phone, notes: notes);

    await _db.into(_db.suppliers).insert(supplier);

    _sync.updatePendingCount();
    _sync.sync();

    return supplier;
  }

  Future<void> updateSupplier({
    required String id,
    required String name,
    required String? phone,
    required String? notes,
  }) async {
    _logger.info(
      'Updating supplier: $id, name=$name',
      context: LogContext.inventory,
    );
    final companion = SuppliersCompanion(
      name: Value(name),
      phone: Value(phone),
      notes: Value(notes),
      syncedAt: const Value(null),
    );

    await (_db.update(
      _db.suppliers,
    )..where((t) => t.id.equals(id))).write(companion);

    _sync.updatePendingCount();
    _sync.sync();
  }

  // --- Purchases ---

  Future<void> recordPurchase({
    required String supplierId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    _logger.info(
      'Recording purchase: supplier=$supplierId, amount=$totalAmount, items=${items.length}',
      context: LogContext.inventory,
    );
    final purchaseId = _uuid.v4();
    final now = DateTime.now();

    await _db.transaction(() async {
      final invoice = PurchaseInvoice(
        id: purchaseId,
        supplierId: supplierId,
        totalAmount: totalAmount,
        createdAt: now,
      );

      // Insert purchase invoice
      await _db.into(_db.purchaseInvoices).insert(invoice);

      for (final item in items) {
        final itemId = _uuid.v4();
        final prodId = item['productId'] as String;
        final qty = (item['quantity'] as num).toDouble();
        final cost = (item['unitCost'] as num).toDouble();

        final purchaseItem = PurchaseItem(
          id: itemId,
          purchaseInvoiceId: purchaseId,
          productId: prodId,
          quantity: qty,
          unitCost: cost,
        );

        // Insert purchase item record
        await _db.into(_db.purchaseItems).insert(purchaseItem);

        // Increase stock via Stock Movement (positive quantity)
        final movementId = _uuid.v4();
        final movement = StockMovement(
          id: movementId,
          productId: prodId,
          type: 'purchase',
          quantity: qty,
          createdAt: now,
          referenceId: purchaseId,
        );

        await _db.into(_db.stockMovements).insert(movement);

        // Update product's cost price (mark syncedAt null)
        await (_db.update(_db.products)..where((t) => t.id.equals(prodId))).write(
          ProductsCompanion(costPrice: Value(cost), updatedAt: Value(now), syncedAt: const Value(null)),
        );
      }
    });

    _sync.updatePendingCount();
    _sync.sync();
  }
}
