import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/price_tag_chip.dart';
import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';

class CustomersList extends StatelessWidget {
  const CustomersList({
    super.key,
    required this.customers,
    required this.selectedCustomerId,
    required this.searchQuery,
    required this.onSelectCustomer,
  });

  final List<CustomerWithDebts> customers;
  final String? selectedCustomerId;
  final String searchQuery;
  final ValueChanged<String> onSelectCustomer;

  @override
  Widget build(BuildContext context) {
    final q = searchQuery.trim().toLowerCase();
    final filtered = customers.where((c) {
      if (q.isEmpty) return true;
      final matchName = c.customer.name.toLowerCase().contains(q);
      final matchPhone = c.customer.phone?.toLowerCase().contains(q) ?? false;
      final matchNotes = c.customer.notes?.toLowerCase().contains(q) ?? false;
      return matchName || matchPhone || matchNotes;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: EmptyStateView(
            icon: Icons.people_outline,
            title: 'customers.empty_customers'.tr(),
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
          final isSelected = selectedCustomerId == item.customer.id;
          final hasNotes = item.customer.notes != null && item.customer.notes!.trim().isNotEmpty;
          final hasPhone = item.customer.phone != null && item.customer.phone!.trim().isNotEmpty;

          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primary.withValues(alpha: 0.05),
            title: Text(item.customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPhone)
                  Text(
                    item.customer.phone!.trim(),
                    style: AppTheme.numericStyle(fontSize: 12, color: AppColors.textSecondary),
                  )
                else if (!hasNotes)
                  Text('-', style: AppTheme.numericStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (hasNotes) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.sticky_note_2_outlined, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.customer.notes!.trim(),
                          style: const TextStyle(
                            fontSize: 11.5,
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
            ),
            trailing: PriceTagChip(
              label: '${'customers.balance'.tr()}: ${item.totalDebt.toStringAsFixed(1)}',
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
