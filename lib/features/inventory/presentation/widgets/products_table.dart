import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/price_helper.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_table.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/price_tag_chip.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';

class ProductsTable extends StatelessWidget {
  const ProductsTable({
    super.key,
    required this.products,
    required this.searchQuery,
    this.selectedCategoryId,
    required this.onEditProduct,
    required this.onDeleteProduct,
    this.onViewHistory,
    this.onResetFilters,
  });

  final List<ProductWithDetails> products;
  final String searchQuery;
  final String? selectedCategoryId;
  final ValueChanged<ProductWithDetails> onEditProduct;
  final ValueChanged<ProductWithDetails> onDeleteProduct;
  final ValueChanged<ProductWithDetails>? onViewHistory;
  final VoidCallback? onResetFilters;

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim().toLowerCase();
    final filtered = products.where((p) {
      final matchesSearch = query.isEmpty ||
          p.product.name.toLowerCase().contains(query) ||
          (p.product.serialNumber != null && p.product.serialNumber.toString() == query) ||
          (p.product.code?.toLowerCase().contains(query) ?? false);

      final bool matchesCategory;
      if (selectedCategoryId == null) {
        matchesCategory = true;
      } else if (selectedCategoryId == '__uncategorized__') {
        matchesCategory = p.product.categoryId == null;
      } else {
        matchesCategory = p.product.categoryId == selectedCategoryId;
      }

      return matchesSearch && matchesCategory;
    }).toList();

    if (products.isEmpty) {
      return Center(
        child: EmptyStateView(
          icon: Icons.inventory_2_outlined,
          title: 'inventory.products_title'.tr(),
          description: 'inventory.empty_products'.tr(),
        ),
      );
    }

    return AppTable<ProductWithDetails>(
      items: filtered,
      emptyTitle: 'inventory.no_matching_products'.tr(),
      emptyIcon: Icons.search_off_rounded,
      onResetFilters: onResetFilters,
      columns: [
        AppTableColumn<ProductWithDetails>(
          title: 'inventory.product_id'.tr(),
          cellBuilder: (item) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Text(
              '#${item.product.serialNumber ?? '-'}',
              style: AppTheme.numericStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
        AppTableColumn<ProductWithDetails>(
          title: 'inventory.product_name'.tr(),
          cellBuilder: (item) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (item.product.code != null && item.product.code!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.qr_code_2_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item.product.code!,
                        style: AppTheme.numericStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        AppTableColumn<ProductWithDetails>(
          title: 'inventory.category'.tr(),
          cellBuilder: (item) => Text(item.category?.name ?? '-'),
        ),
        AppTableColumn<ProductWithDetails>(
          title: 'inventory.cost_price'.tr(),
          cellBuilder: (item) => Text(
            item.product.costPrice.toStringAsFixed(2),
            style: AppTheme.numericStyle(),
          ),
        ),
        AppTableColumn<ProductWithDetails>(
          title: 'inventory.selling_prices'.tr(),
          cellBuilder: (item) {
            final retail = item.prices.firstWhere((p) => p.priceLabel == 'retail',
                orElse: () => ProductPrice(id: '', productId: '', priceLabel: 'retail', priceValue: 0.0));
            final wholesale = item.prices.firstWhere((p) => p.priceLabel == 'wholesale',
                orElse: () => ProductPrice(id: '', productId: '', priceLabel: 'wholesale', priceValue: 0.0));

            return Wrap(
              spacing: 8,
              children: [
                PriceTagChip(
                  label: '${'retail'.priceLabelText}: ${retail.priceValue.toStringAsFixed(1)}',
                  backgroundColor: 'retail'.priceLabelColor,
                  cutSize: 6,
                ),
                PriceTagChip(
                  label: '${'wholesale'.priceLabelText}: ${wholesale.priceValue.toStringAsFixed(1)}',
                  backgroundColor: 'wholesale'.priceLabelColor,
                  cutSize: 6,
                ),
              ],
            );
          },
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
              color: item.isLowStock ? AppColors.danger : AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        AppTableColumn<ProductWithDetails>(
          title: 'common.actions'.tr(),
          cellBuilder: (item) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onViewHistory != null)
                IconButton(
                  icon: const Icon(Icons.manage_history_rounded, color: AppColors.primary),
                  tooltip: 'inventory.operations_history'.tr(),
                  onPressed: () => onViewHistory!(item),
                ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                tooltip: 'common.edit'.tr(),
                onPressed: () => onEditProduct(item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                tooltip: 'common.delete'.tr(),
                onPressed: () => onDeleteProduct(item),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
