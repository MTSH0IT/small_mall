import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_state.dart';
import 'package:small_mall/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';

void main() {
  group('AppCurrency Central Configuration Tests', () {
    test('Verify Primary Currency is Syrian Pound (SYP / ل.س)', () {
      expect(AppCurrency.primaryCode, equals('SYP'));
      expect(AppCurrency.primarySymbol, equals('ل.س'));
      expect(AppCurrency.primary.nameAr, equals('ليرة سورية'));
      expect(AppCurrency.primary.isPrimary, isTrue);
    });

    test('Verify Secondary Currency is US Dollar (USD / \$)', () {
      expect(AppCurrency.secondaryCode, equals('USD'));
      expect(AppCurrency.secondarySymbol, equals(r'$'));
      expect(AppCurrency.secondary.nameAr, equals('دولار أمريكي'));
      expect(AppCurrency.secondary.isPrimary, isFalse);
    });

    test('Verify currency lookup and fallbacks', () {
      expect(AppCurrency.fromCode('SYP').code, equals('SYP'));
      expect(AppCurrency.fromCode('USD').code, equals('USD'));
      // Fallback for null or unknown code returns primary currency
      expect(AppCurrency.fromCode(null).code, equals('SYP'));
      expect(AppCurrency.fromCode('EUR').code, equals('SYP'));

      expect(AppCurrency.getSymbol('SYP'), equals('ل.س'));
      expect(AppCurrency.getSymbol('USD'), equals(r'$'));
      expect(AppCurrency.getSymbol(null), equals('ل.س'));
    });

    test('Verify price formatting for both currencies', () {
      final sypFormatted = AppCurrency.format(5000, currencyCode: 'SYP');
      expect(sypFormatted, contains('5000'));
      expect(sypFormatted, contains('ل.س'));

      final usdFormatted = AppCurrency.format(25.5, currencyCode: 'USD');
      expect(usdFormatted, contains('25.5'));
      expect(usdFormatted, contains(r'$'));
    });
  });

  group('Database & InventoryRepository Multi-Currency Persistence Tests', () {
    late AppDatabase db;
    late AppLogger logger;
    late SyncService sync;
    late InventoryRepository repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      logger = AppLogger();
      sync = SyncService(db, logger);
      repository = InventoryRepository(db, sync, logger);
    });

    tearDown(() async {
      await db.close();
    });

    test('Adding product without specifying currency defaults to SYP', () async {
      await repository.addProduct(
        name: 'منتج بالليرة',
        categoryId: null,
        costPrice: 1000.0,
        minStockAlert: 5.0,
        initialStock: 10.0,
        prices: [
          {'price_label': 'retail', 'price_value': 1500.0},
          {'price_label': 'wholesale', 'price_value': 1200.0},
        ],
      );

      final products = await repository.getProducts();
      expect(products.length, equals(1));
      final item = products.first;

      expect(item.product.name, equals('منتج بالليرة'));
      expect(item.currency, equals('SYP'));
      expect(item.currencySymbol, equals('ل.س'));
      expect(item.prices.every((p) => p.currency == 'SYP'), isTrue);
    });

    test('Adding product with USD currency persists and reflects properly', () async {
      await repository.addProduct(
        name: 'منتج بالدولار',
        categoryId: null,
        costPrice: 10.0,
        minStockAlert: 5.0,
        initialStock: 20.0,
        currency: AppCurrency.secondaryCode,
        prices: [
          {
            'price_label': 'retail',
            'price_value': 15.0,
            'currency': AppCurrency.secondaryCode,
          },
          {
            'price_label': 'wholesale',
            'price_value': 12.5,
            'currency': AppCurrency.secondaryCode,
          },
        ],
      );

      final products = await repository.getProducts();
      final item = products.firstWhere((p) => p.product.name == 'منتج بالدولار');

      expect(item.product.name, equals('منتج بالدولار'));
      expect(item.currency, equals('USD'));
      expect(item.currencySymbol, equals(r'$'));
      expect(item.prices.length, equals(2));
      expect(item.prices.every((p) => p.currency == 'USD'), isTrue);
    });

    test('Updating product currency updates both product and price records', () async {
      await repository.addProduct(
        name: 'منتج سيتحول عملته',
        categoryId: null,
        costPrice: 500.0,
        minStockAlert: 5.0,
        initialStock: 5.0,
        currency: 'SYP',
        prices: [
          {'price_label': 'retail', 'price_value': 750.0},
        ],
      );

      // Verify created as SYP
      var products = await repository.getProducts();
      var item = products.firstWhere((p) => p.product.name == 'منتج سيتحول عملته');
      expect(item.currency, equals('SYP'));

      // Update to USD
      await repository.updateProduct(
        id: item.product.id,
        name: 'منتج تم تحويله للدولار',
        categoryId: null,
        costPrice: 2.0,
        minStockAlert: 5.0,
        currency: 'USD',
        prices: [
          {'price_label': 'retail', 'price_value': 3.0, 'currency': 'USD'},
        ],
      );

      products = await repository.getProducts();
      item = products.firstWhere((p) => p.product.id == item.product.id);

      expect(item.product.name, equals('منتج تم تحويله للدولار'));
      expect(item.currency, equals('USD'));
      expect(item.currencySymbol, equals(r'$'));
      expect(item.product.costPrice, equals(2.0));
      expect(item.prices.first.currency, equals('USD'));
      expect(item.prices.first.priceValue, equals(3.0));
    });

    test('Adding product with simultaneous dual prices (SYP and USD) persists and exposes getters', () async {
      await repository.addProduct(
        name: 'منتج ثنائي العملة',
        categoryId: null,
        costPrice: 5000.0,
        minStockAlert: 5.0,
        initialStock: 25.0,
        currency: 'SYP',
        prices: [
          {'price_label': 'retail', 'price_value': 15000.0, 'currency': 'SYP'},
          {'price_label': 'wholesale', 'price_value': 14000.0, 'currency': 'SYP'},
          {'price_label': 'retail', 'price_value': 1.00, 'currency': 'USD'},
          {'price_label': 'wholesale', 'price_value': 0.90, 'currency': 'USD'},
        ],
      );

      final products = await repository.getProducts();
      final item = products.firstWhere((p) => p.product.name == 'منتج ثنائي العملة');

      expect(item.prices.length, equals(4));
      expect(item.hasDualPrices, isTrue);
      expect(item.retailPriceSyp, equals(15000.0));
      expect(item.wholesalePriceSyp, equals(14000.0));
      expect(item.retailPriceUsd, equals(1.00));
      expect(item.wholesalePriceUsd, equals(0.90));

      // Test CartItem currency resolution
      final sypPrice = item.prices.firstWhere((p) => p.currency == 'SYP' && p.priceLabel == 'retail');
      final usdPrice = item.prices.firstWhere((p) => p.currency == 'USD' && p.priceLabel == 'retail');

      final cartItemSyp = CartItem(productDetails: item, selectedPrice: sypPrice, quantity: 2);
      expect(cartItemSyp.currency, equals('SYP'));
      expect(cartItemSyp.currencySymbol, equals('ل.س'));
      expect(cartItemSyp.subtotal, equals(30000.0));

      final cartItemUsd = CartItem(productDetails: item, selectedPrice: usdPrice, quantity: 3);
      expect(cartItemUsd.currency, equals('USD'));
      expect(cartItemUsd.currencySymbol, equals(r'$'));
      expect(cartItemUsd.subtotal, equals(3.00));
    });

    test('SuppliersPurchasingRepository updates both SYP and USD selling prices on purchase', () async {
      final suppRepo = SuppliersPurchasingRepository(db, sync, logger);

      // Create initial supplier
      await db.into(db.suppliers).insert(
        SuppliersCompanion.insert(
          id: 'sup-1',
          name: 'مورد الاختبار',
        ),
      );

      // Create product with initial prices
      await repository.addProduct(
        name: 'منتج شراء ثنائي',
        categoryId: null,
        costPrice: 5000.0,
        minStockAlert: 2.0,
        initialStock: 10.0,
        currency: 'SYP',
        prices: [
          {'price_label': 'retail', 'price_value': 10000.0, 'currency': 'SYP'},
          {'price_label': 'retail', 'price_value': 0.80, 'currency': 'USD'},
        ],
      );

      var products = await repository.getProducts();
      var prod = products.firstWhere((p) => p.product.name == 'منتج شراء ثنائي');

      // Record purchase and update both SYP and USD prices and cost prices
      await suppRepo.recordPurchase(
        supplierId: 'sup-1',
        totalAmount: 60000.0,
        items: [
          {
            'productId': prod.product.id,
            'quantity': 10.0,
            'unitCost': 6000.0,
            'unitCostUsd': 0.40,
            'retailPriceSyp': 12000.0,
            'wholesalePriceSyp': 11000.0,
            'retailPriceUsd': 0.95,
            'wholesalePriceUsd': 0.85,
          },
        ],
      );

      products = await repository.getProducts();
      prod = products.firstWhere((p) => p.product.id == prod.product.id);

      expect(prod.product.costPrice, equals(6000.0));
      expect(prod.product.costPriceUsd, equals(0.40));
      expect(prod.costPriceSyp, equals(6000.0));
      expect(prod.costPriceUsd, equals(0.40));
      expect(prod.hasDualCostPrices, isTrue);
      expect(prod.currentStock, equals(20.0));
      expect(prod.retailPriceSyp, equals(12000.0));
      expect(prod.wholesalePriceSyp, equals(11000.0));
      expect(prod.retailPriceUsd, equals(0.95));
      expect(prod.wholesalePriceUsd, equals(0.85));
    });

    test('Adding and updating product with dual cost prices (SYP and USD) persists and exposes getters', () async {
      await repository.addProduct(
        name: 'منتج تكلفة ثنائية',
        categoryId: null,
        costPrice: 7500.0,
        costPriceUsd: 0.50,
        minStockAlert: 5.0,
        initialStock: 15.0,
        currency: 'SYP',
        prices: [
          {'price_label': 'retail', 'price_value': 10000.0, 'currency': 'SYP'},
          {'price_label': 'retail', 'price_value': 0.70, 'currency': 'USD'},
        ],
      );

      var products = await repository.getProducts();
      var item = products.firstWhere((p) => p.product.name == 'منتج تكلفة ثنائية');

      expect(item.product.costPrice, equals(7500.0));
      expect(item.product.costPriceUsd, equals(0.50));
      expect(item.costPriceSyp, equals(7500.0));
      expect(item.costPriceUsd, equals(0.50));
      expect(item.hasDualCostPrices, isTrue);

      // Update both cost prices
      await repository.updateProduct(
        id: item.product.id,
        name: 'منتج تكلفة ثنائية معدل',
        categoryId: null,
        costPrice: 8000.0,
        costPriceUsd: 0.55,
        minStockAlert: 5.0,
        currency: 'SYP',
        prices: [
          {'price_label': 'retail', 'price_value': 11000.0, 'currency': 'SYP'},
          {'price_label': 'retail', 'price_value': 0.75, 'currency': 'USD'},
        ],
      );

      products = await repository.getProducts();
      item = products.firstWhere((p) => p.product.id == item.product.id);

      expect(item.product.costPrice, equals(8000.0));
      expect(item.product.costPriceUsd, equals(0.55));
      expect(item.costPriceSyp, equals(8000.0));
      expect(item.costPriceUsd, equals(0.55));
      expect(item.hasDualCostPrices, isTrue);
    });
  });
}
