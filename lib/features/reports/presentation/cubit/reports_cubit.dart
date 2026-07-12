import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:artisan_gift_manager/features/reports/data/reports_repository.dart';

abstract class ReportsState {}

class ReportsInitial extends ReportsState {}

class ReportsLoading extends ReportsState {}

class ReportsLoaded extends ReportsState {
  final ProfitReportData profitData;
  final List<ProductSalesSummary> bestSellers;
  final List<InventoryReportItem> inventoryReport;
  final double totalOutstandingDebts;
  final PurchasesSalesSummary purchasesSalesSummary;
  final DateTime startDate;
  final DateTime endDate;

  ReportsLoaded({
    required this.profitData,
    required this.bestSellers,
    required this.inventoryReport,
    required this.totalOutstandingDebts,
    required this.purchasesSalesSummary,
    required this.startDate,
    required this.endDate,
  });
}

class ReportsError extends ReportsState {
  final String message;
  ReportsError(this.message);
}

class ReportsCubit extends Cubit<ReportsState> {
  final ReportsRepository _repository;

  ReportsCubit(this._repository) : super(ReportsInitial());

  Future<void> loadReports({DateTime? start, DateTime? end}) async {
    emit(ReportsLoading());
    final endDate = end ?? DateTime.now();
    final startDate = start ?? endDate.subtract(const Duration(days: 30));

    try {
      final profitData = await _repository.getProfitReport(startDate, endDate);
      final bestSellers = await _repository.getBestSellers(startDate, endDate);
      final inventoryReport = await _repository.getInventoryReport();
      final totalOutstandingDebts = await _repository.getTotalOutstandingDebts();
      final purchasesSalesSummary = await _repository.getPurchasesSalesSummary(startDate, endDate);

      emit(ReportsLoaded(
        profitData: profitData,
        bestSellers: bestSellers,
        inventoryReport: inventoryReport,
        totalOutstandingDebts: totalOutstandingDebts,
        purchasesSalesSummary: purchasesSalesSummary,
        startDate: startDate,
        endDate: endDate,
      ));
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }
}
