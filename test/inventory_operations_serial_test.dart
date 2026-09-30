import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';

void main() {
  late AppDatabase db;
  late AppLogger logger;
  late SyncService sync;
  late InventoryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = AppLogger();
    sync = SyncService(db, logger);
    repo = InventoryRepository(db, sync, logger);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'getProductOperations assigns sequential serial numbers to purchases and adjustments',
    () async {
      final now = DateTime.now();

      // Insert category and product
      await db
          .into(db.categories)
          .insert(CategoriesCompanion.insert(id: 'cat-1', name: 'General'));

      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              id: 'prod-1',
              name: 'Test Product',
              categoryId: const Value('cat-1'),
              costPrice: const Value(30.0),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Insert purchase invoice and items
      await db
          .into(db.purchaseInvoices)
          .insert(
            PurchaseInvoicesCompanion.insert(
              id: 'purch-uuid-1',
              supplierId: 'supp-1',
              totalAmount: 300.0,
              createdAt: now.subtract(const Duration(hours: 2)),
            ),
          );

      await db
          .into(db.purchaseItems)
          .insert(
            PurchaseItemsCompanion.insert(
              id: 'item-1',
              purchaseInvoiceId: 'purch-uuid-1',
              productId: 'prod-1',
              quantity: 10,
              unitCost: 30.0,
            ),
          );

      // Insert stock movement for purchase
      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: 'mov-purch-1',
              productId: 'prod-1',
              type: 'purchase',
              quantity: 10,
              referenceId: const Value('purch-uuid-1'),
              createdAt: now.subtract(const Duration(hours: 2)),
            ),
          );

      // Insert stock adjustment movement
      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: 'adj-uuid-1',
              productId: 'prod-1',
              type: 'adjustment',
              quantity: 5,
              createdAt: now.subtract(const Duration(hours: 1)),
            ),
          );

      // Fetch operations
      final ops = await repo.getProductOperations('prod-1');

      expect(ops.length, 2);

      // Adjustment check
      final adjOp = ops.firstWhere((o) => o.type == 'adjustment');
      expect(adjOp.referenceNumber, '#1');
      expect(adjOp.referenceId, 'adj-uuid-1');

      // Purchase check
      final purchOp = ops.firstWhere((o) => o.type == 'purchase');
      expect(purchOp.referenceNumber, '#1');
      expect(purchOp.referenceId, 'purch-uuid-1');
    },
  );

  test(
    'ProductStockOperation computes inflow, outflow, valuation, and profit margins correctly',
    () async {
      final now = DateTime.now();

      // 1. Initial / Purchase
      final purchOp = ProductStockOperation(
        id: 'op-1',
        createdAt: now.subtract(const Duration(days: 2)),
        type: 'purchase',
        quantity: 20,
        runningBalance: 20,
        unitPrice: 50.0,
        unitCost: 50.0,
        currency: 'USD',
        discount: 0.0,
        referenceNumber: '#101',
      );

      expect(purchOp.inflowQty, 20);
      expect(purchOp.outflowQty, 0);
      expect(purchOp.totalMovementValue, 1000.0);
      expect(purchOp.currencySymbol, '\$');

      // 2. Sale
      final saleOp = ProductStockOperation(
        id: 'op-2',
        createdAt: now.subtract(const Duration(days: 1)),
        type: 'sale',
        quantity: -5,
        runningBalance: 15,
        unitPrice: 75.0,
        unitCost: 50.0,
        currency: 'USD',
        discount: 25.0, // e.g. \$25 discount
        referenceNumber: '#INV-001',
      );

      expect(saleOp.inflowQty, 0);
      expect(saleOp.outflowQty, 5);
      expect(saleOp.totalMovementValue, 375.0); // 5 * 75
      expect(saleOp.totalCostValue, 250.0); // 5 * 50
      expect(saleOp.grossProfit, 100.0); // 375 - 250 - 25

      // 3. Negative Stock Adjustment
      final adjOpNeg = ProductStockOperation(
        id: 'op-3',
        createdAt: now,
        type: 'adjustment',
        quantity: -2,
        runningBalance: 13,
        unitPrice: 50.0,
        unitCost: 50.0,
        currency: 'SYP',
      );

      expect(adjOpNeg.inflowQty, 0);
      expect(adjOpNeg.outflowQty, 2);
      expect(adjOpNeg.totalMovementValue, 100.0);
      expect(adjOpNeg.currencySymbol, 'ل.س');

      // 4. Positive Stock Adjustment
      final adjOpPos = ProductStockOperation(
        id: 'op-4',
        createdAt: now,
        type: 'adjustment',
        quantity: 4,
        runningBalance: 17,
        unitPrice: 50.0,
        unitCost: 50.0,
        currency: 'SYP',
      );

      expect(adjOpPos.inflowQty, 4);
      expect(adjOpPos.outflowQty, 0);
      expect(adjOpPos.totalMovementValue, 200.0);
    },
  );

  test(
    'getProductOperations handles multi-currency sale with multiple items for same product correctly',
    () async {
      final now = DateTime.now();

      // 1. Insert product
      await db
          .into(db.categories)
          .insert(CategoriesCompanion.insert(id: 'cat-gifts', name: 'Gifts'));

      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              id: 'prod-gift',
              name: 'لف هدية',
              categoryId: const Value('cat-gifts'),
              costPrice: const Value(50.0),
              costPriceUsd: const Value(0.005),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 2. Insert Sale invoice (header currency is SYP, but invoice has both currencies)
      await db
          .into(db.invoices)
          .insert(
            InvoicesCompanion.insert(
              id: 'inv-multi-curr',
              serialNumber: const Value(7),
              type: 'sale',
              totalAmount: 100.15,
              currency: const Value('SYP'),
              paymentType: 'cash',
              createdAt: now,
            ),
          );

      // Item 1: in SYP (100 SYP)
      await db
          .into(db.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              id: 'item-syp-1',
              invoiceId: 'inv-multi-curr',
              productId: 'prod-gift',
              priceUsed: 100.0,
              quantity: 1.0,
              currency: const Value('SYP'),
            ),
          );

      // Item 2: in USD ($ 0.01)
      await db
          .into(db.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              id: 'item-usd-2',
              invoiceId: 'inv-multi-curr',
              productId: 'prod-gift',
              priceUsed: 0.01,
              quantity: 1.0,
              currency: const Value('USD'),
            ),
          );

      // 3. Insert stock movements for both items
      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: 'mov-1',
              productId: 'prod-gift',
              type: 'sale',
              quantity: -1.0,
              referenceId: const Value('inv-multi-curr'),
              createdAt: now,
            ),
          );

      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: 'mov-2',
              productId: 'prod-gift',
              type: 'sale',
              quantity: -1.0,
              referenceId: const Value('inv-multi-curr'),
              createdAt: now.add(const Duration(seconds: 1)),
            ),
          );

      // 4. Query operations
      final ops = await repo.getProductOperations('prod-gift');

      expect(ops.length, 2);

      final sypOp = ops.firstWhere((o) => o.currency == 'SYP');
      expect(sypOp.unitPrice, 100.0);
      expect(sypOp.totalMovementValue, 100.0);
      expect(sypOp.currencySymbol, 'ل.س');
      expect(sypOp.referenceNumber, '#7');

      final usdOp = ops.firstWhere((o) => o.currency == 'USD');
      expect(usdOp.unitPrice, 0.01);
      expect(usdOp.totalMovementValue, 0.01);
      expect(usdOp.currencySymbol, '\$');
      expect(usdOp.referenceNumber, '#7');
    },
  );

  test(
    'Changing product costPrice does NOT affect previous sales operations profit',
    () async {
      final now = DateTime.now();

      // 1. Insert product with cost = 12.0 USD
      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'prod-immutable-cost',
              name: 'منتج اختبار التكلفة التاريخية',
              costPrice: const Value(0.0),
              costPriceUsd: const Value(12.0),
              createdAt: now.subtract(const Duration(days: 10)),
              updatedAt: now.subtract(const Duration(days: 10)),
            ),
          );

      // 2. Sale 1 occurs at price = 22.0 USD with cost locked at 12.0 USD
      await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              id: 'inv-past-1',
              type: 'sale',
              paymentType: 'cash',
              totalAmount: 22.0,
              currency: const Value('USD'),
              createdAt: now.subtract(const Duration(days: 5)),
            ),
          );

      await db.into(db.invoiceItems).insert(
            InvoiceItemsCompanion.insert(
              id: 'item-past-1',
              invoiceId: 'inv-past-1',
              productId: 'prod-immutable-cost',
              quantity: 1.0,
              priceUsed: 22.0,
              currency: const Value('USD'),
              costPrice: const Value(12.0), // locked at sale time
            ),
          );

      await db.into(db.stockMovements).insert(
            StockMovementsCompanion.insert(
              id: 'mov-past-1',
              productId: 'prod-immutable-cost',
              type: 'sale',
              quantity: -1.0,
              referenceId: const Value('inv-past-1'),
              createdAt: now.subtract(const Duration(days: 5)),
            ),
          );

      // 3. User later changes product cost to 18.0 USD
      await (db.update(db.products)..where((t) => t.id.equals('prod-immutable-cost'))).write(
        const ProductsCompanion(
          costPriceUsd: Value(18.0),
        ),
      );

      // 4. Sale 2 occurs under the new cost
      await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              id: 'inv-new-2',
              type: 'sale',
              paymentType: 'cash',
              totalAmount: 28.0,
              currency: const Value('USD'),
              createdAt: now,
            ),
          );

      await db.into(db.invoiceItems).insert(
            InvoiceItemsCompanion.insert(
              id: 'item-new-2',
              invoiceId: 'inv-new-2',
              productId: 'prod-immutable-cost',
              quantity: 1.0,
              priceUsed: 28.0,
              currency: const Value('USD'),
              costPrice: const Value(18.0),
            ),
          );

      await db.into(db.stockMovements).insert(
            StockMovementsCompanion.insert(
              id: 'mov-new-2',
              productId: 'prod-immutable-cost',
              type: 'sale',
              quantity: -1.0,
              referenceId: const Value('inv-new-2'),
              createdAt: now,
            ),
          );

      // 5. Query operations
      final ops = await repo.getProductOperations('prod-immutable-cost');
      expect(ops.length, 2);

      // Check past sale: profit MUST remain 22 - 12 = +10.0 (NOT 22 - 18 = 4)
      final pastOp = ops.firstWhere((o) => o.referenceId == 'inv-past-1');
      expect(pastOp.unitPrice, 22.0);
      expect(pastOp.unitCost, 12.0);
      expect(pastOp.grossProfit, 10.0);

      // Check new sale: profit is 28 - 18 = +10.0
      final newOp = ops.firstWhere((o) => o.referenceId == 'inv-new-2');
      expect(newOp.unitPrice, 28.0);
      expect(newOp.unitCost, 18.0);
      expect(newOp.grossProfit, 10.0);
    },
  );
}
