import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_cubit.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';

class DeleteInvoiceDialog extends StatefulWidget {
  const DeleteInvoiceDialog({
    super.key,
    required this.invoiceData,
    required this.cubit,
  });

  final InvoiceWithDetails invoiceData;
  final InvoicesCubit cubit;

  static Future<void> show(BuildContext context, InvoiceWithDetails invoiceData, InvoicesCubit cubit) {
    return showDialog(
      context: context,
      builder: (context) => DeleteInvoiceDialog(
        invoiceData: invoiceData,
        cubit: cubit,
      ),
    );
  }

  @override
  State<DeleteInvoiceDialog> createState() => _DeleteInvoiceDialogState();
}

class _DeleteInvoiceDialogState extends State<DeleteInvoiceDialog> {
  bool _isLoading = false;
  bool _canDelete = true;
  String? _blockedReason;

  @override
  void initState() {
    super.initState();
    _checkCanDelete();
  }

  Future<void> _checkCanDelete() async {
    try {
      final res = await widget.cubit.checkCanDelete(widget.invoiceData.invoice.id);
      if (mounted) {
        setState(() {
          _canDelete = res['canDelete'] == true;
          if (!_canDelete) {
            _blockedReason = 'invoices.delete_invoice_debt_has_payments_warning'.tr();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _handleDelete() async {
    setState(() => _isLoading = true);
    try {
      await widget.cubit.deleteInvoice(widget.invoiceData.invoice.id);
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, message: 'invoices.invoice_deleted_success'.tr());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.error(context, message: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoiceData.invoice;
    final displayId = inv.serialNumber != null ? '${inv.serialNumber}' : inv.id.substring(0, 8);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surfaceElevated,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'invoices.delete_invoice_confirm_title'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Warning or Confirmation Message
            if (!_canDelete && _blockedReason != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _blockedReason!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Text(
                'invoices.delete_invoice_confirm_msg'.tr(namedArgs: {'id': displayId}),
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
            ],

            // Details card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildDetailRow('invoices.invoice_id'.tr(), '#$displayId'),
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    'invoices.customer'.tr(),
                    widget.invoiceData.customerName ?? 'pos.walk_in_customer'.tr(),
                  ),
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    'common.total'.tr(),
                    inv.totalAmount.toStringAsFixed(2),
                    isAmount: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text('common.cancel'.tr()),
                ),
                if (_canDelete) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleDelete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('invoices.delete_invoice'.tr()),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAmount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isAmount ? FontWeight.bold : FontWeight.w500,
            color: isAmount ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
