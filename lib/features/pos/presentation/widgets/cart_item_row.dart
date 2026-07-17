import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/features/pos/presentation/cubit/pos_state.dart';
import 'package:flutter/material.dart';

class CartItemRow extends StatelessWidget {

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = item.selectedPrice.priceLabel == 'retail'
        ? 'مفرق'
        : (item.selectedPrice.priceLabel == 'wholesale' ? 'جملة' : 'عرض');

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
                      item.productDetails.product.name,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'سعر الـ$label: ${item.selectedPrice.priceValue.toStringAsFixed(2)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                onPressed: onRemove,
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
                    onPressed: item.quantity > 1
                        ? () => onQuantityChanged(item.quantity - 1)
                        : null,
                  ),
                  Container(
                    alignment: Alignment.center,
                    width: 40,
                    child: Text(
                      item.quantity.toStringAsFixed(0),
                      style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary),
                    onPressed: () => onQuantityChanged(item.quantity + 1),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Item-level Discount Field
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
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
                      onDiscountChanged(discount);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Subtotal
              Text(
                item.subtotal.toStringAsFixed(2),
                style: AppTheme.numericStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
