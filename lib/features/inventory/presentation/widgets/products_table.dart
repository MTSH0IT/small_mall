import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/price_helper.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/price_tag_chip.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';

class ProductsTable extends StatelessWidget {
  const ProductsTable({
    super.key,
    required this.products,
    required this.searchQuery,
    required this.onEditProduct,
    required this.onDeleteProduct,
  });

  final List<ProductWithDetails> products;
  final String searchQuery;
  final ValueChanged<ProductWithDetails> onEditProduct;
  final ValueChanged<ProductWithDetails> onDeleteProduct;

  @override
  Widget build(BuildContext context) {
    final filtered = products.where((p) {
      return p.product.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: EmptyStateView(
          icon: Icons.inventory_2_outlined,
          title: 'inventory.products_title'.tr(),
          description: 'inventory.empty_products'.tr(),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            DataColumn(label: Text('inventory.product_name'.tr())),
            DataColumn(label: Text('inventory.category'.tr())),
            DataColumn(label: Text('inventory.cost_price'.tr())),
            DataColumn(label: Text('inventory.selling_prices'.tr())),
            DataColumn(label: Text('inventory.current_stock'.tr())),
            DataColumn(label: Text('common.actions'.tr())),
          ],
          rows: filtered.map((item) {
            final retail = item.prices.firstWhere((p) => p.priceLabel == 'retail',
                orElse: () => ProductPrice(id: '', productId: '', priceLabel: 'retail', priceValue: 0.0));
            final wholesale = item.prices.firstWhere((p) => p.priceLabel == 'wholesale',
                orElse: () => ProductPrice(id: '', productId: '', priceLabel: 'wholesale', priceValue: 0.0));

            return DataRow(
              cells: [
                DataCell(Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(item.category?.name ?? '-')),
                DataCell(Text(item.product.costPrice.toStringAsFixed(2), style: AppTheme.numericStyle())),
                DataCell(
                  Wrap(
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
                  ),
                ),
                DataCell(
                  Text(
                    item.currentStock.toStringAsFixed(0),
                    style: AppTheme.numericStyle(
                      color: item.isLowStock ? AppColors.danger : AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                        onPressed: () => onEditProduct(item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () => onDeleteProduct(item),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
