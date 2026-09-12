import 'package:drift/drift.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:uuid/uuid.dart';

class PurchaseItemWithProduct {
  PurchaseItemWithProduct({
    required this.item,
    required this.product,
  });

  final PurchaseItem item;
  final Product? product;

  double get subtotal => item.quantity * item.unitCost;
}

class PurchaseInvoiceWithDetails {
  PurchaseInvoiceWithDetails({
    required this.invoice,
    required this.supplier,
    required this.items,
    this.serialNumber,
  });

  final PurchaseInvoice invoice;
  final Supplier? supplier;
  final List<PurchaseItemWithProduct> items;
  final int? serialNumber;

  int get itemsCount => items.length;
  double get totalPieces => items.fold<double>(0.0, (sum, i) => sum + i.item.quantity);
}

class SupplierWithPurchases {
  SupplierWithPurchases({
    required this.supplier,
    required this.totalPurchasesAmount,
    required this.invoicesCount,
    this.lastPurchaseDate,
  });
  final Supplier supplier;
  final double totalPurchasesAmount;
  final int invoicesCount;
  final DateTime? lastPurchaseDate;
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
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final totalAmount = supplierInvoices.fold<double>(
        0.0,
        (sum, p) => sum + p.totalAmount,
      );

      return SupplierWithPurchases(
        supplier: sup,
        totalPurchasesAmount: totalAmount,
        invoicesCount: supplierInvoices.length,
        lastPurchaseDate: supplierInvoices.isNotEmpty ? supplierInvoices.first.createdAt : null,
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

  Future<List<PurchaseInvoiceWithDetails>> getSupplierInvoices(String supplierId) async {
    _logger.debug('Fetching invoices for supplier: $supplierId', context: LogContext.inventory);
    final supplier = await (_db.select(_db.suppliers)..where((t) => t.id.equals(supplierId))).getSingleOrNull();

    final allPurchaseInvoices = await (_db.select(_db.purchaseInvoices)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    final serialMap = <String, int>{};
    for (int i = 0; i < allPurchaseInvoices.length; i++) {
      serialMap[allPurchaseInvoices[i].id] = i + 1;
    }

    final invoices = allPurchaseInvoices
        .where((p) => p.supplierId == supplierId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (invoices.isEmpty) return [];

    final invoiceIds = invoices.map((i) => i.id).toList();
    final allItems = await (_db.select(_db.purchaseItems)
          ..where((t) => t.purchaseInvoiceId.isIn(invoiceIds)))
        .get();

    final productIds = allItems.map((i) => i.productId).toSet().toList();
    final products = await (_db.select(_db.products)
          ..where((t) => t.id.isIn(productIds)))
        .get();
    final productMap = {for (final p in products) p.id: p};

    return invoices.map((invoice) {
      final items = allItems
          .where((item) => item.purchaseInvoiceId == invoice.id)
          .map((item) => PurchaseItemWithProduct(
                item: item,
                product: productMap[item.productId],
              ))
          .toList();

      return PurchaseInvoiceWithDetails(
        invoice: invoice,
        supplier: supplier,
        items: items,
        serialNumber: serialMap[invoice.id] ?? 1,
      );
    }).toList();
  }

  Future<PurchaseInvoiceWithDetails?> getPurchaseInvoiceDetails(String invoiceId) async {
    _logger.debug('Fetching purchase invoice details: $invoiceId', context: LogContext.inventory);
    final invoice = await (_db.select(_db.purchaseInvoices)..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
    if (invoice == null) return null;

    final allPurchaseInvoices = await (_db.select(_db.purchaseInvoices)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    final serialIndex = allPurchaseInvoices.indexWhere((inv) => inv.id == invoiceId);
    final serialNumber = serialIndex != -1 ? serialIndex + 1 : 1;

    final supplier = await (_db.select(_db.suppliers)..where((t) => t.id.equals(invoice.supplierId))).getSingleOrNull();
    final items = await (_db.select(_db.purchaseItems)..where((t) => t.purchaseInvoiceId.equals(invoiceId))).get();

    final productIds = items.map((i) => i.productId).toSet().toList();
    final products = await (_db.select(_db.products)..where((t) => t.id.isIn(productIds))).get();
    final productMap = {for (final p in products) p.id: p};

    final detailedItems = items
        .map((item) => PurchaseItemWithProduct(
              item: item,
              product: productMap[item.productId],
            ))
        .toList();

    return PurchaseInvoiceWithDetails(
      invoice: invoice,
      supplier: supplier,
      items: detailedItems,
      serialNumber: serialNumber,
    );
  }
}
