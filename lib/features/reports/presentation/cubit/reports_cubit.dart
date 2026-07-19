import 'package:small_mall/features/reports/data/reports_repository.dart';
import 'package:small_mall/features/reports/presentation/cubit/reports_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReportsCubit extends Cubit<ReportsState> {

  ReportsCubit(this._repository) : super(ReportsInitial());
  final ReportsRepository _repository;

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
