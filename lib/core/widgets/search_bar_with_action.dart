import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';

class SearchBarWithAction extends StatelessWidget {

  const SearchBarWithAction({
    super.key,
    required this.searchLabel,
    this.searchHint,
    required this.searchController,
    required this.onSearchChanged,
    this.actionLabel,
    this.actionIcon,
    this.onActionPressed,
  });
  final String searchLabel;
  final String? searchHint;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            label: searchLabel,
            hint: searchHint,
            controller: searchController,
            onChanged: onSearchChanged,
            prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 22.0),
            child: PrimaryButton(
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onActionPressed,
            ),
          ),
        ],
      ],
    );
  }
}
