import 'package:drift/drift.dart';
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
  });

  final double totalRevenue;
  final double totalCost;
  final double grossProfit;
  final double totalExpenses;
  final double netProfit;

  // Backwards compatibility alias
  double get totalProfit => netProfit;
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

    // Get all sale and return invoices in period
    final invoices = await (_db.select(_db.invoices)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    if (invoices.isEmpty) {
      return ProfitReportData(
        totalRevenue: 0.0,
        totalCost: 0.0,
        grossProfit: 0.0,
        totalExpenses: totalExpenses,
        netProfit: -totalExpenses,
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

    double totalRevenue = 0.0;
    double totalCost = 0.0;

    for (final inv in invoices) {
      final items = periodItems.where((i) => i.invoiceId == inv.id).toList();

      double invoiceCost = 0.0;
      for (final item in items) {
        final prod = productMap[item.productId];
        if (prod == null) continue;
        invoiceCost += prod.costPrice * item.quantity;
      }

      if (inv.type == 'sale') {
        totalRevenue += inv.totalAmount;
        totalCost += invoiceCost;
      } else if (inv.type == 'return') {
        totalRevenue -= inv.totalAmount;
        totalCost -= invoiceCost;
      }
    }

    final grossProfit = totalRevenue - totalCost;
    final netProfit = grossProfit - totalExpenses;

    return ProfitReportData(
      totalRevenue: totalRevenue,
      totalCost: totalCost,
      grossProfit: grossProfit,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
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
      if (sale.type == 'sale') {
        totalSales += sale.totalAmount;
      } else if (sale.type == 'return') {
        totalSales -= sale.totalAmount;
      }
    }

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
