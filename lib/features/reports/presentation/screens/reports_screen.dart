import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/widgets/card_container.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/stat_card.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';
import 'package:small_mall/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:small_mall/features/reports/presentation/cubit/reports_state.dart';
import 'package:small_mall/features/reports/presentation/widgets/exchange_report_card.dart';
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

      // Profit calculation: المبيعات - التكلفة
      final salesProfit = profit.grossProfit;
      final salesProfitUsd = profit.grossProfitUsd;
      final isSalesProfitable = salesProfit >= 0;
      final salesProfitColor = isSalesProfitable ? AppColors.success : AppColors.danger;
      final isSalesProfitableUsd = salesProfitUsd >= 0;
      final salesProfitColorUsd = isSalesProfitableUsd ? const Color(0xFF059669) : AppColors.danger;

      // Cash drawer & currency exchange data
      final drawer = state.cashDrawerData;
      final exchangeInSyp = drawer.exchangeInSyp;
      final exchangeInUsd = drawer.exchangeInUsd;
      final exchangeOutSyp = drawer.exchangeOutSyp;
      final exchangeOutUsd = drawer.exchangeOutUsd;
      final hasExchanges = drawer.exchangeCount > 0;

      // Net Cash Flow formula: (المبيعات + السداد + وارد الصرافة) - (المصاريف + المشتريات + صادر الصرافة)
      final totalInflow = cashSales + debtPayments + exchangeInSyp;
      final totalInflowUsd = profit.cashSalesUsd + profit.debtPaymentsUsd + exchangeInUsd;
      final totalOutflow = expenses + purchases + exchangeOutSyp;
      final totalOutflowUsd = profit.totalExpensesUsd + profit.totalPurchasesUsd + exchangeOutUsd;
      final netCashFlow = totalInflow - totalOutflow;
      final netCashFlowUsd = totalInflowUsd - totalOutflowUsd;

      final isCashFlowPositive = netCashFlow >= 0;
      final cashFlowColor = isCashFlowPositive ? AppColors.success : AppColors.danger;
      final isCashFlowPositiveUsd = netCashFlowUsd >= 0;
      final cashFlowColorUsd = isCashFlowPositiveUsd ? const Color(0xFF059669) : AppColors.danger;

      // USD counterparts
      final cashSalesUsd = profit.cashSalesUsd;
      final expensesUsd = profit.totalExpensesUsd;
      final purchasesUsd = profit.totalPurchasesUsd;
      final debtsUsd = profit.newDebtsUsd;
      final debtPaymentsUsd = profit.debtPaymentsUsd;

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
                    value: '${cashSales.toStringAsFixed(2)} ل.س',
                    secondaryValue: '${cashSalesUsd.toStringAsFixed(2)} \$',
                    color: AppColors.primary,
                    subtitle: '${profit.cashSalesCount} ${'reports.cash_sales_operations'.tr()}',
                    icon: Icons.point_of_sale,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'expenses.title'.tr(),
                    value: '${expenses.toStringAsFixed(2)} ل.س',
                    secondaryValue: '${expensesUsd.toStringAsFixed(2)} \$',
                    color: AppColors.warning,
                    subtitle: '${profit.expensesCount} ${'expenses.operations_count'.tr()}',
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'reports.purchases'.tr(),
                    value: '${purchases.toStringAsFixed(2)} ل.س',
                    secondaryValue: '${purchasesUsd.toStringAsFixed(2)} \$',
                    color: const Color(0xFF8B5CF6),
                    subtitle: '${profit.purchasesCount} ${'invoices.purchase'.tr()}',
                    icon: Icons.shopping_bag_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'reports.net_profit_clean'.tr(),
                    value: '${salesProfit.toStringAsFixed(2)} ل.س',
                    secondaryValue: '${salesProfitUsd.toStringAsFixed(2)} \$',
                    color: salesProfitColor,
                    secondaryColor: salesProfitColorUsd,
                    subtitle: 'reports.sales_minus_cost'.tr(),
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
                    value: '${debts.toStringAsFixed(2)} ل.س',
                    secondaryValue: '${debtsUsd.toStringAsFixed(2)} \$',
                    color: AppColors.danger,
                    subtitle: '${profit.newDebtsCount} ${'expenses.operations_count'.tr()}',
                    icon: Icons.money_off_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'reports.simple_debt_payments'.tr(),
                    value: '${debtPayments.toStringAsFixed(2)} ل.س',
                    secondaryValue: '${debtPaymentsUsd.toStringAsFixed(2)} \$',
                    color: AppColors.success,
                    subtitle: '${profit.debtPaymentsCount} ${'reports.debt_collections'.tr()}',
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'reports.inflows_card_title'.tr(),
                    value: '${totalInflow.toStringAsFixed(2)} ل.س',
                    secondaryValue: '${totalInflowUsd.toStringAsFixed(2)} \$',
                    color: AppColors.success,
                    subtitle: hasExchanges
                        ? '${'reports.sales'.tr()} + ${'reports.simple_debt_payments'.tr()} + ${'reports.exchange_in'.tr()}'
                        : '${'reports.sales'.tr()} + ${'reports.simple_debt_payments'.tr()}',
                    icon: Icons.download,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'reports.outflows_card_title'.tr(),
                    value: '${totalOutflow.toStringAsFixed(2)} ل.س',
                    secondaryValue: '${totalOutflowUsd.toStringAsFixed(2)} \$',
                    color: AppColors.danger,
                    subtitle: hasExchanges
                        ? '${'expenses.title'.tr()} + ${'reports.purchases'.tr()} + ${'reports.exchange_out'.tr()}'
                        : '${'expenses.title'.tr()} + ${'reports.purchases'.tr()}',
                    icon: Icons.upload,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Exchange Impact Card (بطاقة الصرافة: إجمالي الدخل قبل وإجمالي الدخل بعد)
            ExchangeReportCard(
              drawerData: state.cashDrawerData,
              onExchangeRecorded: () => context.read<ReportsCubit>().loadReports(
                start: state.startDate,
                end: state.endDate,
                periodType: state.periodType,
              ),
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
                          _buildLineItem('reports.sales'.tr(), cashSales, AppColors.textPrimary, amountUsd: cashSalesUsd),
                          _buildLineItem('reports.simple_debt_payments'.tr(), debtPayments, AppColors.textPrimary, amountUsd: debtPaymentsUsd),
                          _buildLineItem('reports.exchange_in'.tr(), exchangeInSyp, AppColors.textPrimary, amountUsd: exchangeInUsd),
                          const Divider(height: 16, color: AppColors.border),
                          _buildTotalLine('reports.inflows_card_title'.tr(), totalInflow, AppColors.success, amountUsd: totalInflowUsd),

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
                          _buildLineItem('expenses.title'.tr(), expenses, AppColors.textPrimary, amountUsd: expensesUsd),
                          _buildLineItem('reports.purchases'.tr(), purchases, AppColors.textPrimary, amountUsd: purchasesUsd),
                          _buildLineItem('reports.exchange_out'.tr(), exchangeOutSyp, AppColors.textPrimary, amountUsd: exchangeOutUsd),
                          const Divider(height: 16, color: AppColors.border),
                          _buildTotalLine('reports.outflows_card_title'.tr(), totalOutflow, AppColors.danger, amountUsd: totalOutflowUsd),

                          const SizedBox(height: 24),

                          // 3. Final Net Cash Flow Result
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cashFlowColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: cashFlowColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'reports.operational_cash_flow'.tr(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: cashFlowColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'reports.net_profit_formula'.tr(),
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${netCashFlow.toStringAsFixed(2)} ل.س',
                                      style: AppTheme.numericStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: cashFlowColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${netCashFlowUsd.toStringAsFixed(2)} \$',
                                      style: AppTheme.numericStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: cashFlowColorUsd,
                                      ),
                                    ),
                                  ],
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

                // Right: Sales vs Purchases Comparison
                Expanded(
                  flex: 3,
                  child: CardContainer(
                    title: 'reports.comparison_chart'.tr(),
                    child: SalesPurchasesComparisonChart(
                      summary: state.purchasesSalesSummary,
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

  Widget _buildLineItem(String title, double amount, Color color, {double? amountUsd}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Row(
            children: [
              Text(
                '${amount.toStringAsFixed(2)} ل.س',
                style: AppTheme.numericStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
              if (amountUsd != null) ...[
                const SizedBox(width: 6),
                Text(
                  '/ ${amountUsd.toStringAsFixed(2)} \$',
                  style: AppTheme.numericStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF059669),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalLine(String title, double amount, Color color, {double? amountUsd}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          Row(
            children: [
              Text(
                '${amount.toStringAsFixed(2)} ل.س',
                style: AppTheme.numericStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
              ),
              if (amountUsd != null) ...[
                const SizedBox(width: 6),
                Text(
                  '/ ${amountUsd.toStringAsFixed(2)} \$',
                  style: AppTheme.numericStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF059669),
                  ),
                ),
              ],
            ],
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
