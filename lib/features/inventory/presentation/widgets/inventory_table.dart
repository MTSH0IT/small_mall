import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/price_tag_chip.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';

class InventoryTable extends StatelessWidget {
  const InventoryTable({
    super.key,
    required this.products,
    required this.searchQuery,
    required this.filterLowStockOnly,
    required this.onAdjustStock,
  });

  final List<ProductWithDetails> products;
  final String searchQuery;
  final bool filterLowStockOnly;
  final ValueChanged<ProductWithDetails> onAdjustStock;

  @override
  Widget build(BuildContext context) {
    final filtered = products.where((p) {
      final matchQuery = p.product.name.toLowerCase().contains(searchQuery.toLowerCase());
      final matchFilter = !filterLowStockOnly || p.isLowStock;
      return matchQuery && matchFilter;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: EmptyStateView(
          icon: Icons.inventory_outlined,
          title: 'inventory.title'.tr(),
          description: 'inventory.no_matching_products'.tr(),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            DataColumn(label: Text('inventory.product_name'.tr())),
            DataColumn(label: Text('inventory.category'.tr())),
            DataColumn(label: Text('inventory.alert_quantity'.tr())),
            DataColumn(label: Text('inventory.current_stock'.tr())),
            DataColumn(label: Text('common.status'.tr())),
            DataColumn(label: Text('inventory.adjust_stock'.tr())),
          ],
          rows: filtered.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(item.category?.name ?? '-')),
                DataCell(Text(item.product.minStockAlert.toStringAsFixed(0), style: AppTheme.numericStyle())),
                DataCell(Text(item.currentStock.toStringAsFixed(0), style: AppTheme.numericStyle(fontWeight: FontWeight.bold))),
                DataCell(
                  PriceTagChip(
                    label: item.isLowStock ? 'inventory.low_stock'.tr() : 'inventory.in_stock'.tr(),
                    backgroundColor: item.isLowStock ? AppColors.danger : AppColors.success,
                    cutSize: 6,
                  ),
                ),
                DataCell(
                  OutlinedButton.icon(
                    onPressed: () => onAdjustStock(item),
                    icon: const Icon(Icons.swap_vert, size: 16, color: AppColors.primary),
                    label: Text('common.edit'.tr(), style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
