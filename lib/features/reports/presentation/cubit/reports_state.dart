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
    required this.startDate,
    required this.endDate,
  });
  final ProfitReportData profitData;
  final List<ProductSalesSummary> bestSellers;
  final List<InventoryReportItem> inventoryReport;
  final double totalOutstandingDebts;
  final PurchasesSalesSummary purchasesSalesSummary;
  final DateTime startDate;
  final DateTime endDate;
}

class ReportsError extends ReportsState {
  ReportsError(this.message);
  final String message;
}
