import 'package:drift/drift.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';
import 'package:small_mall/features/treasury/data/models/treasury_closure.dart';
import 'package:small_mall/features/treasury/data/models/treasury_ledger_item.dart';
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
  TreasuryRepository(
    this._db,
    this._sync,
    this._logger, {
    ReportsRepository? reportsRepo,
  }) : _reportsRepo = reportsRepo;

  final AppDatabase _db;
  final SyncService _sync;
  final AppLogger _logger;
  final ReportsRepository? _reportsRepo;
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

  // --- Treasury Closures & Reconciliation (Z-Reports) ---

  Future<void> _ensureClosuresTableExists() async {
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS treasury_closures (
        id TEXT PRIMARY KEY NOT NULL,
        serial_number INTEGER,
        closed_at INTEGER NOT NULL,
        opening_balance_syp REAL NOT NULL DEFAULT 0.0,
        opening_balance_usd REAL NOT NULL DEFAULT 0.0,
        total_in_syp REAL NOT NULL DEFAULT 0.0,
        total_in_usd REAL NOT NULL DEFAULT 0.0,
        total_out_syp REAL NOT NULL DEFAULT 0.0,
        total_out_usd REAL NOT NULL DEFAULT 0.0,
        expected_balance_syp REAL NOT NULL,
        expected_balance_usd REAL NOT NULL,
        actual_balance_syp REAL NOT NULL,
        actual_balance_usd REAL NOT NULL,
        difference_syp REAL NOT NULL,
        difference_usd REAL NOT NULL,
        denominations_syp_json TEXT,
        denominations_usd_json TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'balanced'
      );
    ''');
  }

  Future<int> getNextClosureSerialNumber() async {
    await _ensureClosuresTableExists();
    final result = await _db.customSelect(
      'SELECT MAX(serial_number) as max_serial FROM treasury_closures',
    ).getSingleOrNull();
    final maxSerial = result?.data['max_serial'] as int?;
    return (maxSerial ?? 0) + 1;
  }

  Future<void> saveClosure(
    TreasuryClosure closure, {
    bool createAdjustmentTransactions = false,
  }) async {
    _logger.info(
      'Saving treasury closure: status=${closure.status}, diffSyp=${closure.differenceSyp}, diffUsd=${closure.differenceUsd}',
      context: LogContext.treasury,
    );
    await _ensureClosuresTableExists();
    final serial = closure.serialNumber ?? await getNextClosureSerialNumber();
    final updatedClosure = TreasuryClosure(
      id: closure.id,
      serialNumber: serial,
      closedAt: closure.closedAt,
      openingBalanceSyp: closure.openingBalanceSyp,
      openingBalanceUsd: closure.openingBalanceUsd,
      totalInSyp: closure.totalInSyp,
      totalInUsd: closure.totalInUsd,
      totalOutSyp: closure.totalOutSyp,
      totalOutUsd: closure.totalOutUsd,
      expectedBalanceSyp: closure.expectedBalanceSyp,
      expectedBalanceUsd: closure.expectedBalanceUsd,
      actualBalanceSyp: closure.actualBalanceSyp,
      actualBalanceUsd: closure.actualBalanceUsd,
      differenceSyp: closure.differenceSyp,
      differenceUsd: closure.differenceUsd,
      denominations: closure.denominations,
      notes: closure.notes,
      status: closure.status,
    );

    await _db.customInsert(
      '''
      INSERT OR REPLACE INTO treasury_closures (
        id, serial_number, closed_at,
        opening_balance_syp, opening_balance_usd,
        total_in_syp, total_in_usd,
        total_out_syp, total_out_usd,
        expected_balance_syp, expected_balance_usd,
        actual_balance_syp, actual_balance_usd,
        difference_syp, difference_usd,
        denominations_syp_json, denominations_usd_json,
        notes, status
      ) VALUES (
        ?, ?, ?,
        ?, ?,
        ?, ?,
        ?, ?,
        ?, ?,
        ?, ?,
        ?, ?,
        ?, ?,
        ?, ?
      )
      ''',
      variables: [
        Variable.withString(updatedClosure.id),
        Variable.withInt(updatedClosure.serialNumber!),
        Variable.withInt(updatedClosure.closedAt.millisecondsSinceEpoch),
        Variable.withReal(updatedClosure.openingBalanceSyp),
        Variable.withReal(updatedClosure.openingBalanceUsd),
        Variable.withReal(updatedClosure.totalInSyp),
        Variable.withReal(updatedClosure.totalInUsd),
        Variable.withReal(updatedClosure.totalOutSyp),
        Variable.withReal(updatedClosure.totalOutUsd),
        Variable.withReal(updatedClosure.expectedBalanceSyp),
        Variable.withReal(updatedClosure.expectedBalanceUsd),
        Variable.withReal(updatedClosure.actualBalanceSyp),
        Variable.withReal(updatedClosure.actualBalanceUsd),
        Variable.withReal(updatedClosure.differenceSyp),
        Variable.withReal(updatedClosure.differenceUsd),
        Variable.withString(updatedClosure.denominations.toJsonSyp()),
        Variable.withString(updatedClosure.denominations.toJsonUsd()),
        Variable.withString(updatedClosure.notes ?? ''),
        Variable.withString(updatedClosure.status),
      ],
    );

    if (createAdjustmentTransactions) {
      if (updatedClosure.differenceSyp.abs() > 0.001) {
        final isShortage = updatedClosure.differenceSyp < 0;
        await addTransaction(
          type: isShortage ? 'out' : 'in',
          amount: updatedClosure.differenceSyp.abs(),
          categoryName: isShortage ? 'تسوية عجز جرد خزينة' : 'تسوية فائض جرد خزينة',
          currency: AppCurrency.sypCode,
          notes: 'تسوية آلية لمحضر جرد رقم #${updatedClosure.serialNumber}',
          createdAt: updatedClosure.closedAt,
        );
      }

      if (updatedClosure.differenceUsd.abs() > 0.001) {
        final isShortage = updatedClosure.differenceUsd < 0;
        await addTransaction(
          type: isShortage ? 'out' : 'in',
          amount: updatedClosure.differenceUsd.abs(),
          categoryName: isShortage ? 'تسوية عجز جرد خزينة' : 'تسوية فائض جرد خزينة',
          currency: AppCurrency.usdCode,
          notes: 'تسوية آلية لمحضر جرد رقم #${updatedClosure.serialNumber}',
          createdAt: updatedClosure.closedAt,
        );
      }
    }
  }

  Future<List<TreasuryClosure>> getClosures() async {
    await _ensureClosuresTableExists();
    final rows = await _db.customSelect(
      'SELECT * FROM treasury_closures ORDER BY closed_at DESC',
    ).get();

    return rows.map((row) => TreasuryClosure.fromMap(row.data)).toList();
  }

  Future<TreasuryClosure?> getLatestClosure() async {
    await _ensureClosuresTableExists();
    final row = await _db.customSelect(
      'SELECT * FROM treasury_closures ORDER BY closed_at DESC LIMIT 1',
    ).getSingleOrNull();

    if (row == null) return null;
    return TreasuryClosure.fromMap(row.data);
  }

  ReportsRepository get _effectiveReportsRepo {
    if (_reportsRepo != null) return _reportsRepo;
    if (getIt.isRegistered<ReportsRepository>()) {
      return getIt<ReportsRepository>();
    }
    return ReportsRepository(_db, _logger);
  }

  // --- Real-Time Main Vault Balances ---

  Future<Map<String, double>> getCurrentVaultBalances() async {
    final reportsRepo = _effectiveReportsRepo;
    final drawerReport = await reportsRepo.getCashDrawerReport(
      DateTime(2020),
      DateTime.now().add(const Duration(days: 1)),
    );
    return {
      'SYP': drawerReport.netCashFlow,
      'USD': drawerReport.netCashFlowUsd,
    };
  }

  // --- Store-Wide Unified Ledger With Running Balance ---

  Future<List<TreasuryLedgerItem>> getUnifiedLedger({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final reportsRepo = _effectiveReportsRepo;
    final end = endDate ?? DateTime.now().add(const Duration(days: 1));

    double runningSyp = 0.0;
    double runningUsd = 0.0;

    if (startDate != null) {
      final priorReport = await reportsRepo.getCashDrawerReport(
        DateTime(2020),
        startDate.subtract(const Duration(milliseconds: 1)),
      );
      runningSyp = priorReport.netCashFlow;
      runningUsd = priorReport.netCashFlowUsd;
    }

    final periodReport = await reportsRepo.getCashDrawerReport(
      startDate ?? DateTime(2020),
      end,
    );

    final chronMovements = List<CashMovementItem>.from(periodReport.movements)
      ..sort((a, b) => a.date.compareTo(b.date));

    final List<TreasuryLedgerItem> ledger = [];

    for (final m in chronMovements) {
      final isUsd = m.currency == 'USD';
      final factor = m.isCashIn ? 1.0 : -1.0;
      if (isUsd) {
        runningUsd += factor * m.amount;
      } else {
        runningSyp += factor * m.amount;
      }

      ledger.add(
        TreasuryLedgerItem(
          id: m.id,
          title: m.title,
          type: m.type,
          isCashIn: m.isCashIn,
          amount: m.amount,
          date: m.date,
          currency: m.currency,
          partyName: m.partyName,
          referenceNumber: m.referenceNumber,
          notes: m.notes,
          runningBalanceSyp: runningSyp,
          runningBalanceUsd: runningUsd,
        ),
      );
    }

    return ledger.reversed.toList();
  }
}
