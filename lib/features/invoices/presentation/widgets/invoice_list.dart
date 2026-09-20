import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';

class InvoiceList extends StatelessWidget {
  const InvoiceList({
    super.key,
    required this.transactions,
    required this.selectedTransactionId,
    required this.onSelectTransaction,
  });

  final List<UnifiedTransactionRecord> transactions;
  final String? selectedTransactionId;
  final ValueChanged<String> onSelectTransaction;

  Color _getTypeColor(UnifiedTransactionType type) {
    switch (type) {
      case UnifiedTransactionType.sale:
        return AppColors.success;
      case UnifiedTransactionType.returnSale:
        return AppColors.danger;
      case UnifiedTransactionType.purchase:
        return const Color(0xFF2563EB);
      case UnifiedTransactionType.expense:
        return const Color(0xFFEA580C);
      case UnifiedTransactionType.debtPayment:
        return const Color(0xFF7C3AED);
      case UnifiedTransactionType.debtInvoice:
        return AppColors.warning;
      case UnifiedTransactionType.adjustment:
        return const Color(0xFF0D9488);
    }
  }

  IconData _getTypeIcon(UnifiedTransactionType type) {
    switch (type) {
      case UnifiedTransactionType.sale:
        return Icons.point_of_sale;
      case UnifiedTransactionType.returnSale:
        return Icons.replay;
      case UnifiedTransactionType.purchase:
        return Icons.local_shipping;
      case UnifiedTransactionType.expense:
        return Icons.account_balance_wallet;
      case UnifiedTransactionType.debtPayment:
        return Icons.payments;
      case UnifiedTransactionType.debtInvoice:
        return Icons.request_quote;
      case UnifiedTransactionType.adjustment:
        return Icons.tune;
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelSmall = Theme.of(context).textTheme.labelSmall;

    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: EmptyStateView(
            icon: Icons.receipt_long_outlined,
            title: 'invoices.empty_invoices'.tr(),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: transactions.length,
      separatorBuilder: (_, _) => const Divider(color: AppColors.border),
      itemBuilder: (context, index) {
        final item = transactions[index];
        final isSelected = item.id == selectedTransactionId;
        final typeColor = _getTypeColor(item.type);
        final typeIcon = _getTypeIcon(item.type);
        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt);
        final globalText = item.globalSerialNumber != null
            ? '#${item.globalSerialNumber}'
            : (item.serialNumber != null ? '#${item.serialNumber}' : '#${item.id.substring(0, 8)}');
        final typeSerialText = item.serialNumber != null
            ? '${item.typeLabel} #${item.serialNumber}'
            : item.typeLabel;

        // Party label fallback
        String partyLabel = item.partyName ?? '';
        if (partyLabel.isEmpty) {
          if (item.isSale || item.isReturn || item.isDebtInvoice) {
            partyLabel = 'pos.walk_in_customer'.tr();
          } else if (item.isPurchase) {
            partyLabel = 'invoices.supplier'.tr();
          } else if (item.isExpense) {
            partyLabel = 'invoices.expense_category'.tr();
          } else if (item.isAdjustment) {
            partyLabel = 'invoices.adjustment'.tr();
          }
        }

        return Card(
          elevation: isSelected ? 2 : 0,
          color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onSelectTransaction(item.id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      typeIcon,
                      color: typeColor,
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
                            Row(
                              children: [
                                // Global Serial Number Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                                  ),
                                  child: Text(
                                    globalText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Department / Type Serial Number Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    typeSerialText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: typeColor,
                                    ),
                                  ),
                                ),
                                if (item.paymentType == 'debt') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'pos.debt'.tr(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              item.isReturn
                                  ? '-${item.totalAmount.toStringAsFixed(2)}'
                                  : item.totalAmount.toStringAsFixed(2),
                              style: AppTheme.numericStyle(
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                partyLabel,
                                style: labelSmall?.copyWith(fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
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
