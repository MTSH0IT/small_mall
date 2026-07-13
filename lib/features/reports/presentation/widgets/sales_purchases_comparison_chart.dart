import 'package:flutter/material.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/features/reports/data/reports_repository.dart';

class SalesPurchasesComparisonChart extends StatelessWidget {
  final PurchasesSalesSummary summary;

  const SalesPurchasesComparisonChart({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
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
