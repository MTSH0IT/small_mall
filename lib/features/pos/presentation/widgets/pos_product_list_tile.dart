import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/price_helper.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';

class POSProductListTile extends StatefulWidget {
  const POSProductListTile({
    super.key,
    required this.item,
    required this.onPriceSelected,
    this.quantityInCart = 0,
  });

  final ProductWithDetails item;
  final Function(ProductPrice) onPriceSelected;
  final double quantityInCart;

  @override
  State<POSProductListTile> createState() => _POSProductListTileState();
}

class _POSProductListTileState extends State<POSProductListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final inStock = item.currentStock > 0;
    final hasInCart = widget.quantityInCart > 0;
    final singlePrice = item.prices.length == 1 ? item.prices.first : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (inStock && singlePrice != null)
              ? () => widget.onPriceSelected(singlePrice)
              : null,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: hasInCart
                  ? AppColors.primary.withValues(alpha: 0.04)
                  : (_isHovered ? AppColors.surface : AppColors.surfaceElevated),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasInCart
                    ? AppColors.primary
                    : (_isHovered
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : (item.isLowStock
                            ? AppColors.danger.withValues(alpha: 0.35)
                            : AppColors.border)),
                width: hasInCart ? 1.5 : (_isHovered ? 1.2 : 1.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.02),
                  blurRadius: _isHovered ? 6 : 2,
                  offset: Offset(0, _isHovered ? 2 : 1),
                ),
              ],
            ),
            child: Row(
              children: [
                // Serial Number Tag
                if (item.product.serialNumber != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
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
                  const SizedBox(width: 10),
                ],

                // Product Details (Title, Category, Barcode)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.product.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasInCart) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '×${widget.quantityInCart.toStringAsFixed(widget.quantityInCart % 1 == 0 ? 0 : 1)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (item.category?.name != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                item.category!.name,
                                style: theme.textTheme.labelSmall?.copyWith(fontSize: 9.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (item.product.code != null && item.product.code!.trim().isNotEmpty) ...[
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 11,
                              color: AppColors.textSecondary.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              item.product.code!.trim(),
                              style: AppTheme.numericStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Stock Indicator Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                        size: 12,
                        color: inStock
                            ? (item.isLowStock ? AppColors.danger : AppColors.success)
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        inStock
                            ? item.currentStock.toStringAsFixed(
                                item.currentStock % 1 == 0 ? 0 : 1,
                              )
                            : 'pos.out_of_stock'.tr(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: inStock
                              ? (item.isLowStock ? AppColors.danger : AppColors.success)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Prices Section
                if (item.prices.isEmpty)
                  Text(
                    '—',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else if (singlePrice != null)
                  Material(
                    color: inStock ? AppColors.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(7),
                    child: InkWell(
                      onTap: inStock ? () => widget.onPriceSelected(singlePrice) : null,
                      borderRadius: BorderRadius.circular(7),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 13,
                              color: inStock ? Colors.white : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${singlePrice.priceValue.toStringAsFixed(2)} ${'common.currency'.tr()}',
                              style: AppTheme.numericStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: inStock ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: item.prices.map((price) {
                      final label = price.priceLabel.priceLabelDisplay;
                      final color = price.priceLabel.priceLabelColor;

                      return Material(
                        color: inStock
                            ? color.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          onTap: inStock ? () => widget.onPriceSelected(price) : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: inStock ? color : Colors.grey.shade400,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: inStock ? color : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  price.priceValue.toStringAsFixed(1),
                                  style: AppTheme.numericStyle(
                                    fontSize: 10.5,
                                    color: inStock ? color : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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
