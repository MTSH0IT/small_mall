import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
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
    this.salesCount = 0,
    this.returnsCount = 0,
    this.purchasesCount = 0,
    this.expensesCount = 0,
    this.debtPaymentsCount = 0,
    this.adjustmentsCount = 0,
  });

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
  final int salesCount;
  final int returnsCount;
  final int purchasesCount;
  final int expensesCount;
  final int debtPaymentsCount;
  final int adjustmentsCount;

  // Formula helpers: صافي الربح = (المبيعات + السداد) - (المصاريف + المشتريات)
  double get netSales => totalRevenue;
  double get totalInflows => netSales + debtPayments;
  double get totalOutflows => totalExpenses + totalPurchases;
  double get formulaNetProfit => totalInflows - totalOutflows;

  double get costOfGoodsSold => totalCost;
  double get profitMargin => netSales > 0 ? (netProfit / netSales) * 100 : 0.0;

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
  final String? partyName;
  final String? referenceNumber;
  final String? notes;
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

    // Get operational expenses in period
    final totalExpenses = await _db.getTotalExpensesInPeriod(start, end);

    // Get all invoices in period
    final invoices = await (_db.select(_db.invoices)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    // Get purchases in period
    final purchases = await (_db.select(_db.purchaseInvoices)
          ..where((t) =>
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end)))
        .get();
    final totalPurchases = purchases.fold<double>(0.0, (sum, p) => sum + p.totalAmount);
    final purchasesCount = purchases.length;

    // Get expenses count in period
    final expensesCountQuery = _db.selectOnly(_db.expenses)
      ..addColumns([_db.expenses.id.count()])
      ..where(_db.expenses.createdAt.isBiggerOrEqualValue(start) &
          _db.expenses.createdAt.isSmallerOrEqualValue(end));
    final expensesCountRow = await expensesCountQuery.getSingleOrNull();
    final expensesCount = expensesCountRow?.read(_db.expenses.id.count()) ?? 0;

    // Get debt payments in period
    final debtPayments = await (_db.select(_db.debtPayments)
          ..where((t) =>
              t.paidAt.isBiggerOrEqualValue(start) &
              t.paidAt.isSmallerOrEqualValue(end)))
        .get();
    final totalDebtPayments = debtPayments.fold<double>(0.0, (sum, dp) => sum + dp.amountPaid);
    final debtPaymentsCount = debtPayments.length;

    // Get new debts created in period
    final newDebtsRows = await (_db.select(_db.debts)
          ..where((t) =>
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end)))
        .get();
    final totalNewDebts = newDebtsRows.fold<double>(0.0, (sum, d) => sum + d.amount);

    // Adjustments in period
    final adjustments = await (_db.select(_db.stockMovements)
          ..where((t) => t.type.equals('adjustment') &
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    double adjustmentsLoss = 0.0;
    if (adjustments.isNotEmpty) {
      final adjProdIds = adjustments.map((a) => a.productId).toSet();
      final adjProds = await (_db.select(_db.products)..where((t) => t.id.isIn(adjProdIds))).get();
      final adjProdMap = {for (final p in adjProds) p.id: p};

      for (final adj in adjustments) {
        if (adj.quantity < 0) {
          final prod = adjProdMap[adj.productId];
          final cost = prod?.costPrice ?? 0.0;
          adjustmentsLoss += adj.quantity.abs() * cost;
        }
      }
    }

    if (invoices.isEmpty) {
      final netProfit = (0.0 + totalDebtPayments) - (totalExpenses + totalPurchases);
      return ProfitReportData(
        totalRevenue: 0.0,
        totalCost: 0.0,
        grossProfit: 0.0,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        cashSales: 0.0,
        debtSales: 0.0,
        grossSales: 0.0,
        returnsAmount: 0.0,
        totalPurchases: totalPurchases,
        debtPayments: totalDebtPayments,
        newDebts: totalNewDebts,
        adjustmentsLoss: adjustmentsLoss,
        salesCount: 0,
        returnsCount: 0,
        purchasesCount: purchasesCount,
        expensesCount: expensesCount,
        debtPaymentsCount: debtPaymentsCount,
        adjustmentsCount: adjustments.length,
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

    double cashSales = 0.0;
    double debtSales = 0.0;
    double grossSales = 0.0;
    double returnsAmount = 0.0;
    double totalCost = 0.0;
    int salesCount = 0;
    int returnsCount = 0;

    for (final inv in invoices) {
      final items = periodItems.where((i) => i.invoiceId == inv.id).toList();

      double invoiceCost = 0.0;
      for (final item in items) {
        final prod = productMap[item.productId];
        if (prod == null) continue;
        invoiceCost += prod.costPrice * item.quantity;
      }

      if (inv.type == 'sale') {
        grossSales += inv.totalAmount;
        if (inv.paymentType == 'cash') {
          cashSales += inv.totalAmount;
          salesCount++;
        } else {
          debtSales += inv.totalAmount;
        }
        totalCost += invoiceCost;
      } else if (inv.type == 'return') {
        returnsCount++;
        returnsAmount += inv.totalAmount;
        totalCost -= invoiceCost;
      }
    }

    // Do NOT add debts to sales! Sales is strictly cash sales minus cash returns
    final actualCashSales = cashSales - returnsAmount;
    final grossProfit = actualCashSales - totalCost;

    // صافي الربح هو عبارة عن المبيعات والسداد مطروح منه المصاريف والمشتريات
    final formulaNetProfit = (actualCashSales + totalDebtPayments) - (totalExpenses + totalPurchases);

    return ProfitReportData(
      totalRevenue: actualCashSales > 0 ? actualCashSales : 0.0,
      totalCost: totalCost,
      grossProfit: grossProfit,
      totalExpenses: totalExpenses,
      netProfit: formulaNetProfit,
      cashSales: actualCashSales > 0 ? actualCashSales : 0.0,
      debtSales: debtSales,
      grossSales: grossSales,
      returnsAmount: returnsAmount,
      totalPurchases: totalPurchases,
      debtPayments: totalDebtPayments,
      newDebts: totalNewDebts > 0 ? totalNewDebts : debtSales,
      adjustmentsLoss: adjustmentsLoss,
      salesCount: salesCount,
      returnsCount: returnsCount,
      purchasesCount: purchasesCount,
      expensesCount: expensesCount,
      debtPaymentsCount: debtPaymentsCount,
      adjustmentsCount: adjustments.length,
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

    double totalCashSales = 0.0;
    for (final inv in cashSalesInvoices) {
      totalCashSales += inv.totalAmount;
      final custName = inv.customerId != null ? customerMap[inv.customerId] : null;
      movements.add(CashMovementItem(
        id: inv.id,
        title: 'reports.cash_sales'.tr(),
        type: 'cash_sale',
        isCashIn: true,
        amount: inv.totalAmount,
        date: inv.createdAt,
        partyName: custName,
        referenceNumber: inv.serialNumber != null ? '#${inv.serialNumber}' : null,
      ));
    }

    double totalDebtPayments = 0.0;
    for (final dp in debtPayments) {
      totalDebtPayments += dp.amountPaid;
      final debt = debtMap[dp.debtId];
      final custName = debt != null ? customerMap[debt.customerId] : null;
      movements.add(CashMovementItem(
        id: dp.id,
        title: 'reports.debt_collections'.tr(),
        type: 'debt_payment',
        isCashIn: true,
        amount: dp.amountPaid,
        date: dp.paidAt,
        partyName: custName,
      ));
    }

    double totalCashReturns = 0.0;
    for (final ret in returnsInvoices) {
      totalCashReturns += ret.totalAmount;
      final custName = ret.customerId != null ? customerMap[ret.customerId] : null;
      movements.add(CashMovementItem(
        id: ret.id,
        title: 'reports.cash_returns'.tr(),
        type: 'return',
        isCashIn: false,
        amount: ret.totalAmount,
        date: ret.createdAt,
        partyName: custName,
        referenceNumber: ret.serialNumber != null ? '#${ret.serialNumber}' : null,
      ));
    }

    double totalExpenses = 0.0;
    for (final exp in expenses) {
      totalExpenses += exp.amount;
      final catName = categoryMap[exp.categoryId] ?? 'expenses.title'.tr();
      movements.add(CashMovementItem(
        id: exp.id,
        title: catName,
        type: 'expense',
        isCashIn: false,
        amount: exp.amount,
        date: exp.createdAt,
        partyName: catName,
        notes: exp.notes,
      ));
    }

    double totalPurchases = 0.0;
    for (final pur in purchases) {
      totalPurchases += pur.totalAmount;
      final suppName = supplierMap[pur.supplierId];
      movements.add(CashMovementItem(
        id: pur.id,
        title: 'reports.cash_purchases'.tr(),
        type: 'purchase',
        isCashIn: false,
        amount: pur.totalAmount,
        date: pur.createdAt,
        partyName: suppName,
      ));
    }

    // Sort movements by date descending (newest first)
    movements.sort((a, b) => b.date.compareTo(a.date));

    final totalCashIn = totalCashSales + totalDebtPayments;
    final totalCashOut = totalCashReturns + totalExpenses + totalPurchases;
    final netCashFlow = totalCashIn - totalCashOut;

    return CashDrawerReportData(
      cashSales: totalCashSales,
      debtPaymentsCollected: totalDebtPayments,
      totalCashIn: totalCashIn,
      cashReturns: totalCashReturns,
      expensesPaid: totalExpenses,
      cashPurchases: totalPurchases,
      totalCashOut: totalCashOut,
      netCashFlow: netCashFlow,
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
