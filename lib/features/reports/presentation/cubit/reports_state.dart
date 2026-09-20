import 'package:small_mall/features/reports/data/reports_repository.dart';

abstract class ReportsState {}

class ReportsInitial extends ReportsState {}

class ReportsLoading extends ReportsState {}

class ReportsLoaded extends ReportsState {
  ReportsLoaded({
    required this.profitData,
    required this.bestSellers,
    required this.inventoryReport,
    required this.totalOutstandingDebts,
    required this.purchasesSalesSummary,
    required this.cashDrawerData,
    required this.inventoryAndDebtsData,
    required this.startDate,
    required this.endDate,
    this.periodType = 'today',
    this.selectedTab = 0,
  });

  final ProfitReportData profitData;
  final List<ProductSalesSummary> bestSellers;
  final List<InventoryReportItem> inventoryReport;
  final double totalOutstandingDebts;
  final PurchasesSalesSummary purchasesSalesSummary;
  final CashDrawerReportData cashDrawerData;
  final InventoryAndDebtsReportData inventoryAndDebtsData;
  final DateTime startDate;
  final DateTime endDate;
  final String periodType;
  final int selectedTab;

  ReportsLoaded copyWith({
    ProfitReportData? profitData,
    List<ProductSalesSummary>? bestSellers,
    List<InventoryReportItem>? inventoryReport,
    double? totalOutstandingDebts,
    PurchasesSalesSummary? purchasesSalesSummary,
    CashDrawerReportData? cashDrawerData,
    InventoryAndDebtsReportData? inventoryAndDebtsData,
    DateTime? startDate,
    DateTime? endDate,
    String? periodType,
    int? selectedTab,
  }) {
    return ReportsLoaded(
      profitData: profitData ?? this.profitData,
      bestSellers: bestSellers ?? this.bestSellers,
      inventoryReport: inventoryReport ?? this.inventoryReport,
      totalOutstandingDebts: totalOutstandingDebts ?? this.totalOutstandingDebts,
      purchasesSalesSummary: purchasesSalesSummary ?? this.purchasesSalesSummary,
      cashDrawerData: cashDrawerData ?? this.cashDrawerData,
      inventoryAndDebtsData: inventoryAndDebtsData ?? this.inventoryAndDebtsData,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      periodType: periodType ?? this.periodType,
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}

class ReportsError extends ReportsState {
  ReportsError(this.message);
  final String message;
}
