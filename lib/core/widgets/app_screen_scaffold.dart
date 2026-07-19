import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_bar_title.dart';
import 'package:flutter/material.dart';

class AppScreenScaffold extends StatelessWidget {
  const AppScreenScaffold({
    super.key,
    required this.title,
    this.onRefresh,
    this.actions = const [],
    required this.body,
  });
  final String title;
  final VoidCallback? onRefresh;
  final List<Widget> actions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(title),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          ...actions,
          if (onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: onRefresh,
            ),
        ],
      ),
      body: body,
    );
  }
}
