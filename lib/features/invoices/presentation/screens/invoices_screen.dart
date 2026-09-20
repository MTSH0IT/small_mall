import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/split_pane_layout.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_cubit.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_state.dart';
import 'package:small_mall/features/invoices/presentation/widgets/invoice_detail_panel.dart';
import 'package:small_mall/features/invoices/presentation/widgets/invoice_list.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InvoicesCubit>(
      create: (context) => InvoicesCubit(getIt<InvoicesRepository>())..loadInvoices(),
      child: BlocConsumer<InvoicesCubit, InvoicesState>(
        listener: (context, state) {
          if (state is InvoicesError) {
            AppToast.error(context, message: state.message);
          }
        },
        builder: (context, state) {
          final cubit = context.read<InvoicesCubit>();

          return AppScreenScaffold(
            title: 'invoices.title'.tr(),
            onRefresh: () => cubit.loadInvoices(),
            body: SplitPaneLayout(
              leftFlex: 2,
              rightFlex: 3,
              leftChild: _buildLeftPane(context, cubit, state),
              rightChild: _buildRightPane(context, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeftPane(BuildContext context, InvoicesCubit cubit, InvoicesState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Search Bar
          _buildSearchBar(cubit),
          const SizedBox(height: 12),

          // 2. Dropdown Filters (Operation Type & Duration)
          _buildDropdownFilters(context, cubit, state),
          const SizedBox(height: 12),

          // 3. Dynamic Summary Cards
          if (state is InvoicesLoaded) _buildSummaryCards(state),
          const SizedBox(height: 12),

          // 4. Transactions List
          Expanded(child: _buildTransactionsList(cubit, state)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(InvoicesCubit cubit) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'invoices.search_hint'.tr(),
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  cubit.setSearchQuery('');
                  setState(() {});
                },
                splashRadius: 16,
              )
            : null,
        filled: true,
        fillColor: AppColors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      onChanged: (val) {
        cubit.setSearchQuery(val);
        setState(() {});
      },
    );
  }

  Widget _buildDropdownFilters(BuildContext context, InvoicesCubit cubit, InvoicesState state) {
    final currentType = state is InvoicesLoaded ? state.typeFilter : 'all';
    final currentDate = state is InvoicesLoaded ? state.dateFilter : 'all';
    final customRange = state is InvoicesLoaded ? state.customDateRange : null;

    final typeOptions = [
      {'key': 'all', 'label': 'invoices.all_types'.tr(), 'icon': Icons.layers_outlined, 'color': AppColors.primary},
      {'key': 'sale', 'label': 'invoices.sale'.tr(), 'icon': Icons.point_of_sale, 'color': AppColors.success},
      {'key': 'debt_invoice', 'label': 'invoices.debt_invoice'.tr(), 'icon': Icons.request_quote, 'color': AppColors.warning},
      {'key': 'debt_payment', 'label': 'invoices.debt_payment'.tr(), 'icon': Icons.payments, 'color': const Color(0xFF7C3AED)},
      {'key': 'return', 'label': 'invoices.return'.tr(), 'icon': Icons.replay, 'color': AppColors.danger},
      {'key': 'purchase', 'label': 'invoices.purchase'.tr(), 'icon': Icons.local_shipping, 'color': const Color(0xFF2563EB)},
      {'key': 'expense', 'label': 'invoices.expense'.tr(), 'icon': Icons.account_balance_wallet, 'color': const Color(0xFFEA580C)},
      {'key': 'adjustment', 'label': 'invoices.adjustment'.tr(), 'icon': Icons.tune, 'color': const Color(0xFF0D9488)},
    ];

    final dateOptions = [
      {'key': 'all', 'label': 'invoices.filter_all'.tr()},
      {'key': 'today', 'label': 'invoices.filter_today'.tr()},
      {'key': 'yesterday', 'label': 'invoices.filter_yesterday'.tr()},
      {'key': 'this_week', 'label': 'invoices.filter_this_week'.tr()},
      {'key': 'this_month', 'label': 'invoices.filter_this_month'.tr()},
      {'key': 'custom', 'label': 'invoices.filter_custom_date'.tr()},
    ];

    return Column(
      children: [
        Row(
          children: [
            // 1. Operation Type Dropdown
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: currentType,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 20),
                    borderRadius: BorderRadius.circular(10),
                    items: typeOptions.map((opt) {
                      final isSelected = opt['key'] == currentType;
                      final color = opt['color'] as Color;
                      final icon = opt['icon'] as IconData;

                      return DropdownMenuItem<String>(
                        value: opt['key'] as String,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 16, color: color),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                opt['label'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? color : AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) cubit.setTypeFilter(val);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 2. Duration / Date Filter Dropdown
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: currentDate,
                    icon: const Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 16),
                    borderRadius: BorderRadius.circular(10),
                    items: dateOptions.map((opt) {
                      final isSelected = opt['key'] == currentDate;
                      return DropdownMenuItem<String>(
                        value: opt['key'] as String,
                        child: Text(
                          opt['label'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) async {
                      if (val == null) return;
                      if (val == 'custom') {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: customRange ??
                              DateTimeRange(
                                start: DateTime.now().subtract(const Duration(days: 7)),
                                end: DateTime.now(),
                              ),
                        );
                        if (picked != null) {
                          cubit.setDateFilter('custom', range: picked);
                        }
                      } else {
                        cubit.setDateFilter(val);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),

        // Custom Date Range indicator if active
        if (currentDate == 'custom' && customRange != null) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: customRange,
              );
              if (picked != null) {
                cubit.setDateFilter('custom', range: picked);
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_calendar, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('yyyy-MM-dd').format(customRange.start)} - ${DateFormat('yyyy-MM-dd').format(customRange.end)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryCards(InvoicesLoaded loaded) {
    final type = loaded.typeFilter;

    // When a specific filter is chosen, show focused metrics
    if (type == 'sale') {
      return Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              'invoices.summary_sales'.tr(),
              '${loaded.salesCount}',
              loaded.totalSalesAmount.toStringAsFixed(2),
              AppColors.success,
            ),
          ),
        ],
      );
    }

    if (type == 'debt_invoice' || type == 'debt') {
      return Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              'invoices.debt_invoice'.tr(),
              '${loaded.debtInvoicesCount}',
              loaded.totalDebtInvoicesAmount.toStringAsFixed(2),
              AppColors.warning,
            ),
          ),
        ],
      );
    }

    if (type == 'return') {
      return Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              'invoices.return'.tr(),
              '${loaded.returnsCount}',
              loaded.totalReturnsAmount.toStringAsFixed(2),
              AppColors.danger,
            ),
          ),
        ],
      );
    }

    if (type == 'purchase') {
      return Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              'invoices.summary_purchases'.tr(),
              '${loaded.purchasesCount}',
              loaded.totalPurchasesAmount.toStringAsFixed(2),
              const Color(0xFF2563EB),
            ),
          ),
        ],
      );
    }

    if (type == 'expense') {
      return Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              'invoices.summary_expenses'.tr(),
              '${loaded.expensesCount}',
              loaded.totalExpensesAmount.toStringAsFixed(2),
              const Color(0xFFEA580C),
            ),
          ),
        ],
      );
    }

    if (type == 'debt_payment') {
      return Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              'invoices.summary_debt_payments'.tr(),
              '${loaded.debtPaymentsCount}',
              loaded.totalDebtPaymentsAmount.toStringAsFixed(2),
              const Color(0xFF7C3AED),
            ),
          ),
        ],
      );
    }

    if (type == 'adjustment') {
      return Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              'invoices.adjustment'.tr(),
              '${loaded.adjustmentsCount}',
              '${loaded.adjustmentsCount} ${'inventory.adjustments'.tr()}',
              const Color(0xFF0D9488),
            ),
          ),
        ],
      );
    }

    // Default 'all': 3 key metrics (Sales, Purchases, Expenses)
    return Row(
      children: [
        Expanded(
          child: _buildMiniStat(
            'invoices.summary_sales'.tr(),
            '${loaded.salesCount}',
            loaded.totalSalesAmount.toStringAsFixed(2),
            AppColors.success,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildMiniStat(
            'invoices.summary_purchases'.tr(),
            '${loaded.purchasesCount}',
            loaded.totalPurchasesAmount.toStringAsFixed(2),
            const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildMiniStat(
            'invoices.summary_expenses'.tr(),
            '${loaded.expensesCount}',
            loaded.totalExpensesAmount.toStringAsFixed(2),
            const Color(0xFFEA580C),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String count, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(count, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(amount, style: AppTheme.numericStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(InvoicesCubit cubit, InvoicesState state) {
    if (state is InvoicesLoading) {
      return LoadingIndicator(message: 'common.loading'.tr());
    }

    if (state is InvoicesLoaded) {
      return InvoiceList(
        transactions: state.filteredTransactions,
        selectedTransactionId: state.selectedTransactionId,
        onSelectTransaction: (id) => cubit.selectTransaction(id),
      );
    }

    return const SizedBox();
  }

  Widget _buildRightPane(BuildContext context, InvoicesState state) {
    if (state is InvoicesLoaded) {
      final selected = state.selectedTransaction;
      if (selected != null) {
        return InvoiceDetailPanel(transaction: selected);
      }
      return Center(
        child: EmptyStateView(
          icon: Icons.receipt_long_outlined,
          title: 'invoices.details'.tr(),
          description: 'invoices.select_invoice_to_view'.tr(),
        ),
      );
    }

    return const SizedBox();
  }
}
