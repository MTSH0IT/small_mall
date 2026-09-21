import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_cubit.dart';

class EditAdjustmentDialog extends StatefulWidget {
  const EditAdjustmentDialog({
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
      builder: (context) => EditAdjustmentDialog(
        transaction: transaction,
        cubit: cubit,
      ),
    );
  }

  @override
  State<EditAdjustmentDialog> createState() => _EditAdjustmentDialogState();
}

class _EditAdjustmentDialogState extends State<EditAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late final TextEditingController _reasonController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final tr = widget.transaction;
    final initialQty = tr.rawStockMovement?.quantity ?? (tr.items.isNotEmpty ? tr.items.first.quantity : 0.0);
    _quantityController = TextEditingController(text: initialQty.toStringAsFixed(initialQty % 1 == 0 ? 0 : 2));
    _reasonController = TextEditingController(text: tr.notes ?? '');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = double.tryParse(_quantityController.text.trim());
    if (qty == null || qty == 0) {
      AppToast.warning(context, message: 'الرجاء إدخال كمية تسوية صحيحة وغير صفرية');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.cubit.updateAdjustment(
        movementId: widget.transaction.id,
        quantity: qty,
        reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, message: 'تم تحديث تسوية الجرد بنجاح');
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
                        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.tune, color: Color(0xFF0D9488), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'تعديل تسوية الجرد $displayId',
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
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFF0D9488)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr.partyName ?? 'المنتج',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quantity input
                TextFormField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(
                    labelText: 'كمية التسوية (+ للزيادة، - للعجز)',
                    prefixIcon: Icon(Icons.numbers),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'الرجاء إدخال الكمية';
                    final n = double.tryParse(val.trim());
                    if (n == null || n == 0) return 'الكمية لا يمكن أن تكون صفراً';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Reason input
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'سبب التسوية / ملاحظات',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
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
                        backgroundColor: const Color(0xFF0D9488),
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
