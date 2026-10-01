import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';
import 'package:small_mall/core/services/app_settings_service.dart';
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

  String get currency => product.currency;
  String get currencySymbol => AppCurrency.getSymbol(product.currency);

  /// Dual Currency Price Getters
  ProductPrice? get retailPriceSypItem => prices
      .where(
        (p) =>
            p.priceLabel == 'retail' &&
            (p.currency == 'SYP' || p.currency == null || p.currency!.isEmpty),
      )
      .firstOrNull;
  ProductPrice? get retailPriceUsdItem => prices
      .where((p) => p.priceLabel == 'retail' && p.currency == 'USD')
      .firstOrNull;
  ProductPrice? get wholesalePriceSypItem => prices
      .where(
        (p) =>
            p.priceLabel == 'wholesale' &&
            (p.currency == 'SYP' || p.currency == null || p.currency!.isEmpty),
      )
      .firstOrNull;
  ProductPrice? get wholesalePriceUsdItem => prices
      .where((p) => p.priceLabel == 'wholesale' && p.currency == 'USD')
      .firstOrNull;

  double? get retailPriceSyp => retailPriceSypItem?.priceValue;
  double? get retailPriceUsd => retailPriceUsdItem?.priceValue;
  double? get wholesalePriceSyp => wholesalePriceSypItem?.priceValue;
  double? get wholesalePriceUsd => wholesalePriceUsdItem?.priceValue;

  /// Dual Currency Cost Price Getters
  double get costPriceSyp => product.costPrice;
  double get costPriceUsd => product.costPriceUsd;
  bool get hasDualCostPrices => costPriceSyp > 0 && costPriceUsd > 0;

  bool get hasDualPrices => retailPriceSyp != null && retailPriceUsd != null;

  bool get isLowStock =>
      product.minStockAlert > 0 && currentStock <= product.minStockAlert;

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
    this.referenceId,
    this.partyName,
    this.unitPrice,
    this.unitCost,
    this.currency = 'SYP',
    this.discount = 0.0,
    required this.runningBalance,
  });

  final String id;
  final String type; // 'initial', 'sale', 'purchase', 'return', 'adjustment'
  final double quantity;
  final DateTime createdAt;
  final String? referenceNumber;
  final String? referenceId;
  final String? partyName;
  final double? unitPrice;
  final double? unitCost;
  final String currency;
  final double discount;
  final double runningBalance;

  // Accounting & Financial Getters
  double get inflowQty => quantity > 0 ? quantity : 0.0;
  double get outflowQty => quantity < 0 ? quantity.abs() : 0.0;
  double get totalMovementValue => (unitPrice ?? 0.0) * quantity.abs();
  double get totalCostValue => (unitCost ?? 0.0) * quantity.abs();
  double? get grossProfit {
    if (type == 'sale') {
      return totalMovementValue - totalCostValue - discount;
    }
    if (type == 'return') {
      return -(totalMovementValue - totalCostValue);
    }
    return null;
  }

  String get currencySymbol => AppCurrency.getSymbol(currency);
  bool get isClickable => referenceId != null;

  String get typeLabel {
    switch (type) {
      case 'initial':
        return 'inventory.initial_balance'.tr();
      case 'sale':
        return 'inventory.sales'.tr();
      case 'purchase':
        return 'inventory.purchases'.tr();
      case 'return':
        return 'inventory.returns'.tr();
      case 'adjustment':
      default:
        return 'inventory.adjustments'.tr();
    }
  }
}

enum PriceRecalculationMode {
  /// Recalculates SYP prices based on USD prices: SYP = USD * rate
  usdToSyp,

  /// Smart: Recalculates SYP for items with USD, and calculates USD for items with only SYP
  smart,

  /// Recalculates USD prices based on SYP prices: USD = SYP / rate
  sypToUsd,
}

class RecalculatePricesResult {
  const RecalculatePricesResult({
    required this.totalProducts,
    required this.updatedProducts,
  });

  final int totalProducts;
  final int updatedProducts;
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
    return (_db.select(_db.categories)..orderBy([
          (t) => OrderingTerm.asc(t.serialNumber),
          (t) => OrderingTerm.asc(t.name),
        ]))
        .get();
  }

  Future<Category> addCategory(String name) async {
    _logger.info('Adding category: $name', context: LogContext.inventory);
    final id = _uuid.v4();
    final serialNumber = await _db.getNextCategorySerialNumber();
    final category = Category(id: id, name: name, serialNumber: serialNumber);
    await _db.into(_db.categories).insert(category);

    _sync.updatePendingCount();
    _sync.sync();
    return category;
  }

  Future<void> updateCategory(String id, String name) async {
    _logger.info(
      'Updating category: $id with name: $name',
      context: LogContext.inventory,
    );
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(name: Value(name), syncedAt: const Value(null)),
    );

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<void> deleteCategory(String id) async {
    _logger.info('Deleting category: $id', context: LogContext.inventory);

    // Unlink products assigned to this category
    final affectedProducts = await (_db.select(
      _db.products,
    )..where((t) => t.categoryId.equals(id))).get();
    for (final p in affectedProducts) {
      await (_db.update(_db.products)..where((t) => t.id.equals(p.id))).write(
        const ProductsCompanion(categoryId: Value(null), syncedAt: Value(null)),
      );
    }

    // Record deletion for sync
    await _db
        .into(_db.deletedRecords)
        .insert(
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
    final products = await (_db.select(
      _db.products,
    )..orderBy([(t) => OrderingTerm.asc(t.serialNumber)])).get();
    final categories = await getCategories();
    final allPrices = await _db.select(_db.productPrices).get();
    final stockBalances = await _db.getAllStockBalances();
    final initialStocks = await _db.getAllInitialStocks();

    final categoryMap = {for (var c in categories) c.id: c};

    return products.map((prod) {
      final category = prod.categoryId != null
          ? categoryMap[prod.categoryId]
          : null;
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
    double costPriceUsd = 0.0,
    required double minStockAlert,
    required List<Map<String, dynamic>> prices,
    required double initialStock,
    String? currency = 'SYP',
  }) async {
    _logger.info(
      'Adding product: $name, cost=$costPrice, costUsd=$costPriceUsd, stock=$initialStock, currency=$currency',
      context: LogContext.inventory,
    );
    final productId = _uuid.v4();
    final productCode = (code != null && code.trim().isNotEmpty)
        ? code.trim()
        : null;
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
        costPriceUsd: costPriceUsd,
        isActive: true,
        minStockAlert: minStockAlert,
        currency: currency ?? 'SYP',
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

        final priceCurrency =
            (price['currency'] as String?) ?? currency ?? 'SYP';

        final prodPrice = ProductPrice(
          id: priceId,
          productId: productId,
          priceLabel: label,
          priceValue: priceVal,
          currency: priceCurrency,
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
    double costPriceUsd = 0.0,
    required double minStockAlert,
    required List<Map<String, dynamic>> prices,
    double? initialStock,
    String? currency,
  }) async {
    _logger.info(
      'Updating product: $id, name=$name, cost=$costPrice, costUsd=$costPriceUsd, initialStock=$initialStock, currency=$currency',
      context: LogContext.inventory,
    );
    final now = DateTime.now();
    final productCode = (code != null && code.trim().isNotEmpty)
        ? code.trim()
        : null;

    await _db.transaction(() async {
      final productUpdate = ProductsCompanion(
        serialNumber: Value(serialNumber),
        code: Value(productCode),
        name: Value(name),
        categoryId: Value(categoryId),
        costPrice: Value(costPrice),
        costPriceUsd: Value(costPriceUsd),
        minStockAlert: Value(minStockAlert),
        currency: currency != null ? Value(currency) : const Value.absent(),
        updatedAt: Value(now),
        syncedAt: const Value(null),
      );

      // Update locally
      await (_db.update(
        _db.products,
      )..where((t) => t.id.equals(id))).write(productUpdate);

      // Handle prices: Simple way is delete old ones, insert new ones
      final oldPrices = await (_db.select(
        _db.productPrices,
      )..where((t) => t.productId.equals(id))).get();
      for (final oldPrice in oldPrices) {
        await _db
            .into(_db.deletedRecords)
            .insert(
              DeletedRecordsCompanion.insert(
                id: _uuid.v4(),
                targetTable: 'product_prices',
                recordId: oldPrice.id,
                createdAt: now,
              ),
            );
        await (_db.delete(
          _db.productPrices,
        )..where((t) => t.id.equals(oldPrice.id))).go();
      }

      for (final price in prices) {
        final priceId = _uuid.v4();
        final priceVal = (price['price_value'] as num).toDouble();
        final label = price['price_label'] as String;

        final priceCurrency =
            (price['currency'] as String?) ?? currency ?? 'SYP';

        final prodPrice = ProductPrice(
          id: priceId,
          productId: id,
          priceLabel: label,
          priceValue: priceVal,
          currency: priceCurrency,
        );

        await _db.into(_db.productPrices).insert(prodPrice);
      }

      // Handle Initial Stock Movement
      if (initialStock != null) {
        final existingInitialMovements = await (_db.select(_db.stockMovements)
              ..where(
                (t) =>
                    t.productId.equals(id) &
                    t.referenceId.equals('initial_stock'),
              ))
            .get();

        if (initialStock > 0) {
          if (existingInitialMovements.isNotEmpty) {
            // Update existing initial stock movement
            final firstMovement = existingInitialMovements.first;
            await (_db.update(_db.stockMovements)
                  ..where((t) => t.id.equals(firstMovement.id)))
                .write(
              StockMovementsCompanion(
                quantity: Value(initialStock),
                syncedAt: const Value(null),
              ),
            );

            // Clean up any extra initial movements if duplicates exist
            for (var i = 1; i < existingInitialMovements.length; i++) {
              await _db.into(_db.deletedRecords).insert(
                    DeletedRecordsCompanion.insert(
                      id: _uuid.v4(),
                      targetTable: 'stock_movements',
                      recordId: existingInitialMovements[i].id,
                      createdAt: now,
                    ),
                  );
              await (_db.delete(_db.stockMovements)
                    ..where((t) => t.id.equals(existingInitialMovements[i].id)))
                  .go();
            }
          } else {
            // Create new initial stock movement
            final movementId = _uuid.v4();
            final movement = StockMovement(
              id: movementId,
              productId: id,
              type: 'adjustment',
              quantity: initialStock,
              createdAt: now,
              referenceId: 'initial_stock',
            );
            await _db.into(_db.stockMovements).insert(movement);
          }
        } else {
          // If initialStock is 0, delete any existing initial stock movements
          for (final movement in existingInitialMovements) {
            await _db.into(_db.deletedRecords).insert(
                  DeletedRecordsCompanion.insert(
                    id: _uuid.v4(),
                    targetTable: 'stock_movements',
                    recordId: movement.id,
                    createdAt: now,
                  ),
                );
            await (_db.delete(_db.stockMovements)
                  ..where((t) => t.id.equals(movement.id)))
                .go();
          }
        }
      }
    });

    _sync.updatePendingCount();
    _sync.sync();
  }

  /// Bulk recalculate all product prices based on current exchange rate
  Future<RecalculatePricesResult> recalculateAllProductPrices({
    required double exchangeRate,
    PriceRecalculationMode mode = PriceRecalculationMode.usdToSyp,
  }) async {
    if (exchangeRate <= 0) {
      return const RecalculatePricesResult(
        totalProducts: 0,
        updatedProducts: 0,
      );
    }

    _logger.info(
      'Bulk repricing started with rate=$exchangeRate, mode=$mode',
      context: LogContext.inventory,
    );

    final products = await getProducts();
    if (products.isEmpty) {
      return const RecalculatePricesResult(
        totalProducts: 0,
        updatedProducts: 0,
      );
    }

    final now = DateTime.now();
    int updatedCount = 0;

    await _db.transaction(() async {
      for (final item in products) {
        final prod = item.product;
        final costSyp = item.costPriceSyp;
        final costUsd = item.costPriceUsd;
        final retailSypItem = item.retailPriceSypItem;
        final retailUsdItem = item.retailPriceUsdItem;
        final wholesaleSypItem = item.wholesalePriceSypItem;
        final wholesaleUsdItem = item.wholesalePriceUsdItem;

        final hasUsdPrices =
            (costUsd > 0) ||
            (retailUsdItem != null && retailUsdItem.priceValue > 0) ||
            (wholesaleUsdItem != null && wholesaleUsdItem.priceValue > 0);

        final hasSypPrices =
            (costSyp > 0) ||
            (retailSypItem != null && retailSypItem.priceValue > 0) ||
            (wholesaleSypItem != null && wholesaleSypItem.priceValue > 0);

        double newCostSyp = costSyp;
        double newCostUsd = costUsd;
        double? newRetailSyp = retailSypItem?.priceValue;
        double? newRetailUsd = retailUsdItem?.priceValue;
        double? newWholesaleSyp = wholesaleSypItem?.priceValue;
        double? newWholesaleUsd = wholesaleUsdItem?.priceValue;

        bool shouldUpdate = false;

        if (mode == PriceRecalculationMode.usdToSyp) {
          if (hasUsdPrices) {
            if (costUsd > 0) {
              newCostSyp = (costUsd * exchangeRate).roundToDouble();
            }
            if (retailUsdItem != null && retailUsdItem.priceValue > 0) {
              newRetailSyp = (retailUsdItem.priceValue * exchangeRate)
                  .roundToDouble();
            }
            if (wholesaleUsdItem != null && wholesaleUsdItem.priceValue > 0) {
              newWholesaleSyp = (wholesaleUsdItem.priceValue * exchangeRate)
                  .roundToDouble();
            }
            shouldUpdate = true;
          }
        } else if (mode == PriceRecalculationMode.sypToUsd) {
          if (hasSypPrices) {
            if (costSyp > 0) {
              newCostUsd = double.parse(
                (costSyp / exchangeRate).toStringAsFixed(2),
              );
            }
            if (retailSypItem != null && retailSypItem.priceValue > 0) {
              newRetailUsd = double.parse(
                (retailSypItem.priceValue / exchangeRate).toStringAsFixed(2),
              );
            }
            if (wholesaleSypItem != null && wholesaleSypItem.priceValue > 0) {
              newWholesaleUsd = double.parse(
                (wholesaleSypItem.priceValue / exchangeRate).toStringAsFixed(2),
              );
            }
            shouldUpdate = true;
          }
        } else if (mode == PriceRecalculationMode.smart) {
          if (hasUsdPrices) {
            if (costUsd > 0) {
              newCostSyp = (costUsd * exchangeRate).roundToDouble();
            }
            if (retailUsdItem != null && retailUsdItem.priceValue > 0) {
              newRetailSyp = (retailUsdItem.priceValue * exchangeRate)
                  .roundToDouble();
            }
            if (wholesaleUsdItem != null && wholesaleUsdItem.priceValue > 0) {
              newWholesaleSyp = (wholesaleUsdItem.priceValue * exchangeRate)
                  .roundToDouble();
            }
            shouldUpdate = true;
          } else if (hasSypPrices) {
            if (costSyp > 0) {
              newCostUsd = double.parse(
                (costSyp / exchangeRate).toStringAsFixed(2),
              );
            }
            if (retailSypItem != null && retailSypItem.priceValue > 0) {
              newRetailUsd = double.parse(
                (retailSypItem.priceValue / exchangeRate).toStringAsFixed(2),
              );
            }
            if (wholesaleSypItem != null && wholesaleSypItem.priceValue > 0) {
              newWholesaleUsd = double.parse(
                (wholesaleSypItem.priceValue / exchangeRate).toStringAsFixed(2),
              );
            }
            shouldUpdate = true;
          }
        }

        if (shouldUpdate) {
          updatedCount++;
          await (_db.update(
            _db.products,
          )..where((t) => t.id.equals(prod.id))).write(
            ProductsCompanion(
              costPrice: Value(newCostSyp),
              costPriceUsd: Value(newCostUsd),
              updatedAt: Value(now),
              syncedAt: const Value(null),
            ),
          );

          Future<void> upsertPrice(
            String label,
            String curr,
            double? val,
            ProductPrice? existing,
          ) async {
            if (val == null || val <= 0) return;
            if (existing != null) {
              await (_db.update(
                _db.productPrices,
              )..where((t) => t.id.equals(existing.id))).write(
                ProductPricesCompanion(
                  priceValue: Value(val),
                  currency: Value(curr),
                ),
              );
            } else {
              await _db
                  .into(_db.productPrices)
                  .insert(
                    ProductPrice(
                      id: _uuid.v4(),
                      productId: prod.id,
                      priceLabel: label,
                      priceValue: val,
                      currency: curr,
                    ),
                  );
            }
          }

          await upsertPrice('retail', 'SYP', newRetailSyp, retailSypItem);
          await upsertPrice(
            'wholesale',
            'SYP',
            newWholesaleSyp,
            wholesaleSypItem,
          );
          await upsertPrice('retail', 'USD', newRetailUsd, retailUsdItem);
          await upsertPrice(
            'wholesale',
            'USD',
            newWholesaleUsd,
            wholesaleUsdItem,
          );
        }
      }
    });

    _sync.updatePendingCount();
    _sync.sync();

    _logger.info(
      'Bulk repricing completed: $updatedCount/${products.length} products updated',
      context: LogContext.inventory,
    );

    return RecalculatePricesResult(
      totalProducts: products.length,
      updatedProducts: updatedCount,
    );
  }

  Future<void> deleteProduct(String id) async {
    _logger.info('Soft-deleting product: $id', context: LogContext.inventory);
    final now = DateTime.now();
    await (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(
        isActive: const Value(false),
        updatedAt: Value(now),
        syncedAt: const Value(null),
      ),
    );

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<void> adjustStock(
    String productId,
    double quantity,
    String reason,
  ) async {
    _logger.info(
      'Adjusting stock: product=$productId, qty=$quantity, reason=$reason',
      context: LogContext.inventory,
    );
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

  Future<List<ProductStockOperation>> getProductOperations(
    String productId,
  ) async {
    _logger.debug(
      'Fetching operations for product: $productId',
      context: LogContext.inventory,
    );

    final movements =
        await (_db.select(_db.stockMovements)
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
    final Map<String, List<InvoiceItem>> invoiceItemsMap = {};
    final Map<String, Customer> customerMap = {};

    if (invoiceIds.isNotEmpty) {
      final invList = await (_db.select(
        _db.invoices,
      )..where((t) => t.id.isIn(invoiceIds))).get();
      for (final inv in invList) {
        invoiceMap[inv.id] = inv;
      }

      final items =
          await (_db.select(_db.invoiceItems)..where(
                (t) =>
                    t.productId.equals(productId) &
                    t.invoiceId.isIn(invoiceIds),
              ))
              .get();
      for (final item in items) {
        invoiceItemsMap.putIfAbsent(item.invoiceId, () => []).add(item);
      }

      final customerIds = invList
          .map((i) => i.customerId)
          .whereType<String>()
          .toSet();
      if (customerIds.isNotEmpty) {
        final custList = await (_db.select(
          _db.customers,
        )..where((t) => t.id.isIn(customerIds))).get();
        for (final c in custList) {
          customerMap[c.id] = c;
        }
      }
    }

    final Map<String, PurchaseInvoice> purchaseMap = {};
    final Map<String, List<PurchaseItem>> purchaseItemsMap = {};
    final Map<String, Supplier> supplierMap = {};

    if (purchaseIds.isNotEmpty) {
      final purchList = await (_db.select(
        _db.purchaseInvoices,
      )..where((t) => t.id.isIn(purchaseIds))).get();
      for (final p in purchList) {
        purchaseMap[p.id] = p;
      }

      final pItems =
          await (_db.select(_db.purchaseItems)..where(
                (t) =>
                    t.productId.equals(productId) &
                    t.purchaseInvoiceId.isIn(purchaseIds),
              ))
              .get();
      for (final item in pItems) {
        purchaseItemsMap
            .putIfAbsent(item.purchaseInvoiceId, () => [])
            .add(item);
      }

      final supplierIds = purchList.map((p) => p.supplierId).toSet();
      if (supplierIds.isNotEmpty) {
        final suppList = await (_db.select(
          _db.suppliers,
        )..where((t) => t.id.isIn(supplierIds))).get();
        for (final s in suppList) {
          supplierMap[s.id] = s;
        }
      }
    }

    final product = await (_db.select(
      _db.products,
    )..where((t) => t.id.equals(productId))).getSingleOrNull();
    final purchaseSerialMap = await _db.getPurchaseSerialNumbers();
    final adjustmentSerialMap = await _db.getAdjustmentSerialNumbers();

    // Query all purchase items and their invoices for this product to build a historical cost timeline
    final allProductPurchases = await (_db.select(_db.purchaseItems)
          ..where((t) => t.productId.equals(productId)))
        .get();

    final allPurchInvoiceIds = allProductPurchases.map((p) => p.purchaseInvoiceId).toSet();
    final allPurchInvoices = allPurchInvoiceIds.isNotEmpty
        ? await (_db.select(_db.purchaseInvoices)..where((t) => t.id.isIn(allPurchInvoiceIds))).get()
        : <PurchaseInvoice>[];
    final purchInvoiceDateMap = {for (final pi in allPurchInvoices) pi.id: pi.createdAt};

    final exchangeRate = AppSettingsService.usdExchangeRate;

    // Helper to resolve historical unit cost active on or before a given movement timestamp
    double? resolveHistoricalUnitCost(String targetCurrency, DateTime movementDate) {
      // 1. Filter purchases that took place on or before this movement date
      final validPurchases = allProductPurchases.where((p) {
        final pDate = purchInvoiceDateMap[p.purchaseInvoiceId];
        return pDate == null || !pDate.isAfter(movementDate);
      }).toList();

      if (targetCurrency == AppCurrency.usdCode) {
        // Direct USD purchase on or before movement
        final usdPurchases = validPurchases.where((p) => p.currency == AppCurrency.usdCode && p.unitCost > 0).toList();
        if (usdPurchases.isNotEmpty) {
          return usdPurchases.last.unitCost;
        }
        // Converted SYP purchase on or before movement
        final sypPurchases = validPurchases.where((p) => p.currency != AppCurrency.usdCode && p.unitCost > 0).toList();
        if (sypPurchases.isNotEmpty && exchangeRate > 0) {
          return sypPurchases.last.unitCost / exchangeRate;
        }
        // Direct product USD cost if product created on or before movement
        if ((product?.costPriceUsd ?? 0) > 0) {
          return product!.costPriceUsd;
        }
        if ((product?.costPrice ?? 0) > 0 && exchangeRate > 0) {
          return product!.costPrice / exchangeRate;
        }
        return 0.0;
      } else {
        // Target currency is SYP
        final sypPurchases = validPurchases.where((p) => p.currency != AppCurrency.usdCode && p.unitCost > 0).toList();
        if (sypPurchases.isNotEmpty) {
          return sypPurchases.last.unitCost;
        }
        final usdPurchases = validPurchases.where((p) => p.currency == AppCurrency.usdCode && p.unitCost > 0).toList();
        if (usdPurchases.isNotEmpty && exchangeRate > 0) {
          return usdPurchases.last.unitCost * exchangeRate;
        }
        if ((product?.costPrice ?? 0) > 0) {
          return product!.costPrice;
        }
        if ((product?.costPriceUsd ?? 0) > 0 && exchangeRate > 0) {
          return product!.costPriceUsd * exchangeRate;
        }
        return 0.0;
      }
    }

    // Create pools so movements can consume items matching their quantity and currency
    final remainingInvoiceItems = <String, List<InvoiceItem>>{};
    invoiceItemsMap.forEach((k, v) => remainingInvoiceItems[k] = List.from(v));

    final remainingPurchaseItems = <String, List<PurchaseItem>>{};
    purchaseItemsMap.forEach(
      (k, v) => remainingPurchaseItems[k] = List.from(v),
    );

    double runningBalance = 0.0;
    final List<ProductStockOperation> operations = [];

    for (final m in movements) {
      runningBalance += m.quantity;
      final isInitial = m.referenceId == 'initial_stock';
      final effectiveType = isInitial ? 'initial' : m.type;

      String? refNumber;
      String? party;
      double? unitPrice;
      double? unitCost;
      String opCurrency = product?.currency ?? AppCurrency.sypCode;
      double itemDiscount = 0.0;

      if (isInitial) {
        party = 'inventory.initial_balance'.tr();
        opCurrency = product?.currency ?? AppCurrency.sypCode;
        unitCost = resolveHistoricalUnitCost(opCurrency, m.createdAt);
        unitPrice = unitCost;
      } else if (m.type == 'sale' || m.type == 'return') {
        final inv = invoiceMap[m.referenceId];
        if (inv != null) {
          opCurrency = inv.currency;
          refNumber = inv.serialNumber != null
              ? '#${inv.serialNumber}'
              : (inv.id.length >= 8 ? inv.id.substring(0, 8) : inv.id);
          if (inv.customerId != null) {
            party = customerMap[inv.customerId]?.name;
          }
        }

        final pool = remainingInvoiceItems[m.referenceId];
        InvoiceItem? item;
        if (pool != null && pool.isNotEmpty) {
          final matchIdx = pool.indexWhere(
            (it) => it.quantity == m.quantity.abs(),
          );
          item = matchIdx >= 0 ? pool.removeAt(matchIdx) : pool.removeAt(0);
        }

        if (item != null) {
          opCurrency = item.currency; // Exact currency of the individual item
          unitPrice = item.priceUsed;
          itemDiscount = item.discount;
        }

        if (item != null && item.costPrice != null && item.costPrice! > 0) {
          // Locked historical cost preserved on the invoice item at the exact moment of sale
          unitCost = item.costPrice;
        } else {
          // Fallback to historical purchase cost active on or before this sale date
          unitCost = resolveHistoricalUnitCost(opCurrency, m.createdAt);
        }
      } else if (m.type == 'purchase') {
        final purch = purchaseMap[m.referenceId];
        if (purch != null) {
          opCurrency = purch.currency;
          final serial = purchaseSerialMap[purch.id];
          refNumber = serial != null
              ? '#$serial'
              : (purch.id.length >= 8 ? purch.id.substring(0, 8) : purch.id);
          party = supplierMap[purch.supplierId]?.name;
        }

        final pool = remainingPurchaseItems[m.referenceId];
        PurchaseItem? item;
        if (pool != null && pool.isNotEmpty) {
          final matchIdx = pool.indexWhere(
            (it) => it.quantity == m.quantity.abs(),
          );
          item = matchIdx >= 0 ? pool.removeAt(matchIdx) : pool.removeAt(0);
        }

        if (item != null) {
          opCurrency = item.currency; // Exact currency of the individual item
          unitPrice = item.unitCost;
          unitCost = item.unitCost;
        }
      } else if (m.type == 'adjustment') {
        final serial = adjustmentSerialMap[m.id];
        refNumber = serial != null ? '#$serial' : '-';
        final reason = m.referenceId;
        party = (reason != null && reason.trim().isNotEmpty)
            ? reason
            : 'inventory.adjustments'.tr();
        opCurrency = product?.currency ?? AppCurrency.sypCode;
        unitCost = resolveHistoricalUnitCost(opCurrency, m.createdAt);
        unitPrice = unitCost;
      }

      operations.add(
        ProductStockOperation(
          id: m.id,
          type: effectiveType,
          quantity: m.quantity,
          createdAt: m.createdAt,
          referenceNumber: refNumber,
          referenceId: isInitial
              ? null
              : (m.type == 'adjustment' ? m.id : m.referenceId),
          partyName: party,
          unitPrice: unitPrice,
          unitCost: unitCost,
          currency: opCurrency,
          discount: itemDiscount,
          runningBalance: runningBalance,
        ),
      );
    }

    return operations.reversed.toList();
  }
}
