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
        _discountController.text = widget.item.discount > 0 ? widget.item.discount.toStringAsFixed(2) : '';
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.productDetails.product.name,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'سعر $label: ${widget.item.selectedPrice.priceValue.toStringAsFixed(2)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quantity and Discount Inputs
          Row(
            children: [
              // Quantity Adjustment
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.primary),
                    onPressed: widget.item.quantity > 1
                        ? () => widget.onQuantityChanged(widget.item.quantity - 1)
                        : null,
                  ),
                  Container(
                    alignment: Alignment.center,
                    width: 40,
                    child: Text(
                      widget.item.quantity.toStringAsFixed(widget.item.quantity % 1 == 0 ? 0 : 1),
                      style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary),
                    onPressed: widget.item.quantity + 1 <= widget.item.productDetails.currentStock
                        ? () => widget.onQuantityChanged(widget.item.quantity + 1)
                        : null,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Item-level Discount Field
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTheme.numericStyle(fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.local_offer_outlined, size: 14, color: AppColors.textSecondary),
                      hintText: 'خصم (مبلغ)',
                      hintStyle: theme.textTheme.labelSmall,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onChanged: (val) {
                      final discount = double.tryParse(val) ?? 0.0;
                      widget.onDiscountChanged(discount);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Subtotal
              Text(
                widget.item.subtotal.toStringAsFixed(2),
                style: AppTheme.numericStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
