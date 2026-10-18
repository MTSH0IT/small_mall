import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/primary_button.dart';

class TreasuryCategoryFormDialog extends StatefulWidget {
  const TreasuryCategoryFormDialog({
    super.key,
    this.initialCategory,
    this.parentId,
    this.parentName,
    this.defaultType = 'both',
    required this.onSave,
  });

  final TreasuryCategory? initialCategory;
  final String? parentId;
  final String? parentName;
  final String defaultType;
  final Future<void> Function({
    required String name,
    required String type,
    String? description,
    String? parentId,
  }) onSave;

  @override
  State<TreasuryCategoryFormDialog> createState() =>
      _TreasuryCategoryFormDialogState();
}

class _TreasuryCategoryFormDialogState extends State<TreasuryCategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isLoading = false;

  bool get isSubcategory =>
      widget.parentId != null || widget.initialCategory?.parentId != null;

  @override
  void initState() {
    super.initState();
    final cat = widget.initialCategory;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _descriptionController =
        TextEditingController(text: cat?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await widget.onSave(
        name: _nameController.text.trim(),
        type: 'both',
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        parentId: widget.parentId ?? widget.initialCategory?.parentId,
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
    final isEditing = widget.initialCategory != null;

    final dialogTitle = isSubcategory
        ? (isEditing
            ? 'treasury.edit_subcategory'.tr()
            : 'treasury.add_subcategory'.tr())
        : (isEditing
            ? 'treasury.edit_category'.tr()
            : 'treasury.add_category'.tr());

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isSubcategory
                  ? Icons.subdirectory_arrow_left_rounded
                  : Icons.category_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            dialogTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isSubcategory && widget.parentName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${'treasury.categories_heading'.tr()}: ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        widget.parentName!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              AppTextField(
                controller: _nameController,
                label: isSubcategory
                    ? 'treasury.subcategory_name'.tr()
                    : 'treasury.category_name'.tr(),
                hint: isSubcategory
                    ? 'treasury.subcategory_name_hint'.tr()
                    : 'treasury.category_name_hint'.tr(),
                prefixIcon: const Icon(Icons.label_outline),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'common.required_field'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _descriptionController,
                label: 'treasury.category_desc'.tr(),
                hint: 'expenses.category_desc_hint'.tr(),
                prefixIcon: const Icon(Icons.notes_outlined),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        PrimaryButton(
          label: isEditing ? 'common.save'.tr() : 'common.add'.tr(),
          isLoading: _isLoading,
          onPressed: _handleSubmit,
        ),
      ],
    );
  }
}
