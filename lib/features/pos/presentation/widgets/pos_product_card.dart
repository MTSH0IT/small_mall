import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/widgets/price_tag_chip.dart';
import 'package:artisan_gift_manager/features/inventory/data/inventory_repository.dart';
import 'package:flutter/material.dart';

class POSProductCard extends StatelessWidget {

  const POSProductCard({
    super.key,
    required this.item,
    required this.onPriceSelected,
  });
  final ProductWithDetails item;
  final Function(ProductPrice) onPriceSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inStock = item.currentStock > 0;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: item.isLowStock ? AppColors.danger.withValues(alpha: 0.4) : AppColors.border,
          width: item.isLowStock ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name
            Text(
              item.product.name,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Category & Stock Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.category?.name ?? 'بدون فئة',
                  style: theme.textTheme.labelSmall,
                ),
                PriceTagChip(
                  label: inStock ? 'متوفر: ${item.currentStock.toStringAsFixed(0)}' : 'نفذ',
                  backgroundColor: inStock
                      ? (item.isLowStock ? AppColors.danger : AppColors.success)
                      : Colors.grey,
                  cutSize: 6,
                ),
              ],
            ),
            const Spacer(),
            const Divider(color: AppColors.border, height: 16),
            // Available Prices List (Cashier clicks to add)
            Text(
              'اختر السعر للإضافة:',
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.prices.map((price) {
                final label = price.priceLabel == 'retail'
                    ? 'مفرق'
                    : (price.priceLabel == 'wholesale' ? 'جملة' : 'عرض');
                final color = price.priceLabel == 'retail'
                    ? AppColors.primary
                    : (price.priceLabel == 'wholesale' ? AppColors.accent : AppColors.success);

                return InkWell(
                  onTap: inStock ? () => onPriceSelected(price) : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: inStock ? color.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: inStock ? color : Colors.grey, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
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
    );
  }
}
