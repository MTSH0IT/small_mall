import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';
import 'package:small_mall/features/reports/presentation/cubit/reports_state.dart';

class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit(this._repository) : super(ReportsInitial());
  final ReportsRepository _repository;

  /// Load comprehensive reports for the given date range
  Future<void> loadReports({
    DateTime? start,
    DateTime? end,
    String? periodType,
    int? selectedTab,
  }) async {
    emit(ReportsLoading());
    final effectivePeriod = periodType ?? 'today';
    final range = _resolveDates(effectivePeriod, start: start, end: end);
    final startDate = range.start;
    final endDate = range.end;

    try {
      final profitData = await _repository.getProfitReport(startDate, endDate);
      final cashDrawerData = await _repository.getCashDrawerReport(startDate, endDate);
      final inventoryAndDebtsData = await _repository.getInventoryAndDebtsReport(startDate, endDate);
      final bestSellers = await _repository.getBestSellers(startDate, endDate);
      final inventoryReport = await _repository.getInventoryReport();
      final totalOutstandingDebts = await _repository.getTotalOutstandingDebts();
      final purchasesSalesSummary = await _repository.getPurchasesSalesSummary(startDate, endDate);

      emit(ReportsLoaded(
        profitData: profitData,
        cashDrawerData: cashDrawerData,
        inventoryAndDebtsData: inventoryAndDebtsData,
        bestSellers: bestSellers,
        inventoryReport: inventoryReport,
        totalOutstandingDebts: totalOutstandingDebts,
        purchasesSalesSummary: purchasesSalesSummary,
        startDate: startDate,
        endDate: endDate,
        periodType: effectivePeriod,
        selectedTab: selectedTab ?? 0,
      ));
    } catch (e) {
      emit(ReportsError(e.toString()));
    }
  }

  /// Change active period (today, yesterday, this_week, this_month, last_month, custom)
  void setPeriod(String periodType, {DateTimeRange? customRange}) {
    final currentTab = state is ReportsLoaded ? (state as ReportsLoaded).selectedTab : 0;
    if (periodType == 'custom' && customRange != null) {
      final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day, 0, 0, 0);
      final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59, 999);
      loadReports(start: start, end: end, periodType: 'custom', selectedTab: currentTab);
    } else {
      loadReports(periodType: periodType, selectedTab: currentTab);
    }
  }

  /// Navigate between periods (e.g. -1 for previous day/month, +1 for next day/month)
  void navigatePeriod(int direction) {
    if (state is! ReportsLoaded) return;
    final current = state as ReportsLoaded;
    final period = current.periodType;

    if (period == 'today' || period == 'yesterday' || (period == 'custom' && current.startDate.day == current.endDate.day)) {
      final nextDate = current.startDate.add(Duration(days: direction));
      final start = DateTime(nextDate.year, nextDate.month, nextDate.day, 0, 0, 0);
      final end = DateTime(nextDate.year, nextDate.month, nextDate.day, 23, 59, 59, 999);

      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final yesterdayDate = todayDate.subtract(const Duration(days: 1));

      String nextType = 'custom';
      if (DateTime(nextDate.year, nextDate.month, nextDate.day) == todayDate) {
        nextType = 'today';
      } else if (DateTime(nextDate.year, nextDate.month, nextDate.day) == yesterdayDate) {
        nextType = 'yesterday';
      }

      loadReports(start: start, end: end, periodType: nextType, selectedTab: current.selectedTab);
    } else if (period == 'this_month' || period == 'last_month') {
      final nextMonthAnchor = DateTime(current.startDate.year, current.startDate.month + direction, 1);
      final start = DateTime(nextMonthAnchor.year, nextMonthAnchor.month, 1, 0, 0, 0);
      final nextMonthEnd = DateTime(nextMonthAnchor.year, nextMonthAnchor.month + 1, 0, 23, 59, 59, 999);

      final now = DateTime.now();
      String nextType = 'custom';
      if (nextMonthAnchor.year == now.year && nextMonthAnchor.month == now.month) {
        nextType = 'this_month';
      }

      loadReports(start: start, end: nextMonthEnd, periodType: nextType, selectedTab: current.selectedTab);
    } else {
      // Default: shift whole duration
      final duration = current.endDate.difference(current.startDate);
      final start = current.startDate.add(duration * direction);
      final end = current.endDate.add(duration * direction);
      loadReports(start: start, end: end, periodType: 'custom', selectedTab: current.selectedTab);
    }
  }

  /// Switch the active dashboard tab
  void changeTab(int index) {
    if (state is ReportsLoaded) {
      emit((state as ReportsLoaded).copyWith(selectedTab: index));
    }
  }

  /// Date resolution helper
  DateTimeRange _resolveDates(String periodType, {DateTime? start, DateTime? end}) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (periodType) {
      case 'today':
        return DateTimeRange(start: todayStart, end: todayEnd);

      case 'yesterday':
        final yesterday = todayStart.subtract(const Duration(days: 1));
        return DateTimeRange(
          start: DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0),
          end: DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59, 999),
        );

      case 'this_week':
        final weekStart = todayStart.subtract(const Duration(days: 6));
        return DateTimeRange(start: weekStart, end: todayEnd);

      case 'this_month':
        final monthStart = DateTime(now.year, now.month, 1, 0, 0, 0);
        return DateTimeRange(start: monthStart, end: todayEnd);

      case 'last_month':
        final firstOfThisMonth = DateTime(now.year, now.month, 1);
        final lastDayPrevMonth = firstOfThisMonth.subtract(const Duration(days: 1));
        final firstOfPrevMonth = DateTime(lastDayPrevMonth.year, lastDayPrevMonth.month, 1, 0, 0, 0);
        final endOfPrevMonth = DateTime(lastDayPrevMonth.year, lastDayPrevMonth.month, lastDayPrevMonth.day, 23, 59, 59, 999);
        return DateTimeRange(start: firstOfPrevMonth, end: endOfPrevMonth);

      case 'custom':
        if (start != null && end != null) {
          return DateTimeRange(start: start, end: end);
        }
        return DateTimeRange(
          start: todayStart.subtract(const Duration(days: 30)),
          end: todayEnd,
        );

      default:
        return DateTimeRange(start: todayStart, end: todayEnd);
    }
  }
}
