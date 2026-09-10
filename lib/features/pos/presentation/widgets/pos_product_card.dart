import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/price_helper.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';

class POSProductCard extends StatelessWidget {
  const POSProductCard({
    super.key,
    required this.item,
    required this.onPriceSelected,
    this.quantityInCart = 0,
  });

  final ProductWithDetails item;
  final Function(ProductPrice) onPriceSelected;
  final double quantityInCart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inStock = item.currentStock > 0;
    final hasInCart = quantityInCart > 0;
    final singlePrice = item.prices.length == 1 ? item.prices.first : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (inStock && singlePrice != null) ? () => onPriceSelected(singlePrice) : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: hasInCart
                ? AppColors.primary.withValues(alpha: 0.03)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasInCart
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : (item.isLowStock
                      ? AppColors.danger.withValues(alpha: 0.4)
                      : AppColors.border),
              width: hasInCart ? 1.5 : (item.isLowStock ? 1.2 : 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Serial ID + Category + Stock Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.product.serialNumber != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '#${item.product.serialNumber}',
                                style: AppTheme.numericStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                item.category?.name ?? '—',
                                style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Stock Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: inStock
                            ? (item.isLowStock
                                ? AppColors.danger.withValues(alpha: 0.12)
                                : AppColors.success.withValues(alpha: 0.12))
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            inStock
                                ? (item.isLowStock
                                    ? Icons.warning_amber_rounded
                                    : Icons.inventory_2_outlined)
                                : Icons.block,
                            size: 11,
                            color: inStock
                                ? (item.isLowStock ? AppColors.danger : AppColors.success)
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            inStock
                                ? item.currentStock.toStringAsFixed(item.currentStock % 1 == 0 ? 0 : 1)
                                : 'pos.out_of_stock'.tr(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: inStock
                                  ? (item.isLowStock ? AppColors.danger : AppColors.success)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Product Name + In-Cart Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.product.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                          fontSize: 13.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasInCart) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '×${quantityInCart.toStringAsFixed(quantityInCart % 1 == 0 ? 0 : 1)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                const Divider(color: AppColors.border, height: 12),

                // Prices Section
                if (item.prices.isEmpty)
                  Text(
                    '—',
                    style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                  )
                else if (singlePrice != null)
                  // Single price prominent button
                  Material(
                    color: inStock ? AppColors.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: inStock ? () => onPriceSelected(singlePrice) : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_shopping_cart_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              singlePrice.priceValue.toStringAsFixed(2),
                              style: AppTheme.numericStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  // Multiple Prices Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: item.prices.map((price) {
                      final label = price.priceLabel.priceLabelDisplay;
                      final color = price.priceLabel.priceLabelColor;

                      return InkWell(
                        onTap: inStock ? () => onPriceSelected(price) : null,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: inStock ? color.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: inStock ? color : Colors.grey.shade400, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  color: inStock ? color : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                price.priceValue.toStringAsFixed(1),
                                style: AppTheme.numericStyle(
                                  fontSize: 11,
                                  color: inStock ? color : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
