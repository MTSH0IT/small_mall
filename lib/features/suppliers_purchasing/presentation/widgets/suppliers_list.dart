import 'package:flutter/material.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/widgets/price_tag_chip.dart';
import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:artisan_gift_manager/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';

class SuppliersList extends StatelessWidget {
  final List<SupplierWithPurchases> suppliers;
  final String? selectedSupplierId;
  final String searchQuery;
  final ValueChanged<Supplier> onSelectSupplier;

  const SuppliersList({
    super.key,
    required this.suppliers,
    required this.selectedSupplierId,
    required this.searchQuery,
    required this.onSelectSupplier,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = suppliers.where((s) {
      return s.supplier.name.contains(searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('لا يوجد موردين مطابقين للبحث.'));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final item = filtered[index];
          final isSelected = selectedSupplierId == item.supplier.id;

          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primary.withOpacity(0.05),
            title: Text(item.supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(item.supplier.phone ?? 'بدون هاتف'),
            trailing: PriceTagChip(
              label: 'مشتريات: ${item.totalPurchasesAmount.toStringAsFixed(1)} د.أ',
              backgroundColor: AppColors.primary,
              cutSize: 6,
            ),
            onTap: () => onSelectSupplier(item.supplier),
          );
        },
      ),
    );
  }
}
