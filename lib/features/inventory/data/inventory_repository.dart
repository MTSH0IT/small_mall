import 'package:drift/drift.dart';
import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:artisan_gift_manager/core/sync/sync_service.dart';
import 'package:uuid/uuid.dart';

class ProductWithDetails {
  final Product product;
  final Category? category;
  final List<ProductPrice> prices;
  final double currentStock;

  ProductWithDetails({
    required this.product,
    this.category,
    required this.prices,
    required this.currentStock,
  });

  bool get isLowStock => product.minStockAlert > 0 && currentStock <= product.minStockAlert;
}

class InventoryRepository {
  final AppDatabase _db;
  final SyncService _sync;
  final _uuid = const Uuid();

  InventoryRepository(this._db, this._sync);

  // --- Categories ---

  Future<List<Category>> getCategories() async {
    return _db.select(_db.categories).get();
  }

  Future<Category> addCategory(String name) async {
    final id = _uuid.v4();
    final category = Category(id: id, name: name);
    await _db.into(_db.categories).insert(category);

    // Sync
    await _sync.enqueue('categories', id, 'insert', {
      'id': id,
      'name': name,
    });

    return category;
  }

  // --- Products ---

  Future<List<ProductWithDetails>> getProducts() async {
    final products = await _db.select(_db.products).get();
    final categories = await getCategories();
    final allPrices = await _db.select(_db.productPrices).get();
    final allMovements = await _db.select(_db.stockMovements).get();

    final categoryMap = {for (var c in categories) c.id: c};

    return products.map((prod) {
      final category = prod.categoryId != null ? categoryMap[prod.categoryId] : null;
      final prices = allPrices.where((p) => p.productId == prod.id).toList();

      // Sum all movements for this product to get current stock
      final currentStock = allMovements
          .where((m) => m.productId == prod.id)
          .fold<double>(0.0, (sum, m) => sum + m.quantity);

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
    required List<Map<String, dynamic>> prices, // price_label, price_value
    required double initialStock,
  }) async {
    final productId = _uuid.v4();
    final now = DateTime.now();

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

    // Sync Product
    await _sync.enqueue('products', productId, 'insert', {
      'id': productId,
      'name': name,
      'category_id': categoryId,
      'cost_price': costPrice,
      'is_active': true,
      'min_stock_alert': minStockAlert,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

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

      // Sync Price
      await _sync.enqueue('product_prices', priceId, 'insert', {
        'id': priceId,
        'product_id': productId,
        'price_label': label,
        'price_value': priceVal,
      });
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

      // Sync Movement
      await _sync.enqueue('stock_movements', movementId, 'insert', {
        'id': movementId,
        'product_id': productId,
        'type': 'adjustment',
        'quantity': initialStock,
        'created_at': now.toIso8601String(),
        'reference_id': 'initial_stock',
      });
    }
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required String? categoryId,
    required double costPrice,
    required double minStockAlert,
    required List<Map<String, dynamic>> prices,
  }) async {
    final now = DateTime.now();

    final productUpdate = ProductsCompanion(
      name: Value(name),
      categoryId: Value(categoryId),
      costPrice: Value(costPrice),
      minStockAlert: Value(minStockAlert),
      updatedAt: Value(now),
    );

    // Update locally
    await (_db.update(_db.products)..where((t) => t.id.equals(id))).write(productUpdate);

    // Sync update
    await _sync.enqueue('products', id, 'update', {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'cost_price': costPrice,
      'min_stock_alert': minStockAlert,
      'updated_at': now.toIso8601String(),
    });

    // Handle prices: Simple way is delete old ones, insert new ones
    final oldPrices = await (_db.select(_db.productPrices)..where((t) => t.productId.equals(id))).get();
    for (final oldPrice in oldPrices) {
      await (_db.delete(_db.productPrices)..where((t) => t.id.equals(oldPrice.id))).go();
      await _sync.enqueue('product_prices', oldPrice.id, 'delete', {});
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

      await _sync.enqueue('product_prices', priceId, 'insert', {
        'id': priceId,
        'product_id': id,
        'price_label': label,
        'price_value': priceVal,
      });
    }
  }

  Future<void> deleteProduct(String id) async {
    // Soft delete product (set isActive = false)
    final now = DateTime.now();
    await (_db.update(_db.products)..where((t) => t.id.equals(id)))
        .write(ProductsCompanion(isActive: const Value(false), updatedAt: Value(now)));

    await _sync.enqueue('products', id, 'update', {
      'id': id,
      'is_active': false,
      'updated_at': now.toIso8601String(),
    });
  }

  Future<void> adjustStock(String productId, double quantity, String reason) async {
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

    await _sync.enqueue('stock_movements', id, 'insert', {
      'id': id,
      'product_id': productId,
      'type': 'adjustment',
      'quantity': quantity,
      'created_at': now.toIso8601String(),
      'reference_id': reason,
    });
  }
}
