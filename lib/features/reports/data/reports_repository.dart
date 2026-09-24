import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';

class ProfitReportData {
  ProfitReportData({
    required this.totalRevenue,
    required this.totalCost,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    this.cashSales = 0.0,
    this.debtSales = 0.0,
    this.grossSales = 0.0,
    this.returnsAmount = 0.0,
    this.totalPurchases = 0.0,
    this.debtPayments = 0.0,
    this.newDebts = 0.0,
    this.adjustmentsLoss = 0.0,
    // USD metrics
    this.cashSalesUsd = 0.0,
    this.debtSalesUsd = 0.0,
    this.grossSalesUsd = 0.0,
    this.returnsAmountUsd = 0.0,
    this.totalCostUsd = 0.0,
    this.grossProfitUsd = 0.0,
    this.totalExpensesUsd = 0.0,
    this.totalPurchasesUsd = 0.0,
    this.debtPaymentsUsd = 0.0,
    this.newDebtsUsd = 0.0,
    this.adjustmentsLossUsd = 0.0,
    this.netProfitUsd = 0.0,
    // Counts
    this.salesCount = 0,
    this.cashSalesCount = 0,
    this.returnsCount = 0,
    this.purchasesCount = 0,
    this.expensesCount = 0,
    this.debtPaymentsCount = 0,
    this.adjustmentsCount = 0,
    this.newDebtsCount = 0,
  });

  // Base SYP values
  final double totalRevenue; // Actual cash sales (no debts added!)
  final double totalCost; // Cost of goods sold (COGS)
  final double grossProfit;
  final double totalExpenses;
  final double netProfit;
  final double cashSales;
  final double debtSales;
  final double grossSales;
  final double returnsAmount;
  final double totalPurchases;
  final double debtPayments;
  final double newDebts;
  final double adjustmentsLoss;

  // USD values
  final double cashSalesUsd;
  final double debtSalesUsd;
  final double grossSalesUsd;
  final double returnsAmountUsd;
  final double totalCostUsd;
  final double grossProfitUsd;
  final double totalExpensesUsd;
  final double totalPurchasesUsd;
  final double debtPaymentsUsd;
  final double newDebtsUsd;
  final double adjustmentsLossUsd;
  final double netProfitUsd;

  final int salesCount;
  final int cashSalesCount;
  final int returnsCount;
  final int purchasesCount;
  final int expensesCount;
  final int debtPaymentsCount;
  final int adjustmentsCount;
  final int newDebtsCount;

  // Formula helpers for SYP: صافي الربح = (المبيعات + السداد) - (المصاريف + المشتريات)
  double get netSales => totalRevenue;
  double get totalInflows => netSales + debtPayments;
  double get totalOutflows => totalExpenses + totalPurchases;
  double get formulaNetProfit => totalInflows - totalOutflows;
  double get costOfGoodsSold => totalCost;
  double get profitMargin => netSales > 0 ? (netProfit / netSales) * 100 : 0.0;

  // Formula helpers for USD
  double get netSalesUsd => cashSalesUsd;
  double get totalInflowsUsd => cashSalesUsd + debtPaymentsUsd;
  double get totalOutflowsUsd => totalExpensesUsd + totalPurchasesUsd;
  double get formulaNetProfitUsd => totalInflowsUsd - totalOutflowsUsd;
  double get costOfGoodsSoldUsd => totalCostUsd;
  double get profitMarginUsd => netSalesUsd > 0 ? (netProfitUsd / netSalesUsd) * 100 : 0.0;

  // Backwards compatibility alias
  double get totalProfit => netProfit;
}

class CashMovementItem {
  CashMovementItem({
    required this.id,
    required this.title,
    required this.type, // 'cash_sale', 'debt_payment', 'return', 'expense', 'purchase'
    required this.isCashIn,
    required this.amount,
    required this.date,
    this.currency = AppCurrency.defaultCode,
    this.partyName,
    this.referenceNumber,
    this.notes,
  });

  final String id;
  final String title;
  final String type;
  final bool isCashIn;
  final double amount;
  final DateTime date;
  final String currency;
  final String? partyName;
  final String? referenceNumber;
  final String? notes;

  String get currencySymbol => AppCurrency.getSymbol(currency);
}

class CashDrawerReportData {
  CashDrawerReportData({
    required this.cashSales,
    required this.debtPaymentsCollected,
    required this.totalCashIn,
    required this.cashReturns,
    required this.expensesPaid,
    required this.cashPurchases,
    required this.totalCashOut,
    required this.netCashFlow,
    this.cashSalesUsd = 0.0,
    this.debtPaymentsCollectedUsd = 0.0,
    this.totalCashInUsd = 0.0,
    this.cashReturnsUsd = 0.0,
    this.expensesPaidUsd = 0.0,
    this.cashPurchasesUsd = 0.0,
    this.totalCashOutUsd = 0.0,
    this.netCashFlowUsd = 0.0,
    required this.movements,
  });

  final double cashSales;
  final double debtPaymentsCollected;
  final double totalCashIn;
  final double cashReturns;
  final double expensesPaid;
  final double cashPurchases;
  final double totalCashOut;
  final double netCashFlow;

  final double cashSalesUsd;
  final double debtPaymentsCollectedUsd;
  final double totalCashInUsd;
  final double cashReturnsUsd;
  final double expensesPaidUsd;
  final double cashPurchasesUsd;
  final double totalCashOutUsd;
  final double netCashFlowUsd;

  final List<CashMovementItem> movements;
}

class InventoryAndDebtsReportData {
  InventoryAndDebtsReportData({
    required this.totalInventoryCost,
    required this.totalActiveProducts,
    required this.lowStockProductsCount,
    required this.adjustmentsCostInPeriod,
    required this.adjustmentsCountInPeriod,
    required this.totalOutstandingDebts,
    required this.newDebtsIssuedInPeriod,
    required this.debtsCollectedInPeriod,
  });

  final double totalInventoryCost;
  final int totalActiveProducts;
  final int lowStockProductsCount;
  final double adjustmentsCostInPeriod;
  final int adjustmentsCountInPeriod;
  final double totalOutstandingDebts;
  final double newDebtsIssuedInPeriod;
  final double debtsCollectedInPeriod;

  double get collectionRate => (newDebtsIssuedInPeriod + debtsCollectedInPeriod) > 0
      ? (debtsCollectedInPeriod / (newDebtsIssuedInPeriod + debtsCollectedInPeriod)) * 100
      : 0.0;
}

class ProductSalesSummary {
  ProductSalesSummary({
    required this.product,
    required this.totalQuantity,
    required this.totalRevenue,
  });
  final Product product;
  final double totalQuantity;
  final double totalRevenue;
}

class InventoryReportItem {
  InventoryReportItem({
    required this.product,
    required this.currentStock,
    required this.totalCostValue,
  });
  final Product product;
  final double currentStock;
  final double totalCostValue;
}

class PurchasesSalesSummary {
  PurchasesSalesSummary({
    required this.totalPurchases,
    required this.totalSales,
  });
  final double totalPurchases;
  final double totalSales;
}

class ReportsRepository {
  ReportsRepository(this._db, this._logger);
  final AppDatabase _db;
  final AppLogger _logger;

  // --- Profit Report ---

  Future<ProfitReportData> getProfitReport(DateTime start, DateTime end) async {
    _logger.debug('Fetching profit report: $start - $end', context: LogContext.inventory);

    // 1. Operational expenses in period
    final expenses = await (_db.select(_db.expenses)
          ..where((t) =>
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    double totalExpensesSyp = 0.0;
    double totalExpensesUsd = 0.0;
    for (final exp in expenses) {
      if (exp.currency == 'USD') {
        totalExpensesUsd += exp.amount;
      } else {
        totalExpensesSyp += exp.amount;
      }
    }
    final expensesCount = expenses.length;

    // 2. Purchases in period
    final purchases = await (_db.select(_db.purchaseInvoices)
          ..where((t) =>
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    double totalPurchasesSyp = 0.0;
    double totalPurchasesUsd = 0.0;
    for (final p in purchases) {
      if (p.currency == 'USD') {
        totalPurchasesUsd += p.totalAmount;
      } else {
        totalPurchasesSyp += p.totalAmount;
      }
    }
    final purchasesCount = purchases.length;

    // 3. Debt payments in period
    final debtPayments = await (_db.select(_db.debtPayments)
          ..where((t) =>
              t.paidAt.isBiggerOrEqualValue(start) &
              t.paidAt.isSmallerOrEqualValue(end)))
        .get();

    double totalDebtPaymentsSyp = 0.0;
    double totalDebtPaymentsUsd = 0.0;
    for (final dp in debtPayments) {
      if (dp.currency == 'USD') {
        totalDebtPaymentsUsd += dp.amountPaid;
      } else {
        totalDebtPaymentsSyp += dp.amountPaid;
      }
    }
    final debtPaymentsCount = debtPayments.length;

    // 4. New debts created in period
    final newDebtsRows = await (_db.select(_db.debts)
          ..where((t) =>
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    double totalNewDebtsSyp = 0.0;
    double totalNewDebtsUsd = 0.0;
    for (final d in newDebtsRows) {
      if (d.currency == 'USD') {
        totalNewDebtsUsd += d.amount;
      } else {
        totalNewDebtsSyp += d.amount;
      }
    }

    // 5. Stock adjustments in period
    final adjustments = await (_db.select(_db.stockMovements)
          ..where((t) => t.type.equals('adjustment') &
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    double adjustmentsLossSyp = 0.0;
    double adjustmentsLossUsd = 0.0;
    if (adjustments.isNotEmpty) {
      final adjProdIds = adjustments.map((a) => a.productId).toSet();
      final adjProds = await (_db.select(_db.products)..where((t) => t.id.isIn(adjProdIds))).get();
      final adjProdMap = {for (final p in adjProds) p.id: p};

      for (final adj in adjustments) {
        if (adj.quantity < 0) {
          final prod = adjProdMap[adj.productId];
          final costSyp = prod?.costPrice ?? 0.0;
          final costUsd = prod?.costPriceUsd ?? 0.0;
          if (prod?.currency == 'USD') {
            adjustmentsLossUsd += adj.quantity.abs() * (costUsd > 0 ? costUsd : costSyp);
          } else {
            adjustmentsLossSyp += adj.quantity.abs() * costSyp;
          }
        }
      }
    }

    // 6. Invoices in period
    final invoices = await (_db.select(_db.invoices)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    if (invoices.isEmpty) {
      final netProfitSyp = (0.0 + totalDebtPaymentsSyp) - (totalExpensesSyp + totalPurchasesSyp);
      final netProfitUsd = (0.0 + totalDebtPaymentsUsd) - (totalExpensesUsd + totalPurchasesUsd);
      return ProfitReportData(
        totalRevenue: 0.0,
        totalCost: 0.0,
        grossProfit: 0.0,
        totalExpenses: totalExpensesSyp,
        netProfit: netProfitSyp,
        cashSales: 0.0,
        debtSales: 0.0,
        grossSales: 0.0,
        returnsAmount: 0.0,
        totalPurchases: totalPurchasesSyp,
        debtPayments: totalDebtPaymentsSyp,
        newDebts: totalNewDebtsSyp,
        adjustmentsLoss: adjustmentsLossSyp,
        // USD
        cashSalesUsd: 0.0,
        debtSalesUsd: 0.0,
        grossSalesUsd: 0.0,
        returnsAmountUsd: 0.0,
        totalCostUsd: 0.0,
        grossProfitUsd: 0.0,
        totalExpensesUsd: totalExpensesUsd,
        totalPurchasesUsd: totalPurchasesUsd,
        debtPaymentsUsd: totalDebtPaymentsUsd,
        newDebtsUsd: totalNewDebtsUsd,
        adjustmentsLossUsd: adjustmentsLossUsd,
        netProfitUsd: netProfitUsd,
        // Counts
        salesCount: 0,
        cashSalesCount: 0,
        returnsCount: 0,
        purchasesCount: purchasesCount,
        expensesCount: expensesCount,
        debtPaymentsCount: debtPaymentsCount,
        adjustmentsCount: adjustments.length,
        newDebtsCount: newDebtsRows.length,
      );
    }

    final invoiceIds = invoices.map((i) => i.id).toSet();
    final periodItems = await (_db.select(_db.invoiceItems)
          ..where((t) => t.invoiceId.isIn(invoiceIds)))
        .get();

    final productIds = periodItems.map((i) => i.productId).toSet();
    final products = productIds.isEmpty
        ? <Product>[]
        : await (_db.select(_db.products)..where((t) => t.id.isIn(productIds))).get();
    final productMap = {for (var p in products) p.id: p};

    double cashSalesSyp = 0.0;
    double debtSalesSyp = 0.0;
    double grossSalesSyp = 0.0;
    double returnsAmountSyp = 0.0;
    double totalCostSyp = 0.0;

    double cashSalesUsd = 0.0;
    double debtSalesUsd = 0.0;
    double grossSalesUsd = 0.0;
    double returnsAmountUsd = 0.0;
    double totalCostUsd = 0.0;

    int salesCount = 0;
    int cashSalesCount = 0;
    int debtSalesCount = 0;
    int returnsCount = 0;

    for (final inv in invoices) {
      final items = periodItems.where((i) => i.invoiceId == inv.id).toList();
      final isUsd = inv.currency == 'USD';

      double invoiceCost = 0.0;
      for (final item in items) {
        final prod = productMap[item.productId];
        if (prod == null) continue;
        final unitCost = isUsd
            ? ((prod.costPriceUsd > 0) ? prod.costPriceUsd : prod.costPrice)
            : prod.costPrice;
        invoiceCost += unitCost * item.quantity;
      }

      if (inv.type == 'sale') {
        salesCount++;
        final isCash = inv.paymentType == 'cash';
        if (isCash) {
          cashSalesCount++;
        } else {
          debtSalesCount++;
        }
        if (isUsd) {
          grossSalesUsd += inv.totalAmount;
          if (isCash) {
            cashSalesUsd += inv.totalAmount;
          } else {
            debtSalesUsd += inv.totalAmount;
          }
          totalCostUsd += invoiceCost;
        } else {
          grossSalesSyp += inv.totalAmount;
          if (isCash) {
            cashSalesSyp += inv.totalAmount;
          } else {
            debtSalesSyp += inv.totalAmount;
          }
          totalCostSyp += invoiceCost;
        }
      } else if (inv.type == 'return') {
        returnsCount++;
        if (isUsd) {
          returnsAmountUsd += inv.totalAmount;
          totalCostUsd -= invoiceCost;
        } else {
          returnsAmountSyp += inv.totalAmount;
          totalCostSyp -= invoiceCost;
        }
      }
    }

    final actualCashSalesSyp = cashSalesSyp - returnsAmountSyp;
    final grossProfitSyp = actualCashSalesSyp - totalCostSyp;
    final formulaNetProfitSyp = (actualCashSalesSyp + totalDebtPaymentsSyp) - (totalExpensesSyp + totalPurchasesSyp);

    final actualCashSalesUsd = cashSalesUsd - returnsAmountUsd;
    final grossProfitUsd = actualCashSalesUsd - totalCostUsd;
    final formulaNetProfitUsd = (actualCashSalesUsd + totalDebtPaymentsUsd) - (totalExpensesUsd + totalPurchasesUsd);

    final finalNewDebtsCount = newDebtsRows.isNotEmpty
        ? newDebtsRows.length
        : debtSalesCount;

    return ProfitReportData(
      totalRevenue: actualCashSalesSyp > 0 ? actualCashSalesSyp : 0.0,
      totalCost: totalCostSyp,
      grossProfit: grossProfitSyp,
      totalExpenses: totalExpensesSyp,
      netProfit: formulaNetProfitSyp,
      cashSales: actualCashSalesSyp > 0 ? actualCashSalesSyp : 0.0,
      debtSales: debtSalesSyp,
      grossSales: grossSalesSyp,
      returnsAmount: returnsAmountSyp,
      totalPurchases: totalPurchasesSyp,
      debtPayments: totalDebtPaymentsSyp,
      newDebts: totalNewDebtsSyp > 0 ? totalNewDebtsSyp : debtSalesSyp,
      adjustmentsLoss: adjustmentsLossSyp,
      // USD
      cashSalesUsd: actualCashSalesUsd > 0 ? actualCashSalesUsd : 0.0,
      debtSalesUsd: debtSalesUsd,
      grossSalesUsd: grossSalesUsd,
      returnsAmountUsd: returnsAmountUsd,
      totalCostUsd: totalCostUsd,
      grossProfitUsd: grossProfitUsd,
      totalExpensesUsd: totalExpensesUsd,
      totalPurchasesUsd: totalPurchasesUsd,
      debtPaymentsUsd: totalDebtPaymentsUsd,
      newDebtsUsd: totalNewDebtsUsd > 0 ? totalNewDebtsUsd : debtSalesUsd,
      adjustmentsLossUsd: adjustmentsLossUsd,
      netProfitUsd: formulaNetProfitUsd,
      // Counts
      salesCount: salesCount,
      cashSalesCount: cashSalesCount,
      returnsCount: returnsCount,
      purchasesCount: purchasesCount,
      expensesCount: expensesCount,
      debtPaymentsCount: debtPaymentsCount,
      adjustmentsCount: adjustments.length,
      newDebtsCount: finalNewDebtsCount,
    );
  }

  // --- Cash Drawer / Register Report ---

  Future<CashDrawerReportData> getCashDrawerReport(DateTime start, DateTime end) async {
    _logger.debug('Fetching cash drawer report: $start - $end', context: LogContext.pos);

    final List<CashMovementItem> movements = [];

    // 1. Cash sales (Invoices type='sale' & paymentType='cash')
    final cashSalesInvoices = await (_db.select(_db.invoices)
          ..where((t) =>
              t.type.equals('sale') &
              t.paymentType.equals('cash') &
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    // 2. Cash returns (Invoices type='return')
    final returnsInvoices = await (_db.select(_db.invoices)
          ..where((t) =>
              t.type.equals('return') &
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    // 3. Debt payments collected (Cash received from debtors)
    final debtPayments = await (_db.select(_db.debtPayments)
          ..where((t) =>
              t.paidAt.isBiggerOrEqualValue(start) &
              t.paidAt.isSmallerOrEqualValue(end)))
        .get();

    // 4. Operational expenses paid
    final expenses = await (_db.select(_db.expenses)
          ..where((t) =>
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    // 5. Cash purchase invoices
    final purchases = await (_db.select(_db.purchaseInvoices)
          ..where((t) =>
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    // Fetch related names for detailed ledger
    final customers = await _db.select(_db.customers).get();
    final customerMap = {for (final c in customers) c.id: c.name};

    final debts = await _db.select(_db.debts).get();
    final debtMap = {for (final d in debts) d.id: d};

    final categories = await _db.select(_db.expenseCategories).get();
    final categoryMap = {for (final c in categories) c.id: c.name};

    final suppliers = await _db.select(_db.suppliers).get();
    final supplierMap = {for (final s in suppliers) s.id: s.name};

    double totalCashSalesSyp = 0.0;
    double totalCashSalesUsd = 0.0;
    for (final inv in cashSalesInvoices) {
      if (inv.currency == 'USD') {
        totalCashSalesUsd += inv.totalAmount;
      } else {
        totalCashSalesSyp += inv.totalAmount;
      }
      final custName = inv.customerId != null ? customerMap[inv.customerId] : null;
      movements.add(CashMovementItem(
        id: inv.id,
        title: 'reports.cash_sales'.tr(),
        type: 'cash_sale',
        isCashIn: true,
        amount: inv.totalAmount,
        date: inv.createdAt,
        currency: inv.currency,
        partyName: custName,
        referenceNumber: inv.serialNumber != null ? '#${inv.serialNumber}' : null,
      ));
    }

    double totalDebtPaymentsSyp = 0.0;
    double totalDebtPaymentsUsd = 0.0;
    for (final dp in debtPayments) {
      if (dp.currency == 'USD') {
        totalDebtPaymentsUsd += dp.amountPaid;
      } else {
        totalDebtPaymentsSyp += dp.amountPaid;
      }
      final debt = debtMap[dp.debtId];
      final custName = debt != null ? customerMap[debt.customerId] : null;
      movements.add(CashMovementItem(
        id: dp.id,
        title: 'reports.debt_collections'.tr(),
        type: 'debt_payment',
        isCashIn: true,
        amount: dp.amountPaid,
        date: dp.paidAt,
        currency: dp.currency,
        partyName: custName,
      ));
    }

    double totalCashReturnsSyp = 0.0;
    double totalCashReturnsUsd = 0.0;
    for (final ret in returnsInvoices) {
      if (ret.currency == 'USD') {
        totalCashReturnsUsd += ret.totalAmount;
      } else {
        totalCashReturnsSyp += ret.totalAmount;
      }
      final custName = ret.customerId != null ? customerMap[ret.customerId] : null;
      movements.add(CashMovementItem(
        id: ret.id,
        title: 'reports.cash_returns'.tr(),
        type: 'return',
        isCashIn: false,
        amount: ret.totalAmount,
        date: ret.createdAt,
        currency: ret.currency,
        partyName: custName,
        referenceNumber: ret.serialNumber != null ? '#${ret.serialNumber}' : null,
      ));
    }

    double totalExpensesSyp = 0.0;
    double totalExpensesUsd = 0.0;
    for (final exp in expenses) {
      if (exp.currency == 'USD') {
        totalExpensesUsd += exp.amount;
      } else {
        totalExpensesSyp += exp.amount;
      }
      final catName = categoryMap[exp.categoryId] ?? 'expenses.title'.tr();
      movements.add(CashMovementItem(
        id: exp.id,
        title: catName,
        type: 'expense',
        isCashIn: false,
        amount: exp.amount,
        date: exp.createdAt,
        currency: exp.currency,
        partyName: catName,
        notes: exp.notes,
      ));
    }

    double totalPurchasesSyp = 0.0;
    double totalPurchasesUsd = 0.0;
    for (final pur in purchases) {
      if (pur.currency == 'USD') {
        totalPurchasesUsd += pur.totalAmount;
      } else {
        totalPurchasesSyp += pur.totalAmount;
      }
      final suppName = supplierMap[pur.supplierId];
      movements.add(CashMovementItem(
        id: pur.id,
        title: 'reports.cash_purchases'.tr(),
        type: 'purchase',
        isCashIn: false,
        amount: pur.totalAmount,
        date: pur.createdAt,
        currency: pur.currency,
        partyName: suppName,
      ));
    }

    // Sort movements by date descending (newest first)
    movements.sort((a, b) => b.date.compareTo(a.date));

    final totalCashInSyp = totalCashSalesSyp + totalDebtPaymentsSyp;
    final totalCashInUsd = totalCashSalesUsd + totalDebtPaymentsUsd;

    final totalCashOutSyp = totalCashReturnsSyp + totalExpensesSyp + totalPurchasesSyp;
    final totalCashOutUsd = totalCashReturnsUsd + totalExpensesUsd + totalPurchasesUsd;

    final netCashFlowSyp = totalCashInSyp - totalCashOutSyp;
    final netCashFlowUsd = totalCashInUsd - totalCashOutUsd;

    return CashDrawerReportData(
      cashSales: totalCashSalesSyp,
      debtPaymentsCollected: totalDebtPaymentsSyp,
      totalCashIn: totalCashInSyp,
      cashReturns: totalCashReturnsSyp,
      expensesPaid: totalExpensesSyp,
      cashPurchases: totalPurchasesSyp,
      totalCashOut: totalCashOutSyp,
      netCashFlow: netCashFlowSyp,
      cashSalesUsd: totalCashSalesUsd,
      debtPaymentsCollectedUsd: totalDebtPaymentsUsd,
      totalCashInUsd: totalCashInUsd,
      cashReturnsUsd: totalCashReturnsUsd,
      expensesPaidUsd: totalExpensesUsd,
      cashPurchasesUsd: totalPurchasesUsd,
      totalCashOutUsd: totalCashOutUsd,
      netCashFlowUsd: netCashFlowUsd,
      movements: movements,
    );
  }

  // --- Inventory & Debts Report ---

  Future<InventoryAndDebtsReportData> getInventoryAndDebtsReport(DateTime start, DateTime end) async {
    _logger.debug('Fetching inventory and debts report: $start - $end', context: LogContext.inventory);

    // 1. Inventory Valuation
    final activeProducts = await (_db.select(_db.products)..where((t) => t.isActive.equals(true))).get();
    final stockBalances = await _db.getAllStockBalances();

    double totalInventoryCost = 0.0;
    int lowStockCount = 0;

    for (final prod in activeProducts) {
      final stock = stockBalances[prod.id] ?? 0.0;
      totalInventoryCost += stock * prod.costPrice;
      if (prod.minStockAlert > 0 && stock <= prod.minStockAlert) {
        lowStockCount++;
      }
    }

    // 2. Adjustments in period
    final adjustments = await (_db.select(_db.stockMovements)
          ..where((t) =>
              t.type.equals('adjustment') &
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    double adjustmentsCost = 0.0;
    if (adjustments.isNotEmpty) {
      final adjProdIds = adjustments.map((a) => a.productId).toSet();
      final prods = await (_db.select(_db.products)..where((t) => t.id.isIn(adjProdIds))).get();
      final prodMap = {for (final p in prods) p.id: p};

      for (final adj in adjustments) {
        final prod = prodMap[adj.productId];
        final cost = prod?.costPrice ?? 0.0;
        adjustmentsCost += adj.quantity * cost;
      }
    }

    // 3. Debts analysis
    final totalOutstanding = await _db.getTotalRemainingDebts();

    final newDebts = await (_db.select(_db.debts)
          ..where((t) =>
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end)))
        .get();
    final newDebtsIssued = newDebts.fold<double>(0.0, (sum, d) => sum + d.amount);

    final debtPayments = await (_db.select(_db.debtPayments)
          ..where((t) =>
              t.paidAt.isBiggerOrEqualValue(start) &
              t.paidAt.isSmallerOrEqualValue(end)))
        .get();
    final debtsCollected = debtPayments.fold<double>(0.0, (sum, dp) => sum + dp.amountPaid);

    return InventoryAndDebtsReportData(
      totalInventoryCost: totalInventoryCost,
      totalActiveProducts: activeProducts.length,
      lowStockProductsCount: lowStockCount,
      adjustmentsCostInPeriod: adjustmentsCost,
      adjustmentsCountInPeriod: adjustments.length,
      totalOutstandingDebts: totalOutstanding,
      newDebtsIssuedInPeriod: newDebtsIssued,
      debtsCollectedInPeriod: debtsCollected,
    );
  }

  // --- Best Selling Products ---

  Future<List<ProductSalesSummary>> getBestSellers(DateTime start, DateTime end, {int limit = 5}) async {
    _logger.debug('Fetching best sellers: $start - $end, limit=$limit', context: LogContext.inventory);
    final invoices = await (_db.select(_db.invoices)
          ..where((t) => t.type.equals('sale') & t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    final invoiceIds = invoices.map((i) => i.id).toSet();
    if (invoiceIds.isEmpty) return [];

    final periodItems = await (_db.select(_db.invoiceItems)
          ..where((t) => t.invoiceId.isIn(invoiceIds)))
        .get();

    if (periodItems.isEmpty) return [];

    final productIds = periodItems.map((i) => i.productId).toSet();
    final products = await (_db.select(_db.products)
          ..where((t) => t.id.isIn(productIds)))
        .get();
    final productMap = {for (var p in products) p.id: p};

    final Map<String, double> productQtyMap = {};
    final Map<String, double> productRevMap = {};

    for (final item in periodItems) {
      productQtyMap[item.productId] = (productQtyMap[item.productId] ?? 0.0) + item.quantity;
      final itemRev = (item.priceUsed * item.quantity) - item.discount;
      productRevMap[item.productId] = (productRevMap[item.productId] ?? 0.0) + itemRev;
    }

    final summaries = productQtyMap.entries.map((entry) {
      final prodId = entry.key;
      final qty = entry.value;
      final rev = productRevMap[prodId] ?? 0.0;
      final prod = productMap[prodId] ?? Product(
        id: prodId,
        name: 'Unknown',
        categoryId: null,
        costPrice: 0,
        costPriceUsd: 0,
        currency: 'SYP',
        isActive: false,
        minStockAlert: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return ProductSalesSummary(
        product: prod,
        totalQuantity: qty,
        totalRevenue: rev,
      );
    }).toList();

    // Sort by quantity descending
    summaries.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));

    if (summaries.length > limit) {
      return summaries.sublist(0, limit);
    }
    return summaries;
  }

  // --- Current Inventory Report ---

  Future<List<InventoryReportItem>> getInventoryReport() async {
    _logger.debug('Fetching inventory report', context: LogContext.inventory);
    final products = await (_db.select(_db.products)..where((t) => t.isActive.equals(true))).get();
    final stockMap = await _db.getAllStockBalances();

    return products.map((prod) {
      final currentStock = stockMap[prod.id] ?? 0.0;
      return InventoryReportItem(
        product: prod,
        currentStock: currentStock,
        totalCostValue: currentStock * prod.costPrice,
      );
    }).toList();
  }

  // --- Outstanding Debts ---

  Future<double> getTotalOutstandingDebts() async {
    _logger.debug('Fetching total outstanding debts', context: LogContext.debts);
    return _db.getTotalRemainingDebts();
  }

  // --- Purchases vs Sales ---

  Future<PurchasesSalesSummary> getPurchasesSalesSummary(DateTime start, DateTime end) async {
    _logger.debug('Fetching purchases vs sales summary: $start - $end', context: LogContext.inventory);
    // Sales
    final sales = await (_db.select(_db.invoices)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    double totalSales = 0.0;
    for (final sale in sales) {
      if (sale.type == 'sale' && sale.paymentType != 'debt') {
        totalSales += sale.totalAmount;
      } else if (sale.type == 'return') {
        totalSales -= sale.totalAmount;
      }
    }
    if (totalSales < 0) totalSales = 0.0;

    // Purchases
    final purchases = await (_db.select(_db.purchaseInvoices)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    final totalPurchases = purchases.fold<double>(0.0, (sum, p) => sum + p.totalAmount);

    return PurchasesSalesSummary(
      totalPurchases: totalPurchases,
      totalSales: totalSales,
    );
  }
}
