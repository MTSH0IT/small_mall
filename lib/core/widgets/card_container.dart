import 'package:small_mall/core/utils/theme.dart';
import 'package:flutter/material.dart';

class CardContainer extends StatelessWidget {

  const CardContainer({
    super.key,
    required this.title,
    required this.child,
  });
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'ElMessiri',
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          child,
        ],
      ),
    );
  }
}
