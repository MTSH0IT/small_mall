import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/card_container.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/stat_card.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';
import 'package:small_mall/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:small_mall/features/reports/presentation/cubit/reports_state.dart';
import 'package:small_mall/features/reports/presentation/widgets/period_filter_row.dart';
import 'package:small_mall/features/reports/presentation/widgets/sales_purchases_comparison_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ReportsCubit>(
      create: (context) => ReportsCubit(getIt<ReportsRepository>())..loadReports(start: _startDate, end: _endDate),
      child: BlocConsumer<ReportsCubit, ReportsState>(
        listener: (context, state) {
          if (state is ReportsError) {
            AppToast.error(context, message: state.message);
          }
        },
        builder: (context, state) {
          final cubit = context.read<ReportsCubit>();

          return AppScreenScaffold(
            title: 'التقارير والإحصائيات',
            onRefresh: () => cubit.loadReports(start: _startDate, end: _endDate),
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Period Selection Controls
                  PeriodFilterRow(
                    startDate: _startDate,
                    endDate: _endDate,
                    onSelectDateRange: () => _selectDateRange(context, cubit),
                  ),
                  const SizedBox(height: 24),
                  // Report Panels
                  Expanded(
                    child: _buildReportContent(context, state),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context, ReportsCubit cubit) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('ar', 'AE'),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      cubit.loadReports(start: _startDate, end: _endDate);
    }
  }

  Widget _buildReportContent(BuildContext context, ReportsState state) {
    if (state is ReportsLoading) {
      return const LoadingIndicator(message: 'جاري احتساب التقارير المالية...');
    }

    if (state is ReportsLoaded) {
      final double totalProfit = state.profitData.totalProfit;
      final double revenue = state.profitData.totalRevenue;
      final double cost = state.profitData.totalCost;

      // Calculate total current inventory valuation cost
      final double totalInventoryValuation = state.inventoryReport.fold(0.0, (sum, item) => sum + item.totalCostValue);

      return SingleChildScrollView(
        child: Column(
          children: [
            // Row 1: Profit and Inventory Summary Cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'صافي أرباح الفترة',
                    value: totalProfit.toStringAsFixed(2),
                    color: totalProfit >= 0 ? AppColors.success : AppColors.danger,
                    subtitle: 'الإيرادات: ${revenue.toStringAsFixed(1)} | التكاليف: ${cost.toStringAsFixed(1)}',
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'إجمالي قيمة المخزون الحالي (سعر التكلفة)',
                    value: totalInventoryValuation.toStringAsFixed(2),
                    color: AppColors.primary,
                    subtitle: 'إجمالي عدد المنتجات المخزنة: ${state.inventoryReport.length}',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'إجمالي الديون المستحقة بذمة العملاء',
                    value: state.totalOutstandingDebts.toStringAsFixed(2),
                    color: AppColors.accent,
                    subtitle: 'ديون معلقة تحتاج للمتابعة',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Row 2: Sales vs Purchases Comparison & Best Sellers List
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Purchases vs Sales Custom Bar Chart
                Expanded(
                  flex: 3,
                  child: CardContainer(
                    title: 'المبيعات مقابل المشتريات خلال الفترة',
                    child: SalesPurchasesComparisonChart(summary: state.purchasesSalesSummary),
                  ),
                ),
                const SizedBox(width: 24),
                // Best Sellers
                Expanded(
                  flex: 3,
                  child: CardContainer(
                    title: 'المنتجات الأكثر مبيعاً',
                    child: state.bestSellers.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(child: Text('لم يتم بيع أي منتجات في هذه الفترة بعد')),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: state.bestSellers.length,
                            separatorBuilder: (_, _) => const Divider(color: AppColors.border),
                            itemBuilder: (context, index) {
                              final item = state.bestSellers[index];
                              return ListTile(
                                leading: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(item.product.name),
                                subtitle: Text('الكمية المباعة: ${item.totalQuantity.toStringAsFixed(0)}'),
                                trailing: Text(
                                  item.totalRevenue.toStringAsFixed(2),
                                  style: AppTheme.numericStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox();
  }
}
