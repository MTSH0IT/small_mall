import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/core/utils/theme.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key, required this.child});
  final Widget child;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final SyncService _syncService = getIt<SyncService>();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final theme = Theme.of(context);

    final navItems = [
      _NavItem(
        icon: Icons.point_of_sale_outlined,
        activeIcon: Icons.point_of_sale,
        label: 'nav.pos'.tr(),
        route: '/pos',
      ),
      _NavItem(
        icon: Icons.card_giftcard_outlined,
        activeIcon: Icons.card_giftcard,
        label: 'nav.products'.tr(),
        route: '/products',
      ),
      _NavItem(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        label: 'nav.inventory'.tr(),
        route: '/inventory',
      ),
      _NavItem(
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet,
        label: 'nav.expenses'.tr(),
        route: '/expenses',
      ),
      _NavItem(
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        label: 'nav.customers'.tr(),
        route: '/customers',
      ),
      _NavItem(
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping,
        label: 'nav.suppliers'.tr(),
        route: '/suppliers',
      ),
      _NavItem(
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        label: 'nav.reports'.tr(),
        route: '/reports',
      ),
      _NavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        label: 'nav.invoices'.tr(),
        route: '/invoices',
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'nav.settings'.tr(),
        route: '/settings',
      ),
    ];

    return Scaffold(
      body: Row(
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'app_title'.tr(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'app_subtitle'.tr(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
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
                      final isSelected = item.route == '/pos'
                          ? (location.startsWith('/pos') || location == '/')
                          : location.startsWith(item.route);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: InkWell(
                          onTap: () => context.go(item.route),
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
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildSyncStatusWidget(SyncStatus status, int pendingCount) {
    final theme = Theme.of(context);
    Color dotColor = Colors.grey;
    String statusText = 'sync.disconnected'.tr();
    IconData icon = Icons.cloud_off_outlined;

    switch (status) {
      case SyncStatus.idle:
        if (pendingCount > 0) {
          dotColor = AppColors.accent;
          statusText = 'sync.pending'.tr();
          icon = Icons.sync_outlined;
        } else {
          dotColor = AppColors.success;
          statusText = 'sync.all_synced'.tr();
          icon = Icons.cloud_done_outlined;
        }
        break;
      case SyncStatus.syncing:
        dotColor = AppColors.primary;
        statusText = 'sync.syncing'.tr();
        icon = Icons.sync;
        break;
      case SyncStatus.success:
        dotColor = AppColors.success;
        statusText = 'sync.synced'.tr();
        icon = Icons.cloud_done_outlined;
        break;
      case SyncStatus.error:
        dotColor = AppColors.danger;
        statusText = 'sync.error'.tr();
        icon = Icons.cloud_off;
        break;
      case SyncStatus.offline:
        dotColor = Colors.orange;
        statusText = 'sync.offline'.tr();
        icon = Icons.wifi_off_outlined;
        break;
    }

    if (pendingCount > 0) {
      statusText += ' ($pendingCount)';
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
                'sync.title'.tr(),
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
  _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
}
