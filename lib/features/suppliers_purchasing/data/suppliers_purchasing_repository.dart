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

    await _sync.enqueue('suppliers', id, 'insert', {
      'id': id,
      'name': name,
      'phone': phone,
      'notes': notes,
    });

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
    );

    await (_db.update(
      _db.suppliers,
    )..where((t) => t.id.equals(id))).write(companion);

    await _sync.enqueue('suppliers', id, 'update', {
      'id': id,
      'name': name,
      'phone': phone,
      'notes': notes,
    });
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

    final invoice = PurchaseInvoice(
      id: purchaseId,
      supplierId: supplierId,
      totalAmount: totalAmount,
      createdAt: now,
    );

    // Insert purchase invoice
    await _db.into(_db.purchaseInvoices).insert(invoice);
    await _sync.enqueue('purchase_invoices', purchaseId, 'insert', {
      'id': purchaseId,
      'supplier_id': supplierId,
      'total_amount': totalAmount,
      'created_at': now.toIso8601String(),
    });

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
      await _sync.enqueue('purchase_items', itemId, 'insert', {
        'id': itemId,
        'purchase_invoice_id': purchaseId,
        'product_id': prodId,
        'quantity': qty,
        'unit_cost': cost,
      });

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
      await _sync.enqueue('stock_movements', movementId, 'insert', {
        'id': movementId,
        'product_id': prodId,
        'type': 'purchase',
        'quantity': qty,
        'created_at': now.toIso8601String(),
        'reference_id': purchaseId,
      });

      // Update product's cost price
      await (_db.update(_db.products)..where((t) => t.id.equals(prodId))).write(
        ProductsCompanion(costPrice: Value(cost), updatedAt: Value(now)),
      );

      await _sync.enqueue('products', prodId, 'update', {
        'id': prodId,
        'cost_price': cost,
        'updated_at': now.toIso8601String(),
      });
    }
  }
}
