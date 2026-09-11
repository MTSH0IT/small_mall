import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/price_helper.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';

class POSProductCard extends StatefulWidget {
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
  State<POSProductCard> createState() => _POSProductCardState();
}

class _POSProductCardState extends State<POSProductCard> {
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
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: hasInCart
                  ? AppColors.primary.withValues(alpha: 0.04)
                  : (_isHovered
                      ? AppColors.surfaceElevated
                      : AppColors.surfaceElevated),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasInCart
                    ? AppColors.primary
                    : (_isHovered
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : (item.isLowStock
                            ? AppColors.danger.withValues(alpha: 0.4)
                            : AppColors.border)),
                width: hasInCart ? 1.5 : (_isHovered ? 1.2 : 1.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.025),
                  blurRadius: _isHovered ? 8 : 4,
                  offset: Offset(0, _isHovered ? 3 : 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // --- TOP SECTION: Header (Serial + Category + Stock) ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.product.serialNumber != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.09),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.25),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      '#${item.product.serialNumber}',
                                      style: AppTheme.numericStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      item.category?.name ?? '—',
                                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 9.5),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Stock Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: inStock
                                  ? (item.isLowStock
                                      ? AppColors.danger.withValues(alpha: 0.12)
                                      : AppColors.success.withValues(alpha: 0.12))
                                  : Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
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
                                  size: 10.5,
                                  color: inStock
                                      ? (item.isLowStock ? AppColors.danger : AppColors.success)
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  inStock
                                      ? item.currentStock.toStringAsFixed(
                                          item.currentStock % 1 == 0 ? 0 : 1,
                                        )
                                      : 'pos.out_of_stock'.tr(),
                                  style: TextStyle(
                                    fontSize: 9.5,
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
                      const SizedBox(height: 6),

                      // --- MIDDLE SECTION: Product Name & Badges ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.product.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.22,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasInCart) ...[
                            const SizedBox(width: 4),
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

                      if (item.product.code != null && item.product.code!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 11,
                              color: AppColors.textSecondary.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                item.product.code!.trim(),
                                style: AppTheme.numericStyle(
                                  fontSize: 9.5,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  // --- BOTTOM SECTION: Price & Action ---
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: item.prices.isEmpty
                        ? Container(
                            height: 32,
                            alignment: Alignment.center,
                            child: Text(
                              '—',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : (singlePrice != null
                            ? Material(
                                color: inStock ? AppColors.primary : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: inStock
                                      ? () => widget.onPriceSelected(singlePrice)
                                      : null,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 32,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
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
                                            color: inStock ? Colors.white : AppColors.textSecondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: item.prices.map((price) {
                                    final label = price.priceLabel.priceLabelDisplay;
                                    final color = price.priceLabel.priceLabelColor;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                      child: Material(
                                        color: inStock
                                            ? color.withValues(alpha: 0.1)
                                            : Colors.grey.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        child: InkWell(
                                          onTap: inStock
                                              ? () => widget.onPriceSelected(price)
                                              : null,
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3.5,
                                            ),
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
                                      ),
                                    );
                                  }).toList(),
                                ),
                              )),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
