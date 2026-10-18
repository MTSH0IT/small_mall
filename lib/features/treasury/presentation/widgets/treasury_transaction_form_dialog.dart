import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_searchable_dropdown.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/treasury/presentation/widgets/treasury_category_form_dialog.dart';

class TreasuryTransactionFormDialog extends StatefulWidget {
  const TreasuryTransactionFormDialog({
    super.key,
    required this.categories,
    this.subcategories = const [],
    this.initialTransaction,
    this.defaultType = 'in',
    this.preselectedCategoryId,
    this.preselectedSubcategoryId,
    this.onQuickAddCategory,
    this.onQuickAddSubcategory,
    required this.onSave,
  });

  final List<TreasuryCategory> categories;
  final List<TreasuryCategory> subcategories;
  final TreasuryTransaction? initialTransaction;
  final String defaultType;
  final String? preselectedCategoryId;
  final String? preselectedSubcategoryId;
  final Future<TreasuryCategory?> Function(String type)? onQuickAddCategory;
  final Future<TreasuryCategory?> Function(String parentId, String type)?
      onQuickAddSubcategory;
  final Future<void> Function({
    required String type,
    required double amount,
    required String categoryName,
    String? categoryId,
    String? subcategoryId,
    String? subcategoryName,
    String? personName,
    String? notes,
    String? currency,
    required DateTime createdAt,
  }) onSave;

  @override
  State<TreasuryTransactionFormDialog> createState() =>
      _TreasuryTransactionFormDialogState();
}

class _TreasuryTransactionFormDialogState
    extends State<TreasuryTransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedType; // 'in' or 'out'
  late final TextEditingController _amountController;
  late final TextEditingController _personNameController;
  late final TextEditingController _notesController;
  late String _selectedCurrency;
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  late List<TreasuryCategory> _localCategories;
  late List<TreasuryCategory> _localSubcategories;
  late DateTime _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;

    if (tx != null) {
      _selectedType = tx.type;
      _selectedCategoryId = tx.categoryId;
      _selectedSubcategoryId = tx.subcategoryId;
    } else {
      _selectedType = widget.defaultType;
      _selectedCategoryId = widget.preselectedCategoryId;
      _selectedSubcategoryId = widget.preselectedSubcategoryId;
    }

    _amountController = TextEditingController(
      text: tx != null ? tx.amount.toString() : '',
    );
    _personNameController = TextEditingController(
      text: tx?.personName ?? '',
    );
    _notesController = TextEditingController(
      text: tx?.notes ?? '',
    );
    _selectedCurrency = tx?.currency ?? AppCurrency.primaryCode;
    _localCategories = List<TreasuryCategory>.from(widget.categories);
    _localSubcategories = List<TreasuryCategory>.from(widget.subcategories);
    _selectedDate = tx?.createdAt ?? DateTime.now();

    _ensureValidCategorySelection();
  }

  void _ensureValidCategorySelection() {
    final available = _availableCategories;
    if (_selectedCategoryId != null &&
        available.any((c) => c.id == _selectedCategoryId)) {
      final availableSubs = _availableSubcategories;
      if (_selectedSubcategoryId != null &&
          !availableSubs.any((s) => s.id == _selectedSubcategoryId)) {
        _selectedSubcategoryId = null;
      }
      return;
    }
    if (available.isNotEmpty) {
      _selectedCategoryId = available.first.id;
      final availableSubs = _availableSubcategories;
      if (_selectedSubcategoryId != null &&
          !availableSubs.any((s) => s.id == _selectedSubcategoryId)) {
        _selectedSubcategoryId = null;
      }
    } else {
      _selectedCategoryId = null;
      _selectedSubcategoryId = null;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _personNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<TreasuryCategory> get _availableCategories => _localCategories;

  List<TreasuryCategory> get _availableSubcategories {
    if (_selectedCategoryId == null) return [];
    return _localSubcategories
        .where((s) => s.parentId == _selectedCategoryId)
        .toList();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: context.locale,
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      } else {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            _selectedDate.hour,
            _selectedDate.minute,
          );
        });
      }
    }
  }

  Future<void> _handleQuickAddCategory() async {
    if (widget.onQuickAddCategory != null) {
      final newCat = await widget.onQuickAddCategory!('both');
      if (newCat != null && mounted) {
        setState(() {
          _localCategories.add(newCat);
          _selectedCategoryId = newCat.id;
          _selectedSubcategoryId = null;
        });
      }
    } else {
      String? createdName;
      String? createdDesc;
      await showDialog(
        context: context,
        builder: (_) => TreasuryCategoryFormDialog(
          defaultType: 'both',
          onSave: ({required name, required type, description, parentId}) async {
            createdName = name;
            createdDesc = description;
          },
        ),
      );

      if (createdName != null && mounted) {
        final dummy = TreasuryCategory(
          id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
          name: createdName!,
          type: 'both',
          description: createdDesc,
          createdAt: DateTime.now(),
        );
        setState(() {
          _localCategories.add(dummy);
          _selectedCategoryId = dummy.id;
          _selectedSubcategoryId = null;
        });
      }
    }
  }

  Future<void> _handleQuickAddSubcategory() async {
    if (_selectedCategoryId == null) return;
    final parent = _localCategories.where((c) => c.id == _selectedCategoryId).firstOrNull;

    if (widget.onQuickAddSubcategory != null) {
      final newSub = await widget.onQuickAddSubcategory!(
        _selectedCategoryId!,
        'both',
      );
      if (newSub != null && mounted) {
        setState(() {
          _localSubcategories.add(newSub);
          _selectedSubcategoryId = newSub.id;
        });
      }
    } else {
      String? createdName;
      String? createdDesc;
      await showDialog(
        context: context,
        builder: (_) => TreasuryCategoryFormDialog(
          parentId: _selectedCategoryId,
          parentName: parent?.name,
          defaultType: 'both',
          onSave: ({required name, required type, description, parentId}) async {
            createdName = name;
            createdDesc = description;
          },
        ),
      );

      if (createdName != null && mounted) {
        final dummy = TreasuryCategory(
          id: 'temp-sub-${DateTime.now().millisecondsSinceEpoch}',
          name: createdName!,
          type: 'both',
          description: createdDesc,
          parentId: _selectedCategoryId,
          createdAt: DateTime.now(),
        );
        setState(() {
          _localSubcategories.add(dummy);
          _selectedSubcategoryId = dummy.id;
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final selectedCat = _localCategories
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;
    final categoryName = selectedCat?.name ?? '';

    if (categoryName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('treasury.select_category_warning'.tr()),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('treasury.invalid_amount'.tr()),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final selectedSub = _localSubcategories
        .where((s) => s.id == _selectedSubcategoryId)
        .firstOrNull;

    setState(() => _isLoading = true);
    try {
      await widget.onSave(
        type: _selectedType,
        amount: amount,
        categoryName: categoryName,
        categoryId: _selectedCategoryId,
        subcategoryId: _selectedSubcategoryId,
        subcategoryName: selectedSub?.name,
        personName: _personNameController.text.trim().isEmpty
            ? null
            : _personNameController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        currency: _selectedCurrency,
        createdAt: _selectedDate,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialTransaction != null;
    final isCashIn = _selectedType == 'in';
    final accentColor = isCashIn ? AppColors.success : const Color(0xFFDC2626);
    final availableCats = _availableCategories;
    final availableSubs = _availableSubcategories;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Icon + Title)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isCashIn ? Icons.arrow_downward : Icons.arrow_upward,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEdit
                            ? 'treasury.edit_movement'.tr()
                            : (isCashIn
                                ? 'treasury.deposit_to_box'.tr()
                                : 'treasury.withdraw_from_box'.tr()),
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

                // Movement Type Selector (Cash In vs Cash Out)
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'in',
                      label: Text('treasury.cash_in'.tr()),
                      icon: const Icon(Icons.arrow_downward, size: 16),
                    ),
                    ButtonSegment(
                      value: 'out',
                      label: Text('treasury.cash_out'.tr()),
                      icon: const Icon(Icons.arrow_upward, size: 16),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (set) {
                    setState(() {
                      _selectedType = set.first;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Main Category Selector + Quick Add
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: AppSearchableDropdown<String>(
                        label: 'treasury.category'.tr(),
                        value: _selectedCategoryId,
                        hint: 'treasury.select_category'.tr(),
                        prefixIcon: const Icon(
                          Icons.category_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        itemSearchText: (catId) {
                          final cat = availableCats
                              .where((c) => c.id == catId)
                              .firstOrNull;
                          return cat?.name ?? '';
                        },
                        items: availableCats.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat.id,
                            child: Text(cat.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategoryId = val;
                            // Reset subcategory if it doesn't belong to this category
                            if (_selectedSubcategoryId != null) {
                              final exists = _localSubcategories.any(
                                (s) =>
                                    s.id == _selectedSubcategoryId &&
                                    s.parentId == val,
                              );
                              if (!exists) {
                                _selectedSubcategoryId = null;
                              }
                            }
                          });
                        },
                        validator: (val) => val == null
                            ? 'treasury.select_category_warning'.tr()
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      child: IconButton.filledTonal(
                        tooltip: 'treasury.add_category'.tr(),
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: _handleQuickAddCategory,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Subcategory Selector + Quick Add
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: AppSearchableDropdown<String?>(
                        label: 'expenses.optional_subcategory'.tr(),
                        value: _selectedSubcategoryId,
                        hint: 'expenses.no_subcategory'.tr(),
                        prefixIcon: const Icon(
                          Icons.subdirectory_arrow_left_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        itemSearchText: (subId) {
                          if (subId == null || subId.isEmpty) {
                            return 'expenses.no_subcategory'.tr();
                          }
                          final sub = availableSubs
                              .where((s) => s.id == subId)
                              .firstOrNull;
                          return sub?.name ?? '';
                        },
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'expenses.no_subcategory'.tr(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          ...availableSubs.map((sub) {
                            return DropdownMenuItem<String?>(
                              value: sub.id,
                              child: Text(sub.name),
                            );
                          }),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedSubcategoryId = val),
                      ),
                    ),
                    if (_selectedCategoryId != null) ...[
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
                      '${'pos.currency'.tr()}: ',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(AppCurrency.primaryCode),
                      selected: _selectedCurrency == AppCurrency.primaryCode,
                      selectedColor: accentColor.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _selectedCurrency == AppCurrency.primaryCode
                            ? accentColor
                            : AppColors.textPrimary,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(
                            () => _selectedCurrency = AppCurrency.primaryCode,
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('USD (\$)'),
                      selected: _selectedCurrency == 'USD',
                      selectedColor: const Color(0xFF059669).withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _selectedCurrency == 'USD'
                            ? const Color(0xFF059669)
                            : AppColors.textPrimary,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCurrency = 'USD');
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount
                AppTextField(
                  controller: _amountController,
                  label: 'treasury.amount'.tr(),
                  hint: '0.00',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Text(
                      AppCurrency.getSymbol(_selectedCurrency),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'treasury.invalid_amount'.tr();
                    }
                    final n = double.tryParse(val.trim());
                    if (n == null || n <= 0) {
                      return 'treasury.invalid_amount'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Person Name (المستفيد / المستلم / المودع / السلفة)
                AppTextField(
                  controller: _personNameController,
                  label: 'treasury.person_name'.tr(),
                  hint: 'treasury.person_name_hint'.tr(),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                const SizedBox(height: 16),

                // Notes
                AppTextField(
                  controller: _notesController,
                  label: 'treasury.notes'.tr(),
                  hint: 'treasury.notes_hint'.tr(),
                  prefixIcon: const Icon(Icons.notes_outlined),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Date & Time Picker
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${'treasury.date'.tr()}: ${DateFormat('yyyy/MM/dd HH:mm').format(_selectedDate)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                      child: Text('common.cancel'.tr()),
                    ),
                    const SizedBox(width: 12),
                    PrimaryButton(
                      label: isEdit ? 'common.save'.tr() : 'common.add'.tr(),
                      backgroundColor: accentColor,
                      isLoading: _isLoading,
                      onPressed: _handleSubmit,
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
