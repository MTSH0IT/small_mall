import 'package:drift/drift.dart';
import 'package:artisan_gift_manager/core/database/app_database.dart';

class ProfitReportData {
  final double totalRevenue;
  final double totalCost;
  final double totalProfit;

  ProfitReportData({
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
  });
}

class ProductSalesSummary {
  final Product product;
  final double totalQuantity;
  final double totalRevenue;

  ProductSalesSummary({
    required this.product,
    required this.totalQuantity,
    required this.totalRevenue,
  });
}

class InventoryReportItem {
  final Product product;
  final double currentStock;
  final double totalCostValue;

  InventoryReportItem({
    required this.product,
    required this.currentStock,
    required this.totalCostValue,
  });
}

class PurchasesSalesSummary {
  final double totalPurchases;
  final double totalSales;

  PurchasesSalesSummary({
    required this.totalPurchases,
    required this.totalSales,
  });
}

class ReportsRepository {
  final AppDatabase _db;

  ReportsRepository(this._db);

  // --- Profit Report ---

  Future<ProfitReportData> getProfitReport(DateTime start, DateTime end) async {
    // Get all sale invoices in period
    final invoices = await (_db.select(_db.invoices)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    final allInvoiceItems = await _db.select(_db.invoiceItems).get();
    final allProducts = await _db.select(_db.products).get();
    final productMap = {for (var p in allProducts) p.id: p};

    double totalRevenue = 0.0;
    double totalCost = 0.0;

    for (final inv in invoices) {
      final items = allInvoiceItems.where((i) => i.invoiceId == inv.id).toList();

      double invoiceRev = 0.0;
      double invoiceCost = 0.0;

      for (final item in items) {
        final prod = productMap[item.productId];
        if (prod == null) continue;

        final itemRev = (item.priceUsed * item.quantity) - item.discount;
        final itemCost = prod.costPrice * item.quantity;

        invoiceRev += itemRev;
        invoiceCost += itemCost;
      }

      // Apply invoice-level discount if it was a sale, or adjust for return
      if (inv.type == 'sale') {
        totalRevenue += (invoiceRev - inv.discount);
        totalCost += invoiceCost;
      } else if (inv.type == 'return') {
        // Returns reduce revenue and reduce cost of goods sold (returns product to stock)
        totalRevenue -= invoiceRev;
        totalCost -= invoiceCost;
      }
    }

    return ProfitReportData(
      totalRevenue: totalRevenue,
      totalCost: totalCost,
      totalProfit: totalRevenue - totalCost,
    );
  }

  // --- Best Selling Products ---

  Future<List<ProductSalesSummary>> getBestSellers(DateTime start, DateTime end, {int limit = 5}) async {
    final invoices = await (_db.select(_db.invoices)
          ..where((t) => t.type.equals('sale') & t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerOrEqualValue(end)))
        .get();

    final invoiceIds = invoices.map((i) => i.id).toList();
    if (invoiceIds.isEmpty) return [];

    final allInvoiceItems = await _db.select(_db.invoiceItems).get();
    final periodItems = allInvoiceItems.where((i) => invoiceIds.contains(i.invoiceId)).toList();

    final allProducts = await _db.select(_db.products).get();
    final productMap = {for (var p in allProducts) p.id: p};

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
    final products = await (_db.select(_db.products)..where((t) => t.isActive.equals(true))).get();
    final allMovements = await _db.select(_db.stockMovements).get();

    return products.map((prod) {
      final currentStock = allMovements
          .where((m) => m.productId == prod.id)
          .fold<double>(0.0, (sum, m) => sum + m.quantity);

      return InventoryReportItem(
        product: prod,
        currentStock: currentStock,
        totalCostValue: currentStock * prod.costPrice,
      );
    }).toList();
  }

  // --- Outstanding Debts ---

  Future<double> getTotalOutstandingDebts() async {
    final debts = await _db.select(_db.debts).get();
    return debts.fold<double>(0.0, (sum, d) => sum + d.remainingAmount);
  }

  // --- Purchases vs Sales ---

  Future<PurchasesSalesSummary> getPurchasesSalesSummary(DateTime start, DateTime end) async {
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
