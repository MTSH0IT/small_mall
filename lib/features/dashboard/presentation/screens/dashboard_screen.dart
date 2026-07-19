import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/card_container.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/price_tag_chip.dart';
import 'package:small_mall/core/widgets/stat_card.dart';
import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';
import 'package:small_mall/features/dashboard/presentation/widgets/quick_action_button.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';
import 'package:flutter/material.dart';
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

    return AppScreenScaffold(
      title: 'لوحة التحكم',
      onRefresh: _loadDashboardData,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row of Stat Cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'مبيعات اليوم',
                    value: _todaySales.toStringAsFixed(2),
                    icon: Icons.monetization_on_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'تنبيهات المخزون',
                    value: _lowStockCount.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: _lowStockCount > 0 ? AppColors.danger : AppColors.success,
                    badge: _lowStockCount > 0 ? 'مخزون منخفض' : 'سليم',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'الديون المستحقة للعملاء',
                    value: _outstandingDebts.toStringAsFixed(2),
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
                QuickActionButton(
                  label: 'بيع منتجات',
                  icon: Icons.shopping_basket_outlined,
                  route: '/pos',
                ),
                const SizedBox(width: 12),
                QuickActionButton(
                  label: 'إضافة منتج',
                  icon: Icons.add_circle_outline,
                  route: '/products',
                ),
                const SizedBox(width: 12),
                QuickActionButton(
                  label: 'إضافة عميل',
                  icon: Icons.person_add_alt,
                  route: '/customers',
                ),
                const SizedBox(width: 12),
                QuickActionButton(
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
                  child: CardContainer(
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
                            separatorBuilder: (_, _) => const Divider(color: AppColors.border),
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
                  child: CardContainer(
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
                            separatorBuilder: (_, _) => const Divider(color: AppColors.border),
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
                                  item.totalAmount.toStringAsFixed(2),
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
}
