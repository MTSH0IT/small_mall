import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/price_tag_chip.dart';
import 'package:small_mall/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';

class SuppliersList extends StatelessWidget {

  const SuppliersList({
    super.key,
    required this.suppliers,
    required this.selectedSupplierId,
    required this.searchQuery,
    required this.onSelectSupplier,
  });
  final List<SupplierWithPurchases> suppliers;
  final String? selectedSupplierId;
  final String searchQuery;
  final ValueChanged<Supplier> onSelectSupplier;

  @override
  Widget build(BuildContext context) {
    final filtered = suppliers.where((s) {
      return s.supplier.name.contains(searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: EmptyStateView(
            icon: Icons.local_shipping_outlined,
            title: 'suppliers.no_matching_suppliers'.tr(),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final item = filtered[index];
          final isSelected = selectedSupplierId == item.supplier.id;

          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.1),
              foregroundColor: isSelected ? Colors.white : AppColors.primary,
              child: const Icon(Icons.local_shipping_outlined, size: 20),
            ),
            title: Text(item.supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${item.supplier.phone ?? 'common.no_phone'.tr()} • ${item.invoicesCount} ${'suppliers.invoices_count'.tr()}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: PriceTagChip(
              label: 'suppliers.purchases_amount'.tr(
                namedArgs: {'amount': item.totalPurchasesAmount.toStringAsFixed(1)},
              ),
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
