import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';
import 'package:small_mall/features/treasury/data/treasury_repository.dart';
import 'package:small_mall/features/treasury/presentation/cubit/treasury_cubit.dart';
import 'package:small_mall/features/treasury/presentation/cubit/treasury_state.dart';

void main() {
  late AppDatabase db;
  late SyncService syncService;
  late AppLogger logger;
  late TreasuryRepository repository;
  late ReportsRepository reportsRepository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = AppLogger();
    syncService = SyncService(db, logger);
    reportsRepository = ReportsRepository(db, logger);
    repository = TreasuryRepository(db, syncService, logger, reportsRepo: reportsRepository);
  });

  tearDown(() async {
    await db.close();
  });

  group('Treasury Repository & Operations Tests', () {
    test('Can add and retrieve categories and subcategories', () async {
      // 1. Add Main Categories
      await repository.addCategory(
        name: 'تغذية الصندوق',
        type: 'in',
        description: 'ضخ سيولة',
      );
      final catOut = await repository.addCategory(
        name: 'سلف الموظفين',
        type: 'out',
        description: 'سلف الموظفين والعاملين',
      );

      final inCategories = await repository.getCategories(type: 'in');
      expect(inCategories.any((c) => c.name == 'تغذية الصندوق'), isTrue);

      final outCategories = await repository.getCategories(type: 'out');
      expect(outCategories.any((c) => c.name == 'سلف الموظفين'), isTrue);

      // 2. Add Subcategories under catOut
      final sub1 = await repository.addSubcategory(
        parentId: catOut.id,
        name: 'سلفة أحمد',
        type: 'out',
      );
      final sub2 = await repository.addSubcategory(
        parentId: catOut.id,
        name: 'سلفة خالد',
        type: 'out',
      );

      expect(sub1.parentId, equals(catOut.id));
      expect(sub2.parentId, equals(catOut.id));

      final subcategories = await repository.getSubcategories(catOut.id);
      expect(subcategories.length, equals(2));
      expect(subcategories.map((s) => s.name), containsAll(['سلفة أحمد', 'سلفة خالد']));

      // 3. Deleting category with subcategories throws exception
      expect(
        () => repository.deleteCategory(catOut.id),
        throwsA(isA<Exception>()),
      );
    });

    test('Can record Cash In and Cash Out with serial numbers and subcategories', () async {
      final mainCat = await repository.addCategory(
        name: 'سلف الموظفين',
        type: 'out',
      );
      final subCat = await repository.addSubcategory(
        parentId: mainCat.id,
        name: 'سلفة أحمد',
        type: 'out',
      );

      // 1. Record Cash In
      final txIn = await repository.addTransaction(
        type: 'in',
        amount: 500000.0,
        categoryName: 'رأس مال إضافي',
        personName: 'المالك',
        notes: 'إيداع نقدي لزيادة السيولة',
        currency: 'SYP',
      );

      expect(txIn.serialNumber, equals(1));
      expect(txIn.type, equals('in'));
      expect(txIn.amount, equals(500000.0));
      expect(txIn.personName, equals('المالك'));

      // 2. Record Cash Out with category and subcategory
      final txOut = await repository.addTransaction(
        type: 'out',
        amount: 75000.0,
        categoryName: mainCat.name,
        categoryId: mainCat.id,
        subcategoryName: subCat.name,
        subcategoryId: subCat.id,
        personName: 'أحمد المحمد',
        notes: 'سلفة على حساب الراتب',
        currency: 'SYP',
      );

      expect(txOut.serialNumber, equals(2));
      expect(txOut.type, equals('out'));
      expect(txOut.amount, equals(75000.0));
      expect(txOut.categoryId, equals(mainCat.id));
      expect(txOut.subcategoryId, equals(subCat.id));
      expect(txOut.personName, equals('أحمد المحمد'));

      // 3. Verify total transactions and list
      final all = await repository.getTransactions();
      expect(all.length, equals(2));

      final onlyOut = await repository.getTransactions(type: 'out');
      expect(onlyOut.length, equals(1));
      expect(onlyOut.first.personName, equals('أحمد المحمد'));

      // 4. Verify getTransactionsWithCategory
      final detailed = await repository.getTransactionsWithCategory();
      expect(detailed.length, equals(2));
      final detailedOut = detailed.firstWhere((d) => d.transaction.id == txOut.id);
      expect(detailedOut.category?.name, equals(mainCat.name));
      expect(detailedOut.subcategory?.name, equals(subCat.name));
    });

    test('Can record multi-currency movements and compute summaries', () async {
      final catIn = await repository.addCategory(
        name: 'تغذية بالدولار',
        type: 'in',
      );
      final catOut = await repository.addCategory(
        name: 'سلفة لشخص',
        type: 'out',
      );

      await repository.addTransaction(
        type: 'in',
        amount: 200.0,
        categoryName: catIn.name,
        categoryId: catIn.id,
        currency: 'USD',
      );

      await repository.addTransaction(
        type: 'out',
        amount: 50.0,
        categoryName: catOut.name,
        categoryId: catOut.id,
        personName: 'محمد',
        currency: 'USD',
      );

      final summaries = await repository.getCategorySummaries();
      expect(summaries.length, equals(2));

      final inSummary = summaries.firstWhere(
        (s) => s.category.name == 'تغذية بالدولار',
      );
      expect(inSummary.totalAmountUsd, equals(200.0));
      expect(inSummary.category.type, equals('in'));

      final outSummary = summaries.firstWhere(
        (s) => s.category.name == 'سلفة لشخص',
      );
      expect(outSummary.totalAmountUsd, equals(-50.0));
      expect(outSummary.category.type, equals('out'));
    });

    test('Can record withdrawal (out) from feed category (تغذية الصندوق) without changing category', () async {
      final feedCat = await repository.addCategory(
        name: 'تغذية الصندوق',
        type: 'both',
      );

      final txWithdrawal = await repository.addTransaction(
        type: 'out',
        amount: 50000.0,
        categoryName: feedCat.name,
        categoryId: feedCat.id,
        notes: 'سحب سيولة من الصندوق',
      );

      expect(txWithdrawal.type, equals('out'));
      expect(txWithdrawal.categoryId, equals(feedCat.id));
      expect(txWithdrawal.categoryName, equals('تغذية الصندوق'));

      final summaries = await repository.getCategorySummaries();
      final feedSummary = summaries.firstWhere((s) => s.category.id == feedCat.id);
      expect(feedSummary.totalAmountSyp, equals(-50000.0));
      expect(feedSummary.count, equals(1));
    });

    test('Can update and delete transactions', () async {
      final tx = await repository.addTransaction(
        type: 'out',
        amount: 30000.0,
        categoryName: 'سلفة',
        personName: 'خالد',
      );

      await repository.updateTransaction(
        id: tx.id,
        type: 'out',
        amount: 35000.0,
        categoryName: 'سلفة',
        personName: 'خالد العلي',
        notes: 'تم تعديل المبلغ',
      );

      final updatedList = await repository.getTransactions();
      expect(updatedList.first.amount, equals(35000.0));
      expect(updatedList.first.personName, equals('خالد العلي'));

      await repository.deleteTransaction(tx.id);
      final afterDelete = await repository.getTransactions();
      expect(afterDelete.isEmpty, isTrue);
    });
  });

  group('Treasury Cubit & State Tests', () {
    test('Calculates net flow and filters by category, subcategory, search and type', () async {
      final mainCat = await repository.addCategory(
        name: 'سلف الموظفين',
        type: 'out',
      );
      final subCat1 = await repository.addSubcategory(
        parentId: mainCat.id,
        name: 'سلفة عمر',
        type: 'out',
      );
      final subCat2 = await repository.addSubcategory(
        parentId: mainCat.id,
        name: 'سلفة زيد',
        type: 'out',
      );

      final cubit = TreasuryCubit(repository);
      await cubit.loadTreasury();

      expect(cubit.state, isA<TreasuryLoaded>());
      var state = cubit.state as TreasuryLoaded;
      expect(state.transactions.isEmpty, isTrue);

      // Add Inflow
      await cubit.addTransaction(
        type: 'in',
        amount: 1000000.0,
        categoryName: 'تغذية الصندوق',
        notes: 'مبلغ افتتاحي',
      );

      // Add Outflow with subcategory 1
      await cubit.addTransaction(
        type: 'out',
        amount: 250000.0,
        categoryName: mainCat.name,
        categoryId: mainCat.id,
        subcategoryName: subCat1.name,
        subcategoryId: subCat1.id,
        personName: 'عمر التاجر',
        notes: 'دفعة نقدية',
      );

      // Add Outflow with subcategory 2
      await cubit.addTransaction(
        type: 'out',
        amount: 150000.0,
        categoryName: mainCat.name,
        categoryId: mainCat.id,
        subcategoryName: subCat2.name,
        subcategoryId: subCat2.id,
        personName: 'زيد العامل',
        notes: 'سلفة شخصية',
      );

      state = cubit.state as TreasuryLoaded;
      expect(state.transactions.length, equals(3));
      expect(state.totalInSyp, equals(1000000.0));
      expect(state.totalOutSyp, equals(400000.0));
      expect(state.netSyp, equals(600000.0));

      // Test searching by person name
      cubit.setSearchQuery('عمر');
      state = cubit.state as TreasuryLoaded;
      expect(state.filteredTransactions.length, equals(1));
      expect(state.filteredTransactions.first.transaction.personName, equals('عمر التاجر'));

      // Test type filter
      cubit.setSearchQuery('');
      cubit.setTypeFilter('in');
      state = cubit.state as TreasuryLoaded;
      expect(state.filteredTransactions.length, equals(1));
      expect(state.filteredTransactions.first.transaction.type, equals('in'));

      // Test category filter
      cubit.setTypeFilter('all');
      cubit.selectCategory(mainCat.id);
      state = cubit.state as TreasuryLoaded;
      expect(state.filteredTransactions.length, equals(2));

      // Test subcategory filter
      cubit.selectSubcategory(subCat1.id);
      state = cubit.state as TreasuryLoaded;
      expect(state.filteredTransactions.length, equals(1));
      expect(state.filteredTransactions.first.transaction.subcategoryId, equals(subCat1.id));
    });
  });

  group('Cash Drawer Integration Tests', () {
    test('Treasury In and Out are reflected in Reports Cash Drawer', () async {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 1));
      final end = now.add(const Duration(days: 1));

      // Add Treasury Cash In
      await repository.addTransaction(
        type: 'in',
        amount: 400000.0,
        categoryName: 'تغذية الصندوق',
        createdAt: now,
      );

      // Add Treasury Cash Out to person
      await repository.addTransaction(
        type: 'out',
        amount: 100000.0,
        categoryName: 'سلفة لشخص / موظف',
        personName: 'سامر',
        createdAt: now,
      );

      final report = await reportsRepository.getCashDrawerReport(start, end);

      expect(report.totalCashIn, equals(400000.0));
      expect(report.totalCashOut, equals(100000.0));
      expect(report.netCashFlow, equals(300000.0));

      final movements = report.movements;
      expect(
        movements.any((m) => m.type == 'treasury_in' && m.amount == 400000.0),
        isTrue,
      );
      expect(
        movements.any((m) => m.type == 'treasury_out' && m.partyName == 'سامر'),
        isTrue,
      );
    });
  });

  group('Main Treasury: Unified Ledger & Vault Balances Tests', () {
    test('getUnifiedLedger computes cumulative running balances chronologically', () async {
      final t1 = DateTime(2026, 10, 10, 10, 0);
      final t2 = DateTime(2026, 10, 10, 11, 0);
      final t3 = DateTime(2026, 10, 10, 12, 0);

      // Deposit 100,000 SYP
      await repository.addTransaction(
        type: 'in',
        amount: 100000.0,
        categoryName: 'رأس مال افتتاحي',
        currency: 'SYP',
        createdAt: t1,
      );

      // Deposit 500 USD
      await repository.addTransaction(
        type: 'in',
        amount: 500.0,
        categoryName: 'رأس مال دولار',
        currency: 'USD',
        createdAt: t2,
      );

      // Withdraw 20,000 SYP
      await repository.addTransaction(
        type: 'out',
        amount: 20000.0,
        categoryName: 'مصاريف نثرية',
        currency: 'SYP',
        createdAt: t3,
      );

      final ledger = await repository.getUnifiedLedger();
      expect(ledger.length, equals(3));

      // Newest (t3): running balance SYP should be 80,000, USD should be 500
      final latest = ledger.first;
      expect(latest.amount, equals(20000.0));
      expect(latest.isCashIn, isFalse);
      expect(latest.runningBalanceSyp, equals(80000.0));
      expect(latest.runningBalanceUsd, equals(500.0));

      // Oldest (t1): running balance SYP should be 100,000, USD should be 0
      final oldest = ledger.last;
      expect(oldest.amount, equals(100000.0));
      expect(oldest.isCashIn, isTrue);
      expect(oldest.runningBalanceSyp, equals(100000.0));
      expect(oldest.runningBalanceUsd, equals(0.0));

      // Vault balances
      final balances = await repository.getCurrentVaultBalances();
      expect(balances['SYP'], equals(80000.0));
      expect(balances['USD'], equals(500.0));
    });
  });
}
