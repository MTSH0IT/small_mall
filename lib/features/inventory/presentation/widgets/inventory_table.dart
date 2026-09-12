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
    required this.onViewHistory,
    this.onAdjustStock,
  });

  final List<ProductWithDetails> products;
  final String searchQuery;
  final bool filterLowStockOnly;
  final ValueChanged<ProductWithDetails> onViewHistory;
  final ValueChanged<ProductWithDetails>? onAdjustStock;

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
          title: 'inventory.initial_stock_short'.tr(),
          cellBuilder: (item) => Text(
            item.initialStock.toStringAsFixed(0),
            style: AppTheme.numericStyle(
              color: const Color(0xFF2563EB),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        AppTableColumn<ProductWithDetails>(
          title: 'inventory.current_stock'.tr(),
          cellBuilder: (item) => Text(
            item.currentStock.toStringAsFixed(0),
            style: AppTheme.numericStyle(
              fontWeight: FontWeight.bold,
              color: item.isLowStock ? AppColors.danger : AppColors.success,
            ),
          ),
        ),
        AppTableColumn<ProductWithDetails>(
          title: 'inventory.alert_quantity'.tr(),
          cellBuilder: (item) => Text(
            item.product.minStockAlert.toStringAsFixed(0),
            style: AppTheme.numericStyle(),
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
          title: 'inventory.operations'.tr(),
          cellBuilder: (item) => ElevatedButton.icon(
            onPressed: () => onViewHistory(item),
            icon: const Icon(Icons.manage_history_rounded, size: 16),
            label: Text(
              'inventory.operations'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              foregroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
      ],
    );
  }
}
