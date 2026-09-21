import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.secondaryValue,
    this.secondaryColor,
    this.subtitle,
    this.secondarySubtitle,
    this.badge,
  });

  final String title;
  final String value;
  final String? secondaryValue;
  final Color? secondaryColor;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final String? secondarySubtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveSecondaryColor = secondaryColor ?? const Color(0xFF059669);

    const double valueFontSize = 20;

    if (subtitle != null) {
      // Column layout used in ReportsScreen
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color.withValues(alpha: 0.8), size: 28),
              ],
            ),
            const SizedBox(height: 12),
            // Primary currency value
            Text(
              value,
              style: AppTheme.numericStyle(
                fontSize: valueFontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (secondaryValue != null) ...[
              const SizedBox(height: 4),
              Text(
                secondaryValue!,
                style: AppTheme.numericStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.bold,
                  color: effectiveSecondaryColor,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(subtitle!, style: theme.textTheme.labelSmall),
            if (secondarySubtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                secondarySubtitle!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: effectiveSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      // Row layout used in DashboardScreen
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Primary currency value
                  Text(
                    value,
                    style: AppTheme.numericStyle(
                      fontSize: secondaryValue != null ? valueFontSize : 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (secondaryValue != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      secondaryValue!,
                      style: AppTheme.numericStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.bold,
                        color: effectiveSecondaryColor,
                      ),
                    ),
                  ],
                  if (badge != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge!,
                        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(icon, size: 40, color: color.withValues(alpha: 0.6)),
          ],
        ),
      );
    }
  }
}
