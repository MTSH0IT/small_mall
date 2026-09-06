import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';

class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onNumberPressed,
    required this.onDeletePressed,
    required this.onConfirmPressed,
    this.onClearPressed,
  });

  final ValueChanged<int> onNumberPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onConfirmPressed;
  final VoidCallback? onClearPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumButton(1),
            _buildNumButton(2),
            _buildNumButton(3),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumButton(4),
            _buildNumButton(5),
            _buildNumButton(6),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumButton(7),
            _buildNumButton(8),
            _buildNumButton(9),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Delete / Backspace (with long-press to clear all)
            _buildActionButton(
              icon: Icons.backspace_outlined,
              tooltip: 'login.delete_tooltip'.tr(),
              color: AppColors.danger,
              onPressed: onDeletePressed,
              onLongPress: onClearPressed ?? onDeletePressed,
            ),
            _buildNumButton(0),
            // Confirm / Submit
            _buildActionButton(
              icon: Icons.check_rounded,
              tooltip: 'login.confirm_tooltip'.tr(),
              color: AppColors.primary,
              isPrimary: true,
              onPressed: onConfirmPressed,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumButton(int number) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => onNumberPressed(number),
          borderRadius: BorderRadius.circular(16),
          hoverColor: AppColors.primary.withValues(alpha: 0.08),
          splashColor: AppColors.primary.withValues(alpha: 0.15),
          child: Container(
            width: 76,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Text(
              number.toString(),
              style: AppTheme.numericStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    VoidCallback? onLongPress,
    String? tooltip,
    Color? color,
    bool isPrimary = false,
  }) {
    final effectiveColor = color ?? AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: isPrimary ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(16),
            hoverColor: isPrimary
                ? AppColors.primaryDark
                : effectiveColor.withValues(alpha: 0.08),
            splashColor: effectiveColor.withValues(alpha: 0.2),
            child: Container(
              width: 76,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPrimary ? AppColors.primary : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : effectiveColor,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
