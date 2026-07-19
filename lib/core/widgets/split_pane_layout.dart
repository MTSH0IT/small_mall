import 'package:small_mall/core/utils/theme.dart';
import 'package:flutter/material.dart';

class SplitPaneLayout extends StatelessWidget {

  const SplitPaneLayout({
    super.key,
    this.leftFlex = 2,
    this.rightFlex = 3,
    required this.leftChild,
    required this.rightChild,
  });
  final int leftFlex;
  final int rightFlex;
  final Widget leftChild;
  final Widget rightChild;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: leftFlex, child: leftChild),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
        Expanded(flex: rightFlex, child: rightChild),
      ],
    );
  }
}
