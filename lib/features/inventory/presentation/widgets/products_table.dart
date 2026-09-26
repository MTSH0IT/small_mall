import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/utils/price_helper.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_table.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
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
      final matchesSearch =
          query.isEmpty ||
          p.product.name.toLowerCase().contains(query) ||
          (p.product.serialNumber != null &&
              p.product.serialNumber.toString() == query) ||
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      item.product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: item.hasDualPrices
                          ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                          : (item.currency == AppCurrency.secondaryCode
                                ? const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.12)
                                : AppColors.primary.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: item.hasDualPrices
                            ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                            : (item.currency == AppCurrency.secondaryCode
                                  ? const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.3)
                                  : AppColors.primary.withValues(alpha: 0.25)),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      item.hasDualPrices ? 'ل.س / \$' : item.currencySymbol,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: item.hasDualPrices
                            ? const Color(0xFF4F46E5)
                            : (item.currency == AppCurrency.secondaryCode
                                  ? const Color(0xFF059669)
                                  : AppColors.primary),
                      ),
                    ),
                  ),
                ],
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
          cellBuilder: (item) {
            final hasUsdCost = item.costPriceUsd > 0;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.costPriceSyp.toStringAsFixed(2),
                      style: AppTheme.numericStyle(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppCurrency.primarySymbol,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (hasUsdCost) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.costPriceUsd.toStringAsFixed(2),
                        style: AppTheme.numericStyle(
                          color: const Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppCurrency.secondarySymbol,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
        AppTableColumn<ProductWithDetails>(
          title: 'inventory.selling_prices'.tr(),
          cellBuilder: (item) {
            final sypChips = <Widget>[];
            final usdChips = <Widget>[];

            final sypRetail = item.retailPriceSyp;
            final sypWholesale = item.wholesalePriceSyp;
            final usdRetail = item.retailPriceUsd;
            final usdWholesale = item.wholesalePriceUsd;

            if (sypRetail != null && sypRetail > 0) {
              sypChips.add(
                _CompactPriceChip(
                  label: 'retail'.priceLabelText,
                  priceText: sypRetail.toStringAsFixed(
                    sypRetail % 1 == 0 ? 0 : 1,
                  ),
                  currencySymbol: AppCurrency.baseSymbol,
                  color: const Color(0xFF2563EB),
                ),
              );
            }
            if (sypWholesale != null && sypWholesale > 0) {
              sypChips.add(
                _CompactPriceChip(
                  label: 'wholesale'.priceLabelText,
                  priceText: sypWholesale.toStringAsFixed(
                    sypWholesale % 1 == 0 ? 0 : 1,
                  ),
                  currencySymbol: AppCurrency.baseSymbol,
                  color: const Color(0xFFD97706),
                ),
              );
            }

            if (usdRetail != null && usdRetail > 0) {
              usdChips.add(
                _CompactPriceChip(
                  label: 'retail'.priceLabelText,
                  priceText: usdRetail.toStringAsFixed(
                    usdRetail % 1 == 0 ? 0 : 2,
                  ),
                  currencySymbol: AppCurrency.secondarySymbol,
                  color: const Color(0xFF059669),
                ),
              );
            }
            if (usdWholesale != null && usdWholesale > 0) {
              usdChips.add(
                _CompactPriceChip(
                  label: 'wholesale'.priceLabelText,
                  priceText: usdWholesale.toStringAsFixed(
                    usdWholesale % 1 == 0 ? 0 : 2,
                  ),
                  currencySymbol: AppCurrency.secondarySymbol,
                  color: const Color(0xFF0D9488),
                ),
              );
            }

            if (sypChips.isEmpty && usdChips.isEmpty) {
              final fallbackChips = <Widget>[];
              for (final p in item.prices) {
                if (p.priceValue > 0) {
                  final isUsd = p.currency == 'USD';
                  final isRetail = p.priceLabel == 'retail';
                  fallbackChips.add(
                    _CompactPriceChip(
                      label: p.priceLabel.priceLabelText,
                      priceText: p.priceValue.toStringAsFixed(
                        p.priceValue % 1 == 0 ? 0 : (isUsd ? 2 : 1),
                      ),
                      currencySymbol: AppCurrency.getSymbol(
                        p.currency ?? item.currency,
                      ),
                      color: isUsd
                          ? (isRetail
                                ? const Color(0xFF059669)
                                : const Color(0xFF0D9488))
                          : (isRetail
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFD97706)),
                    ),
                  );
                }
              }
              if (fallbackChips.isEmpty) {
                return const Text(
                  '-',
                  style: TextStyle(color: AppColors.textSecondary),
                );
              }
              return Wrap(spacing: 4, runSpacing: 3, children: fallbackChips);
            }

            final rows = <Widget>[];
            if (sypChips.isNotEmpty) {
              rows.add(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < sypChips.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      sypChips[i],
                    ],
                  ],
                ),
              );
            }
            if (usdChips.isNotEmpty) {
              if (rows.isNotEmpty) {
                rows.add(const SizedBox(height: 3));
              }
              rows.add(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < usdChips.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      usdChips[i],
                    ],
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: rows,
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
                  icon: const Icon(
                    Icons.manage_history_rounded,
                    color: AppColors.primary,
                  ),
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

class _CompactPriceChip extends StatelessWidget {
  const _CompactPriceChip({
    required this.label,
    required this.priceText,
    required this.currencySymbol,
    required this.color,
  });

  final String label;
  final String priceText;
  final String currencySymbol;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.9),
            ),
          ),
          Text(
            priceText,
            style: AppTheme.numericStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            currencySymbol,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
