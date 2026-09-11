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
  });

  final Expense expense;
  final ExpenseCategory? category;
}

class CategoryExpenseSummary {
  const CategoryExpenseSummary({
    required this.category,
    required this.totalAmount,
    required this.count,
  });

  final ExpenseCategory category;
  final double totalAmount;
  final int count;
}

class ExpensesRepository {
  ExpensesRepository(this._db, this._sync, this._logger);

  final AppDatabase _db;
  final SyncService _sync;
  final AppLogger _logger;
  final _uuid = const Uuid();

  // --- Expense Categories ---

  Future<List<ExpenseCategory>> getCategories() async {
    _logger.debug('Fetching expense categories', context: LogContext.expenses);
    return (_db.select(_db.expenseCategories)
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Stream<List<ExpenseCategory>> watchCategories() {
    return (_db.select(_db.expenseCategories)
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<ExpenseCategory> addCategory({
    required String name,
    String? description,
  }) async {
    _logger.info('Adding expense category: $name', context: LogContext.expenses);
    final id = _uuid.v4();
    final now = DateTime.now();
    final companion = ExpenseCategoriesCompanion.insert(
      id: id,
      name: name,
      description: Value(description),
      createdAt: now,
    );

    await _db.into(_db.expenseCategories).insert(companion);

    _sync.updatePendingCount();
    _sync.sync();

    return ExpenseCategory(
      id: id,
      name: name,
      description: description,
      createdAt: now,
    );
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

    // Check if category is used by any expense
    final linked = await (_db.select(_db.expenses)
          ..where((t) => t.categoryId.equals(id)))
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
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final query = _db.select(_db.expenses).join([
      leftOuterJoin(
        _db.expenseCategories,
        _db.expenseCategories.id.equalsExp(_db.expenses.categoryId),
      ),
    ]);

    if (categoryId != null && categoryId.isNotEmpty) {
      query.where(_db.expenses.categoryId.equals(categoryId));
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
          category: row.readTableOrNull(_db.expenseCategories),
        );
      }).toList();
    });
  }

  Future<List<ExpenseWithCategory>> getExpenses({
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = _db.select(_db.expenses).join([
      leftOuterJoin(
        _db.expenseCategories,
        _db.expenseCategories.id.equalsExp(_db.expenses.categoryId),
      ),
    ]);

    if (categoryId != null && categoryId.isNotEmpty) {
      query.where(_db.expenses.categoryId.equals(categoryId));
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
        category: row.readTableOrNull(_db.expenseCategories),
      );
    }).toList();
  }

  Future<Expense> addExpense({
    required String categoryId,
    required double amount,
    String? notes,
    DateTime? createdAt,
  }) async {
    _logger.info('Adding expense: $amount under category $categoryId', context: LogContext.expenses);
    final id = _uuid.v4();
    final now = createdAt ?? DateTime.now();

    final companion = ExpensesCompanion.insert(
      id: id,
      categoryId: categoryId,
      amount: amount,
      notes: Value(notes),
      createdAt: now,
    );

    await _db.into(_db.expenses).insert(companion);

    _sync.updatePendingCount();
    _sync.sync();

    return Expense(
      id: id,
      categoryId: categoryId,
      amount: amount,
      notes: notes,
      createdAt: now,
    );
  }

  Future<void> updateExpense({
    required String id,
    required String categoryId,
    required double amount,
    String? notes,
    DateTime? createdAt,
  }) async {
    _logger.info('Updating expense: $id', context: LogContext.expenses);

    await (_db.update(_db.expenses)..where((t) => t.id.equals(id))).write(
      ExpensesCompanion(
        categoryId: Value(categoryId),
        amount: Value(amount),
        notes: Value(notes),
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
    final allExpenses = await getExpenses(startDate: startDate, endDate: endDate);

    final Map<String, List<Expense>> grouped = {};
    for (final exp in allExpenses) {
      grouped.putIfAbsent(exp.expense.categoryId, () => []).add(exp.expense);
    }

    return categories.map((cat) {
      final list = grouped[cat.id] ?? [];
      final total = list.fold<double>(0.0, (sum, item) => sum + item.amount);
      return CategoryExpenseSummary(
        category: cat,
        totalAmount: total,
        count: list.length,
      );
    }).toList();
  }
}
