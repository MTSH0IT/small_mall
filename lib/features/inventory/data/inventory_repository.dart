import 'package:drift/drift.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:uuid/uuid.dart';

class ProductWithDetails {
  ProductWithDetails({
    required this.product,
    this.category,
    required this.prices,
    required this.currentStock,
    this.initialStock = 0.0,
  });

  final Product product;
  final Category? category;
  final List<ProductPrice> prices;
  final double currentStock;
  final double initialStock;

  bool get isLowStock => product.minStockAlert > 0 && currentStock <= product.minStockAlert;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductWithDetails && other.product.id == product.id);

  @override
  int get hashCode => product.id.hashCode;
}

class ProductStockOperation {
  const ProductStockOperation({
    required this.id,
    required this.type,
    required this.quantity,
    required this.createdAt,
    this.referenceNumber,
    this.partyName,
    this.unitPrice,
    required this.runningBalance,
  });

  final String id;
  final String type; // 'initial', 'sale', 'purchase', 'return', 'adjustment'
  final double quantity;
  final DateTime createdAt;
  final String? referenceNumber;
  final String? partyName;
  final double? unitPrice;
  final double runningBalance;
}

class InventoryRepository {

  InventoryRepository(this._db, this._sync, this._logger);
  final AppDatabase _db;
  final SyncService _sync;
  final AppLogger _logger;
  final _uuid = const Uuid();

  // --- Categories ---

  Future<List<Category>> getCategories() async {
    _logger.debug('Fetching categories', context: LogContext.inventory);
    return (_db.select(_db.categories)
          ..orderBy([
            (t) => OrderingTerm.asc(t.serialNumber),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  Future<Category> addCategory(String name) async {
    _logger.info('Adding category: $name', context: LogContext.inventory);
    final id = _uuid.v4();
    final serialNumber = await _db.getNextCategorySerialNumber();
    final category = Category(
      id: id,
      name: name,
      serialNumber: serialNumber,
    );
    await _db.into(_db.categories).insert(category);

    _sync.updatePendingCount();
    _sync.sync();
    return category;
  }

  Future<void> updateCategory(String id, String name) async {
    _logger.info('Updating category: $id with name: $name', context: LogContext.inventory);
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(name: Value(name), syncedAt: const Value(null)),
    );

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<void> deleteCategory(String id) async {
    _logger.info('Deleting category: $id', context: LogContext.inventory);

    // Unlink products assigned to this category
    final affectedProducts = await (_db.select(_db.products)..where((t) => t.categoryId.equals(id))).get();
    for (final p in affectedProducts) {
      await (_db.update(_db.products)..where((t) => t.id.equals(p.id))).write(
        const ProductsCompanion(categoryId: Value(null), syncedAt: Value(null)),
      );
    }

    // Record deletion for sync
    await _db.into(_db.deletedRecords).insert(
      DeletedRecordsCompanion.insert(
        id: _uuid.v4(),
        targetTable: 'categories',
        recordId: id,
        createdAt: DateTime.now(),
      ),
    );

    // Delete category
    await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();

    _sync.updatePendingCount();
    _sync.sync();
  }

  // --- Products ---

  Future<List<ProductWithDetails>> getProducts() async {
    _logger.debug('Fetching products', context: LogContext.inventory);
    final products = await (_db.select(_db.products)
          ..orderBy([(t) => OrderingTerm.asc(t.serialNumber)]))
        .get();
    final categories = await getCategories();
    final allPrices = await _db.select(_db.productPrices).get();
    final stockBalances = await _db.getAllStockBalances();
    final initialStocks = await _db.getAllInitialStocks();

    final categoryMap = {for (var c in categories) c.id: c};

    return products.map((prod) {
      final category = prod.categoryId != null ? categoryMap[prod.categoryId] : null;
      final prices = allPrices.where((p) => p.productId == prod.id).toList();
      final currentStock = stockBalances[prod.id] ?? 0.0;
      final initialStock = initialStocks[prod.id] ?? 0.0;

      return ProductWithDetails(
        product: prod,
        category: category,
        prices: prices,
        currentStock: currentStock,
        initialStock: initialStock,
      );
    }).toList();
  }

  Future<int> getNextSerialNumber() async {
    return _db.getNextProductSerialNumber();
  }

  Future<void> addProduct({
    int? serialNumber,
    String? code,
    required String name,
    required String? categoryId,
    required double costPrice,
    required double minStockAlert,
    required List<Map<String, dynamic>> prices,
    required double initialStock,
  }) async {
    _logger.info('Adding product: $name, cost=$costPrice, stock=$initialStock',
        context: LogContext.inventory);
    final productId = _uuid.v4();
    final productCode = (code != null && code.trim().isNotEmpty) ? code.trim() : null;
    final productSeq = serialNumber ?? await _db.getNextProductSerialNumber();
    final now = DateTime.now();

    await _db.transaction(() async {
      final product = Product(
        id: productId,
        serialNumber: productSeq,
        code: productCode,
        name: name,
        categoryId: categoryId,
        costPrice: costPrice,
        isActive: true,
        minStockAlert: minStockAlert,
        createdAt: now,
        updatedAt: now,
      );

      // Insert Product
      await _db.into(_db.products).insert(product);

      // Insert Prices
      for (final price in prices) {
        final priceId = _uuid.v4();
        final priceVal = (price['price_value'] as num).toDouble();
        final label = price['price_label'] as String;

        final prodPrice = ProductPrice(
          id: priceId,
          productId: productId,
          priceLabel: label,
          priceValue: priceVal,
        );

        await _db.into(_db.productPrices).insert(prodPrice);
      }

      // Insert Initial Stock Movement if > 0
      if (initialStock > 0) {
        final movementId = _uuid.v4();
        final movement = StockMovement(
          id: movementId,
          productId: productId,
          type: 'adjustment',
          quantity: initialStock,
          createdAt: now,
          referenceId: 'initial_stock',
        );

        await _db.into(_db.stockMovements).insert(movement);
      }
    });

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<void> updateProduct({
    required String id,
    int? serialNumber,
    String? code,
    required String name,
    required String? categoryId,
    required double costPrice,
    required double minStockAlert,
    required List<Map<String, dynamic>> prices,
  }) async {
    _logger.info('Updating product: $id, name=$name, cost=$costPrice',
        context: LogContext.inventory);
    final now = DateTime.now();
    final productCode = (code != null && code.trim().isNotEmpty) ? code.trim() : null;

    await _db.transaction(() async {
      final productUpdate = ProductsCompanion(
        serialNumber: Value(serialNumber),
        code: Value(productCode),
        name: Value(name),
        categoryId: Value(categoryId),
        costPrice: Value(costPrice),
        minStockAlert: Value(minStockAlert),
        updatedAt: Value(now),
        syncedAt: const Value(null),
      );

      // Update locally
      await (_db.update(_db.products)..where((t) => t.id.equals(id))).write(productUpdate);

      // Handle prices: Simple way is delete old ones, insert new ones
      final oldPrices = await (_db.select(_db.productPrices)..where((t) => t.productId.equals(id))).get();
      for (final oldPrice in oldPrices) {
        await _db.into(_db.deletedRecords).insert(
          DeletedRecordsCompanion.insert(
            id: _uuid.v4(),
            targetTable: 'product_prices',
            recordId: oldPrice.id,
            createdAt: now,
          ),
        );
        await (_db.delete(_db.productPrices)..where((t) => t.id.equals(oldPrice.id))).go();
      }

      for (final price in prices) {
        final priceId = _uuid.v4();
        final priceVal = (price['price_value'] as num).toDouble();
        final label = price['price_label'] as String;

        final prodPrice = ProductPrice(
          id: priceId,
          productId: id,
          priceLabel: label,
          priceValue: priceVal,
        );

        await _db.into(_db.productPrices).insert(prodPrice);
      }
    });

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<void> deleteProduct(String id) async {
    _logger.info('Soft-deleting product: $id', context: LogContext.inventory);
    final now = DateTime.now();
    await (_db.update(_db.products)..where((t) => t.id.equals(id)))
        .write(ProductsCompanion(isActive: const Value(false), updatedAt: Value(now), syncedAt: const Value(null)));

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<void> adjustStock(String productId, double quantity, String reason) async {
    _logger.info('Adjusting stock: product=$productId, qty=$quantity, reason=$reason',
        context: LogContext.inventory);
    final id = _uuid.v4();
    final now = DateTime.now();

    final movement = StockMovement(
      id: id,
      productId: productId,
      type: 'adjustment',
      quantity: quantity,
      createdAt: now,
      referenceId: reason,
    );

    await _db.into(_db.stockMovements).insert(movement);

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<List<ProductStockOperation>> getProductOperations(String productId) async {
    _logger.debug('Fetching operations for product: $productId', context: LogContext.inventory);

    final movements = await (_db.select(_db.stockMovements)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    if (movements.isEmpty) {
      return [];
    }

    final invoiceIds = <String>{};
    final purchaseIds = <String>{};

    for (final m in movements) {
      if (m.referenceId == null || m.referenceId == 'initial_stock') continue;
      if (m.type == 'sale' || m.type == 'return') {
        invoiceIds.add(m.referenceId!);
      } else if (m.type == 'purchase') {
        purchaseIds.add(m.referenceId!);
      }
    }

    final Map<String, Invoice> invoiceMap = {};
    final Map<String, InvoiceItem> invoiceItemMap = {};
    final Map<String, Customer> customerMap = {};

    if (invoiceIds.isNotEmpty) {
      final invList = await (_db.select(_db.invoices)..where((t) => t.id.isIn(invoiceIds))).get();
      for (final inv in invList) {
        invoiceMap[inv.id] = inv;
      }

      final items = await (_db.select(_db.invoiceItems)
            ..where((t) => t.productId.equals(productId) & t.invoiceId.isIn(invoiceIds)))
          .get();
      for (final item in items) {
        invoiceItemMap[item.invoiceId] = item;
      }

      final customerIds = invList.map((i) => i.customerId).whereType<String>().toSet();
      if (customerIds.isNotEmpty) {
        final custList = await (_db.select(_db.customers)..where((t) => t.id.isIn(customerIds))).get();
        for (final c in custList) {
          customerMap[c.id] = c;
        }
      }
    }

    final Map<String, PurchaseInvoice> purchaseMap = {};
    final Map<String, PurchaseItem> purchaseItemMap = {};
    final Map<String, Supplier> supplierMap = {};

    if (purchaseIds.isNotEmpty) {
      final purchList = await (_db.select(_db.purchaseInvoices)..where((t) => t.id.isIn(purchaseIds))).get();
      for (final p in purchList) {
        purchaseMap[p.id] = p;
      }

      final pItems = await (_db.select(_db.purchaseItems)
            ..where((t) => t.productId.equals(productId) & t.purchaseInvoiceId.isIn(purchaseIds)))
          .get();
      for (final item in pItems) {
        purchaseItemMap[item.purchaseInvoiceId] = item;
      }

      final supplierIds = purchList.map((p) => p.supplierId).toSet();
      if (supplierIds.isNotEmpty) {
        final suppList = await (_db.select(_db.suppliers)..where((t) => t.id.isIn(supplierIds))).get();
        for (final s in suppList) {
          supplierMap[s.id] = s;
        }
      }
    }

    double runningBalance = 0.0;
    final List<ProductStockOperation> operations = [];

    for (final m in movements) {
      runningBalance += m.quantity;
      final isInitial = m.referenceId == 'initial_stock';
      final effectiveType = isInitial ? 'initial' : m.type;

      String? refNumber;
      String? party;
      double? unitPrice;

      if (isInitial) {
        party = 'المخزون الافتتاحي';
      } else if (m.type == 'sale' || m.type == 'return') {
        final inv = invoiceMap[m.referenceId];
        if (inv != null) {
          refNumber = inv.serialNumber != null
              ? '#${inv.serialNumber}'
              : (inv.id.length >= 8 ? inv.id.substring(0, 8) : inv.id);
          if (inv.customerId != null) {
            party = customerMap[inv.customerId]?.name;
          }
        }
        final item = invoiceItemMap[m.referenceId];
        if (item != null) {
          unitPrice = item.priceUsed;
        }
      } else if (m.type == 'purchase') {
        final purch = purchaseMap[m.referenceId];
        if (purch != null) {
          refNumber = purch.id.length >= 8 ? purch.id.substring(0, 8) : purch.id;
          party = supplierMap[purch.supplierId]?.name;
        }
        final item = purchaseItemMap[m.referenceId];
        if (item != null) {
          unitPrice = item.unitCost;
        }
      } else if (m.type == 'adjustment') {
        party = m.referenceId;
      }

      operations.add(ProductStockOperation(
        id: m.id,
        type: effectiveType,
        quantity: m.quantity,
        createdAt: m.createdAt,
        referenceNumber: refNumber,
        partyName: party,
        unitPrice: unitPrice,
        runningBalance: runningBalance,
      ));
    }

    return operations.reversed.toList();
  }
}
