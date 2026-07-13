import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class QuickActionButton extends StatelessWidget {

  const QuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.route,
  });
  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => context.go(route),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: const BorderSide(color: AppColors.primary, width: 1.2),
          backgroundColor: AppColors.surfaceElevated,
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
        ),
      ),
    );
  }
}
