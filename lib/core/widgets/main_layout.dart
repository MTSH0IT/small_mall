import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key, required this.child});
  final Widget child;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final SyncService _syncService = getIt<SyncService>();

  // Determine current active index based on route path
  int _getSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/products')) return 1;
    if (location.startsWith('/inventory')) return 2;
    if (location.startsWith('/customers')) return 3;
    if (location.startsWith('/suppliers')) return 4;
    if (location.startsWith('/reports')) return 5;
    if (location.startsWith('/invoices')) return 6;
    if (location.startsWith('/settings')) return 7;
    return 0; // default to pos
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/pos');
        break;
      case 1:
        context.go('/products');
        break;
      case 2:
        context.go('/inventory');
        break;
      case 3:
        context.go('/customers');
        break;
      case 4:
        context.go('/suppliers');
        break;
      case 5:
        context.go('/reports');
        break;
      case 6:
        context.go('/invoices');
        break;
      case 7:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);
    final theme = Theme.of(context);

    final navItems = [
      _NavItem(
        icon: Icons.point_of_sale_outlined,
        activeIcon: Icons.point_of_sale,
        label: 'نقطة البيع',
      ),
      _NavItem(
        icon: Icons.card_giftcard_outlined,
        activeIcon: Icons.card_giftcard,
        label: 'المنتجات',
      ),
      _NavItem(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        label: 'المخزون',
      ),
      _NavItem(
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        label: 'العملاء والديون',
      ),
      _NavItem(
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping,
        label: 'الموردون والمشتريات',
      ),
      _NavItem(
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        label: 'التقارير',
      ),
      _NavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        label: 'الفواتير',
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'الإعدادات',
      ),
    ];

    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            // Sidebar Navigation Rail
            Container(
              width: 220,
              color: AppColors.surfaceElevated,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Title / Branding
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Small Mall',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gift Shop Manager',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Navigation Items
                  Expanded(
                    child: ListView.builder(
                      itemCount: navItems.length,
                      itemBuilder: (context, index) {
                        final item = navItems[index];
                        final isSelected = index == selectedIndex;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: InkWell(
                            onTap: () => _onItemTapped(index, context),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? item.activeIcon : item.icon,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    item.label,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Sync Status indicator at the bottom
                  const Divider(color: AppColors.border, height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ValueListenableBuilder<SyncStatus>(
                      valueListenable: _syncService.status,
                      builder: (context, status, child) {
                        return ValueListenableBuilder<int>(
                          valueListenable: _syncService.pendingCount,
                          builder: (context, pending, child) {
                            return _buildSyncStatusWidget(status, pending);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Divider
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.border,
            ),
            // Main Content
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusWidget(SyncStatus status, int pendingCount) {
    final theme = Theme.of(context);
    Color dotColor = Colors.grey;
    String statusText = 'غير متصل';
    IconData icon = Icons.cloud_off_outlined;

    switch (status) {
      case SyncStatus.idle:
        if (pendingCount > 0) {
          dotColor = AppColors.accent;
          statusText = 'معلق للرفع ($pendingCount)';
          icon = Icons.sync_outlined;
        } else {
          dotColor = AppColors.success;
          statusText = 'مزامنة كاملة';
          icon = Icons.cloud_done_outlined;
        }
        break;
      case SyncStatus.syncing:
        dotColor = AppColors.primary;
        statusText = 'جاري المزامنة...';
        icon = Icons.sync;
        break;
      case SyncStatus.success:
        dotColor = AppColors.success;
        statusText = 'تمت المزامنة';
        icon = Icons.cloud_done_outlined;
        break;
      case SyncStatus.error:
        dotColor = AppColors.danger;
        statusText = 'فشل الاتصال بالخادم';
        icon = Icons.cloud_off;
        break;
      case SyncStatus.offline:
        dotColor = Colors.orange;
        statusText = 'يعمل أوفلاين';
        icon = Icons.wifi_off_outlined;
        break;
    }

    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'حالة السحاب',
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      statusText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem {
  _NavItem({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
