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
  });
  final Product product;
  final Category? category;
  final List<ProductPrice> prices;
  final double currentStock;

  bool get isLowStock => product.minStockAlert > 0 && currentStock <= product.minStockAlert;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductWithDetails && other.product.id == product.id);

  @override
  int get hashCode => product.id.hashCode;
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
    return _db.select(_db.categories).get();
  }

  Future<Category> addCategory(String name) async {
    _logger.info('Adding category: $name', context: LogContext.inventory);
    final id = _uuid.v4();
    final category = Category(id: id, name: name);
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
    final products = await _db.select(_db.products).get();
    final categories = await getCategories();
    final allPrices = await _db.select(_db.productPrices).get();
    final stockBalances = await _db.getAllStockBalances();

    final categoryMap = {for (var c in categories) c.id: c};

    return products.map((prod) {
      final category = prod.categoryId != null ? categoryMap[prod.categoryId] : null;
      final prices = allPrices.where((p) => p.productId == prod.id).toList();
      final currentStock = stockBalances[prod.id] ?? 0.0;

      return ProductWithDetails(
        product: prod,
        category: category,
        prices: prices,
        currentStock: currentStock,
      );
    }).toList();
  }

  Future<void> addProduct({
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
    final now = DateTime.now();

    await _db.transaction(() async {
      final product = Product(
        id: productId,
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
    required String name,
    required String? categoryId,
    required double costPrice,
    required double minStockAlert,
    required List<Map<String, dynamic>> prices,
  }) async {
    _logger.info('Updating product: $id, name=$name, cost=$costPrice',
        context: LogContext.inventory);
    final now = DateTime.now();

    await _db.transaction(() async {
      final productUpdate = ProductsCompanion(
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
}
