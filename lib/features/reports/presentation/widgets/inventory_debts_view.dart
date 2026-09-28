import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/card_container.dart';
import 'package:small_mall/core/widgets/stat_card.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';

class InventoryDebtsView extends StatelessWidget {
  const InventoryDebtsView({
    super.key,
    required this.inventoryAndDebtsData,
    required this.inventoryReport,
  });

  final InventoryAndDebtsReportData inventoryAndDebtsData;
  final List<InventoryReportItem> inventoryReport;

  @override
  Widget build(BuildContext context) {
    final currency = 'common.currency'.tr();
    final data = inventoryAndDebtsData;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Inventory Valuation Header Row
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'reports.inventory_valuation'.tr(),
                  value: '${data.totalInventoryCost.toStringAsFixed(2)} $currency',
                  color: AppColors.primary,
                  subtitle: '${'inventory.products_title'.tr()}: ${data.totalActiveProducts}',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'reports.low_stock_items'.tr(),
                  value: '${data.lowStockProductsCount}',
                  color: data.lowStockProductsCount > 0 ? AppColors.warning : AppColors.success,
                  subtitle: data.lowStockProductsCount > 0
                      ? 'reports.low_stock_report'.tr()
                      : 'reports.all_stock_healthy'.tr(),
                  icon: Icons.warning_amber_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'reports.total_outstanding_debts'.tr(),
                  value: '${NumberFormat('#,##0.##').format(data.totalOutstandingDebtsSyp)} ${AppCurrency.sypSymbol}',
                  secondaryValue: data.totalOutstandingDebtsUsd > 0
                      ? '${NumberFormat('#,##0.00').format(data.totalOutstandingDebtsUsd)} ${AppCurrency.usdSymbol}'
                      : null,
                  color: AppColors.accent,
                  secondaryColor: const Color(0xFF059669),
                  subtitle: 'customers.has_debt'.tr(),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'reports.debts_collected_in_period'.tr(),
                  value: '${NumberFormat('#,##0.##').format(data.debtsCollectedInPeriodSyp)} ${AppCurrency.sypSymbol}',
                  secondaryValue: data.debtsCollectedInPeriodUsd > 0
                      ? '${NumberFormat('#,##0.00').format(data.debtsCollectedInPeriodUsd)} ${AppCurrency.usdSymbol}'
                      : null,
                  color: AppColors.success,
                  secondaryColor: const Color(0xFF059669),
                  subtitle: '${'reports.new_debts_issued'.tr()}: ${NumberFormat('#,##0.##').format(data.newDebtsIssuedInPeriodSyp)} ${AppCurrency.sypSymbol}${data.newDebtsIssuedInPeriodUsd > 0 ? ' / ${NumberFormat('#,##0.00').format(data.newDebtsIssuedInPeriodUsd)} ${AppCurrency.usdSymbol}' : ''}',
                  icon: Icons.price_check,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Inventory Items Valuation Table
          CardContainer(
            title: 'reports.inventory_valuation'.tr(),
            child: inventoryReport.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'inventory.no_products'.tr(),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: inventoryReport.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final item = inventoryReport[index];
                      final isLow = item.product.minStockAlert > 0 && item.currentStock <= item.product.minStockAlert;

                      return ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isLow ? AppColors.warning : AppColors.primary).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isLow ? Icons.warning_amber : Icons.inventory_2_outlined,
                            size: 18,
                            color: isLow ? AppColors.warning : AppColors.primary,
                          ),
                        ),
                        title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${'inventory.current_stock'.tr()}: ${item.currentStock.toStringAsFixed(0)} | ${'suppliers.unit_cost'.tr()}: ${item.product.costPrice.toStringAsFixed(2)} $currency',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.totalCostValue.toStringAsFixed(2)} $currency',
                              style: AppTheme.numericStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'reports.cogs'.tr(),
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
