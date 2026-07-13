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
import 'package:artisan_gift_manager/features/customers_debts/presentation/widgets/customers_list.dart';
import 'package:artisan_gift_manager/features/customers_debts/presentation/widgets/customer_details_panel.dart';
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
      return CustomersList(
        customers: state.customers,
        selectedCustomerId: state.selectedCustomerId,
        searchQuery: _searchQuery,
        onSelectCustomer: (id) => cubit.selectCustomer(id),
      );
    }

    return const SizedBox();
  }

  Widget _buildCustomerDetails(BuildContext context, CustomersDebtsCubit cubit, CustomersDebtsState state) {
    if (state is CustomersDebtsLoaded) {
      final custId = state.selectedCustomerId;
      if (custId == null) {
        return const Center(
          child: Text('اختر عميلاً من القائمة لعرض كشف الحساب وتفاصيل الديون والمدفوعات'),
        );
      }

      final customerData = state.customers.firstWhere((c) => c.customer.id == custId);
      final debts = state.selectedCustomerDebts;

      return CustomerDetailsPanel(
        customerData: customerData,
        debts: debts,
        onRecordPayment: (debtData) => _showRecordPaymentDialog(context, cubit, customerData.customer.id, debtData),
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
