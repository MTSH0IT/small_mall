import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/di/injection.dart';
import 'package:artisan_gift_manager/core/widgets/price_tag_chip.dart';
import 'package:artisan_gift_manager/core/widgets/primary_button.dart';
import 'package:artisan_gift_manager/core/widgets/loading_indicator.dart';
import 'package:artisan_gift_manager/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:artisan_gift_manager/features/reports/data/reports_repository.dart';
import 'package:intl/intl.dart' hide TextDirection;

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
    final theme = Theme.of(context);

    return BlocProvider<ReportsCubit>(
      create: (context) => ReportsCubit(getIt<ReportsRepository>())..loadReports(start: _startDate, end: _endDate),
      child: BlocConsumer<ReportsCubit, ReportsState>(
        listener: (context, state) {
          if (state is ReportsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.danger),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<ReportsCubit>();

          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              title: Text(
                'التقارير والإحصائيات',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontFamily: 'ElMessiri',
                  color: AppColors.primary,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: () => cubit.loadReports(start: _startDate, end: _endDate),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Period Selection Controls
                  _buildPeriodFilterRow(context, cubit),
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

  Widget _buildPeriodFilterRow(BuildContext context, ReportsCubit cubit) {
    final startStr = DateFormat('yyyy/MM/dd').format(_startDate);
    final endStr = DateFormat('yyyy/MM/dd').format(_endDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            'الفترة المحددة: من $startStr إلى $endStr',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _selectDateRange(context, cubit),
            icon: const Icon(Icons.edit_calendar, color: AppColors.primary),
            label: const Text('تعديل الفترة', style: TextStyle(color: AppColors.primary)),
          ),
        ],
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
    final theme = Theme.of(context);

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
                  child: _buildFinancialCard(
                    title: 'صافي أرباح الفترة',
                    value: '${totalProfit.toStringAsFixed(2)} د.أ',
                    color: totalProfit >= 0 ? AppColors.success : AppColors.danger,
                    subtitle: 'الإيرادات: ${revenue.toStringAsFixed(1)} | التكاليف: ${cost.toStringAsFixed(1)}',
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFinancialCard(
                    title: 'إجمالي قيمة المخزون الحالي (سعر التكلفة)',
                    value: '${totalInventoryValuation.toStringAsFixed(2)} د.أ',
                    color: AppColors.primary,
                    subtitle: 'إجمالي عدد المنتجات المخزنة: ${state.inventoryReport.length}',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFinancialCard(
                    title: 'إجمالي الديون المستحقة بذمة العملاء',
                    value: '${state.totalOutstandingDebts.toStringAsFixed(2)} د.أ',
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
                  child: _buildCardWrapper(
                    title: 'المبيعات مقابل المشتريات خلال الفترة',
                    child: _buildSalesPurchasesComparisonChart(state.purchasesSalesSummary),
                  ),
                ),
                const SizedBox(width: 24),
                // Best Sellers
                Expanded(
                  flex: 3,
                  child: _buildCardWrapper(
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
                            separatorBuilder: (_, __) => const Divider(color: AppColors.border),
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
                                  '${item.totalRevenue.toStringAsFixed(2)} د.أ',
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

  Widget _buildFinancialCard({
    required String title,
    required String value,
    required Color color,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              Icon(icon, color: color.withOpacity(0.8), size: 28),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTheme.numericStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildCardWrapper({required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'ElMessiri',
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          child,
        ],
      ),
    );
  }

  Widget _buildSalesPurchasesComparisonChart(PurchasesSalesSummary summary) {
    final theme = Theme.of(context);
    final sales = summary.totalSales;
    final purchases = summary.totalPurchases;

    final maxVal = sales > purchases ? (sales > 0 ? sales : 1.0) : (purchases > 0 ? purchases : 1.0);
    final salesWidthPct = (sales / maxVal).clamp(0.05, 1.0);
    final purchasesWidthPct = (purchases / maxVal).clamp(0.05, 1.0);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('مقارنة التداول المالي (المبيعات مقابل المشتريات):', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          // Sales Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('إجمالي المبيعات (+)', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.success)),
                  Text(
                    '${sales.toStringAsFixed(2)} د.أ',
                    style: AppTheme.numericStyle(fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FractionallySizedBox(
                widthFactor: salesWidthPct,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Purchases Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('إجمالي المشتريات (-)', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.danger)),
                  Text(
                    '${purchases.toStringAsFixed(2)} د.أ',
                    style: AppTheme.numericStyle(fontWeight: FontWeight.bold, color: AppColors.danger),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FractionallySizedBox(
                widthFactor: purchasesWidthPct,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'حجم التداول الكلي: ${(sales + purchases).toStringAsFixed(2)} د.أ',
            style: theme.textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
