import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/widgets/card_container.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/stat_card.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';
import 'package:small_mall/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:small_mall/features/reports/presentation/cubit/reports_state.dart';
import 'package:small_mall/features/reports/presentation/widgets/period_filter_row.dart';
import 'package:small_mall/features/reports/presentation/widgets/sales_purchases_comparison_chart.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<ReportsCubit>(
      create: (context) => ReportsCubit(getIt<ReportsRepository>())..loadReports(),
      child: BlocConsumer<ReportsCubit, ReportsState>(
        listener: (context, state) {
          if (state is ReportsError) {
            AppToast.error(context, message: state.message);
          }
        },
        builder: (context, state) {
          final cubit = context.read<ReportsCubit>();

          final now = DateTime.now();
          final startDate = state is ReportsLoaded
              ? state.startDate
              : DateTime(now.year, now.month, now.day);
          final endDate = state is ReportsLoaded
              ? state.endDate
              : DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          final activePeriod = state is ReportsLoaded ? state.periodType : 'today';

          return AppScreenScaffold(
            title: 'reports.title'.tr(),
            onRefresh: () => cubit.loadReports(start: startDate, end: endDate, periodType: activePeriod),
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Smart Period Filter Bar (Defaults to Today)
                  PeriodFilterRow(
                    startDate: startDate,
                    endDate: endDate,
                    activePeriod: activePeriod,
                    onSelectPeriod: (p) => cubit.setPeriod(p),
                    onSelectCustomRange: () => _selectDateRange(context, cubit, startDate, endDate),
                    onNavigatePeriod: (dir) => cubit.navigatePeriod(dir),
                  ),
                  const SizedBox(height: 20),

                  // 2. Simple & Direct Dashboard Body
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

  Widget _buildReportContent(BuildContext context, ReportsState state) {
    if (state is ReportsLoading) {
      return LoadingIndicator(message: 'common.loading'.tr());
    }

    if (state is ReportsLoaded) {
      final profit = state.profitData;
      final cashSales = profit.cashSales;
      final expenses = profit.totalExpenses;
      final purchases = profit.totalPurchases;
      final debts = profit.newDebts;
      final debtPayments = profit.debtPayments;

      // Net profit formula: (المبيعات + السداد) - (المصاريف + المشتريات)
      final netProfit = profit.netProfit;
      final totalInflow = cashSales + debtPayments;
      final totalOutflow = expenses + purchases;

      final isProfitable = netProfit >= 0;
      final netProfitColor = isProfitable ? AppColors.success : AppColors.danger;

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Primary Operating KPIs (المبيعات، المصاريف، المشتريات، صافي الربح)
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'reports.sales'.tr(),
                    value: cashSales.toStringAsFixed(2),
                    color: AppColors.primary,
                    subtitle: 'reports.sales_no_debt_note'.tr(),
                    icon: Icons.point_of_sale,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'expenses.title'.tr(),
                    value: expenses.toStringAsFixed(2),
                    color: AppColors.warning,
                    subtitle: '${profit.expensesCount} ${'expenses.operations_count'.tr()}',
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'reports.purchases'.tr(),
                    value: purchases.toStringAsFixed(2),
                    color: const Color(0xFF8B5CF6),
                    subtitle: '${profit.purchasesCount} ${'invoices.purchase'.tr()}',
                    icon: Icons.shopping_bag_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'reports.net_profit_clean'.tr(),
                    value: netProfit.toStringAsFixed(2),
                    color: netProfitColor,
                    subtitle: 'reports.net_profit_formula'.tr(),
                    icon: Icons.calculate_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 2: Secondary KPIs (الديون، السداد، إجمالي الداخل، إجمالي الخارج)
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'reports.simple_debts'.tr(),
                    value: debts.toStringAsFixed(2),
                    color: AppColors.danger,
                    subtitle: 'reports.new_debts_issued'.tr(),
                    icon: Icons.money_off_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'reports.simple_debt_payments'.tr(),
                    value: debtPayments.toStringAsFixed(2),
                    color: AppColors.success,
                    subtitle: '${profit.debtPaymentsCount} ${'reports.debt_collections'.tr()}',
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'reports.inflows_card_title'.tr(),
                    value: totalInflow.toStringAsFixed(2),
                    color: AppColors.success,
                    subtitle: '${'reports.sales'.tr()} + ${'reports.simple_debt_payments'.tr()}',
                    icon: Icons.download,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'reports.outflows_card_title'.tr(),
                    value: totalOutflow.toStringAsFixed(2),
                    color: AppColors.danger,
                    subtitle: '${'expenses.title'.tr()} + ${'reports.purchases'.tr()}',
                    icon: Icons.upload,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Row 3: Mathematical Reconciliation Card & (Comparison + Best Sellers)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Clear Formula Reconciliation Card
                Expanded(
                  flex: 3,
                  child: CardContainer(
                    title: 'reports.net_profit_formula'.tr(),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Inflows Section
                          Row(
                            children: [
                              const Icon(Icons.add_circle_outline, color: AppColors.success, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'reports.inflows_card_title'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.success),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildLineItem('reports.sales'.tr(), cashSales, AppColors.textPrimary),
                          _buildLineItem('reports.simple_debt_payments'.tr(), debtPayments, AppColors.textPrimary),
                          const Divider(height: 16, color: AppColors.border),
                          _buildTotalLine('reports.inflows_card_title'.tr(), totalInflow, AppColors.success),

                          const SizedBox(height: 20),

                          // 2. Outflows Section
                          Row(
                            children: [
                              const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'reports.outflows_card_title'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.danger),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildLineItem('expenses.title'.tr(), expenses, AppColors.textPrimary),
                          _buildLineItem('reports.purchases'.tr(), purchases, AppColors.textPrimary),
                          const Divider(height: 16, color: AppColors.border),
                          _buildTotalLine('reports.outflows_card_title'.tr(), totalOutflow, AppColors.danger),

                          const SizedBox(height: 24),

                          // 3. Final Net Profit Result
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: netProfitColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: netProfitColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'reports.net_profit_clean'.tr(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: netProfitColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'reports.net_profit_formula'.tr(),
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                Text(
                                  netProfit.toStringAsFixed(2),
                                  style: AppTheme.numericStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: netProfitColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Right: Sales vs Purchases & Best Sellers
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Sales vs Purchases Chart
                      CardContainer(
                        title: 'reports.comparison_chart'.tr(),
                        child: SalesPurchasesComparisonChart(
                          summary: state.purchasesSalesSummary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Top Selling Products
                      CardContainer(
                        title: 'reports.top_selling'.tr(),
                        child: state.bestSellers.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                                child: EmptyStateView(
                                  icon: Icons.leaderboard_outlined,
                                  title: 'reports.top_selling'.tr(),
                                  description: 'reports.no_sales_data'.tr(),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: state.bestSellers.length,
                                separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                                itemBuilder: (context, index) {
                                  final item = state.bestSellers[index];
                                  return ListTile(
                                    dense: true,
                                    leading: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                      '${'common.quantity'.tr()}: ${item.totalQuantity.toStringAsFixed(0)}',
                                    ),
                                    trailing: Text(
                                      item.totalRevenue.toStringAsFixed(2),
                                      style: AppTheme.numericStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
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

  Widget _buildLineItem(String title, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            amount.toStringAsFixed(2),
            style: AppTheme.numericStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalLine(String title, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          Text(
            amount.toStringAsFixed(2),
            style: AppTheme.numericStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(
    BuildContext context,
    ReportsCubit cubit,
    DateTime currentStart,
    DateTime currentEnd,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: currentStart, end: currentEnd),
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: context.locale,
    );

    if (picked != null) {
      cubit.setPeriod('custom', customRange: picked);
    }
  }
}
