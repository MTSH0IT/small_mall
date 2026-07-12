import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/di/injection.dart';
import 'package:artisan_gift_manager/features/inventory/data/inventory_repository.dart';
import 'package:artisan_gift_manager/features/pos/data/pos_repository.dart';
import 'package:artisan_gift_manager/features/customers_debts/data/customers_debts_repository.dart';
import 'package:artisan_gift_manager/core/widgets/price_tag_chip.dart';
import 'package:artisan_gift_manager/core/widgets/loading_indicator.dart';
import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:intl/intl.dart' hide TextDirection;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  double _todaySales = 0.0;
  int _lowStockCount = 0;
  double _outstandingDebts = 0.0;
  List<ProductWithDetails> _lowStockProducts = [];
  List<Invoice> _recentSales = [];

  final _inventoryRepo = getIt<InventoryRepository>();
  final _posRepo = getIt<POSRepository>();
  final _debtsRepo = getIt<CustomersDebtsRepository>();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load outstanding debts
      final customers = await _debtsRepo.getCustomers();
      double totalDebts = customers.fold(0.0, (sum, c) => sum + c.totalDebt);

      // 2. Load today's sales
      final sales = await _posRepo.getRecentSales();
      final now = DateTime.now();
      final todaySalesList = sales.where((s) {
        return s.createdAt.year == now.year &&
            s.createdAt.month == now.month &&
            s.createdAt.day == now.day;
      }).toList();
      double todayTotal = todaySalesList.fold(0.0, (sum, s) => sum + s.totalAmount);

      // 3. Load low stock items
      final products = await _inventoryRepo.getProducts();
      final lowStockList = products.where((p) => p.isLowStock).toList();

      setState(() {
        _outstandingDebts = totalDebts;
        _todaySales = todayTotal;
        _lowStockCount = lowStockList.length;
        _lowStockProducts = lowStockList;
        _recentSales = sales.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const LoadingIndicator(message: 'جاري تحميل لوحة التحكم...');
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'لوحة التحكم',
          style: theme.textTheme.displayMedium?.copyWith(
            fontFamily: 'ElMessiri',
            color: AppColors.primary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row of Stat Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'مبيعات اليوم',
                    value: '${_todaySales.toStringAsFixed(2)} د.أ',
                    icon: Icons.monetization_on_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'تنبيهات المخزون',
                    value: _lowStockCount.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: _lowStockCount > 0 ? AppColors.danger : AppColors.success,
                    badge: _lowStockCount > 0 ? 'مخزون منخفض' : 'سليم',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'الديون المستحقة للعملاء',
                    value: '${_outstandingDebts.toStringAsFixed(2)} د.أ',
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Quick Actions Section
            Text(
              'إجراءات سريعة',
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'ElMessiri',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQuickActionBtn(
                  context,
                  label: 'بيع منتجات',
                  icon: Icons.shopping_basket_outlined,
                  route: '/pos',
                ),
                const SizedBox(width: 12),
                _buildQuickActionBtn(
                  context,
                  label: 'إضافة منتج',
                  icon: Icons.add_circle_outline,
                  route: '/products',
                ),
                const SizedBox(width: 12),
                _buildQuickActionBtn(
                  context,
                  label: 'إضافة عميل',
                  icon: Icons.person_add_alt,
                  route: '/customers',
                ),
                const SizedBox(width: 12),
                _buildQuickActionBtn(
                  context,
                  label: 'فاتورة مشتريات',
                  icon: Icons.receipt_long_outlined,
                  route: '/suppliers',
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Dual Column Layout for Tables
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Low Stock Warning List
                Expanded(
                  flex: 3,
                  child: _buildCardContainer(
                    title: 'المنتجات منخفضة المخزون',
                    child: _lowStockProducts.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text('جميع المنتجات متوفرة بمخزون كافٍ'),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _lowStockProducts.length,
                            separatorBuilder: (_, __) => const Divider(color: AppColors.border),
                            itemBuilder: (context, index) {
                              final item = _lowStockProducts[index];
                              return ListTile(
                                leading: const Icon(Icons.warning, color: AppColors.danger),
                                title: Text(item.product.name),
                                subtitle: Text('الحد الأدنى: ${item.product.minStockAlert.toStringAsFixed(0)}'),
                                trailing: PriceTagChip(
                                  label: 'المتوفر: ${item.currentStock.toStringAsFixed(0)}',
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(width: 24),
                // Recent Invoices List
                Expanded(
                  flex: 4,
                  child: _buildCardContainer(
                    title: 'آخر المبيعات اليومية',
                    child: _recentSales.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text('لم يتم تسجيل مبيعات اليوم بعد'),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _recentSales.length,
                            separatorBuilder: (_, __) => const Divider(color: AppColors.border),
                            itemBuilder: (context, index) {
                              final item = _recentSales[index];
                              final timeStr = DateFormat('hh:mm a').format(item.createdAt);
                              final typeStr = item.paymentType == 'debt' ? 'آجل' : 'نقدي';
                              final color = item.paymentType == 'debt' ? AppColors.accent : AppColors.success;

                              return ListTile(
                                leading: Icon(Icons.receipt, color: color),
                                title: Text('فاتورة مبيعات - $typeStr'),
                                subtitle: Text(timeStr),
                                trailing: Text(
                                  '${item.totalAmount.toStringAsFixed(2)} د.أ',
                                  style: AppTheme.numericStyle(fontWeight: FontWeight.bold, color: color),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? badge,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: AppTheme.numericStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                )
              ]
            ],
          ),
          Icon(icon, size: 40, color: color.withOpacity(0.6)),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String route,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => context.go(route),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: const BorderSide(color: AppColors.primary, width: 1.2),
          backgroundColor: AppColors.surfaceElevated,
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
        ),
      ),
    );
  }

  Widget _buildCardContainer({required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'ElMessiri',
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          child,
        ],
      ),
    );
  }
}
