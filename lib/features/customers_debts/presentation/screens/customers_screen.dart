import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/di/injection.dart';
import 'package:artisan_gift_manager/core/widgets/price_tag_chip.dart';
import 'package:artisan_gift_manager/core/widgets/primary_button.dart';
import 'package:artisan_gift_manager/core/widgets/app_text_field.dart';
import 'package:artisan_gift_manager/core/widgets/loading_indicator.dart';
import 'package:artisan_gift_manager/features/customers_debts/presentation/cubit/customers_debts_cubit.dart';
import 'package:artisan_gift_manager/features/customers_debts/data/customers_debts_repository.dart';
import 'package:intl/intl.dart' hide TextDirection;

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider<CustomersDebtsCubit>(
      create: (context) => CustomersDebtsCubit(getIt<CustomersDebtsRepository>())..loadCustomers(),
      child: BlocConsumer<CustomersDebtsCubit, CustomersDebtsState>(
        listener: (context, state) {
          if (state is CustomersDebtsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.danger),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<CustomersDebtsCubit>();

          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              title: Text(
                'العملاء والديون',
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
                  onPressed: () => cubit.loadCustomers(),
                ),
              ],
            ),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Right Pane: Customers List (40% width)
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search bar & Add Customer Button
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: 'بحث عن عميل',
                                hint: 'ابحث بالاسم أو الهاتف...',
                                controller: _searchController,
                                onChanged: (val) {
                                  setState(() => _searchQuery = val);
                                },
                                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 22.0),
                              child: PrimaryButton(
                                label: 'إضافة عميل',
                                icon: Icons.person_add,
                                onPressed: () => _showAddCustomerDialog(context, cubit),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // List
                        Expanded(
                          child: _buildCustomersList(context, cubit, state),
                        ),
                      ],
                    ),
                  ),
                ),
                // Divider
                const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
                // Left Pane: Customer Details (60% width)
                Expanded(
                  flex: 3,
                  child: _buildCustomerDetails(context, cubit, state),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomersList(BuildContext context, CustomersDebtsCubit cubit, CustomersDebtsState state) {
    if (state is CustomersDebtsLoading) {
      return const LoadingIndicator(message: 'جاري تحميل قائمة العملاء...');
    }

    if (state is CustomersDebtsLoaded) {
      final filtered = state.customers.where((c) {
        final matchName = c.customer.name.contains(_searchQuery);
        final matchPhone = c.customer.phone?.contains(_searchQuery) ?? false;
        return matchName || matchPhone;
      }).toList();

      if (filtered.isEmpty) {
        return const Center(child: Text('لا يوجد عملاء مطابقين للبحث.'));
      }

      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
          itemBuilder: (context, index) {
            final item = filtered[index];
            final isSelected = state.selectedCustomerId == item.customer.id;

            return ListTile(
              selected: isSelected,
              selectedTileColor: AppColors.primary.withOpacity(0.05),
              title: Text(item.customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.customer.phone ?? 'بدون هاتف'),
              trailing: PriceTagChip(
                label: 'الدين: ${item.totalDebt.toStringAsFixed(1)} د.أ',
                backgroundColor: item.totalDebt > 0 ? AppColors.accent : AppColors.success,
                cutSize: 6,
              ),
              onTap: () => cubit.selectCustomer(item.customer.id),
            );
          },
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildCustomerDetails(BuildContext context, CustomersDebtsCubit cubit, CustomersDebtsState state) {
    final theme = Theme.of(context);

    if (state is CustomersDebtsLoaded) {
      final custId = state.selectedCustomerId;
      if (custId == null) {
        return const Center(
          child: Text('اختر عميلاً من القائمة لعرض كشف الحساب وتفاصيل الديون والمدفوعات'),
        );
      }

      final customerData = state.customers.firstWhere((c) => c.customer.id == custId);
      final debts = state.selectedCustomerDebts;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Header Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerData.customer.name,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontFamily: 'ElMessiri',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (customerData.customer.phone != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(customerData.customer.phone!, style: AppTheme.numericStyle()),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (customerData.customer.notes != null)
                        Text('ملاحظات: ${customerData.customer.notes!}', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('إجمالي الدين المستحق:', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Text(
                        '${customerData.totalDebt.toStringAsFixed(2)} د.أ',
                        style: AppTheme.numericStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: customerData.totalDebt > 0 ? AppColors.accent : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Debts List
            Text(
              'سجل الفواتير الآجلة والمدفوعات',
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'ElMessiri',
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            if (debts == null)
              const LoadingIndicator(message: 'جاري تحميل الديون...')
            else if (debts.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد ديون مسجلة على هذا العميل.')))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: debts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final debtData = debts[index];
                  final dateStr = DateFormat('yyyy/MM/dd hh:mm a').format(debtData.debt.createdAt);

                  final statusStr = debtData.debt.status == 'paid'
                      ? 'مدفوع كامل'
                      : (debtData.debt.status == 'partial' ? 'مدفوع جزئي' : 'غير مدفوع');
                  final statusColor = debtData.debt.status == 'paid'
                      ? AppColors.success
                      : (debtData.debt.status == 'partial' ? AppColors.primary : AppColors.danger);

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'فاتورة مبيعات آجل - $dateStr',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            PriceTagChip(
                              label: statusStr,
                              backgroundColor: statusColor,
                              cutSize: 6,
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.border, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('القيمة الأصلية للبيع:', style: theme.textTheme.labelSmall),
                                Text('${debtData.debt.amount.toStringAsFixed(2)} د.أ', style: AppTheme.numericStyle()),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('المتبقي للتسديد:', style: theme.textTheme.labelSmall),
                                Text(
                                  '${debtData.debt.remainingAmount.toStringAsFixed(2)} د.أ',
                                  style: AppTheme.numericStyle(
                                    fontWeight: FontWeight.bold,
                                    color: debtData.debt.remainingAmount > 0 ? AppColors.accent : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            if (debtData.debt.remainingAmount > 0)
                              PrimaryButton(
                                label: 'تسجيل دفعة',
                                icon: Icons.payments,
                                onPressed: () => _showRecordPaymentDialog(context, cubit, customerData.customer.id, debtData),
                              ),
                          ],
                        ),
                        if (debtData.payments.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('المدفوعات السابقة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          const SizedBox(height: 4),
                          ...debtData.payments.map((p) {
                            final payDate = DateFormat('yyyy/MM/dd hh:mm a').format(p.paidAt);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('دفعة سداد بتاريخ: $payDate', style: theme.textTheme.labelSmall),
                                  Text(
                                    '- ${p.amountPaid.toStringAsFixed(2)} د.أ',
                                    style: AppTheme.numericStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      );
    }

    return const SizedBox();
  }

  void _showAddCustomerDialog(BuildContext context, CustomersDebtsCubit cubit) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة عميل جديد', style: TextStyle(fontFamily: 'ElMessiri', color: AppColors.primary)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    label: 'اسم العميل *',
                    controller: nameController,
                    validator: (val) => val == null || val.isEmpty ? 'الرجاء إدخال الاسم' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'رقم الهاتف',
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'ملاحظات',
                    controller: notesController,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              PrimaryButton(
                label: 'حفظ العميل',
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    cubit.addCustomer(
                      name: nameController.text,
                      phone: phoneController.text.isNotEmpty ? phoneController.text : null,
                      notes: notesController.text.isNotEmpty ? notesController.text : null,
                    );
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRecordPaymentDialog(
    BuildContext context,
    CustomersDebtsCubit cubit,
    String customerId,
    DebtWithPayments debtData,
  ) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: debtData.debt.remainingAmount.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تسجيل دفعة سداد دين', style: TextStyle(fontFamily: 'ElMessiri', color: AppColors.primary)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('الحد الأقصى للدفع: ${debtData.debt.remainingAmount.toStringAsFixed(2)} د.أ'),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'قيمة الدفعة المسددة (د.أ) *',
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'يرجى إدخال القيمة';
                      final parsed = double.tryParse(val);
                      if (parsed == null || parsed <= 0) return 'يرجى إدخال مبلغ صحيح أكبر من 0';
                      if (parsed > debtData.debt.remainingAmount) return 'المبلغ يتعدى قيمة الدين المتبقي!';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              PrimaryButton(
                label: 'تسجيل دفعة السداد',
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    cubit.recordPayment(
                      customerId: customerId,
                      debtId: debtData.debt.id,
                      amountPaid: double.parse(amountController.text),
                    );
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
