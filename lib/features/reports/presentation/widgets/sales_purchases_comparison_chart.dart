import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';

class SalesPurchasesComparisonChart extends StatelessWidget {
  const SalesPurchasesComparisonChart({
    super.key,
    required this.summary,
  });

  final PurchasesSalesSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sales = summary.totalSales;
    final purchases = summary.totalPurchases;
    final totalTurnover = sales + purchases;
    final difference = sales - purchases;

    final maxVal = sales > purchases
        ? (sales > 0 ? sales : 1.0)
        : (purchases > 0 ? purchases : 1.0);
    final salesWidthPct = totalTurnover > 0 ? (sales / maxVal).clamp(0.02, 1.0) : 0.0;
    final purchasesWidthPct = totalTurnover > 0 ? (purchases / maxVal).clamp(0.02, 1.0) : 0.0;

    final salesPct = totalTurnover > 0 ? ((sales / totalTurnover) * 100).toStringAsFixed(0) : '0';
    final purchasesPct = totalTurnover > 0 ? ((purchases / totalTurnover) * 100).toStringAsFixed(0) : '0';

    final isPositiveDiff = difference >= 0;
    final diffColor = isPositiveDiff ? AppColors.success : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtitle
          Text(
            'reports.comparison_chart_title'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          // 1. Sales Track Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'reports.total_sales_plus'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$salesPct%',
                          style: AppTheme.numericStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    sales.toStringAsFixed(2),
                    style: AppTheme.numericStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Background track + Progress Fill
              Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: salesWidthPct,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Purchases Track Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'reports.total_purchases_minus'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$purchasesPct%',
                          style: AppTheme.numericStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    purchases.toStringAsFixed(2),
                    style: AppTheme.numericStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Background track + Progress Fill
              Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: purchasesWidthPct,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.danger.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          // 3. Summary Footer: Turnover & Difference
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Total Turnover
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'reports.comparison_chart'.tr(),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'reports.total_turnover'.tr(namedArgs: {'amount': totalTurnover.toStringAsFixed(2)}),
                    style: AppTheme.numericStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),

              // Difference badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: diffColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositiveDiff ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: diffColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${difference >= 0 ? '+' : ''}${difference.toStringAsFixed(2)}',
                      style: AppTheme.numericStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: diffColor,
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
}
