import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/price_helper.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_state.dart';

class CartItemRow extends StatefulWidget {
  const CartItemRow({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onQuantityChanged,
    required this.onDiscountChanged,
  });

  final CartItem item;
  final VoidCallback onRemove;
  final ValueChanged<double> onQuantityChanged;
  final ValueChanged<double> onDiscountChanged;

  @override
  State<CartItemRow> createState() => _CartItemRowState();
}

class _CartItemRowState extends State<CartItemRow> {
  late TextEditingController _discountController;

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController(
      text: widget.item.discount > 0 ? widget.item.discount.toStringAsFixed(2) : '',
    );
  }

  @override
  void didUpdateWidget(covariant CartItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.discount != widget.item.discount) {
      final currentParsed = double.tryParse(_discountController.text) ?? 0.0;
      if (currentParsed != widget.item.discount) {
        _discountController.text =
            widget.item.discount > 0 ? widget.item.discount.toStringAsFixed(2) : '';
      }
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.item.selectedPrice.priceLabel.priceLabelDisplay;
    final color = widget.item.selectedPrice.priceLabel.priceLabelColor;
    final maxStock = widget.item.productDetails.currentStock;
    final canIncrement = widget.item.quantity + 1 <= maxStock;
    final canDecrement = widget.item.quantity > 1;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Product Name, Price tier tag, and Delete Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.item.productDetails.product.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '× ${widget.item.selectedPrice.priceValue.toStringAsFixed(2)}',
                style: AppTheme.numericStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.close_rounded, color: AppColors.danger, size: 18),
                tooltip: 'common.delete'.tr(),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Bottom Row: Stepper, Discount input, and Subtotal
          Row(
            children: [
              // Quantity Stepper
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: canDecrement
                          ? () => widget.onQuantityChanged(widget.item.quantity - 1)
                          : null,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        child: Icon(
                          Icons.remove_rounded,
                          size: 16,
                          color: canDecrement ? AppColors.textPrimary : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 32),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        widget.item.quantity.toStringAsFixed(widget.item.quantity % 1 == 0 ? 0 : 1),
                        style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                    InkWell(
                      onTap: canIncrement
                          ? () => widget.onQuantityChanged(widget.item.quantity + 1)
                          : null,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        child: Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: canIncrement ? AppColors.primary : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Item-level Discount Field
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTheme.numericStyle(fontSize: 12),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.local_offer_outlined,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 28),
                      hintText: 'pos.item_discount'.tr(),
                      hintStyle: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onChanged: (val) {
                      final discount = double.tryParse(val) ?? 0.0;
                      widget.onDiscountChanged(discount);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Subtotal
              Text(
                widget.item.subtotal.toStringAsFixed(2),
                style: AppTheme.numericStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
