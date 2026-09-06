import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/settings/presentation/widgets/settings_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _dbPath = '';
  int _pendingCount = 0;
  bool _isRestoring = false;
  final _syncService = getIt<SyncService>();

  @override
  void initState() {
    super.initState();
    _pendingCount = _syncService.pendingCount.value;
    _syncService.pendingCount.addListener(_onPendingCountChanged);
    _loadDbPath();
  }

  Future<void> _loadDbPath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    if (mounted) {
      setState(() {
        _dbPath = p.join(dbFolder.path, 'small_mall.db');
      });
    }
  }

  void _onPendingCountChanged() {
    if (mounted) {
      setState(() {
        _pendingCount = _syncService.pendingCount.value;
      });
    }
  }

  @override
  void dispose() {
    _syncService.pendingCount.removeListener(_onPendingCountChanged);
    super.dispose();
  }

  void _showChangePinDialog(BuildContext context) {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('settings.change_pin'.tr(), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'settings.old_pin'.tr(),
                counterText: '',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'settings.new_pin'.tr(),
                counterText: '',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'settings.confirm_new_pin'.tr(),
                counterText: '',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final oldPin = oldController.text;
              final newPin = newController.text;
              final confirmPin = confirmController.text;

              if (oldPin.length < 4 || newPin.length < 4) {
                AppToast.warning(context, message: 'settings.pin_length_warning'.tr());
                return;
              }

              final prefs = await SharedPreferences.getInstance();
              if (!mounted) return;
              final savedPin = prefs.getString('user_pin') ?? '';

              if (!ctx.mounted) return;
              if (oldPin != savedPin) {
                AppToast.error(context, message: 'settings.pin_incorrect'.tr());
                return;
              }

              if (newPin != confirmPin) {
                AppToast.warning(context, message: 'settings.pins_not_matching'.tr());
                return;
              }

              await prefs.setString('user_pin', newPin);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                AppToast.success(context, message: 'settings.pin_change_success'.tr());
              }
            },
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required Locale locale,
    required String title,
    required String flag,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () async {
        if (!isSelected) {
          await context.setLocale(locale);
          if (context.mounted) {
            AppToast.success(context, message: 'settings.language_changed'.tr());
          }
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentLang = context.locale.languageCode;

    return AppScreenScaffold(
      title: 'settings.title'.tr(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language Selection Section
            SettingsSection(
              title: 'settings.language'.tr(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.language_desc'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _buildLanguageOption(
                        context: context,
                        locale: const Locale('ar'),
                        title: 'settings.arabic'.tr(),
                        flag: '🇸🇦',
                        isSelected: currentLang == 'ar',
                      ),
                      _buildLanguageOption(
                        context: context,
                        locale: const Locale('en'),
                        title: 'settings.english'.tr(),
                        flag: '🇺🇸',
                        isSelected: currentLang == 'en',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Sync & Backup Control
            SettingsSection(
              title: 'settings.sync_backup'.tr(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'settings.pending_operations'.tr(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'settings.pending_ops_desc'.tr(namedArgs: {'count': '$_pendingCount'}),
                              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      PrimaryButton(
                        label: 'settings.sync_now'.tr(),
                        icon: Icons.sync,
                        onPressed: () async {
                          await _syncService.sync();
                          if (context.mounted) {
                            AppToast.success(context, message: 'settings.sync_request_sent'.tr());
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Restore from server
            SettingsSection(
              title: 'settings.restore_cloud'.tr(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.restore_cloud_desc'.tr(),
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  _isRestoring
                      ? LoadingIndicator(message: 'settings.restoring'.tr())
                      : PrimaryButton(
                          label: 'settings.restore_now'.tr(),
                          icon: Icons.cloud_download,
                          onPressed: () async {
                            setState(() => _isRestoring = true);
                            await _syncService.fetchAllFromServer();
                            if (context.mounted) {
                              if (_syncService.status.value == SyncStatus.success) {
                                AppToast.success(context, message: 'settings.restore_success'.tr());
                              } else {
                                AppToast.error(context, message: 'settings.restore_failed'.tr());
                              }
                            }
                            setState(() => _isRestoring = false);
                          },
                        ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Change PIN
            SettingsSection(
              title: 'settings.change_pin'.tr(),
              child: PrimaryButton(
                label: 'settings.change_pin'.tr(),
                icon: Icons.lock_reset,
                onPressed: () => _showChangePinDialog(context),
              ),
            ),
            const SizedBox(height: 24),
            // Logout
            SettingsSection(
              title: 'settings.logout'.tr(),
              child: PrimaryButton(
                label: 'settings.logout'.tr(),
                icon: Icons.logout,
                backgroundColor: AppColors.danger,
                onPressed: () => context.go('/login'),
              ),
            ),
            const SizedBox(height: 24),
            // SQLite Local DB Info
            SettingsSection(
              title: 'settings.local_db'.tr(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.local_db_path'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    _dbPath.isEmpty ? 'common.loading'.tr() : _dbPath,
                    style: AppTheme.numericStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'settings.local_db_warning'.tr(),
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
