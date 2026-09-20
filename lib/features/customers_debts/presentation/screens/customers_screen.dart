import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/entity_form_dialog.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/core/widgets/search_bar_with_action.dart';
import 'package:small_mall/core/widgets/split_pane_layout.dart';
import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';
import 'package:small_mall/features/customers_debts/presentation/cubit/customers_debts_cubit.dart';
import 'package:small_mall/features/customers_debts/presentation/cubit/customers_debts_state.dart';
import 'package:small_mall/features/customers_debts/presentation/widgets/customer_details_panel.dart';
import 'package:small_mall/features/customers_debts/presentation/widgets/customers_list.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CustomersDebtsCubit>(
      create: (context) => CustomersDebtsCubit(getIt<CustomersDebtsRepository>())..loadCustomers(),
      child: BlocConsumer<CustomersDebtsCubit, CustomersDebtsState>(
        listener: (context, state) {
          if (state is CustomersDebtsError) {
            AppToast.error(context, message: state.message);
          } else if (state is CustomersDebtsLoaded && state.errorMessage != null) {
            AppToast.error(context, message: state.errorMessage!);
          }
        },
        builder: (context, state) {
          final cubit = context.read<CustomersDebtsCubit>();

          return AppScreenScaffold(
            title: 'customers.title'.tr(),
            onRefresh: () => cubit.loadCustomers(),
            body: SplitPaneLayout(
              leftChild: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SearchBarWithAction(
                      searchLabel: 'customers.customer_name'.tr(),
                      searchHint: 'common.search'.tr(),
                      searchController: _searchController,
                      onSearchChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      actionLabel: 'customers.add_customer'.tr(),
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
      return LoadingIndicator(message: 'common.loading'.tr());
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
      final customerData = custId != null
          ? state.customers.where((c) => c.customer.id == custId).firstOrNull
          : null;

      if (customerData == null) {
        return Center(
          child: EmptyStateView(
            icon: Icons.person_search_outlined,
            title: 'customers.debt_history'.tr(),
            description: 'customers.select_customer_to_view'.tr(),
          ),
        );
      }
      final debts = state.selectedCustomerDebts;

      return CustomerDetailsPanel(
        customerData: customerData,
        debts: debts,
        onRecordPayment: (debtData) => _showRecordPaymentDialog(context, cubit, customerData.customer.id, debtData),
        onEditCustomer: () => _showEditCustomerDialog(context, cubit, customerData.customer),
        onDeleteCustomer: () => _showDeleteCustomerDialog(context, cubit, customerData),
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
        title: 'customers.add_customer'.tr(),
        saveLabel: 'common.save'.tr(),
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
        title: 'customers.edit_customer'.tr(),
        saveLabel: 'common.save'.tr(),
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
        return AlertDialog(
          title: Text('customers.record_payment_title'.tr(), style: const TextStyle(color: AppColors.primary)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${'customers.max_payment'.tr()} ${debtData.debt.remainingAmount.toStringAsFixed(2)}'),
                const SizedBox(height: 12),
                AppTextField(
                  label: '${'customers.payment_amount'.tr()} *',
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'common.required_field'.tr();
                    final parsed = double.tryParse(val);
                    if (parsed == null || parsed <= 0) return 'common.required_field'.tr();
                    if (parsed > debtData.debt.remainingAmount) return 'customers.payment_exceeds_debt'.tr();
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
            PrimaryButton(
              label: 'customers.confirm_payment'.tr(),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final amount = double.tryParse(amountController.text);
                  if (amount != null && amount > 0) {
                    cubit.recordPayment(
                      customerId: customerId,
                      debtId: debtData.debt.id,
                      amountPaid: amount,
                    );
                  }
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteCustomerDialog(
    BuildContext context,
    CustomersDebtsCubit cubit,
    CustomerWithDebts customerData,
  ) async {
    final check = await cubit.checkCanDeleteCustomer(customerData.customer.id);
    if (!context.mounted) return;

    final canDelete = check['canDelete'] == true;

    if (!canDelete) {
      final reason = check['reason'] as String? ?? 'customers.cannot_delete_customer_has_debt'.tr();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'customers.delete_customer_confirm_title'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Text(
            reason,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            PrimaryButton(
              label: 'common.close'.tr(),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
      return;
    }

    final invoicesCount = check['invoicesCount'] as int? ?? 0;
    final paymentsCount = check['paymentsCount'] as int? ?? 0;
    final message = (invoicesCount > 0 || paymentsCount > 0)
        ? 'customers.delete_customer_confirm_msg_with_invoices'.tr(namedArgs: {
            'name': customerData.customer.name,
            'count': invoicesCount.toString(),
            'paymentsCount': paymentsCount.toString(),
          })
        : 'customers.delete_customer_confirm_msg'.tr(namedArgs: {
            'name': customerData.customer.name,
          });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'customers.delete_customer_confirm_title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: AppColors.textSecondary)),
          ),
          PrimaryButton(
            label: 'common.delete'.tr(),
            backgroundColor: AppColors.danger,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await cubit.deleteCustomer(customerData.customer.id);
                if (!context.mounted) return;
                AppToast.success(context, message: 'customers.customer_deleted'.tr());
              } catch (e) {
                if (!context.mounted) return;
                AppToast.error(context, message: e.toString());
              }
            },
          ),
        ],
      ),
    );
  }
}
