import 'package:drift/drift.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:uuid/uuid.dart';

class ExpenseWithCategory {
  const ExpenseWithCategory({
    required this.expense,
    this.category,
    this.subcategory,
  });

  final Expense expense;
  final ExpenseCategory? category;
  final ExpenseCategory? subcategory;
}

class CategoryExpenseSummary {
  const CategoryExpenseSummary({
    required this.category,
    required this.totalAmount,
    required this.count,
    this.subcategories = const [],
  });

  final ExpenseCategory category;
  final double totalAmount;
  final int count;
  final List<CategoryExpenseSummary> subcategories;
}

class ExpensesRepository {
  ExpensesRepository(this._db, this._sync, this._logger);

  final AppDatabase _db;
  final SyncService _sync;
  final AppLogger _logger;
  final _uuid = const Uuid();

  // --- Expense Categories ---

  /// Get main categories (where parentId is null)
  Future<List<ExpenseCategory>> getCategories() async {
    _logger.debug('Fetching main expense categories', context: LogContext.expenses);
    return (_db.select(_db.expenseCategories)
          ..where((t) => t.parentId.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  /// Get all categories (both main and subcategories)
  Future<List<ExpenseCategory>> getAllCategories() async {
    _logger.debug('Fetching all expense categories', context: LogContext.expenses);
    return (_db.select(_db.expenseCategories)
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  /// Get all subcategories in system (where parentId is not null)
  Future<List<ExpenseCategory>> getAllSubcategories() async {
    return (_db.select(_db.expenseCategories)
          ..where((t) => t.parentId.isNotNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  /// Get subcategories for a specific main category
  Future<List<ExpenseCategory>> getSubcategories(String parentId) async {
    return (_db.select(_db.expenseCategories)
          ..where((t) => t.parentId.equals(parentId))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Stream<List<ExpenseCategory>> watchCategories() {
    return (_db.select(_db.expenseCategories)
          ..where((t) => t.parentId.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<ExpenseCategory> addCategory({
    required String name,
    String? description,
    String? parentId,
  }) async {
    _logger.info('Adding expense category: $name (parentId: $parentId)', context: LogContext.expenses);
    final id = _uuid.v4();
    final now = DateTime.now();
    final companion = ExpenseCategoriesCompanion.insert(
      id: id,
      name: name,
      description: Value(description),
      parentId: Value(parentId),
      createdAt: now,
    );

    await _db.into(_db.expenseCategories).insert(companion);

    _sync.updatePendingCount();
    _sync.sync();

    return ExpenseCategory(
      id: id,
      name: name,
      description: description,
      parentId: parentId,
      createdAt: now,
    );
  }

  Future<ExpenseCategory> addSubcategory({
    required String parentId,
    required String name,
    String? description,
  }) {
    return addCategory(name: name, description: description, parentId: parentId);
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    String? description,
  }) async {
    _logger.info('Updating expense category: $id', context: LogContext.expenses);
    await (_db.update(_db.expenseCategories)..where((t) => t.id.equals(id))).write(
      ExpenseCategoriesCompanion(
        name: Value(name),
        description: Value(description),
        syncedAt: const Value(null),
      ),
    );

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<void> deleteCategory(String id) async {
    _logger.info('Deleting expense category: $id', context: LogContext.expenses);

    // Check if category has subcategories
    final subcategories = await (_db.select(_db.expenseCategories)
          ..where((t) => t.parentId.equals(id)))
        .get();
    if (subcategories.isNotEmpty) {
      throw Exception('لا يمكن حذف البند الرئيسي لوجود ${subcategories.length} بنود فرعية مرتبطة به');
    }

    // Check if category is used by any expense as main category or subcategory
    final linked = await (_db.select(_db.expenses)
          ..where((t) => t.categoryId.equals(id) | t.subcategoryId.equals(id)))
        .get();

    if (linked.isNotEmpty) {
      throw Exception('لا يمكن حذف البند لوجود ${linked.length} مصاريف مرتبطة به');
    }

    // Record deletion for sync
    await _db.into(_db.deletedRecords).insert(
      DeletedRecordsCompanion.insert(
        id: _uuid.v4(),
        targetTable: 'expense_categories',
        recordId: id,
        createdAt: DateTime.now(),
      ),
    );

    await (_db.delete(_db.expenseCategories)..where((t) => t.id.equals(id))).go();

    _sync.updatePendingCount();
    _sync.sync();
  }

  // --- Expenses ---

  Stream<List<ExpenseWithCategory>> watchExpenses({
    String? categoryId,
    String? subcategoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final mainCategory = _db.alias(_db.expenseCategories, 'main_cat');
    final subCategory = _db.alias(_db.expenseCategories, 'sub_cat');

    final query = _db.select(_db.expenses).join([
      leftOuterJoin(
        mainCategory,
        mainCategory.id.equalsExp(_db.expenses.categoryId),
      ),
      leftOuterJoin(
        subCategory,
        subCategory.id.equalsExp(_db.expenses.subcategoryId),
      ),
    ]);

    if (categoryId != null && categoryId.isNotEmpty) {
      query.where(_db.expenses.categoryId.equals(categoryId));
    }

    if (subcategoryId != null && subcategoryId.isNotEmpty) {
      query.where(_db.expenses.subcategoryId.equals(subcategoryId));
    }

    if (startDate != null) {
      query.where(_db.expenses.createdAt.isBiggerOrEqualValue(startDate));
    }

    if (endDate != null) {
      query.where(_db.expenses.createdAt.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([
      OrderingTerm.desc(_db.expenses.createdAt),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return ExpenseWithCategory(
          expense: row.readTable(_db.expenses),
          category: row.readTableOrNull(mainCategory),
          subcategory: row.readTableOrNull(subCategory),
        );
      }).toList();
    });
  }

  Future<List<ExpenseWithCategory>> getExpenses({
    String? categoryId,
    String? subcategoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final mainCategory = _db.alias(_db.expenseCategories, 'main_cat');
    final subCategory = _db.alias(_db.expenseCategories, 'sub_cat');

    final query = _db.select(_db.expenses).join([
      leftOuterJoin(
        mainCategory,
        mainCategory.id.equalsExp(_db.expenses.categoryId),
      ),
      leftOuterJoin(
        subCategory,
        subCategory.id.equalsExp(_db.expenses.subcategoryId),
      ),
    ]);

    if (categoryId != null && categoryId.isNotEmpty) {
      query.where(_db.expenses.categoryId.equals(categoryId));
    }

    if (subcategoryId != null && subcategoryId.isNotEmpty) {
      query.where(_db.expenses.subcategoryId.equals(subcategoryId));
    }

    if (startDate != null) {
      query.where(_db.expenses.createdAt.isBiggerOrEqualValue(startDate));
    }

    if (endDate != null) {
      query.where(_db.expenses.createdAt.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([
      OrderingTerm.desc(_db.expenses.createdAt),
    ]);

    final rows = await query.get();
    return rows.map((row) {
      return ExpenseWithCategory(
        expense: row.readTable(_db.expenses),
        category: row.readTableOrNull(mainCategory),
        subcategory: row.readTableOrNull(subCategory),
      );
    }).toList();
  }

  Future<Expense> addExpense({
    required String categoryId,
    String? subcategoryId,
    required double amount,
    String? notes,
    DateTime? createdAt,
    String? currency,
  }) async {
    _logger.info('Adding expense: $amount under category $categoryId, subcategory: $subcategoryId', context: LogContext.expenses);
    final id = _uuid.v4();
    final now = createdAt ?? DateTime.now();
    final curr = currency ?? 'SYP';

    final companion = ExpensesCompanion.insert(
      id: id,
      categoryId: categoryId,
      subcategoryId: Value(subcategoryId),
      amount: amount,
      notes: Value(notes),
      currency: Value(curr),
      createdAt: now,
    );

    await _db.into(_db.expenses).insert(companion);

    _sync.updatePendingCount();
    _sync.sync();

    return Expense(
      id: id,
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      amount: amount,
      notes: notes,
      currency: curr,
      createdAt: now,
    );
  }

  Future<void> updateExpense({
    required String id,
    required String categoryId,
    String? subcategoryId,
    required double amount,
    String? notes,
    DateTime? createdAt,
    String? currency,
  }) async {
    _logger.info('Updating expense: $id', context: LogContext.expenses);

    await (_db.update(_db.expenses)..where((t) => t.id.equals(id))).write(
      ExpensesCompanion(
        categoryId: Value(categoryId),
        subcategoryId: Value(subcategoryId),
        amount: Value(amount),
        notes: Value(notes),
        currency: currency != null ? Value(currency) : const Value.absent(),
        createdAt: createdAt != null ? Value(createdAt) : const Value.absent(),
        syncedAt: const Value(null),
      ),
    );

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<void> deleteExpense(String id) async {
    _logger.info('Deleting expense: $id', context: LogContext.expenses);

    await _db.into(_db.deletedRecords).insert(
      DeletedRecordsCompanion.insert(
        id: _uuid.v4(),
        targetTable: 'expenses',
        recordId: id,
        createdAt: DateTime.now(),
      ),
    );

    await (_db.delete(_db.expenses)..where((t) => t.id.equals(id))).go();

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<double> getTotalExpenses({
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final amountSum = _db.expenses.amount.sum();
    final query = _db.selectOnly(_db.expenses)..addColumns([amountSum]);

    if (categoryId != null && categoryId.isNotEmpty) {
      query.where(_db.expenses.categoryId.equals(categoryId));
    }

    if (startDate != null) {
      query.where(_db.expenses.createdAt.isBiggerOrEqualValue(startDate));
    }

    if (endDate != null) {
      query.where(_db.expenses.createdAt.isSmallerOrEqualValue(endDate));
    }

    final result = await query.map((row) => row.read(amountSum)).getSingle();
    return result ?? 0.0;
  }

  Future<List<CategoryExpenseSummary>> getCategorySummaries({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final categories = await getCategories();
    final allSubcategories = await getAllSubcategories();
    final allExpenses = await getExpenses(startDate: startDate, endDate: endDate);

    final Map<String, List<Expense>> grouped = {};
    final Map<String, List<Expense>> subcategoryGrouped = {};
    for (final exp in allExpenses) {
      grouped.putIfAbsent(exp.expense.categoryId, () => []).add(exp.expense);
      if (exp.expense.subcategoryId != null) {
        subcategoryGrouped.putIfAbsent(exp.expense.subcategoryId!, () => []).add(exp.expense);
      }
    }

    return categories.map((cat) {
      final list = grouped[cat.id] ?? [];
      final total = list.fold<double>(0.0, (sum, item) => sum + item.amount);

      final subcats = allSubcategories.where((s) => s.parentId == cat.id).toList();
      final subSummaries = subcats.map((sub) {
        final subList = subcategoryGrouped[sub.id] ?? [];
        final subTotal = subList.fold<double>(0.0, (sum, item) => sum + item.amount);
        return CategoryExpenseSummary(
          category: sub,
          totalAmount: subTotal,
          count: subList.length,
        );
      }).toList();

      return CategoryExpenseSummary(
        category: cat,
        totalAmount: total,
        count: list.length,
        subcategories: subSummaries,
      );
    }).toList();
  }
}
