import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/settings/presentation/widgets/settings_section.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _dbPath = 'جاري التحميل...';
  int _pendingCount = 0;
  bool _isRestoring = false;
  final _syncService = getIt<SyncService>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final dbFolder = await getApplicationDocumentsDirectory();

    setState(() {
      _dbPath = p.join(dbFolder.path, 'small_mall.db');
      _pendingCount = _syncService.pendingCount.value;
    });

    _syncService.pendingCount.addListener(_onPendingCountChanged);
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
        title: const Text('تغيير رمز PIN', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'الرمز الحالي',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'الرمز الجديد',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'تأكيد الرمز الجديد',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final oldPin = oldController.text;
              final newPin = newController.text;
              final confirmPin = confirmController.text;

              if (oldPin.length < 4 || newPin.length < 4) {
                AppToast.warning(context, message: 'يجب أن يتكون الرمز من 4 أرقام');
                return;
              }

              final prefs = await SharedPreferences.getInstance();
              if (!mounted) return;
              final savedPin = prefs.getString('user_pin') ?? '';

              if (!ctx.mounted) return;
              if (oldPin != savedPin) {
                AppToast.error(context, message: 'الرمز الحالي غير صحيح');
                return;
              }

              if (newPin != confirmPin) {
                AppToast.warning(context, message: 'الرمزان الجديدان غير متطابقين');
                return;
              }

              await prefs.setString('user_pin', newPin);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                AppToast.success(context, message: 'تم تغيير رمز PIN بنجاح');
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScreenScaffold(
      title: 'الإعدادات العامة',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            // Sync & Backup Control
            SettingsSection(
              title: 'النسخ الاحتياطي والمزامنة اليدوية',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('العمليات المعلقة للمزامنة:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            'لديك $_pendingCount عملية تعديل بانتظار رفعها للسحاب.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      PrimaryButton(
                        label: 'مزامنة الآن',
                        icon: Icons.sync,
                        onPressed: () async {
                          await _syncService.sync();
                          if (context.mounted) {
                            AppToast.success(context, message: 'تم إرسال طلب المزامنة للرفع');
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
              title: 'استعادة البيانات من السحاب',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'في حال تم حذف قاعدة البيانات المحلية، يمكنك استعادة جميع البيانات من خادم Supabase.',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  _isRestoring
                      ? const LoadingIndicator(message: 'جاري استعادة البيانات من السحاب...')
                      : PrimaryButton(
                          label: 'استعادة البيانات من السحاب',
                          icon: Icons.cloud_download,
                          onPressed: () async {
                            setState(() => _isRestoring = true);
                            await _syncService.fetchAllFromServer();
                            if (context.mounted) {
                              if (_syncService.status.value == SyncStatus.success) {
                                AppToast.success(context, message: 'تم استعادة البيانات بنجاح');
                              } else {
                                AppToast.error(context, message: 'فشل استعادة البيانات');
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
              title: 'تغيير رمز PIN',
              child: PrimaryButton(
                label: 'تغيير رمز PIN',
                icon: Icons.lock_reset,
                onPressed: () => _showChangePinDialog(context),
              ),
            ),
            const SizedBox(height: 24),
            // Logout
            SettingsSection(
              title: 'تسجيل الخروج',
              child: PrimaryButton(
                label: 'تسجيل الخروج',
                icon: Icons.logout,
                backgroundColor: AppColors.danger,
                onPressed: () => context.go('/login'),
              ),
            ),
            const SizedBox(height: 24),
            // SQLite Local DB Info
            SettingsSection(
              title: 'قاعدة البيانات المحلية (أوفلاين)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مسار ملف قاعدة البيانات المحلي:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SelectableText(
                    _dbPath,
                    style: AppTheme.numericStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تنبيه: يتم تشفير وحفظ كافة بيانات المحل محلياً على هذا الجهاز. في حال عدم ربطه بسحابة Supabase، فإن حذف التطبيق سيؤدي لفقدان البيانات.',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w500),
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
