import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:flutter/material.dart';

class PinPad extends StatelessWidget {

  const PinPad({
    super.key,
    required this.onNumberPressed,
    required this.onDeletePressed,
    required this.onConfirmPressed,
  });
  final ValueChanged<int> onNumberPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onConfirmPressed;

  @override
  Widget build(BuildContext context) {
    return Table(
      children: [
        TableRow(
          children: [
            _buildNumButton(1),
            _buildNumButton(2),
            _buildNumButton(3),
          ],
        ),
        TableRow(
          children: [
            _buildNumButton(4),
            _buildNumButton(5),
            _buildNumButton(6),
          ],
        ),
        TableRow(
          children: [
            _buildNumButton(7),
            _buildNumButton(8),
            _buildNumButton(9),
          ],
        ),
        TableRow(
          children: [
            // Delete button
            _buildIconButton(Icons.backspace_outlined, onDeletePressed),
            _buildNumButton(0),
            // Confirm button
            _buildIconButton(Icons.check_circle_outline, onConfirmPressed, color: AppColors.success),
          ],
        ),
      ],
    );
  }

  Widget _buildNumButton(int number) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: AspectRatio(
        aspectRatio: 1.5,
        child: OutlinedButton(
          onPressed: () => onNumberPressed(number),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: const BorderSide(color: AppColors.border),
            backgroundColor: AppColors.surface,
          ),
          child: Text(
            number.toString(),
            style: AppTheme.numericStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: AspectRatio(
        aspectRatio: 1.5,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: const BorderSide(color: AppColors.border),
            backgroundColor: AppColors.surface,
          ),
          child: Icon(
            icon,
            color: color ?? AppColors.textPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }
}
