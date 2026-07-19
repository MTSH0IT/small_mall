import 'package:small_mall/core/utils/theme.dart';
import 'package:flutter/material.dart';

class AppBarTitle extends StatelessWidget {

  const AppBarTitle(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.displayMedium?.copyWith(
        fontFamily: 'ElMessiri',
        color: AppColors.primary,
      ),
    );
  }
}
