import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_searchable_dropdown.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_cubit.dart';

class EditExpenseDialog extends StatefulWidget {
  const EditExpenseDialog({
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
      builder: (context) => EditExpenseDialog(
        transaction: transaction,
        cubit: cubit,
      ),
    );
  }

  @override
  State<EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends State<EditExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late String _selectedCurrency;
  late DateTime _selectedDate;
  String? _selectedCategoryId;
  List<ExpenseCategory> _categories = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final tr = widget.transaction;
    _amountController = TextEditingController(text: tr.totalAmount.toStringAsFixed(2));
    _notesController = TextEditingController(text: tr.notes ?? '');
    _selectedCurrency = tr.currency;
    _selectedDate = tr.createdAt;
    _selectedCategoryId = tr.rawExpense?.categoryId;

    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.cubit.getExpenseCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
    if (_selectedCategoryId == null) {
      AppToast.warning(context, message: 'الرجاء اختيار تصنيف المصروف');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      AppToast.warning(context, message: 'الرجاء إدخال مبلغ صحيح');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.cubit.updateExpense(
        expenseId: widget.transaction.id,
        categoryId: _selectedCategoryId!,
        amount: amount,
        currency: _selectedCurrency,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: _selectedDate,
      );

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, message: 'تم تحديث المصروف بنجاح');
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
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
                              color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.account_balance_wallet, color: Color(0xFFEA580C), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'تعديل بيانات المصروف $displayId',
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

                      // Category selection
                      AppSearchableDropdown<String>(
                        items: _categories
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            .toList(),
                        label: 'تصنيف المصروف',
                        hint: 'اختر التصنيف',
                        prefixIcon: const Icon(Icons.category_outlined, size: 18, color: AppColors.textSecondary),
                        value: _selectedCategoryId,
                        onChanged: (id) => setState(() => _selectedCategoryId = id),
                      ),
                      const SizedBox(height: 16),

                      // Currency toggle
                      Row(
                        children: [
                          const Text('العملة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 12),
                          ChoiceChip(
                            label: Text(AppCurrency.primary.nameAr),
                            selected: _selectedCurrency == AppCurrency.sypCode,
                            onSelected: (val) {
                              if (val) setState(() => _selectedCurrency = AppCurrency.sypCode);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(AppCurrency.secondary.nameAr),
                            selected: _selectedCurrency == AppCurrency.usdCode,
                            onSelected: (val) {
                              if (val) setState(() => _selectedCurrency = AppCurrency.usdCode);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Amount input
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'المبلغ (${AppCurrency.getSymbol(_selectedCurrency)})',
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
                      const SizedBox(height: 16),

                      // Notes input
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات / بيان المصروف',
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
                              backgroundColor: const Color(0xFFEA580C),
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
