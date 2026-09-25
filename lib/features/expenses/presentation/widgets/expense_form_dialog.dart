import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_searchable_dropdown.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/primary_button.dart';

class ExpenseFormDialog extends StatefulWidget {
  const ExpenseFormDialog({
    super.key,
    required this.categories,
    this.subcategories = const [],
    this.initialExpense,
    this.preselectedCategoryId,
    this.preselectedSubcategoryId,
    this.onQuickAddSubcategory,
    required this.onSave,
  });

  final List<ExpenseCategory> categories;
  final List<ExpenseCategory> subcategories;
  final Expense? initialExpense;
  final String? preselectedCategoryId;
  final String? preselectedSubcategoryId;
  final Future<ExpenseCategory?> Function(String parentId)? onQuickAddSubcategory;
  final Future<void> Function({
    required String categoryId,
    String? subcategoryId,
    required double amount,
    String? currency,
    String? notes,
    required DateTime createdAt,
  }) onSave;

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late String _selectedCurrency;
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  late List<ExpenseCategory> _localSubcategories;
  late DateTime _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.initialExpense;
    _amountController = TextEditingController(
      text: expense != null ? expense.amount.toString() : '',
    );
    _notesController = TextEditingController(
      text: expense?.notes ?? '',
    );
    _selectedCurrency = expense?.currency ?? AppCurrency.primaryCode;
    _selectedCategoryId = expense?.categoryId ??
        widget.preselectedCategoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    _selectedSubcategoryId = expense?.subcategoryId ?? widget.preselectedSubcategoryId;
    _localSubcategories = List<ExpenseCategory>.from(widget.subcategories);
    _selectedDate = expense?.createdAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<ExpenseCategory> get _availableSubcategories {
    if (_selectedCategoryId == null) return [];
    return _localSubcategories.where((s) => s.parentId == _selectedCategoryId).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: context.locale,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleQuickAddSubcategory() async {
    if (_selectedCategoryId == null) return;
    if (widget.onQuickAddSubcategory != null) {
      final newSub = await widget.onQuickAddSubcategory!(_selectedCategoryId!);
      if (newSub != null && mounted) {
        setState(() {
          _localSubcategories.add(newSub);
          _selectedSubcategoryId = newSub.id;
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('expenses.select_category_warning'.tr()),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('expenses.invalid_amount_warning'.tr()),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.onSave(
        categoryId: _selectedCategoryId!,
        subcategoryId: _selectedSubcategoryId,
        amount: amount,
        currency: _selectedCurrency,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: _selectedDate,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialExpense != null;
    final availableSubs = _availableSubcategories;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: AppColors.warning),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit
                          ? 'expenses.edit_expense'.tr()
                          : 'expenses.add_expense'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Main Category Selector
              AppSearchableDropdown<String>(
                label: 'expenses.category'.tr(),
                value: _selectedCategoryId,
                hint: 'expenses.category'.tr(),
                prefixIcon: const Icon(Icons.category_outlined, size: 18, color: AppColors.textSecondary),
                itemSearchText: (catId) {
                  final cat = widget.categories.where((c) => c.id == catId).firstOrNull;
                  return cat?.name ?? '';
                },
                items: widget.categories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat.id,
                    child: Text(cat.name),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategoryId = val;
                    // Reset subcategory if it does not belong to new category
                    if (_selectedSubcategoryId != null) {
                      final exists = _localSubcategories.any((s) => s.id == _selectedSubcategoryId && s.parentId == val);
                      if (!exists) {
                        _selectedSubcategoryId = null;
                      }
                    }
                  });
                },
                validator: (val) => val == null ? 'common.required_field'.tr() : null,
              ),
              const SizedBox(height: 16),

              // Subcategory Selector (Optional)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppSearchableDropdown<String?>(
                      label: 'expenses.optional_subcategory'.tr(),
                      value: _selectedSubcategoryId,
                      hint: 'expenses.no_subcategory'.tr(),
                      prefixIcon: const Icon(Icons.subdirectory_arrow_left_rounded, size: 18, color: AppColors.textSecondary),
                      itemSearchText: (subId) {
                        if (subId == null || subId.isEmpty) return 'expenses.no_subcategory'.tr();
                        final sub = availableSubs.where((s) => s.id == subId).firstOrNull;
                        return sub?.name ?? '';
                      },
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'expenses.no_subcategory'.tr(),
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        ...availableSubs.map((sub) {
                          return DropdownMenuItem<String?>(
                            value: sub.id,
                            child: Text(sub.name),
                          );
                        }),
                      ],
                      onChanged: (val) => setState(() => _selectedSubcategoryId = val),
                    ),
                  ),
                  if (widget.onQuickAddSubcategory != null && _selectedCategoryId != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      child: IconButton.filledTonal(
                        tooltip: 'expenses.add_subcategory'.tr(),
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: _handleQuickAddSubcategory,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Currency Selector
              Row(
                children: [
                  Text(
                    'common.currency_select'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
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

              // Amount Field
              AppTextField(
                label: '${'expenses.amount'.tr()} (${AppCurrency.getSymbol(_selectedCurrency)})',
                hint: '0.00',
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'common.required_field'.tr();
                  }
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0) {
                    return 'expenses.invalid_amount_warning'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date Picker Field
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'common.date'.tr(),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          Text(
                            DateFormat('yyyy/MM/dd').format(_selectedDate),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              AppTextField(
                label: 'common.notes'.tr(),
                hint: 'expenses.notes_hint'.tr(),
                controller: _notesController,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text('common.cancel'.tr()),
                  ),
                  const SizedBox(width: 12),
                  PrimaryButton(
                    label: isEdit ? 'common.save'.tr() : 'common.add'.tr(),
                    isLoading: _isLoading,
                    onPressed: _handleSubmit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
