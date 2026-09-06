import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  SyncStatus _syncStatus = SyncStatus.idle;
  bool _isManualSyncing = false;
  bool _isRestoring = false;
  final _syncService = getIt<SyncService>();

  @override
  void initState() {
    super.initState();
    _pendingCount = _syncService.pendingCount.value;
    _syncStatus = _syncService.status.value;
    _syncService.pendingCount.addListener(_onPendingCountChanged);
    _syncService.status.addListener(_onSyncStatusChanged);
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

  void _onSyncStatusChanged() {
    if (mounted) {
      setState(() {
        _syncStatus = _syncService.status.value;
      });
    }
  }

  @override
  void dispose() {
    _syncService.pendingCount.removeListener(_onPendingCountChanged);
    _syncService.status.removeListener(_onSyncStatusChanged);
    super.dispose();
  }

  Future<void> _handleManualSync() async {
    if (_isManualSyncing) return;
    setState(() => _isManualSyncing = true);
    try {
      await _syncService.sync();
      if (mounted) {
        AppToast.success(context, message: 'settings.sync_request_sent'.tr());
      }
    } finally {
      if (mounted) {
        setState(() => _isManualSyncing = false);
      }
    }
  }

  Future<void> _showRestoreConfirmDialog() async {
    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_download_rounded, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'settings.cloud_restore_confirm_title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'settings.cloud_restore_confirm_msg'.tr(),
          style: const TextStyle(color: AppColors.textPrimary, height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('settings.restore_now'.tr()),
          ),
        ],
      ),
    );

    if (shouldRestore == true && mounted) {
      setState(() => _isRestoring = true);
      try {
        await _syncService.fetchAllFromServer();
        if (mounted) {
          if (_syncService.status.value == SyncStatus.success) {
            AppToast.success(context, message: 'settings.restore_success'.tr());
          } else {
            AppToast.error(context, message: 'settings.restore_failed'.tr());
          }
        }
      } finally {
        if (mounted) {
          setState(() => _isRestoring = false);
        }
      }
    }
  }

  Future<void> _showLogoutConfirmDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'settings.confirm_logout_title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'settings.confirm_logout_msg'.tr(),
          style: const TextStyle(color: AppColors.textPrimary, height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('settings.logout'.tr()),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      context.go('/login');
    }
  }

  Future<void> _showChangePinDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _ChangePinDialog(),
    );

    if (result == true && mounted) {
      AppToast.success(context, message: 'settings.pin_change_success'.tr());
    }
  }

  Future<void> _copyDbPathToClipboard() async {
    if (_dbPath.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _dbPath));
    if (mounted) {
      AppToast.success(context, message: 'settings.path_copied'.tr());
    }
  }

  Widget _buildSyncStatusBadge() {
    Color badgeColor;
    String statusText;
    IconData badgeIcon;

    switch (_syncStatus) {
      case SyncStatus.syncing:
        badgeColor = AppColors.primary;
        statusText = 'sync.syncing'.tr();
        badgeIcon = Icons.sync_rounded;
        break;
      case SyncStatus.success:
        badgeColor = AppColors.success;
        statusText = 'sync.synced'.tr();
        badgeIcon = Icons.cloud_done_rounded;
        break;
      case SyncStatus.error:
        badgeColor = AppColors.danger;
        statusText = 'sync.error'.tr();
        badgeIcon = Icons.cloud_off_rounded;
        break;
      case SyncStatus.offline:
        badgeColor = Colors.orange;
        statusText = 'sync.offline'.tr();
        badgeIcon = Icons.wifi_off_rounded;
        break;
      case SyncStatus.idle:
        if (_pendingCount > 0) {
          badgeColor = AppColors.accent;
          statusText = 'sync.pending'.tr();
          badgeIcon = Icons.cloud_upload_rounded;
        } else {
          badgeColor = AppColors.success;
          statusText = 'sync.all_synced'.tr();
          badgeIcon = Icons.cloud_done_rounded;
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 15, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
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
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = context.locale.languageCode;

    return AppScreenScaffold(
      title: 'settings.title'.tr(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Language & Localization Section
                SettingsSection(
                  title: 'settings.language'.tr(),
                  subtitle: 'settings.language_desc'.tr(),
                  icon: Icons.language_rounded,
                  iconColor: AppColors.primary,
                  child: Wrap(
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
                ),
                const SizedBox(height: 20),

                // 2. Security & PIN Section
                SettingsSection(
                  title: 'settings.security'.tr(),
                  subtitle: 'settings.security_desc'.tr(),
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0xFFB57A2A),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB57A2A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Color(0xFFB57A2A),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'settings.pin_protected'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'settings.change_pin_desc'.tr(),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        PrimaryButton(
                          label: 'settings.change_pin'.tr(),
                          icon: Icons.lock_reset_rounded,
                          onPressed: _showChangePinDialog,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Cloud Sync & Backup Section
                SettingsSection(
                  title: 'settings.sync_backup'.tr(),
                  subtitle: 'settings.cloud_sync_desc'.tr(),
                  icon: Icons.cloud_sync_rounded,
                  iconColor: const Color(0xFF1E70A6),
                  trailing: _buildSyncStatusBadge(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sync Operations Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _pendingCount > 0
                              ? AppColors.accent.withValues(alpha: 0.06)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _pendingCount > 0
                                ? AppColors.accent.withValues(alpha: 0.35)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (_pendingCount > 0 ? AppColors.accent : AppColors.success)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _pendingCount > 0
                                    ? Icons.pending_actions_rounded
                                    : Icons.cloud_done_rounded,
                                color: _pendingCount > 0
                                    ? AppColors.accent
                                    : AppColors.success,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'settings.pending_operations'.tr(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _pendingCount > 0
                                        ? 'settings.pending_ops_desc'.tr(
                                            namedArgs: {'count': '$_pendingCount'},
                                          )
                                        : 'settings.synced_all'.tr(),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: _pendingCount > 0
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            PrimaryButton(
                              label: 'settings.sync_now'.tr(),
                              icon: Icons.sync_rounded,
                              isLoading: _isManualSyncing,
                              onPressed: _isManualSyncing ? null : _handleManualSync,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cloud Restore Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _isRestoring
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: LoadingIndicator(message: 'settings.restoring'.tr()),
                              )
                            : Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.cloud_download_rounded,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'settings.restore_cloud'.tr(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'settings.restore_cloud_desc'.tr(),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(color: AppColors.primary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    icon: const Icon(Icons.cloud_download_outlined, size: 18),
                                    label: Text(
                                      'settings.restore_now'.tr(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: _showRestoreConfirmDialog,
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Local Database & Offline Info Section
                SettingsSection(
                  title: 'settings.database_info'.tr(),
                  subtitle: 'settings.database_info_desc'.tr(),
                  icon: Icons.storage_rounded,
                  iconColor: const Color(0xFF3F6F67),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Database Path Container
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.dns_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'settings.local_db_path'.tr(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    _dbPath.isEmpty ? 'common.loading'.tr() : _dbPath,
                                    style: AppTheme.numericStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'settings.copy_path'.tr(),
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.surfaceElevated,
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                                onPressed: _copyDbPathToClipboard,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Local Storage Notice Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF4E4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFECCB7A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFF946A14),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'settings.local_db_warning'.tr(),
                                style: const TextStyle(
                                  color: Color(0xFF6B4D08),
                                  fontSize: 12.5,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Session & Logout Section
                SettingsSection(
                  title: 'settings.logout'.tr(),
                  subtitle: 'settings.confirm_logout_msg'.tr(),
                  icon: Icons.logout_rounded,
                  iconColor: AppColors.danger,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'settings.confirm_logout_msg'.tr(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      PrimaryButton(
                        label: 'settings.logout'.tr(),
                        icon: Icons.logout_rounded,
                        backgroundColor: AppColors.danger,
                        onPressed: _showLogoutConfirmDialog,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Enhanced, secure Change PIN modal dialog
class _ChangePinDialog extends StatefulWidget {
  const _ChangePinDialog();

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureText = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final oldPin = _oldController.text.trim();
    final newPin = _newController.text.trim();
    final confirmPin = _confirmController.text.trim();

    if (oldPin.length < 4 || newPin.length < 4) {
      setState(() {
        _errorMessage = 'settings.pin_length_warning'.tr();
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedPin = prefs.getString('user_pin') ?? '';

    if (oldPin != savedPin) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'settings.pin_incorrect'.tr();
      });
      return;
    }

    if (newPin != confirmPin) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'settings.pins_not_matching'.tr();
      });
      return;
    }

    await prefs.setString('user_pin', newPin);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      obscureText: _obscureText,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 6,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        counterText: '',
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'settings.change_pin'.tr(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'settings.change_pin_desc'.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: _obscureText ? 'إظهار الرمز' : 'إخفاء الرمز',
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // Error feedback banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Input fields
            _buildPinField(
              controller: _oldController,
              label: 'settings.old_pin'.tr(),
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 12),
            _buildPinField(
              controller: _newController,
              label: 'settings.new_pin'.tr(),
              icon: Icons.pin_outlined,
            ),
            const SizedBox(height: 12),
            _buildPinField(
              controller: _confirmController,
              label: 'settings.confirm_new_pin'.tr(),
              icon: Icons.check_circle_outline_rounded,
            ),
            const SizedBox(height: 22),

            // Dialog Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                  child: Text('common.cancel'.tr()),
                ),
                const SizedBox(width: 10),
                PrimaryButton(
                  label: 'common.save'.tr(),
                  icon: Icons.check_rounded,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _handleSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
