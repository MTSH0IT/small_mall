import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/services/app_settings_service.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
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
  bool _isSavingPricing = false;
  bool _isRepricing = false;
  late final TextEditingController _exchangeRateController;
  late final TextEditingController _defaultMinStockController;
  final _syncService = getIt<SyncService>();

  @override
  void initState() {
    super.initState();
    _pendingCount = _syncService.pendingCount.value;
    _syncStatus = _syncService.status.value;
    _syncService.pendingCount.addListener(_onPendingCountChanged);
    _syncService.status.addListener(_onSyncStatusChanged);
    _loadDbPath();

    final rate = AppSettingsService.usdExchangeRate;
    _exchangeRateController = TextEditingController(
      text: rate > 0 ? (rate % 1 == 0 ? rate.toInt().toString() : rate.toString()) : '',
    );
    final minStock = AppSettingsService.defaultMinStockAlert;
    _defaultMinStockController = TextEditingController(
      text: minStock % 1 == 0 ? minStock.toInt().toString() : minStock.toString(),
    );
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

  Future<void> _savePricingSettings() async {
    setState(() => _isSavingPricing = true);
    try {
      final rate = AppSettingsService.parseNumber(_exchangeRateController.text) ?? 0.0;
      final minStock = AppSettingsService.parseNumber(_defaultMinStockController.text) ?? 5.0;
      await AppSettingsService.saveSettings(
        exchangeRate: rate,
        defaultMinStock: minStock,
      );
      if (mounted) {
        AppToast.success(
          context,
          message: 'settings.pricing_settings_saved'.tr(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPricing = false);
      }
    }
  }

  Future<void> _showRepriceConfirmationDialog() async {
    final rawRate = AppSettingsService.parseNumber(_exchangeRateController.text) ?? AppSettingsService.usdExchangeRate;
    if (rawRate <= 0) {
      AppToast.warning(
        context,
        message: 'settings.reprice_no_rate_warning'.tr(),
      );
      return;
    }

    final rateStr = rawRate % 1 == 0 ? rawRate.toInt().toString() : rawRate.toString();
    var selectedMode = PriceRecalculationMode.usdToSyp;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.currency_exchange_rounded,
                      color: Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'settings.reprice_dialog_title'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Rate Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'settings.reprice_current_rate'.tr(namedArgs: {'rate': rateStr}),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'settings.reprice_dialog_desc'.tr(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Options
                      _buildRepriceModeOption(
                        mode: PriceRecalculationMode.usdToSyp,
                        currentMode: selectedMode,
                        title: 'settings.reprice_mode_usd_to_syp'.tr(),
                        subtitle: 'settings.reprice_mode_usd_to_syp_desc'.tr(),
                        onSelect: () => setDialogState(() => selectedMode = PriceRecalculationMode.usdToSyp),
                      ),
                      const SizedBox(height: 8),
                      _buildRepriceModeOption(
                        mode: PriceRecalculationMode.smart,
                        currentMode: selectedMode,
                        title: 'settings.reprice_mode_smart'.tr(),
                        subtitle: 'settings.reprice_mode_smart_desc'.tr(),
                        onSelect: () => setDialogState(() => selectedMode = PriceRecalculationMode.smart),
                      ),
                      const SizedBox(height: 8),
                      _buildRepriceModeOption(
                        mode: PriceRecalculationMode.sypToUsd,
                        currentMode: selectedMode,
                        title: 'settings.reprice_mode_syp_to_usd'.tr(),
                        subtitle: 'settings.reprice_mode_syp_to_usd_desc'.tr(),
                        onSelect: () => setDialogState(() => selectedMode = PriceRecalculationMode.sypToUsd),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('common.cancel'.tr()),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('settings.reprice_confirm_btn'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isRepricing = true);
      try {
        final minStock = AppSettingsService.parseNumber(_defaultMinStockController.text) ?? 5.0;
        await AppSettingsService.saveSettings(
          exchangeRate: rawRate,
          defaultMinStock: minStock,
        );

        final result = await getIt<InventoryRepository>().recalculateAllProductPrices(
          exchangeRate: rawRate,
          mode: selectedMode,
        );

        if (mounted) {
          if (result.totalProducts == 0) {
            AppToast.warning(context, message: 'settings.reprice_no_products'.tr());
          } else {
            AppToast.success(
              context,
              message: 'settings.reprice_success'.tr(namedArgs: {
                'updated': result.updatedProducts.toString(),
                'total': result.totalProducts.toString(),
              }),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          AppToast.error(context, message: e.toString());
        }
      } finally {
        if (mounted) {
          setState(() => _isRepricing = false);
        }
      }
    }
  }

  Widget _buildRepriceModeOption({
    required PriceRecalculationMode mode,
    required PriceRecalculationMode currentMode,
    required String title,
    required String subtitle,
    required VoidCallback onSelect,
  }) {
    final isSelected = mode == currentMode;
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF059669).withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF059669) : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: isSelected ? const Color(0xFF059669) : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? const Color(0xFF059669) : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _syncService.pendingCount.removeListener(_onPendingCountChanged);
    _syncService.status.removeListener(_onSyncStatusChanged);
    _exchangeRateController.dispose();
    _defaultMinStockController.dispose();
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

                // 2. Pricing & Products Section
                SettingsSection(
                  title: 'settings.pricing_and_products'.tr(),
                  subtitle: 'settings.pricing_and_products_desc'.tr(),
                  icon: Icons.currency_exchange_rounded,
                  iconColor: const Color(0xFF059669),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 500;
                            final exchangeField = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppTextField(
                                  label: 'settings.usd_exchange_rate'.tr(),
                                  controller: _exchangeRateController,
                                  hint: 'settings.usd_exchange_rate_hint'.tr(),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  prefixIcon: const Icon(
                                    Icons.currency_exchange_rounded,
                                    size: 18,
                                    color: Color(0xFF059669),
                                  ),
                                  suffixIcon: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    child: Text(
                                      '1\$ = ل.س',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF059669),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'settings.usd_exchange_rate_note'.tr(),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            );

                            final minStockField = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppTextField(
                                  label: 'settings.default_min_stock'.tr(),
                                  controller: _defaultMinStockController,
                                  hint: 'settings.default_min_stock_hint'.tr(),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  prefixIcon: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'settings.default_min_stock_note'.tr(),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            );

                            if (isNarrow) {
                              return Column(
                                children: [
                                  exchangeField,
                                  const SizedBox(height: 14),
                                  minStockField,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: exchangeField),
                                const SizedBox(width: 16),
                                Expanded(child: minStockField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: PrimaryButton(
                            label: 'settings.save_pricing_settings'.tr(),
                            icon: Icons.save_rounded,
                            isLoading: _isSavingPricing,
                            onPressed: _isSavingPricing ? null : _savePricingSettings,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 12),

                        // Reprice Stored Products Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF059669).withValues(alpha: 0.25),
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, boxConstraints) {
                              final isCompact = boxConstraints.maxWidth < 600;
                              final infoColumn = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 18,
                                        color: Color(0xFF059669),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'settings.reprice_products_title'.tr(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'settings.reprice_products_desc'.tr(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              );

                              final repriceBtn = ElevatedButton.icon(
                                icon: _isRepricing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.currency_exchange_rounded, size: 18),
                                label: Text('settings.reprice_products_btn'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: (_isRepricing || _isSavingPricing)
                                    ? null
                                    : _showRepriceConfirmationDialog,
                              );

                              if (isCompact) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    infoColumn,
                                    const SizedBox(height: 12),
                                    repriceBtn,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: infoColumn),
                                  const SizedBox(width: 16),
                                  repriceBtn,
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Security & PIN Section
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
                  tooltip: _obscureText ? 'settings.show_pin'.tr() : 'settings.hide_pin'.tr(),
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
