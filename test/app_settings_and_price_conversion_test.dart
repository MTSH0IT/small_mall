import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/services/app_settings_service.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsService & Price Conversion Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppSettingsService.init();
    });

    test('Initial defaults should be 0.0 for exchange rate and 5.0 for defaultMinStock', () {
      expect(AppSettingsService.usdExchangeRate, 0.0);
      expect(AppSettingsService.hasExchangeRate, false);
      expect(AppSettingsService.defaultMinStockAlert, 5.0);
    });

    test('Saving and loading settings should persist properly', () async {
      await AppSettingsService.saveSettings(
        exchangeRate: 15000.0,
        defaultMinStock: 10.0,
      );

      expect(AppSettingsService.usdExchangeRate, 15000.0);
      expect(AppSettingsService.hasExchangeRate, true);
      expect(AppSettingsService.defaultMinStockAlert, 10.0);

      // Re-init to simulate app restart
      await AppSettingsService.init();
      expect(AppSettingsService.usdExchangeRate, 15000.0);
      expect(AppSettingsService.defaultMinStockAlert, 10.0);
    });

    test('Bidirectional conversion: USD to SYP', () async {
      await AppSettingsService.saveSettings(
        exchangeRate: 15000.0,
        defaultMinStock: 5.0,
      );

      expect(AppSettingsService.convertUsdToSyp(1.0), 15000.0);
      expect(AppSettingsService.convertUsdToSyp(2.5), 37500.0);
      expect(AppSettingsService.formatSyp(37500.0), '37500');
    });

    test('Bidirectional conversion: SYP to USD', () async {
      await AppSettingsService.saveSettings(
        exchangeRate: 15000.0,
        defaultMinStock: 5.0,
      );

      expect(AppSettingsService.convertSypToUsd(15000.0), 1.0);
      expect(AppSettingsService.convertSypToUsd(30000.0), 2.0);
      expect(AppSettingsService.convertSypToUsd(7500.0), 0.5);
      expect(AppSettingsService.formatUsd(0.5), '0.50');
      expect(AppSettingsService.formatUsd(2.0), '2');
    });

    test('Parsing numbers handles Arabic numerals and commas', () {
      expect(AppSettingsService.parseNumber('١٥٠٠٠'), 15000.0);
      expect(AppSettingsService.parseNumber('15,5'), 15.5);
      expect(AppSettingsService.parseNumber('١٢,٥'), 12.5);
      expect(AppSettingsService.parseNumber(''), null);
      expect(AppSettingsService.parseNumber(null), null);
      expect(AppSettingsService.parseNumber('abc'), null);
    });
  });

  group('Bulk Repricing Tests in InventoryRepository', () {
    late AppDatabase db;
    late SyncService syncService;
    late InventoryRepository repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final logger = AppLogger();
      syncService = SyncService(db, logger);
      repository = InventoryRepository(db, syncService, logger);
    });

    tearDown(() async {
      await db.close();
    });

    test('recalculateAllProductPrices with usdToSyp updates SYP prices from USD', () async {
      await repository.addProduct(
        name: 'منتج مسعر بالدولار',
        categoryId: null,
        costPrice: 0.0,
        costPriceUsd: 2.0,
        minStockAlert: 5.0,
        initialStock: 10.0,
        prices: [
          {'price_label': 'retail', 'price_value': 3.0, 'currency': 'USD'},
          {'price_label': 'wholesale', 'price_value': 2.5, 'currency': 'USD'},
        ],
      );

      final result = await repository.recalculateAllProductPrices(
        exchangeRate: 15000.0,
        mode: PriceRecalculationMode.usdToSyp,
      );

      expect(result.totalProducts, 1);
      expect(result.updatedProducts, 1);

      final products = await repository.getProducts();
      final p = products.first;
      expect(p.costPriceSyp, 30000.0); // 2.0 * 15000
      expect(p.costPriceUsd, 2.0); // USD unchanged
      expect(p.retailPriceSyp, 45000.0); // 3.0 * 15000
      expect(p.wholesalePriceSyp, 37500.0); // 2.5 * 15000
      expect(p.retailPriceUsd, 3.0);
      expect(p.wholesalePriceUsd, 2.5);
    });

    test('recalculateAllProductPrices with smart mode updates both directions appropriately', () async {
      // Product 1: only has USD
      await repository.addProduct(
        name: 'منتج بالدولار فقط',
        categoryId: null,
        costPrice: 0.0,
        costPriceUsd: 10.0,
        minStockAlert: 5.0,
        initialStock: 5.0,
        prices: [
          {'price_label': 'retail', 'price_value': 12.0, 'currency': 'USD'},
        ],
      );

      // Product 2: only has SYP
      await repository.addProduct(
        name: 'منتج بالسوري فقط',
        categoryId: null,
        costPrice: 15000.0,
        costPriceUsd: 0.0,
        minStockAlert: 5.0,
        initialStock: 5.0,
        prices: [
          {'price_label': 'retail', 'price_value': 30000.0, 'currency': 'SYP'},
        ],
      );

      final result = await repository.recalculateAllProductPrices(
        exchangeRate: 15000.0,
        mode: PriceRecalculationMode.smart,
      );

      expect(result.totalProducts, 2);
      expect(result.updatedProducts, 2);

      final products = await repository.getProducts();
      final prodUsd = products.firstWhere((p) => p.product.name == 'منتج بالدولار فقط');
      final prodSyp = products.firstWhere((p) => p.product.name == 'منتج بالسوري فقط');

      // Product 1 SYP updated from USD
      expect(prodUsd.costPriceSyp, 150000.0); // 10 * 15000
      expect(prodUsd.retailPriceSyp, 180000.0); // 12 * 15000

      // Product 2 USD calculated from SYP
      expect(prodSyp.costPriceUsd, 1.0); // 15000 / 15000
      expect(prodSyp.retailPriceUsd, 2.0); // 30000 / 15000
    });
  });
}
