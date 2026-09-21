import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/features/expenses/data/expenses_repository.dart';
import 'package:small_mall/features/expenses/presentation/cubit/expenses_state.dart';
import 'package:small_mall/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';

void main() {
  late AppDatabase db;
  late AppLogger logger;
  late SyncService sync;
  late ExpensesRepository expensesRepo;
  late SuppliersPurchasingRepository suppliersRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = AppLogger();
    sync = SyncService(db, logger);
    expensesRepo = ExpensesRepository(db, sync, logger);
    suppliersRepo = SuppliersPurchasingRepository(db, sync, logger);
  });

  tearDown(() async {
    await db.close();
  });

  group('V2 Expenses Subcategories Repository & Rules Tests', () {
    test('Categories and subcategories hierarchy and filtering', () async {
      // 1. Add main category
      final mainCat = await expensesRepo.addCategory(
        name: 'الرواتب والأجور',
        description: 'رواتب عامة للمنشأة',
      );
      expect(mainCat.parentId, isNull);

      // 2. Add subcategories under main category
      final subAhmed = await expensesRepo.addSubcategory(
        parentId: mainCat.id,
        name: 'راتب أحمد',
        description: 'محاسب',
      );
      final subAli = await expensesRepo.addSubcategory(
        parentId: mainCat.id,
        name: 'راتب علي',
        description: 'مندوب مبيعات',
      );

      expect(subAhmed.parentId, equals(mainCat.id));
      expect(subAli.parentId, equals(mainCat.id));

      // 3. getCategories() should only return main categories (parentId is null)
      final mainCategories = await expensesRepo.getCategories();
      expect(mainCategories.length, equals(1));
      expect(mainCategories.first.id, equals(mainCat.id));

      // 4. getSubcategories(parentId) should return child subcategories
      final subcategories = await expensesRepo.getSubcategories(mainCat.id);
      expect(subcategories.length, equals(2));
      expect(subcategories.map((s) => s.name).toSet(), containsAll(['راتب أحمد', 'راتب علي']));

      // 5. getAllSubcategories() should return all subcategories across the system
      final allSubs = await expensesRepo.getAllSubcategories();
      expect(allSubs.length, equals(2));
    });

    test('Record expenses with and without subcategories and check summaries', () async {
      final mainCat = await expensesRepo.addCategory(name: 'الرواتب والأجور');
      final subAhmed = await expensesRepo.addSubcategory(
        parentId: mainCat.id,
        name: 'راتب أحمد',
      );
      final subAli = await expensesRepo.addSubcategory(
        parentId: mainCat.id,
        name: 'راتب علي',
      );

      // Add expense with subcategory Ahmad (3000)
      final expAhmed = await expensesRepo.addExpense(
        categoryId: mainCat.id,
        subcategoryId: subAhmed.id,
        amount: 3000.0,
        notes: 'دفعة شهرية',
      );
      expect(expAhmed.categoryId, equals(mainCat.id));
      expect(expAhmed.subcategoryId, equals(subAhmed.id));

      // Add expense with subcategory Ali (2500)
      final expAli = await expensesRepo.addExpense(
        categoryId: mainCat.id,
        subcategoryId: subAli.id,
        amount: 2500.0,
        notes: 'دفعة شهرية',
      );
      expect(expAli.categoryId, equals(mainCat.id));
      expect(expAli.subcategoryId, equals(subAli.id));

      // Add general expense without subcategory (500)
      final expGeneral = await expensesRepo.addExpense(
        categoryId: mainCat.id,
        subcategoryId: null,
        amount: 500.0,
        notes: 'حوافز عامة',
      );
      expect(expGeneral.categoryId, equals(mainCat.id));
      expect(expGeneral.subcategoryId, isNull);

      // Verify getExpenses joins both category and subcategory
      final expensesList = await expensesRepo.getExpenses();
      expect(expensesList.length, equals(3));

      final fetchedAhmed = expensesList.firstWhere((e) => e.expense.id == expAhmed.id);
      expect(fetchedAhmed.category?.name, equals('الرواتب والأجور'));
      expect(fetchedAhmed.subcategory?.name, equals('راتب أحمد'));

      final fetchedGeneral = expensesList.firstWhere((e) => e.expense.id == expGeneral.id);
      expect(fetchedGeneral.category?.name, equals('الرواتب والأجور'));
      expect(fetchedGeneral.subcategory, isNull);

      // Verify category summaries calculate main category total and breakdown by subcategory
      final summaries = await expensesRepo.getCategorySummaries();
      expect(summaries.length, equals(1));
      final catSummary = summaries.first;
      expect(catSummary.category.id, equals(mainCat.id));
      expect(catSummary.totalAmount, equals(6000.0)); // 3000 + 2500 + 500
      expect(catSummary.count, equals(3));

      expect(catSummary.subcategories.length, equals(2));
      final ahmadSummary = catSummary.subcategories.firstWhere((s) => s.category.id == subAhmed.id);
      expect(ahmadSummary.totalAmount, equals(3000.0));
      expect(ahmadSummary.count, equals(1));

      final aliSummary = catSummary.subcategories.firstWhere((s) => s.category.id == subAli.id);
      expect(aliSummary.totalAmount, equals(2500.0));
      expect(aliSummary.count, equals(1));
    });

    test('Deletion safety: cannot delete category with subcategories or linked expenses', () async {
      final mainCat = await expensesRepo.addCategory(name: 'المصاريف التشغيلية');
      final subcat = await expensesRepo.addSubcategory(
        parentId: mainCat.id,
        name: 'الصيانة',
      );

      // Attempting to delete mainCat should fail because subcategories exist
      expect(
        () => expensesRepo.deleteCategory(mainCat.id),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('بنود فرعية مرتبطة به'),
        )),
      );

      // Add expense linked to subcat
      final exp = await expensesRepo.addExpense(
        categoryId: mainCat.id,
        subcategoryId: subcat.id,
        amount: 150.0,
      );

      // Attempting to delete subcat should fail because linked expenses exist
      expect(
        () => expensesRepo.deleteCategory(subcat.id),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('مصاريف مرتبطة به'),
        )),
      );

      // Delete the expense first
      await expensesRepo.deleteExpense(exp.id);

      // Now deleting subcat succeeds
      await expensesRepo.deleteCategory(subcat.id);
      final remainingSubs = await expensesRepo.getSubcategories(mainCat.id);
      expect(remainingSubs, isEmpty);

      // Now deleting mainCat succeeds
      await expensesRepo.deleteCategory(mainCat.id);
      final remainingCats = await expensesRepo.getCategories();
      expect(remainingCats, isEmpty);
    });

    test('ExpensesLoaded state subcategory filtering and search', () {
      final now = DateTime.now();
      final cat = ExpenseCategory(id: 'c1', name: 'الرواتب', createdAt: now);
      final sub1 = ExpenseCategory(id: 's1', parentId: 'c1', name: 'راتب أحمد', createdAt: now);
      final sub2 = ExpenseCategory(id: 's2', parentId: 'c1', name: 'راتب علي', createdAt: now);

      final exp1 = ExpenseWithCategory(
        expense: Expense(id: 'e1', categoryId: 'c1', subcategoryId: 's1', amount: 3000.0, createdAt: now, currency: 'SYP'),
        category: cat,
        subcategory: sub1,
      );
      final exp2 = ExpenseWithCategory(
        expense: Expense(id: 'e2', categoryId: 'c1', subcategoryId: 's2', amount: 2000.0, createdAt: now, currency: 'SYP'),
        category: cat,
        subcategory: sub2,
      );
      final exp3 = ExpenseWithCategory(
        expense: Expense(id: 'e3', categoryId: 'c1', subcategoryId: null, amount: 500.0, createdAt: now, currency: 'SYP'),
        category: cat,
      );

      final state = ExpensesLoaded(
        categories: [cat],
        subcategories: [sub1, sub2],
        categorySummaries: [],
        expenses: [exp1, exp2, exp3],
        totalAmount: 5500.0,
      );

      expect(state.getSubcategoriesFor('c1').length, equals(2));

      // Filter by subcategory s1
      final filteredBySub = state.copyWith(selectedSubcategoryId: () => 's1');
      expect(filteredBySub.filteredExpenses.length, equals(1));
      expect(filteredBySub.filteredExpenses.first.expense.id, equals('e1'));
      expect(filteredBySub.filteredTotalAmount, equals(3000.0));

      // Search by subcategory name
      final searched = state.copyWith(searchQuery: 'علي');
      expect(searched.filteredExpenses.length, equals(1));
      expect(searched.filteredExpenses.first.expense.id, equals('e2'));
    });
  });

  group('V2 Suppliers Purchasing Selling Prices Update Tests', () {
    test('recordPurchase updates product cost, retail, and wholesale selling prices', () async {
      // 1. Create a supplier
      final supplier = await suppliersRepo.addSupplier(
        name: 'شركة التوريدات العالمية',
        phone: '0555000111',
        notes: 'مورد معتمد',
      );

      // 2. Insert a product with initial prices
      final now = DateTime.now();
      const prodId = 'prod-test-01';
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          id: prodId,
          name: 'طابعة ليزرية',
          costPrice: const Value(200.0),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Insert initial retail and wholesale prices
      await db.into(db.productPrices).insert(
        ProductPricesCompanion.insert(
          id: 'price-retail-01',
          productId: prodId,
          priceLabel: 'retail',
          priceValue: 260.0,
        ),
      );
      await db.into(db.productPrices).insert(
        ProductPricesCompanion.insert(
          id: 'price-wholesale-01',
          productId: prodId,
          priceLabel: 'wholesale',
          priceValue: 230.0,
        ),
      );

      // 3. Record a purchase with NEW cost price and NEW selling prices (retail & wholesale)
      await suppliersRepo.recordPurchase(
        supplierId: supplier.id,
        totalAmount: 1050.0,
        items: [
          {
            'productId': prodId,
            'quantity': 5.0,
            'unitCost': 210.0,       // Updated cost price
            'retailPrice': 280.0,   // New retail selling price
            'wholesalePrice': 245.0, // New wholesale selling price
          },
        ],
      );

      // 4. Verify product cost price was updated
      final updatedProduct = await (db.select(db.products)..where((t) => t.id.equals(prodId))).getSingle();
      expect(updatedProduct.costPrice, equals(210.0));
      expect(updatedProduct.syncedAt, isNull); // Marked for sync

      // 5. Verify product prices were updated in productPrices table
      final currentPrices = await (db.select(db.productPrices)..where((t) => t.productId.equals(prodId))).get();
      expect(currentPrices.length, equals(2));

      final currentRetail = currentPrices.firstWhere((p) => p.priceLabel == 'retail');
      expect(currentRetail.priceValue, equals(280.0));

      final currentWholesale = currentPrices.firstWhere((p) => p.priceLabel == 'wholesale');
      expect(currentWholesale.priceValue, equals(245.0));
    });

    test('recordPurchase inserts retail and wholesale prices if they did not previously exist', () async {
      final supplier = await suppliersRepo.addSupplier(
        name: 'مورد مواد خام',
        phone: null,
        notes: null,
      );

      final now = DateTime.now();
      const prodId = 'prod-test-02';
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          id: prodId,
          name: 'لوحة مفاتيح لاسلكية',
          costPrice: const Value(50.0),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // No entries in productPrices yet
      final initialPrices = await (db.select(db.productPrices)..where((t) => t.productId.equals(prodId))).get();
      expect(initialPrices, isEmpty);

      // Record purchase providing retail and wholesale prices
      await suppliersRepo.recordPurchase(
        supplierId: supplier.id,
        totalAmount: 550.0,
        items: [
          {
            'productId': prodId,
            'quantity': 10.0,
            'unitCost': 55.0,
            'retailPrice': 85.0,
            'wholesalePrice': 70.0,
          },
        ],
      );

      // Verify newly created price records
      final newPrices = await (db.select(db.productPrices)..where((t) => t.productId.equals(prodId))).get();
      expect(newPrices.length, equals(2));

      final retail = newPrices.firstWhere((p) => p.priceLabel == 'retail');
      expect(retail.priceValue, equals(85.0));

      final wholesale = newPrices.firstWhere((p) => p.priceLabel == 'wholesale');
      expect(wholesale.priceValue, equals(70.0));
    });
  });
}
