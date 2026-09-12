import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_table.dart';
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

    return AppTable<ProductWithDetails>(
      items: filtered,
      emptyTitle: 'inventory.title'.tr(),
      emptyDescription: 'inventory.no_matching_products'.tr(),
      emptyIcon: Icons.inventory_outlined,
      columns: [
        AppTableColumn<ProductWithDetails>(
          title: 'inventory.product_name'.tr(),
          cellBuilder: (item) => Text(
            item.product.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        AppTableColumn<ProductWithDetails>(
          title: 'inventory.category'.tr(),
          cellBuilder: (item) => Text(item.category?.name ?? '-'),
        ),
        AppTableColumn<ProductWithDetails>(
          title: 'inventory.alert_quantity'.tr(),
          cellBuilder: (item) => Text(
            item.product.minStockAlert.toStringAsFixed(0),
            style: AppTheme.numericStyle(),
          ),
        ),
        AppTableColumn<ProductWithDetails>(
          title: 'inventory.current_stock'.tr(),
          cellBuilder: (item) => Text(
            item.currentStock.toStringAsFixed(0),
            style: AppTheme.numericStyle(fontWeight: FontWeight.bold),
          ),
        ),
        AppTableColumn<ProductWithDetails>(
          title: 'common.status'.tr(),
          cellBuilder: (item) => PriceTagChip(
            label: item.isLowStock ? 'inventory.low_stock'.tr() : 'inventory.in_stock'.tr(),
            backgroundColor: item.isLowStock ? AppColors.danger : AppColors.success,
            cutSize: 6,
          ),
        ),
        AppTableColumn<ProductWithDetails>(
          title: 'inventory.adjust_stock'.tr(),
          cellBuilder: (item) => OutlinedButton.icon(
            onPressed: () => onAdjustStock(item),
            icon: const Icon(Icons.swap_vert, size: 16, color: AppColors.primary),
            label: Text(
              'common.edit'.tr(),
              style: const TextStyle(color: AppColors.primary, fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
      ],
    );
  }
}
