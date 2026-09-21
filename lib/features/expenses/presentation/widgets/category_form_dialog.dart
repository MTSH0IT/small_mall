import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/primary_button.dart';

class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({
    super.key,
    this.initialCategory,
    this.parentId,
    this.parentName,
    required this.onSave,
  });

  final ExpenseCategory? initialCategory;
  final String? parentId;
  final String? parentName;
  final Future<void> Function({required String name, String? description}) onSave;

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  bool _isLoading = false;

  bool get isSubcategory => widget.parentId != null || widget.initialCategory?.parentId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialCategory?.name ?? '');
    _descController = TextEditingController(text: widget.initialCategory?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await widget.onSave(
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
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
    final isEdit = widget.initialCategory != null;

    final dialogTitle = isSubcategory
        ? (isEdit ? 'expenses.edit_subcategory'.tr() : 'expenses.add_subcategory'.tr())
        : (isEdit ? 'expenses.edit_category'.tr() : 'expenses.add_category'.tr());

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSubcategory ? Icons.subdirectory_arrow_left_rounded : Icons.category_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dialogTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (widget.parentName != null)
                          Text(
                            widget.parentName!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: isSubcategory ? 'expenses.subcategory_name'.tr() : 'expenses.category_name'.tr(),
                hint: isSubcategory ? 'expenses.subcategory_name_hint'.tr() : 'expenses.category_name_hint'.tr(),
                controller: _nameController,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'common.required_field'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'expenses.category_desc'.tr(),
                hint: 'expenses.category_desc_hint'.tr(),
                controller: _descController,
                maxLines: 2,
              ),
              const SizedBox(height: 24),
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
