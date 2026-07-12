import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/di/injection.dart';
import 'package:artisan_gift_manager/core/sync/sync_service.dart';
import 'package:artisan_gift_manager/core/widgets/primary_button.dart';
import 'package:artisan_gift_manager/core/widgets/app_text_field.dart';
import 'package:artisan_gift_manager/core/database/app_database.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _dbPath = 'جاري التحميل...';
  int _pendingCount = 0;
  bool _isSaving = false;
  final _syncService = getIt<SyncService>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final dbFolder = await getApplicationDocumentsDirectory();

    setState(() {
      _urlController.text = prefs.getString('supabase_url') ?? '';
      _keyController.text = prefs.getString('supabase_anon_key') ?? '';
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
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveSupabaseConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _syncService.saveCredentials(
        _urlController.text.trim(),
        _keyController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ إعدادات Supabase والاتصال بنجاح. يرجى إعادة تشغيل التطبيق لتفعيل الاتصال الكامل.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الاتصال: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _clearConfig() async {
    setState(() => _isSaving = true);
    await _syncService.clearCredentials();
    _urlController.clear();
    _keyController.clear();
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف إعدادات الاتصال بنجاح. التطبيق يعمل الآن في وضع أوفلاين محلي.'), backgroundColor: AppColors.primary),
      );
    }
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
            // Supabase Config Section
            _buildSection(
              title: 'إعدادات المزامنة السحابية (Supabase)',
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'قم بربط تطبيقك بقاعدة بيانات Supabase لتمكين المزامنة والنسخ الاحتياطي التلقائي عند توفر الإنترنت.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: 'رابط المشروع (Supabase URL) *',
                      controller: _urlController,
                      hint: 'https://xxxxxx.supabase.co',
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'الرجاء إدخال رابط المشروع';
                        if (!val.startsWith('http')) return 'يجب أن يبدأ الرابط بـ http أو https';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'مفتاح الوصول العام (Anon Key) *',
                      controller: _keyController,
                      hint: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                      validator: (val) => val == null || val.isEmpty ? 'الرجاء إدخال مفتاح الوصول' : null,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        PrimaryButton(
                          label: 'حفظ وإعادة الاتصال',
                          icon: Icons.save_outlined,
                          onPressed: _saveSupabaseConfig,
                          isLoading: _isSaving,
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _clearConfig,
                          icon: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
                          label: const Text('حذف الإعدادات', style: TextStyle(color: AppColors.danger)),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Sync & Backup Control
            _buildSection(
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
                          if (mounted) {
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
            _buildSection(
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

  Widget _buildSection({required String title, required Widget child}) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'ElMessiri',
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
