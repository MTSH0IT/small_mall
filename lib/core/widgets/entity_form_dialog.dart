import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/primary_button.dart';

class EntityFormDialog extends StatefulWidget {
  const EntityFormDialog({
    super.key,
    required this.title,
    required this.saveLabel,
    this.nameLabel,
    this.phoneLabel,
    this.notesLabel,
    required this.nameController,
    required this.phoneController,
    required this.notesController,
    required this.onSave,
  });

  final String title;
  final String saveLabel;
  final String? nameLabel;
  final String? phoneLabel;
  final String? notesLabel;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController notesController;
  final Future<void> Function() onSave;

  @override
  State<EntityFormDialog> createState() => _EntityFormDialogState();
}

class _EntityFormDialogState extends State<EntityFormDialog> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(color: AppColors.primary)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: widget.nameLabel ?? 'customers.customer_name'.tr(),
              controller: widget.nameController,
              validator: (val) => val == null || val.isEmpty ? 'common.required_field'.tr() : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: widget.phoneLabel ?? 'common.phone'.tr(),
              controller: widget.phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: widget.notesLabel ?? 'common.notes'.tr(),
              controller: widget.notesController,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('common.cancel'.tr())),
        PrimaryButton(
          label: widget.saveLabel,
          onPressed: () async {
            if (_formKey.currentState?.validate() ?? false) {
              final navigator = Navigator.of(context);
              await widget.onSave();
              if (mounted) navigator.pop();
            }
          },
        ),
      ],
    );
  }
}
