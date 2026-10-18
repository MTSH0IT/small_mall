import 'package:drift/drift.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:uuid/uuid.dart';

class TreasuryTransactionWithCategory {
  const TreasuryTransactionWithCategory({
    required this.transaction,
    this.category,
    this.subcategory,
  });

  final TreasuryTransaction transaction;
  final TreasuryCategory? category;
  final TreasuryCategory? subcategory;
}

class TreasuryCategorySummary {
  const TreasuryCategorySummary({
    required this.category,
    required this.totalAmountSyp,
    required this.totalAmountUsd,
    required this.count,
    this.subcategories = const [],
  });

  final TreasuryCategory category;
  final double totalAmountSyp;
  final double totalAmountUsd;
  final int count;
  final List<TreasuryCategorySummary> subcategories;
}

class TreasuryRepository {
  TreasuryRepository(this._db, this._sync, this._logger);

  final AppDatabase _db;
  final SyncService _sync;
  final AppLogger _logger;
  final _uuid = const Uuid();

  // --- Categories ---

  /// Get main categories (where parentId is null)
  Future<List<TreasuryCategory>> getCategories({String? type}) async {
    _logger.debug(
      'Fetching main treasury categories (type: $type)',
      context: LogContext.treasury,
    );
    final query = _db.select(_db.treasuryCategories)
      ..where((t) => t.parentId.isNull());
    if (type != null && type.isNotEmpty && type != 'all') {
      query.where((t) => t.type.equals(type) | t.type.equals('both'));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return query.get();
  }

  /// Get all categories (both main and subcategories)
  Future<List<TreasuryCategory>> getAllCategories({String? type}) async {
    final query = _db.select(_db.treasuryCategories);
    if (type != null && type.isNotEmpty && type != 'all') {
      query.where((t) => t.type.equals(type) | t.type.equals('both'));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return query.get();
  }

  /// Get all subcategories in system (where parentId is not null)
  Future<List<TreasuryCategory>> getAllSubcategories() async {
    return (_db.select(_db.treasuryCategories)
          ..where((t) => t.parentId.isNotNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  /// Get subcategories for a specific main category
  Future<List<TreasuryCategory>> getSubcategories(String parentId) async {
    return (_db.select(_db.treasuryCategories)
          ..where((t) => t.parentId.equals(parentId))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Stream<List<TreasuryCategory>> watchCategories({String? type}) {
    final query = _db.select(_db.treasuryCategories)
      ..where((t) => t.parentId.isNull());
    if (type != null && type.isNotEmpty && type != 'all') {
      query.where((t) => t.type.equals(type) | t.type.equals('both'));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return query.watch();
  }

  Future<TreasuryCategory> addCategory({
    required String name,
    String type = 'both',
    String? description,
    String? parentId,
  }) async {
    _logger.info(
      'Adding treasury category: $name ($type) parent: $parentId',
      context: LogContext.treasury,
    );
    final id = _uuid.v4();
    final now = DateTime.now();

    final companion = TreasuryCategoriesCompanion.insert(
      id: id,
      name: name,
      type: type,
      description: Value(description),
      parentId: Value(parentId),
      createdAt: now,
    );

    await _db.into(_db.treasuryCategories).insert(companion);
    _sync.updatePendingCount();
    _sync.sync();

    return TreasuryCategory(
      id: id,
      name: name,
      type: type,
      description: description,
      parentId: parentId,
      createdAt: now,
    );
  }

  Future<TreasuryCategory> addSubcategory({
    required String parentId,
    required String name,
    String type = 'both',
    String? description,
  }) {
    return addCategory(
      name: name,
      type: type,
      description: description,
      parentId: parentId,
    );
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    String type = 'both',
    String? description,
  }) async {
    _logger.info(
      'Updating treasury category: $id',
      context: LogContext.treasury,
    );
    await (_db.update(
      _db.treasuryCategories,
    )..where((t) => t.id.equals(id))).write(
      TreasuryCategoriesCompanion(
        name: Value(name),
        type: Value(type),
        description: Value(description),
        syncedAt: const Value(null),
      ),
    );
    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<void> deleteCategory(String id) async {
    _logger.info(
      'Deleting treasury category: $id',
      context: LogContext.treasury,
    );

    // Check if category has subcategories
    final subcategories = await (_db.select(_db.treasuryCategories)
          ..where((t) => t.parentId.equals(id)))
        .get();
    if (subcategories.isNotEmpty) {
      throw Exception(
        'لا يمكن حذف البند الرئيسي لوجود ${subcategories.length} بنود فرعية مرتبطة به',
      );
    }

    final linked = await (_db.select(
      _db.treasuryTransactions,
    )..where((t) => t.categoryId.equals(id) | t.subcategoryId.equals(id))).get();

    if (linked.isNotEmpty) {
      throw Exception(
        'لا يمكن حذف التصنيف لوجود ${linked.length} حركات مرتبطة به',
      );
    }

    await _db
        .into(_db.deletedRecords)
        .insert(
          DeletedRecordsCompanion.insert(
            id: _uuid.v4(),
            targetTable: 'treasury_categories',
            recordId: id,
            createdAt: DateTime.now(),
          ),
        );

    await (_db.delete(
      _db.treasuryCategories,
    )..where((t) => t.id.equals(id))).go();
    _sync.updatePendingCount();
    _sync.sync();
  }

  // --- Transactions ---

  Future<List<TreasuryTransaction>> getTransactions({
    String? type,
    String? categoryId,
    String? subcategoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = _db.select(_db.treasuryTransactions);

    if (type != null && type.isNotEmpty && type != 'all') {
      query.where((t) => t.type.equals(type));
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      query.where((t) => t.categoryId.equals(categoryId));
    }

    if (subcategoryId != null && subcategoryId.isNotEmpty) {
      query.where((t) => t.subcategoryId.equals(subcategoryId));
    }

    if (startDate != null) {
      query.where((t) => t.createdAt.isBiggerOrEqualValue(startDate));
    }

    if (endDate != null) {
      query.where((t) => t.createdAt.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Future<List<TreasuryTransactionWithCategory>> getTransactionsWithCategory({
    String? type,
    String? categoryId,
    String? subcategoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final txList = await getTransactions(
      type: type,
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      startDate: startDate,
      endDate: endDate,
    );

    final allCats = await _db.select(_db.treasuryCategories).get();
    final catMap = {for (final c in allCats) c.id: c};
    final catNameMap = {for (final c in allCats) c.name: c};

    return txList.map((tx) {
      TreasuryCategory? cat;
      if (tx.categoryId != null) {
        cat = catMap[tx.categoryId];
      } else if (tx.categoryName != null) {
        cat = catNameMap[tx.categoryName];
      }

      TreasuryCategory? sub;
      if (tx.subcategoryId != null) {
        sub = catMap[tx.subcategoryId];
      } else if (tx.subcategoryName != null) {
        sub = catNameMap[tx.subcategoryName];
      }

      return TreasuryTransactionWithCategory(
        transaction: tx,
        category: cat,
        subcategory: sub,
      );
    }).toList();
  }

  Stream<List<TreasuryTransaction>> watchTransactions({
    String? type,
    String? categoryId,
    String? subcategoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final query = _db.select(_db.treasuryTransactions);

    if (type != null && type.isNotEmpty && type != 'all') {
      query.where((t) => t.type.equals(type));
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      query.where((t) => t.categoryId.equals(categoryId));
    }

    if (subcategoryId != null && subcategoryId.isNotEmpty) {
      query.where((t) => t.subcategoryId.equals(subcategoryId));
    }

    if (startDate != null) {
      query.where((t) => t.createdAt.isBiggerOrEqualValue(startDate));
    }

    if (endDate != null) {
      query.where((t) => t.createdAt.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }

  Future<TreasuryTransaction> addTransaction({
    required String type, // 'in' or 'out'
    required double amount,
    required String categoryName,
    String? categoryId,
    String? subcategoryId,
    String? subcategoryName,
    String? personName,
    String? notes,
    String? currency,
    DateTime? createdAt,
  }) async {
    _logger.info(
      'Adding treasury transaction: $type $amount ($categoryName) person: $personName',
      context: LogContext.treasury,
    );
    final id = _uuid.v4();
    final now = createdAt ?? DateTime.now();
    final curr = currency ?? AppCurrency.primaryCode;
    final nextSerial = await _db.getNextTreasurySerialNumber();

    final companion = TreasuryTransactionsCompanion.insert(
      id: id,
      serialNumber: Value(nextSerial),
      type: type,
      amount: amount,
      currency: Value(curr),
      categoryId: Value(categoryId),
      categoryName: Value(categoryName),
      subcategoryId: Value(subcategoryId),
      subcategoryName: Value(subcategoryName),
      personName: Value(
        personName?.trim().isEmpty ?? true ? null : personName!.trim(),
      ),
      notes: Value(notes?.trim().isEmpty ?? true ? null : notes!.trim()),
      createdAt: now,
    );

    await _db.into(_db.treasuryTransactions).insert(companion);
    _sync.updatePendingCount();
    _sync.sync();

    return TreasuryTransaction(
      id: id,
      serialNumber: nextSerial,
      type: type,
      amount: amount,
      currency: curr,
      categoryId: categoryId,
      categoryName: categoryName,
      subcategoryId: subcategoryId,
      subcategoryName: subcategoryName,
      personName: personName?.trim().isEmpty ?? true
          ? null
          : personName!.trim(),
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      createdAt: now,
    );
  }

  Future<void> updateTransaction({
    required String id,
    required String type,
    required double amount,
    required String categoryName,
    String? categoryId,
    String? subcategoryId,
    String? subcategoryName,
    String? personName,
    String? notes,
    String? currency,
    DateTime? createdAt,
  }) async {
    _logger.info(
      'Updating treasury transaction: $id',
      context: LogContext.treasury,
    );

    await (_db.update(
      _db.treasuryTransactions,
    )..where((t) => t.id.equals(id))).write(
      TreasuryTransactionsCompanion(
        type: Value(type),
        amount: Value(amount),
        currency: currency != null ? Value(currency) : const Value.absent(),
        categoryId: Value(categoryId),
        categoryName: Value(categoryName),
        subcategoryId: Value(subcategoryId),
        subcategoryName: Value(subcategoryName),
        personName: Value(
          personName?.trim().isEmpty ?? true ? null : personName!.trim(),
        ),
        notes: Value(notes?.trim().isEmpty ?? true ? null : notes!.trim()),
        createdAt: createdAt != null ? Value(createdAt) : const Value.absent(),
        syncedAt: const Value(null),
      ),
    );

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<void> deleteTransaction(String id) async {
    _logger.info(
      'Deleting treasury transaction: $id',
      context: LogContext.treasury,
    );

    await _db
        .into(_db.deletedRecords)
        .insert(
          DeletedRecordsCompanion.insert(
            id: _uuid.v4(),
            targetTable: 'treasury_transactions',
            recordId: id,
            createdAt: DateTime.now(),
          ),
        );

    await (_db.delete(
      _db.treasuryTransactions,
    )..where((t) => t.id.equals(id))).go();
    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<List<TreasuryCategorySummary>> getCategorySummaries({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final mainCategories = await getCategories();
    final allSubcategories = await getAllSubcategories();
    final transactions = await getTransactions(
      startDate: startDate,
      endDate: endDate,
    );

    final List<TreasuryCategorySummary> result = [];

    for (final mainCat in mainCategories) {
      final subs = allSubcategories
          .where((s) => s.parentId == mainCat.id)
          .toList();
      final subSummaries = <TreasuryCategorySummary>[];

      for (final sub in subs) {
        final subTx = transactions
            .where((t) =>
                t.subcategoryId == sub.id ||
                (t.subcategoryId == null &&
                 t.subcategoryName == sub.name &&
                 (t.categoryId == mainCat.id ||
                  (t.categoryId == null && t.categoryName == mainCat.name))))
            .toList();
        final syp = subTx
            .where((t) => t.currency != 'USD')
            .fold<double>(0.0, (sum, t) => sum + (t.type == 'in' ? t.amount : -t.amount));
        final usd = subTx
            .where((t) => t.currency == 'USD')
            .fold<double>(0.0, (sum, t) => sum + (t.type == 'in' ? t.amount : -t.amount));

        subSummaries.add(
          TreasuryCategorySummary(
            category: sub,
            totalAmountSyp: syp,
            totalAmountUsd: usd,
            count: subTx.length,
          ),
        );
      }

      final mainTx = transactions.where((t) =>
          t.categoryId == mainCat.id ||
          (t.categoryId == null && t.categoryName == mainCat.name));

      double catTotalSyp = 0.0;
      double catTotalUsd = 0.0;
      int catCount = 0;

      for (final tx in mainTx) {
        final sign = tx.type == 'in' ? 1.0 : -1.0;
        if (tx.currency == 'USD') {
          catTotalUsd += sign * tx.amount;
        } else {
          catTotalSyp += sign * tx.amount;
        }
        catCount++;
      }

      result.add(
        TreasuryCategorySummary(
          category: mainCat,
          totalAmountSyp: catTotalSyp,
          totalAmountUsd: catTotalUsd,
          count: catCount,
          subcategories: subSummaries,
        ),
      );
    }

    return result;
  }
}
