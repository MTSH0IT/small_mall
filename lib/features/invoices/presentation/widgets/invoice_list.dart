import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';

class InvoiceList extends StatelessWidget {
  const InvoiceList({
    super.key,
    required this.invoices,
    required this.selectedInvoiceId,
    required this.onSelectInvoice,
  });
  final List<InvoiceWithDetails> invoices;
  final String? selectedInvoiceId;
  final ValueChanged<String> onSelectInvoice;

  @override
  Widget build(BuildContext context) {
    final labelSmall = Theme.of(context).textTheme.labelSmall;

    if (invoices.isEmpty) {
      return Center(child: Text('invoices.empty_invoices'.tr()));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: invoices.length,
      separatorBuilder: (_, _) => const Divider(color: AppColors.border),
      itemBuilder: (context, index) {
        final inv = invoices[index];
        final isSelected = inv.invoice.id == selectedInvoiceId;
        final isReturn = inv.invoice.type == 'return';
        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(inv.invoice.createdAt);

        return Card(
          elevation: isSelected ? 2 : 0,
          color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onSelectInvoice(inv.invoice.id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isReturn
                          ? AppColors.danger.withValues(alpha: 0.1)
                          : AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isReturn ? Icons.replay : Icons.receipt_long,
                      color: isReturn ? AppColors.danger : AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${'invoices.invoice_id'.tr()} #${inv.invoice.id.substring(0, 8)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              inv.invoice.totalAmount.toStringAsFixed(2),
                              style: AppTheme.numericStyle(
                                fontWeight: FontWeight.bold,
                                color: isReturn ? AppColors.danger : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              inv.customerName ?? 'pos.walk_in_customer'.tr(),
                              style: labelSmall,
                            ),
                            Text(dateStr, style: labelSmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
