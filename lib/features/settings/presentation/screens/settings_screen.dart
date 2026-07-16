import 'package:artisan_gift_manager/core/di/injection.dart';
import 'package:artisan_gift_manager/core/sync/sync_service.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/widgets/app_text_field.dart';
import 'package:artisan_gift_manager/core/widgets/primary_button.dart';
import 'package:artisan_gift_manager/features/settings/presentation/widgets/settings_section.dart';
import 'package:flutter/material.dart';
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
  final _syncService = getIt<SyncService>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final dbFolder = await getApplicationDocumentsDirectory();

    setState(() {
      _dbPath = p.join(dbFolder.path, 'artisan_gift_manager.db');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'الإعدادات العامة',
          style: theme.textTheme.displayMedium?.copyWith(
            fontFamily: 'ElMessiri',
            color: AppColors.primary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إرسال طلب المزامنة للرفع')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
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
