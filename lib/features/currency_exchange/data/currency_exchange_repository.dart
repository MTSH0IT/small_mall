import 'package:drift/drift.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:uuid/uuid.dart';

class CurrencyExchangeSummary {
  const CurrencyExchangeSummary({
    this.totalSypOut = 0.0,
    this.totalSypIn = 0.0,
    this.totalUsdOut = 0.0,
    this.totalUsdIn = 0.0,
    this.count = 0,
  });

  final double totalSypOut;
  final double totalSypIn;
  final double totalUsdOut;
  final double totalUsdIn;
  final int count;

  double get netSypImpact => totalSypIn - totalSypOut;
  double get netUsdImpact => totalUsdIn - totalUsdOut;
}

class CurrencyExchangeRepository {
  CurrencyExchangeRepository(this._db, this._sync, this._logger);

  final AppDatabase _db;
  final SyncService _sync;
  final AppLogger _logger;
  final _uuid = const Uuid();

  Future<ExchangeInvoice> recordExchange({
    required String actionType, // 'buy_usd' | 'sell_usd'
    required String fromCurrency,
    required double fromAmount,
    required String toCurrency,
    required double toAmount,
    required double exchangeRate,
    String? notes,
    DateTime? createdAt,
  }) async {
    final now = createdAt ?? DateTime.now();
    final id = _uuid.v4();
    final serialNumber = await _db.getNextExchangeSerialNumber();

    _logger.info(
      'Recording currency exchange: #$serialNumber $actionType from=$fromAmount $fromCurrency to=$toAmount $toCurrency @ $exchangeRate',
      context: LogContext.pos,
    );

    final item = ExchangeInvoice(
      id: id,
      serialNumber: serialNumber,
      actionType: actionType,
      fromCurrency: fromCurrency,
      fromAmount: fromAmount,
      toCurrency: toCurrency,
      toAmount: toAmount,
      exchangeRate: exchangeRate,
      notes: (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      createdAt: now,
      syncedAt: null,
    );

    await _db.into(_db.exchangeInvoices).insert(item);

    _sync.updatePendingCount();
    _sync.sync();

    return item;
  }

  Future<List<ExchangeInvoice>> getExchanges({
    DateTime? start,
    DateTime? end,
  }) async {
    var query = _db.select(_db.exchangeInvoices);
    if (start != null && end != null) {
      query = query
        ..where(
          (t) =>
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end),
        );
    }
    return (query..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  Future<CurrencyExchangeSummary> getExchangeSummary({
    DateTime? start,
    DateTime? end,
  }) async {
    final exchanges = await getExchanges(start: start, end: end);
    double sypOut = 0.0;
    double sypIn = 0.0;
    double usdOut = 0.0;
    double usdIn = 0.0;

    for (final ex in exchanges) {
      if (ex.fromCurrency == 'SYP') {
        sypOut += ex.fromAmount;
      } else if (ex.fromCurrency == 'USD') {
        usdOut += ex.fromAmount;
      }

      if (ex.toCurrency == 'SYP') {
        sypIn += ex.toAmount;
      } else if (ex.toCurrency == 'USD') {
        usdIn += ex.toAmount;
      }
    }

    return CurrencyExchangeSummary(
      totalSypOut: sypOut,
      totalSypIn: sypIn,
      totalUsdOut: usdOut,
      totalUsdIn: usdIn,
      count: exchanges.length,
    );
  }

  Future<void> deleteExchange(String id) async {
    _logger.info('Deleting currency exchange invoice: $id', context: LogContext.pos);
    final now = DateTime.now();

    await _db.transaction(() async {
      await _db.into(_db.deletedRecords).insert(
        DeletedRecordsCompanion.insert(
          id: _uuid.v4(),
          targetTable: 'exchange_invoices',
          recordId: id,
          createdAt: now,
        ),
      );
      await (_db.delete(_db.exchangeInvoices)..where((t) => t.id.equals(id))).go();
    });

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<ExchangeInvoice> updateExchange({
    required String id,
    required String actionType,
    required String fromCurrency,
    required double fromAmount,
    required String toCurrency,
    required double toAmount,
    required double exchangeRate,
    String? notes,
    DateTime? createdAt,
  }) async {
    _logger.info('Updating currency exchange invoice: $id', context: LogContext.pos);

    await (_db.update(_db.exchangeInvoices)..where((t) => t.id.equals(id))).write(
      ExchangeInvoicesCompanion(
        actionType: Value(actionType),
        fromCurrency: Value(fromCurrency),
        fromAmount: Value(fromAmount),
        toCurrency: Value(toCurrency),
        toAmount: Value(toAmount),
        exchangeRate: Value(exchangeRate),
        notes: Value(notes),
        createdAt: createdAt != null ? Value(createdAt) : const Value.absent(),
        syncedAt: const Value(null),
      ),
    );

    _sync.updatePendingCount();
    _sync.sync();

    return (_db.select(_db.exchangeInvoices)..where((t) => t.id.equals(id))).getSingle();
  }
}
