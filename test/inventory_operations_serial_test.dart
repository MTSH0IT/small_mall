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

  test('getProductOperations assigns sequential serial numbers to purchases and adjustments', () async {
    final now = DateTime.now();

    // Insert category and product
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat-1',
            name: 'General',
          ),
        );

    await db.into(db.products).insert(
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
    await db.into(db.purchaseInvoices).insert(
          PurchaseInvoicesCompanion.insert(
            id: 'purch-uuid-1',
            supplierId: 'supp-1',
            totalAmount: 300.0,
            createdAt: now.subtract(const Duration(hours: 2)),
          ),
        );

    await db.into(db.purchaseItems).insert(
          PurchaseItemsCompanion.insert(
            id: 'item-1',
            purchaseInvoiceId: 'purch-uuid-1',
            productId: 'prod-1',
            quantity: 10,
            unitCost: 30.0,
          ),
        );

    // Insert stock movement for purchase
    await db.into(db.stockMovements).insert(
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
    await db.into(db.stockMovements).insert(
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
  });
}
