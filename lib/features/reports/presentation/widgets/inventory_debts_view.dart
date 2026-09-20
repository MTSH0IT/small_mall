import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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
                  value: '${data.totalOutstandingDebts.toStringAsFixed(2)} $currency',
                  color: AppColors.accent,
                  subtitle: 'customers.has_debt'.tr(),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'reports.debts_collected_in_period'.tr(),
                  value: '${data.debtsCollectedInPeriod.toStringAsFixed(2)} $currency',
                  color: AppColors.success,
                  subtitle: '${'reports.new_debts_issued'.tr()}: ${data.newDebtsIssuedInPeriod.toStringAsFixed(1)} $currency',
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
