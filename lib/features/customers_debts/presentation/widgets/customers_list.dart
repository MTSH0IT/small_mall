import 'package:flutter/material.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/widgets/price_tag_chip.dart';
import 'package:artisan_gift_manager/features/customers_debts/data/customers_debts_repository.dart';

class CustomersList extends StatelessWidget {
  final List<CustomerWithDebts> customers;
  final String? selectedCustomerId;
  final String searchQuery;
  final ValueChanged<String> onSelectCustomer;

  const CustomersList({
    super.key,
    required this.customers,
    required this.selectedCustomerId,
    required this.searchQuery,
    required this.onSelectCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = customers.where((c) {
      final matchName = c.customer.name.contains(searchQuery);
      final matchPhone = c.customer.phone?.contains(searchQuery) ?? false;
      return matchName || matchPhone;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('لا يوجد عملاء مطابقين للبحث.'));
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
          final isSelected = selectedCustomerId == item.customer.id;

          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primary.withOpacity(0.05),
            title: Text(item.customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(item.customer.phone ?? 'بدون هاتف'),
            trailing: PriceTagChip(
              label: 'الدين: ${item.totalDebt.toStringAsFixed(1)} د.أ',
              backgroundColor: item.totalDebt > 0 ? AppColors.accent : AppColors.success,
              cutSize: 6,
            ),
            onTap: () => onSelectCustomer(item.customer.id),
          );
        },
      ),
    );
  }
}
