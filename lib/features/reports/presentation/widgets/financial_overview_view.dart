import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/card_container.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/stat_card.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';
import 'package:small_mall/features/reports/presentation/widgets/sales_purchases_comparison_chart.dart';

class FinancialOverviewView extends StatelessWidget {
  const FinancialOverviewView({
    super.key,
    required this.profitData,
    required this.cashDrawerData,
    required this.bestSellers,
    required this.purchasesSalesSummary,
  });

  final ProfitReportData profitData;
  final CashDrawerReportData cashDrawerData;
  final List<ProductSalesSummary> bestSellers;
  final PurchasesSalesSummary purchasesSalesSummary;

  @override
  Widget build(BuildContext context) {
    final currency = 'common.currency'.tr();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top KPI Summary Cards
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'reports.net_profit'.tr(),
                  value: '${profitData.netProfit.toStringAsFixed(2)} $currency',
                  color: profitData.netProfit >= 0 ? AppColors.success : AppColors.danger,
                  subtitle: '${'reports.profit_margin'.tr()}: ${profitData.profitMargin.toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'reports.gross_sales'.tr(),
                  value: '${profitData.grossSales.toStringAsFixed(2)} $currency',
                  color: AppColors.primary,
                  subtitle: '${'reports.cash_sales'.tr()}: ${profitData.cashSales.toStringAsFixed(1)} | ${'reports.debt_sales_label'.tr()}: ${profitData.debtSales.toStringAsFixed(1)}',
                  icon: Icons.point_of_sale,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'expenses.title'.tr(),
                  value: '${profitData.totalExpenses.toStringAsFixed(2)} $currency',
                  color: AppColors.warning,
                  subtitle: '${profitData.expensesCount} ${'expenses.operations_count'.tr()}',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'reports.net_cash_flow'.tr(),
                  value: '${cashDrawerData.netCashFlow.toStringAsFixed(2)} $currency',
                  color: cashDrawerData.netCashFlow >= 0 ? AppColors.success : AppColors.danger,
                  subtitle: '${'reports.cash_in'.tr()}: ${cashDrawerData.totalCashIn.toStringAsFixed(1)} | ${'reports.cash_out'.tr()}: ${cashDrawerData.totalCashOut.toStringAsFixed(1)}',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Middle Row: Simplified Income Statement & (Comparison Chart + Best Sellers)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Simplified Income Statement
              Expanded(
                flex: 3,
                child: CardContainer(
                  title: 'reports.income_statement'.tr(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatementRow(
                          title: 'reports.cash_sales_label'.tr(),
                          amount: profitData.cashSales,
                          color: AppColors.textPrimary,
                          isSubItem: true,
                        ),
                        _buildStatementRow(
                          title: 'reports.debt_sales_label'.tr(),
                          amount: profitData.debtSales,
                          color: AppColors.textPrimary,
                          isSubItem: true,
                        ),
                        const Divider(height: 16, color: AppColors.border),
                        _buildStatementRow(
                          title: 'reports.gross_sales'.tr(),
                          amount: profitData.grossSales,
                          color: AppColors.primary,
                          isBold: true,
                        ),
                        _buildStatementRow(
                          title: 'reports.returns_deduction'.tr(),
                          amount: -profitData.returnsAmount,
                          color: AppColors.danger,
                        ),
                        const Divider(height: 16, color: AppColors.border),
                        _buildStatementRow(
                          title: 'reports.net_sales'.tr(),
                          amount: profitData.netSales,
                          color: AppColors.primary,
                          isBold: true,
                        ),
                        _buildStatementRow(
                          title: 'reports.cogs'.tr(),
                          amount: -profitData.costOfGoodsSold,
                          color: AppColors.danger,
                        ),
                        const Divider(height: 16, color: AppColors.border),
                        _buildStatementRow(
                          title: 'reports.gross_profit_label'.tr(),
                          amount: profitData.grossProfit,
                          color: profitData.grossProfit >= 0 ? AppColors.success : AppColors.danger,
                          isBold: true,
                        ),
                        _buildStatementRow(
                          title: 'reports.expenses_deduction'.tr(),
                          amount: -profitData.totalExpenses,
                          color: AppColors.warning,
                        ),
                        if (profitData.adjustmentsLoss > 0)
                          _buildStatementRow(
                            title: 'reports.adjustments_loss'.tr(),
                            amount: -profitData.adjustmentsLoss,
                            color: AppColors.danger,
                          ),
                        const Divider(height: 20, thickness: 1.5, color: AppColors.border),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (profitData.netProfit >= 0 ? AppColors.success : AppColors.danger)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (profitData.netProfit >= 0 ? AppColors.success : AppColors.danger)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'reports.net_profit_final'.tr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: profitData.netProfit >= 0 ? AppColors.success : AppColors.danger,
                                ),
                              ),
                              Text(
                                '${profitData.netProfit.toStringAsFixed(2)} $currency',
                                style: AppTheme.numericStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: profitData.netProfit >= 0 ? AppColors.success : AppColors.danger,
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

              // Right: Purchases vs Sales Bar + Best Sellers
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Comparison Bar
                    CardContainer(
                      title: 'reports.comparison_chart'.tr(),
                      child: SalesPurchasesComparisonChart(
                        summary: purchasesSalesSummary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Best Sellers
                    CardContainer(
                      title: 'reports.top_selling'.tr(),
                      child: bestSellers.isEmpty
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
                              itemCount: bestSellers.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (context, index) {
                                final item = bestSellers[index];
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
                                    '${item.totalRevenue.toStringAsFixed(2)} $currency',
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

  Widget _buildStatementRow({
    required String title,
    required double amount,
    required Color color,
    bool isBold = false,
    bool isSubItem = false,
  }) {
    final formatted = amount.abs().toStringAsFixed(2);
    final sign = amount < 0 ? '-' : (amount > 0 && !isSubItem ? '+' : '');

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: isSubItem ? 12.0 : 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 14 : 13,
              color: isSubItem ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
          Text(
            '$sign$formatted',
            style: AppTheme.numericStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 14 : 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
