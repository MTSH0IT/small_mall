import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';
import 'package:small_mall/features/reports/presentation/cubit/reports_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reports Data Models & Cash Drawer Calculations', () {
    test('CashDrawerReportData computes totalIn, totalOut, and netCashFlow correctly', () {
      final movements = [
        CashMovementItem(
          id: '1',
          title: 'مبيعات نقدية',
          type: 'cash_sale',
          isCashIn: true,
          amount: 1500.0,
          date: DateTime(2026, 9, 20, 10, 0),
        ),
        CashMovementItem(
          id: '2',
          title: 'تحصيل دين',
          type: 'debt_payment',
          isCashIn: true,
          amount: 500.0,
          date: DateTime(2026, 9, 20, 11, 0),
        ),
        CashMovementItem(
          id: '3',
          title: 'مرتجع نقدي',
          type: 'return',
          isCashIn: false,
          amount: 100.0,
          date: DateTime(2026, 9, 20, 12, 0),
        ),
        CashMovementItem(
          id: '4',
          title: 'فاتورة كهرباء',
          type: 'expense',
          isCashIn: false,
          amount: 250.0,
          date: DateTime(2026, 9, 20, 13, 0),
        ),
        CashMovementItem(
          id: '5',
          title: 'مشتريات بضاعة',
          type: 'purchase',
          isCashIn: false,
          amount: 650.0,
          date: DateTime(2026, 9, 20, 14, 0),
        ),
      ];

      final drawer = CashDrawerReportData(
        cashSales: 1500.0,
        debtPaymentsCollected: 500.0,
        totalCashIn: 2000.0,
        cashReturns: 100.0,
        expensesPaid: 250.0,
        cashPurchases: 650.0,
        totalCashOut: 1000.0,
        netCashFlow: 1000.0, // 2000 - 1000
        movements: movements,
      );

      expect(drawer.totalCashIn, equals(2000.0));
      expect(drawer.totalCashOut, equals(1000.0));
      expect(drawer.netCashFlow, equals(1000.0));
      expect(drawer.movements.length, equals(5));
      expect(drawer.movements.where((m) => m.isCashIn).length, equals(2));
      expect(drawer.movements.where((m) => !m.isCashIn).length, equals(3));
    });

    test('ProfitReportData calculates gross profit, margin, and net profit with loss adjustments', () {
      final profit = ProfitReportData(
        totalRevenue: 8500.0, // net sales
        totalCost: 5000.0, // cogs
        grossProfit: 3500.0, // 8500 - 5000
        totalExpenses: 1200.0,
        netProfit: 2000.0, // 3500 - 1200 - 300
        cashSales: 6000.0,
        debtSales: 3000.0,
        grossSales: 9000.0,
        returnsAmount: 500.0,
        adjustmentsLoss: 300.0,
        salesCount: 15,
        cashSalesCount: 10,
        returnsCount: 2,
        purchasesCount: 5,
        expensesCount: 4,
        debtPaymentsCount: 3,
        adjustmentsCount: 1,
        newDebtsCount: 5,
      );

      expect(profit.salesCount, equals(15));
      expect(profit.cashSalesCount, equals(10));
      expect(profit.newDebtsCount, equals(5));

      expect(profit.netSales, equals(8500.0));
      expect(profit.grossSales, equals(9000.0));
      expect(profit.returnsAmount, equals(500.0));
      expect(profit.costOfGoodsSold, equals(5000.0));
      expect(profit.grossProfit, equals(3500.0));
      expect(profit.totalExpenses, equals(1200.0));
      expect(profit.adjustmentsLoss, equals(300.0));
      expect(profit.netProfit, equals(2000.0));
      expect(profit.profitMargin, closeTo((2000.0 / 8500.0) * 100, 0.01));
    });

    test('Calculates net profit using user formula: (Sales + Debt Payments) - (Expenses + Purchases)', () {
      final profit = ProfitReportData(
        totalRevenue: 5000.0,
        totalCost: 3000.0,
        grossProfit: 2000.0,
        totalExpenses: 800.0,
        netProfit: 4700.0, // (5000 + 1500) - (800 + 1000) = 4700
        cashSales: 5000.0,
        debtPayments: 1500.0,
        totalPurchases: 1000.0,
        newDebts: 2000.0, // not added to sales!
      );

      expect(profit.netSales, equals(5000.0));
      expect(profit.debtPayments, equals(1500.0));
      expect(profit.totalExpenses, equals(800.0));
      expect(profit.totalPurchases, equals(1000.0));
      expect(profit.formulaNetProfit, equals(4700.0));
      expect(profit.netProfit, equals(4700.0));
    });

    test('InventoryAndDebtsReportData computes collection rate correctly', () {
      final invDebts = InventoryAndDebtsReportData(
        totalInventoryCost: 45000.0,
        totalActiveProducts: 120,
        lowStockProductsCount: 8,
        adjustmentsCostInPeriod: -150.0,
        adjustmentsCountInPeriod: 2,
        totalOutstandingDebts: 6500.0,
        newDebtsIssuedInPeriod: 1500.0,
        debtsCollectedInPeriod: 1000.0,
      );

      expect(invDebts.totalInventoryCost, equals(45000.0));
      expect(invDebts.totalActiveProducts, equals(120));
      expect(invDebts.lowStockProductsCount, equals(8));
      expect(invDebts.collectionRate, closeTo(40.0, 0.01)); // 1000 / (1500 + 1000) * 100 = 40%
    });
  });

  group('ReportsCubit Tab & Period Navigation Tests', () {
    test('ReportsLoaded state supports copyWith and tab switching', () {
      final now = DateTime.now();
      final state = ReportsLoaded(
        profitData: ProfitReportData(
          totalRevenue: 1000.0,
          totalCost: 600.0,
          grossProfit: 400.0,
          totalExpenses: 100.0,
          netProfit: 300.0,
        ),
        bestSellers: [],
        inventoryReport: [],
        totalOutstandingDebts: 0.0,
        purchasesSalesSummary: PurchasesSalesSummary(totalPurchases: 0, totalSales: 1000),
        cashDrawerData: CashDrawerReportData(
          cashSales: 1000,
          debtPaymentsCollected: 0,
          totalCashIn: 1000,
          cashReturns: 0,
          expensesPaid: 100,
          cashPurchases: 0,
          totalCashOut: 100,
          netCashFlow: 900,
          movements: [],
        ),
        inventoryAndDebtsData: InventoryAndDebtsReportData(
          totalInventoryCost: 10000,
          totalActiveProducts: 20,
          lowStockProductsCount: 0,
          adjustmentsCostInPeriod: 0,
          adjustmentsCountInPeriod: 0,
          totalOutstandingDebts: 0,
          newDebtsIssuedInPeriod: 0,
          debtsCollectedInPeriod: 0,
        ),
        startDate: now.subtract(const Duration(days: 7)),
        endDate: now,
        periodType: 'this_week',
        selectedTab: 0,
      );

      expect(state.selectedTab, equals(0));
      final tab1 = state.copyWith(selectedTab: 1);
      expect(tab1.selectedTab, equals(1));
      final tab2 = state.copyWith(selectedTab: 2);
      expect(tab2.selectedTab, equals(2));
      expect(tab2.periodType, equals('this_week'));
    });
  });

  group('Multi-Currency Invoices in ReportsRepository', () {
    late AppDatabase db;
    late ReportsRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ReportsRepository(db, AppLogger());
    });

    tearDown(() async {
      await db.close();
    });

    test('getProfitReport and getCashDrawerReport properly split multi-currency sales', () async {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 1));
      final end = now.add(const Duration(days: 1));

      // 1. Insert two products (one SYP, one USD)
      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'prod-syp',
              name: 'منتج بالليرة',
              costPrice: const Value(1000.0),
              costPriceUsd: const Value(0.0),
              currency: const Value('SYP'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'prod-usd',
              name: 'منتج بالدولار',
              costPrice: const Value(0.0),
              costPriceUsd: const Value(5.0),
              currency: const Value('USD'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 2. Insert multi-currency sale invoice (#2) with totalAmount = 1359.0 and currency = SYP
      await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              id: 'inv-multi',
              serialNumber: const Value(2),
              type: 'sale',
              totalAmount: 1359.0, // 1350 SYP + 9 USD
              discount: const Value(0.0),
              paymentType: 'cash',
              currency: const Value('SYP'),
              createdAt: now,
            ),
          );

      // 3. Insert invoice items: 1350 SYP and 9 USD
      await db.into(db.invoiceItems).insert(
            InvoiceItemsCompanion.insert(
              id: 'item-1',
              invoiceId: 'inv-multi',
              productId: 'prod-syp',
              priceUsed: 1350.0,
              quantity: 1.0,
              discount: const Value(0.0),
              currency: const Value('SYP'),
              costPrice: const Value(1000.0),
            ),
          );
      await db.into(db.invoiceItems).insert(
            InvoiceItemsCompanion.insert(
              id: 'item-2',
              invoiceId: 'inv-multi',
              productId: 'prod-usd',
              priceUsed: 9.0,
              quantity: 1.0,
              discount: const Value(0.0),
              currency: const Value('USD'),
              costPrice: const Value(5.0),
            ),
          );

      // 4. Test Profit Report
      final profitReport = await repo.getProfitReport(start, end);

      expect(profitReport.cashSales, equals(1350.0), reason: 'SYP cash sales should only be 1350.0');
      expect(profitReport.cashSalesUsd, equals(9.0), reason: 'USD cash sales should be 9.0');
      expect(profitReport.totalCost, equals(1000.0), reason: 'SYP cost should be 1000.0');
      expect(profitReport.totalCostUsd, equals(5.0), reason: 'USD cost should be 5.0');
      expect(profitReport.grossProfit, equals(350.0));
      expect(profitReport.grossProfitUsd, equals(4.0));
      expect(profitReport.salesCount, equals(1));
      expect(profitReport.cashSalesCount, equals(1));

      // 5. Test Cash Drawer Report
      final drawerReport = await repo.getCashDrawerReport(start, end);

      expect(drawerReport.cashSales, equals(1350.0));
      expect(drawerReport.cashSalesUsd, equals(9.0));
      expect(drawerReport.totalCashIn, equals(1350.0));
      expect(drawerReport.totalCashInUsd, equals(9.0));

      final sypMovement = drawerReport.movements.firstWhere((m) => m.currency == 'SYP');
      final usdMovement = drawerReport.movements.firstWhere((m) => m.currency == 'USD');
      expect(sypMovement.amount, equals(1350.0));
      expect(usdMovement.amount, equals(9.0));
    });
  });
}

