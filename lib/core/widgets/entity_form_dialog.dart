import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';

class EntityFormDialog extends StatefulWidget {

  const EntityFormDialog({
    super.key,
    required this.title,
    required this.saveLabel,
    this.nameLabel = 'اسم العميل *',
    this.phoneLabel = 'رقم الهاتف',
    this.notesLabel = 'ملاحظات',
    required this.nameController,
    required this.phoneController,
    required this.notesController,
    required this.onSave,
  });
  final String title;
  final String saveLabel;
  final String nameLabel;
  final String phoneLabel;
  final String notesLabel;
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.title, style: const TextStyle(fontFamily: 'ElMessiri', color: AppColors.primary)),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: widget.nameLabel,
                controller: widget.nameController,
                validator: (val) => val == null || val.isEmpty ? 'الرجاء إدخال الاسم' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: widget.phoneLabel,
                controller: widget.phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: widget.notesLabel,
                controller: widget.notesController,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
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
      ),
    );
  }
}
