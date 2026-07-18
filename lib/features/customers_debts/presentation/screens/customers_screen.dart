import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:artisan_gift_manager/core/di/injection.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/widgets/app_screen_scaffold.dart';
import 'package:artisan_gift_manager/core/widgets/app_text_field.dart';
import 'package:artisan_gift_manager/core/widgets/entity_form_dialog.dart';
import 'package:artisan_gift_manager/core/widgets/loading_indicator.dart';
import 'package:artisan_gift_manager/core/widgets/primary_button.dart';
import 'package:artisan_gift_manager/core/widgets/search_bar_with_action.dart';
import 'package:artisan_gift_manager/core/widgets/split_pane_layout.dart';
import 'package:artisan_gift_manager/features/customers_debts/data/customers_debts_repository.dart';
import 'package:artisan_gift_manager/features/customers_debts/presentation/cubit/customers_debts_cubit.dart';
import 'package:artisan_gift_manager/features/customers_debts/presentation/cubit/customers_debts_state.dart';
import 'package:artisan_gift_manager/features/customers_debts/presentation/widgets/customer_details_panel.dart';
import 'package:artisan_gift_manager/features/customers_debts/presentation/widgets/customers_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

          return AppScreenScaffold(
            title: 'العملاء والديون',
            onRefresh: () => cubit.loadCustomers(),
            body: SplitPaneLayout(
              leftChild: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SearchBarWithAction(
                      searchLabel: 'بحث عن عميل',
                      searchHint: 'ابحث بالاسم أو الهاتف...',
                      searchController: _searchController,
                      onSearchChanged: (val) => _searchQuery = val,
                      actionLabel: 'إضافة عميل',
                      actionIcon: Icons.person_add,
                      onActionPressed: () => _showAddCustomerDialog(context, cubit),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildCustomersList(context, cubit, state)),
                  ],
                ),
              ),
              rightChild: _buildCustomerDetails(context, cubit, state),
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
        onEditCustomer: () => _showEditCustomerDialog(context, cubit, customerData.customer),
      );
    }

    return const SizedBox();
  }

  void _showAddCustomerDialog(BuildContext context, CustomersDebtsCubit cubit) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => EntityFormDialog(
        title: 'إضافة عميل جديد',
        saveLabel: 'حفظ العميل',
        nameController: nameController,
        phoneController: phoneController,
        notesController: notesController,
        onSave: () async {
          await cubit.addCustomer(
            name: nameController.text,
            phone: phoneController.text.isNotEmpty ? phoneController.text : null,
            notes: notesController.text.isNotEmpty ? notesController.text : null,
          );
        },
      ),
    );
  }

  void _showEditCustomerDialog(BuildContext context, CustomersDebtsCubit cubit, Customer customer) {
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);
    final notesController = TextEditingController(text: customer.notes);

    showDialog(
      context: context,
      builder: (_) => EntityFormDialog(
        title: 'تعديل بيانات العميل',
        saveLabel: 'حفظ التعديلات',
        nameController: nameController,
        phoneController: phoneController,
        notesController: notesController,
        onSave: () async {
          await cubit.updateCustomer(
            id: customer.id,
            name: nameController.text,
            phone: phoneController.text.isNotEmpty ? phoneController.text : null,
            notes: notesController.text.isNotEmpty ? notesController.text : null,
          );
        },
      ),
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
                  Text('الحد الأقصى للدفع: ${debtData.debt.remainingAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'قيمة الدفعة المسددة *',
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
