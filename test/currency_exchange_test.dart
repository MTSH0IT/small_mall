import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/features/currency_exchange/data/currency_exchange_repository.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';

void main() {
  late AppDatabase db;
  late AppLogger logger;
  late SyncService sync;
  late CurrencyExchangeRepository exchangeRepo;
  late InvoicesRepository invoicesRepo;
  late ReportsRepository reportsRepo;
  late POSRepository posRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = AppLogger();
    sync = SyncService(db, logger);
    posRepo = POSRepository(db, sync, logger);
    exchangeRepo = CurrencyExchangeRepository(db, sync, logger);
    invoicesRepo = InvoicesRepository(db, posRepo, logger, sync);
    reportsRepo = ReportsRepository(db, logger);
  });

  tearDown(() async {
    await db.close();
  });

  group('Currency Exchange Accounting & Repository Tests', () {
    test('Buy USD and Sell USD update summary and sequence serial numbers', () async {
      final now = DateTime.now();

      // Record first exchange: buy $100 at rate 15,000 SYP (pays 1,500,000 SYP)
      final ex1 = await exchangeRepo.recordExchange(
        actionType: 'buy_usd',
        fromCurrency: 'SYP',
        fromAmount: 1500000.0,
        toCurrency: 'USD',
        toAmount: 100.0,
        exchangeRate: 15000.0,
        notes: 'شراء 100 دولار للخزينة',
        createdAt: now,
      );

      expect(ex1.serialNumber, equals(1));
      expect(ex1.actionType, equals('buy_usd'));
      expect(ex1.fromCurrency, equals('SYP'));
      expect(ex1.fromAmount, equals(1500000.0));
      expect(ex1.toCurrency, equals('USD'));
      expect(ex1.toAmount, equals(100.0));
      expect(ex1.exchangeRate, equals(15000.0));

      // Record second exchange: sell $50 at rate 15,000 SYP (receives 750,000 SYP)
      final ex2 = await exchangeRepo.recordExchange(
        actionType: 'sell_usd',
        fromCurrency: 'USD',
        fromAmount: 50.0,
        toCurrency: 'SYP',
        toAmount: 750000.0,
        exchangeRate: 15000.0,
        notes: 'بيع 50 دولار',
        createdAt: now.add(const Duration(minutes: 5)),
      );

      expect(ex2.serialNumber, equals(2));
      expect(ex2.actionType, equals('sell_usd'));
      expect(ex2.fromCurrency, equals('USD'));
      expect(ex2.toCurrency, equals('SYP'));

      // Check summary
      final summary = await exchangeRepo.getExchangeSummary();
      expect(summary.totalUsdIn, equals(100.0));
      expect(summary.totalUsdOut, equals(50.0));
      expect(summary.netUsdImpact, equals(50.0)); // 100 - 50 = +$50 net to cashbox
      expect(summary.totalSypOut, equals(1500000.0));
      expect(summary.totalSypIn, equals(750000.0));
      expect(summary.netSypImpact, equals(-750000.0)); // -1.5M + 750k = -750k net from cashbox
      expect(summary.count, equals(2));
    });

    test('Invoices integration: unified transactions include exchange vouchers and deletion', () async {
      final now = DateTime.now();

      final ex = await exchangeRepo.recordExchange(
        actionType: 'buy_usd',
        fromCurrency: 'SYP',
        fromAmount: 300000.0,
        toCurrency: 'USD',
        toAmount: 20.0,
        exchangeRate: 15000.0,
        notes: 'صرافة تجريبية',
        createdAt: now,
      );

      final transactions = await invoicesRepo.getAllTransactions();
      final exTr = transactions.firstWhere((t) => t.id == ex.id);

      expect(exTr.type, equals(UnifiedTransactionType.exchange));
      expect(exTr.isExchange, isTrue);
      expect(exTr.hasMultipleCurrencies, isTrue);
      expect(exTr.totalSyp, equals(300000.0));
      expect(exTr.totalUsd, equals(20.0));
      expect(exTr.serialNumber, equals(1));

      // Test delete exchange transaction
      await invoicesRepo.deleteTransaction(exTr);
      final remaining = await exchangeRepo.getExchanges();
      expect(remaining.isEmpty, isTrue);
    });

    test('Editing exchange invoice updates amounts, rates, and cashbox balances', () async {
      final now = DateTime.now();
      final ex = await exchangeRepo.recordExchange(
        actionType: 'buy_usd',
        fromCurrency: 'SYP',
        fromAmount: 1500000.0,
        toCurrency: 'USD',
        toAmount: 100.0,
        exchangeRate: 15000.0,
        notes: 'ملاحظة أصلية',
        createdAt: now,
      );

      // Edit exchange to buy $200 at rate 15,000 (fromAmount 3,000,000 SYP)
      await invoicesRepo.updateExchangeInvoice(
        exchangeId: ex.id,
        actionType: 'buy_usd',
        fromCurrency: 'SYP',
        fromAmount: 3000000.0,
        toCurrency: 'USD',
        toAmount: 200.0,
        exchangeRate: 15000.0,
        notes: 'ملاحظة معدلة',
        createdAt: now,
      );

      final updated = (await exchangeRepo.getExchanges()).firstWhere((e) => e.id == ex.id);
      expect(updated.fromAmount, equals(3000000.0));
      expect(updated.toAmount, equals(200.0));
      expect(updated.notes, equals('ملاحظة معدلة'));

      // Check summary reflects updated amounts
      final summary = await exchangeRepo.getExchangeSummary();
      expect(summary.totalSypOut, equals(3000000.0));
      expect(summary.totalUsdIn, equals(200.0));
    });

    test('Reports integration: cash drawer before and after exchange calculations', () async {
      final start = DateTime.now().subtract(const Duration(hours: 1));
      final end = DateTime.now().add(const Duration(hours: 1));

      // 1. Initial operational state:
      // Cash sale: 2,000,000 SYP
      await db.into(db.invoices).insert(
        InvoicesCompanion.insert(
          id: 'inv_1',
          type: 'sale',
          paymentType: 'cash',
          totalAmount: 2000000.0,
          currency: const Value('SYP'),
          createdAt: DateTime.now(),
        ),
      );

      // Operational expenses: 500,000 SYP
      await db.into(db.expenseCategories).insert(
        ExpenseCategoriesCompanion.insert(
          id: 'cat_1',
          name: 'إيجار',
          createdAt: DateTime.now(),
        ),
      );
      await db.into(db.expenses).insert(
        ExpensesCompanion.insert(
          id: 'exp_1',
          categoryId: 'cat_1',
          amount: 500000.0,
          currency: const Value('SYP'),
          createdAt: DateTime.now(),
        ),
      );

      // 2. Exchange movement:
      // Buy $50 by spending 750,000 SYP (withdraw 750k SYP, deposit $50)
      await exchangeRepo.recordExchange(
        actionType: 'buy_usd',
        fromCurrency: 'SYP',
        fromAmount: 750000.0,
        toCurrency: 'USD',
        toAmount: 50.0,
        exchangeRate: 15000.0,
        createdAt: DateTime.now(),
      );

      // 3. Verify Cash Drawer Report:
      final report = await reportsRepo.getCashDrawerReport(start, end);

      // Operational cash flow before exchange:
      // Inflow = 2,000,000 SYP
      // Outflow = 500,000 SYP
      // Net Cash Flow Before = 1,500,000 SYP
      expect(report.cashSales, equals(2000000.0));
      expect(report.expensesPaid, equals(500000.0));
      expect(report.balanceBeforeSyp, equals(1500000.0));
      expect(report.balanceBeforeUsd, equals(0.0));

      // Exchange movement impact:
      // SYP Out = 750,000, SYP In = 0 => Net SYP = -750,000
      // USD In = 50, USD Out = 0 => Net USD = +50
      expect(report.exchangeOutSyp, equals(750000.0));
      expect(report.exchangeInSyp, equals(0.0));
      expect(report.netExchangeSyp, equals(-750000.0));
      expect(report.exchangeInUsd, equals(50.0));
      expect(report.netExchangeUsd, equals(50.0));
      expect(report.exchangeCount, equals(1));

      // Actual cash in drawer after exchange:
      // SYP actual = 1,500,000 - 750,000 = 750,000 SYP
      // USD actual = 0 + 50 = $50
      expect(report.balanceAfterSyp, equals(750000.0));
      expect(report.balanceAfterUsd, equals(50.0));

      // Movements ledger includes exchange items
      final exchangeMovements = report.movements.where((m) => m.type == 'exchange').toList();
      expect(exchangeMovements.length, equals(2)); // One SYP outflow, one USD inflow
    });
  });
}
