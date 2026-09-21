import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_cubit.dart';

class EditDebtPaymentDialog extends StatefulWidget {
  const EditDebtPaymentDialog({
    super.key,
    required this.transaction,
    required this.cubit,
  });

  final UnifiedTransactionRecord transaction;
  final InvoicesCubit cubit;

  static Future<void> show(
    BuildContext context,
    UnifiedTransactionRecord transaction,
    InvoicesCubit cubit,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditDebtPaymentDialog(
        transaction: transaction,
        cubit: cubit,
      ),
    );
  }

  @override
  State<EditDebtPaymentDialog> createState() => _EditDebtPaymentDialogState();
}

class _EditDebtPaymentDialogState extends State<EditDebtPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final tr = widget.transaction;
    _amountController = TextEditingController(text: tr.totalAmount.toStringAsFixed(2));
    _selectedDate = tr.createdAt;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: context.locale,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      AppToast.warning(context, message: 'الرجاء إدخال مبلغ صحيح');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.cubit.updateDebtPayment(
        paymentId: widget.transaction.id,
        newAmount: amount,
        paidAt: _selectedDate,
      );

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, message: 'تم تحديث دفعة الدين بنجاح');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.error(context, message: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.transaction;
    final displayId = tr.globalSerialNumber != null
        ? '#${tr.globalSerialNumber}'
        : (tr.serialNumber != null ? '#${tr.serialNumber}' : '#${tr.id.substring(0, 8)}');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surfaceElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.payments, color: Color(0xFF7C3AED), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'تعديل بيانات دفعة الدين $displayId',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('العميل:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(tr.partyName ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      if (tr.notes != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('معلومات الدين:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text(tr.notes!, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Amount input
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'مبلغ الدفعة (${tr.currencySymbol})',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'الرجاء إدخال المبلغ';
                    final n = double.tryParse(val.trim());
                    if (n == null || n <= 0) return 'المبلغ يجب أن يكون أكبر من صفر';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date picker row
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Text(
                          'التاريخ: ${DateFormat('yyyy/MM/dd').format(_selectedDate)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: Text('common.cancel'.tr()),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('common.save'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
