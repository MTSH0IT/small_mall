import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
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
    final canAddMore = (item.currentStock - widget.quantityInCart) > 0;
    final singlePrice = item.prices.length == 1 ? item.prices.first : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (canAddMore && singlePrice != null)
              ? () => widget.onPriceSelected(singlePrice)
              : null,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: hasInCart
                  ? AppColors.primary.withValues(alpha: 0.04)
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
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
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // --- TOP & MIDDLE: Header + Info ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(item, inStock, theme),
                      const SizedBox(height: 4),
                      _buildProductInfo(item, hasInCart, theme),
                    ],
                  ),

                  // --- BOTTOM: Prices ---
                  Padding(
                    padding: const EdgeInsets.only(top: 3.0),
                    child: _buildPriceSection(item, canAddMore, theme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Top row: Serial number, category, currency badge, and stock count
  Widget _buildHeader(ProductWithDetails item, bool inStock, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.product.serialNumber != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.0),
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
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.0),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    item.category?.name ?? '—',
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 9.0),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.0),
                decoration: BoxDecoration(
                  color: item.hasDualPrices
                      ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                      : (item.currency == AppCurrency.secondaryCode
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: item.hasDualPrices
                        ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                        : (item.currency == AppCurrency.secondaryCode
                            ? const Color(0xFF10B981).withValues(alpha: 0.3)
                            : AppColors.primary.withValues(alpha: 0.25)),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  item.hasDualPrices ? 'ل.س / \$' : item.currencySymbol,
                  style: TextStyle(
                    fontSize: 8.5,
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
        ),
        const SizedBox(width: 3),
        // Stock Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.0),
          decoration: BoxDecoration(
            color: inStock
                ? (item.isLowStock
                    ? AppColors.danger.withValues(alpha: 0.12)
                    : AppColors.success.withValues(alpha: 0.12))
                : Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
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
                size: 10,
                color: inStock
                    ? (item.isLowStock ? AppColors.danger : AppColors.success)
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 2.5),
              Text(
                inStock
                    ? item.currentStock.toStringAsFixed(
                        item.currentStock % 1 == 0 ? 0 : 1,
                      )
                    : 'pos.out_of_stock'.tr(),
                style: TextStyle(
                  fontSize: 9.0,
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
    );
  }

  /// Middle section: Product name, cart count badge, and barcode/code
  Widget _buildProductInfo(ProductWithDetails item, bool hasInCart, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.product.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                  fontSize: 12.0,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasInCart) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.0),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '×${widget.quantityInCart.toStringAsFixed(widget.quantityInCart % 1 == 0 ? 0 : 1)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (item.product.code != null && item.product.code!.trim().isNotEmpty) ...[
          const SizedBox(height: 1.5),
          Row(
            children: [
              Icon(
                Icons.qr_code_2_rounded,
                size: 10.0,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 2.5),
              Expanded(
                child: Text(
                  item.product.code!.trim(),
                  style: AppTheme.numericStyle(
                    fontSize: 8.5,
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
    );
  }

  /// Price container: handles empty, single price, dual-currency rows, and multi-prices
  Widget _buildPriceSection(
    ProductWithDetails item,
    bool inStock,
    ThemeData theme,
  ) {
    if (item.prices.isEmpty) {
      return Container(
        height: 23,
        alignment: Alignment.center,
        child: Text(
          '—',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    if (item.prices.length == 1) {
      return _buildSinglePriceButton(item.prices.first, item, inStock);
    }

    if (item.hasDualPrices) {
      final sypPrices = item.prices
          .where((p) => (p.currency ?? item.currency) != AppCurrency.secondaryCode)
          .toList();
      final usdPrices = item.prices
          .where((p) => (p.currency ?? item.currency) == AppCurrency.secondaryCode)
          .toList();

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sypPrices.isNotEmpty)
            Row(
              children: _buildRowPriceButtons(sypPrices, inStock),
            ),
          if (sypPrices.isNotEmpty && usdPrices.isNotEmpty)
            const SizedBox(height: 2.5),
          if (usdPrices.isNotEmpty)
            Row(
              children: _buildRowPriceButtons(usdPrices, inStock),
            ),
        ],
      );
    } else {
      final rows = <List<ProductPrice>>[];
      for (var i = 0; i < item.prices.length; i += 2) {
        rows.add(item.prices.sublist(i, (i + 2 > item.prices.length) ? item.prices.length : i + 2));
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 2.5),
            Row(
              children: _buildRowPriceButtons(rows[i], inStock),
            ),
          ],
        ],
      );
    }
  }

  List<Widget> _buildRowPriceButtons(
    List<ProductPrice> prices,
    bool inStock,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < prices.length; i++) {
      if (i > 0) {
        widgets.add(const SizedBox(width: 3.5));
      }
      widgets.add(
        Expanded(
          child: _buildPriceButton(
            price: prices[i],
            inStock: inStock,
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildSinglePriceButton(
    ProductPrice singlePrice,
    ProductWithDetails item,
    bool inStock,
  ) {
    return Material(
      color: inStock ? AppColors.primary : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: inStock ? () => widget.onPriceSelected(singlePrice) : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 23,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_shopping_cart_rounded,
                  size: 11,
                  color: inStock ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatPriceValue(singlePrice, item),
                  style: AppTheme.numericStyle(
                    fontSize: 10.5,
                    color: inStock ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceButton({
    required ProductPrice price,
    required bool inStock,
  }) {
    final item = widget.item;
    final label = price.priceLabel.priceLabelDisplay;
    final isUsd = (price.currency ?? item.currency) == AppCurrency.secondaryCode;
    final color = isUsd
        ? (price.priceLabel == 'retail' ? const Color(0xFF059669) : const Color(0xFF0D9488))
        : price.priceLabel.priceLabelColor;

    return Material(
      color: inStock ? color.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: inStock ? () => widget.onPriceSelected(price) : null,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          height: 22.5,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: inStock ? color.withValues(alpha: 0.8) : Colors.grey.shade400,
              width: 0.8,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: inStock ? color : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 9.0,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  _formatPriceValue(price, item),
                  style: AppTheme.numericStyle(
                    fontSize: 9.5,
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
  }

  /// Helper to format price value and its currency symbol uniformly
  String _formatPriceValue(ProductPrice price, ProductWithDetails item) {
    final priceCurr = price.currency ?? item.currency;
    final isUsd = priceCurr == AppCurrency.secondaryCode;
    final priceStr = price.priceValue.toStringAsFixed(
      !isUsd && price.priceValue % 1 == 0 ? 0 : (isUsd ? 2 : 1),
    );
    final priceSymbol = AppCurrency.getSymbol(priceCurr);
    return '$priceStr $priceSymbol';
  }
}
