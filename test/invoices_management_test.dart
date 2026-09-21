import 'package:drift/drift.dart' as drift hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SyncService syncService;
  late POSRepository posRepo;
  late InvoicesRepository invoicesRepo;
  const uuid = Uuid();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final logger = AppLogger();
    syncService = SyncService(db, logger);
    posRepo = POSRepository(db, syncService, logger);
    invoicesRepo = InvoicesRepository(db, posRepo, logger, syncService);
  });

  tearDown(() async {
    await db.close();
  });

  group('Universal Invoices & Transactions Management Tests', () {
    test('Delete expense transaction cleans up expense record and syncs deletion', () async {
      final now = DateTime.now();
      final catId = uuid.v4();
      await db.into(db.expenseCategories).insert(
        ExpenseCategoriesCompanion.insert(id: catId, name: 'مكتبة ومطبوعات', createdAt: now),
      );

      final expId = uuid.v4();
      await db.into(db.expenses).insert(
        ExpensesCompanion.insert(
          id: expId,
          categoryId: catId,
          amount: 1500.0,
          createdAt: now,
          currency: const drift.Value('SYP'),
        ),
      );

      final tr = UnifiedTransactionRecord(
        id: expId,
        type: UnifiedTransactionType.expense,
        createdAt: now,
        totalAmount: 1500.0,
        currency: 'SYP',
      );

      await invoicesRepo.deleteTransaction(tr);

      final remaining = await (db.select(db.expenses)..where((t) => t.id.equals(expId))).getSingleOrNull();
      expect(remaining, isNull);

      final deleted = await (db.select(db.deletedRecords)..where((t) => t.recordId.equals(expId))).getSingleOrNull();
      expect(deleted, isNotNull);
      expect(deleted!.targetTable, equals('expenses'));
    });

    test('Delete debt payment transaction updates remaining amount on parent debt and reopens debt', () async {
      final now = DateTime.now();
      final custId = uuid.v4();
      await db.into(db.customers).insert(
        CustomersCompanion.insert(
          id: custId,
          name: 'عميل اختبار',
          phone: const drift.Value('0999111222'),
          createdAt: now,
        ),
      );

      final debtId = uuid.v4();
      await db.into(db.debts).insert(
        DebtsCompanion.insert(
          id: debtId,
          customerId: custId,
          amount: 5000.0,
          remainingAmount: 3000.0,
          status: 'open',
          createdAt: now,
        ),
      );

      final payId = uuid.v4();
      await db.into(db.debtPayments).insert(
        DebtPaymentsCompanion.insert(
          id: payId,
          debtId: debtId,
          amountPaid: 2000.0,
          paidAt: now,
        ),
      );

      final tr = UnifiedTransactionRecord(
        id: payId,
        type: UnifiedTransactionType.debtPayment,
        createdAt: now,
        totalAmount: 2000.0,
        currency: 'SYP',
      );

      await invoicesRepo.deleteTransaction(tr);

      final remainingPay = await (db.select(db.debtPayments)..where((t) => t.id.equals(payId))).getSingleOrNull();
      expect(remainingPay, isNull);

      final updatedDebt = await (db.select(db.debts)..where((t) => t.id.equals(debtId))).getSingle();
      expect(updatedDebt.remainingAmount, equals(5000.0));
      expect(updatedDebt.status, equals('open'));
    });

    test('Delete purchase transaction cleans up invoice, items, and stock movements', () async {
      final now = DateTime.now();
      final supId = uuid.v4();
      await db.into(db.suppliers).insert(
        SuppliersCompanion.insert(id: supId, name: 'مورد مواد أولية'),
      );

      final prodId = uuid.v4();
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          id: prodId,
          name: 'بضاعة للشراء',
          costPrice: const drift.Value(500.0),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final purchaseId = uuid.v4();
      await db.into(db.purchaseInvoices).insert(
        PurchaseInvoicesCompanion.insert(
          id: purchaseId,
          supplierId: supId,
          totalAmount: 5000.0,
          createdAt: now,
          currency: const drift.Value('SYP'),
        ),
      );

      final itemId = uuid.v4();
      await db.into(db.purchaseItems).insert(
        PurchaseItemsCompanion.insert(
          id: itemId,
          purchaseInvoiceId: purchaseId,
          productId: prodId,
          quantity: 10.0,
          unitCost: 500.0,
          currency: const drift.Value('SYP'),
        ),
      );

      final smId = uuid.v4();
      await db.into(db.stockMovements).insert(
        StockMovementsCompanion.insert(
          id: smId,
          productId: prodId,
          type: 'purchase',
          quantity: 10.0,
          createdAt: now,
          referenceId: drift.Value(purchaseId),
        ),
      );

      final tr = UnifiedTransactionRecord(
        id: purchaseId,
        type: UnifiedTransactionType.purchase,
        createdAt: now,
        totalAmount: 5000.0,
        currency: 'SYP',
      );

      await invoicesRepo.deleteTransaction(tr);

      final p = await (db.select(db.purchaseInvoices)..where((t) => t.id.equals(purchaseId))).getSingleOrNull();
      expect(p, isNull);

      final items = await (db.select(db.purchaseItems)..where((t) => t.purchaseInvoiceId.equals(purchaseId))).get();
      expect(items, isEmpty);

      final movements = await (db.select(db.stockMovements)..where((t) => t.referenceId.equals(purchaseId))).get();
      expect(movements, isEmpty);
    });

    test('Update expense transaction persists changes correctly', () async {
      final now = DateTime.now();
      final catId1 = uuid.v4();
      final catId2 = uuid.v4();
      await db.into(db.expenseCategories).insert(
        ExpenseCategoriesCompanion.insert(id: catId1, name: 'فئة 1', createdAt: now),
      );
      await db.into(db.expenseCategories).insert(
        ExpenseCategoriesCompanion.insert(id: catId2, name: 'فئة 2', createdAt: now),
      );

      final expId = uuid.v4();
      await db.into(db.expenses).insert(
        ExpensesCompanion.insert(
          id: expId,
          categoryId: catId1,
          amount: 200.0,
          createdAt: now,
          currency: const drift.Value('SYP'),
        ),
      );

      await invoicesRepo.updateExpense(
        expenseId: expId,
        categoryId: catId2,
        amount: 350.0,
        currency: 'USD',
        notes: 'ملاحظة محدثة',
        createdAt: now,
      );

      final updated = await (db.select(db.expenses)..where((t) => t.id.equals(expId))).getSingle();
      expect(updated.categoryId, equals(catId2));
      expect(updated.amount, equals(350.0));
      expect(updated.currency, equals('USD'));
      expect(updated.notes, equals('ملاحظة محدثة'));
    });
  });
}
