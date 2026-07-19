import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/price_tag_chip.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:flutter/material.dart';

class InventoryTable extends StatelessWidget {

  const InventoryTable({
    super.key,
    required this.products,
    required this.searchQuery,
    required this.filterLowStockOnly,
    required this.onAdjustStock,
  });
  final List<ProductWithDetails> products;
  final String searchQuery;
  final bool filterLowStockOnly;
  final ValueChanged<ProductWithDetails> onAdjustStock;

  @override
  Widget build(BuildContext context) {
    final filtered = products.where((p) {
      final matchQuery = p.product.name.contains(searchQuery);
      final matchFilter = !filterLowStockOnly || p.isLowStock;
      return matchQuery && matchFilter;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('لا توجد منتجات مطابقة لخيارات الفلترة'));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('اسم المنتج')),
            DataColumn(label: Text('الفئة')),
            DataColumn(label: Text('تنبيه الحد الأدنى')),
            DataColumn(label: Text('المخزون الحالي')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('تعديل المخزون')),
          ],
          rows: filtered.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(item.category?.name ?? 'بدون فئة')),
                DataCell(Text(item.product.minStockAlert.toStringAsFixed(0), style: AppTheme.numericStyle())),
                DataCell(Text(item.currentStock.toStringAsFixed(0), style: AppTheme.numericStyle(fontWeight: FontWeight.bold))),
                DataCell(
                  PriceTagChip(
                    label: item.isLowStock ? 'مخزون منخفض' : 'متوفر',
                    backgroundColor: item.isLowStock ? AppColors.danger : AppColors.success,
                    cutSize: 6,
                  ),
                ),
                DataCell(
                  OutlinedButton.icon(
                    onPressed: () => onAdjustStock(item),
                    icon: const Icon(Icons.swap_vert, size: 16, color: AppColors.primary),
                    label: const Text('تعديل', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
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
