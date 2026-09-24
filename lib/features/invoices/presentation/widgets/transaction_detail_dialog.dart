import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/invoices/presentation/widgets/invoice_detail_panel.dart';

class TransactionDetailDialog extends StatelessWidget {
  const TransactionDetailDialog({
    super.key,
    required this.transaction,
  });

  final UnifiedTransactionRecord transaction;

  static Future<void> show(BuildContext context, UnifiedTransactionRecord transaction) {
    return showDialog(
      context: context,
      builder: (ctx) => TransactionDetailDialog(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 680,
          maxHeight: 750,
        ),
        child: Container(
          color: AppColors.surfaceElevated,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'invoices.details'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'common.close'.tr(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: InvoiceDetailPanel(
                  transaction: transaction,
                  showActions: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
