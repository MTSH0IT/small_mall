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
import 'package:small_mall/features/invoices/presentation/cubit/invoices_cubit.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_state.dart';
import 'package:small_mall/features/invoices/presentation/widgets/invoice_detail_panel.dart';
import 'package:small_mall/features/invoices/presentation/widgets/invoice_list.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';

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
      create: (context) => InvoicesCubit(getIt<POSRepository>())..loadInvoices(),
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
          const SizedBox(height: 10),

          // 2. Date Filter Chips
          _buildDateFilterChips(context, cubit, state),
          const SizedBox(height: 8),

          // 3. Type Filter Chips
          _buildTypeFilterChips(cubit, state),
          const SizedBox(height: 12),

          // 4. Summary Cards (Sales & Returns)
          if (state is InvoicesLoaded) _buildSummaryCards(state),
          const SizedBox(height: 12),

          // 5. Invoices List
          Expanded(child: _buildInvoiceList(cubit, state)),
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

  Widget _buildDateFilterChips(BuildContext context, InvoicesCubit cubit, InvoicesState state) {
    final currentDateFilter = state is InvoicesLoaded ? state.dateFilter : 'all';
    final customRange = state is InvoicesLoaded ? state.customDateRange : null;

    final filters = [
      {'key': 'all', 'label': 'invoices.filter_all'.tr()},
      {'key': 'today', 'label': 'invoices.filter_today'.tr()},
      {'key': 'yesterday', 'label': 'invoices.filter_yesterday'.tr()},
      {'key': 'this_week', 'label': 'invoices.filter_this_week'.tr()},
      {'key': 'this_month', 'label': 'invoices.filter_this_month'.tr()},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...filters.map((f) {
                final isSelected = currentDateFilter == f['key'];
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(f['label']!),
                    selected: isSelected,
                    onSelected: (_) => cubit.setDateFilter(f['key']!),
                    selectedColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }),
              // Custom Date Chip
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 14),
                  label: Text(
                    currentDateFilter == 'custom' && customRange != null
                        ? '${DateFormat('MM/dd').format(customRange.start)} - ${DateFormat('MM/dd').format(customRange.end)}'
                        : 'invoices.filter_custom_date'.tr(),
                  ),
                  backgroundColor: currentDateFilter == 'custom'
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceElevated,
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: currentDateFilter == 'custom' ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: currentDateFilter == 'custom' ? FontWeight.bold : FontWeight.normal,
                  ),
                  onPressed: () async {
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
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeFilterChips(InvoicesCubit cubit, InvoicesState state) {
    final currentFilter = state is InvoicesLoaded ? state.typeFilter : 'all';

    return Row(
      children: [
        ChoiceChip(
          label: Text('common.all'.tr()),
          selected: currentFilter == 'all',
          onSelected: (_) => cubit.setTypeFilter('all'),
          selectedColor: AppColors.primary,
          visualDensity: VisualDensity.compact,
          labelStyle: TextStyle(
            fontSize: 12,
            color: currentFilter == 'all' ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text('invoices.sale'.tr()),
          selected: currentFilter == 'sale',
          onSelected: (_) => cubit.setTypeFilter('sale'),
          selectedColor: AppColors.success,
          visualDensity: VisualDensity.compact,
          labelStyle: TextStyle(
            fontSize: 12,
            color: currentFilter == 'sale' ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text('invoices.return'.tr()),
          selected: currentFilter == 'return',
          onSelected: (_) => cubit.setTypeFilter('return'),
          selectedColor: AppColors.danger,
          visualDensity: VisualDensity.compact,
          labelStyle: TextStyle(
            fontSize: 12,
            color: currentFilter == 'return' ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(InvoicesLoaded loaded) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniStat(
            'invoices.sale'.tr(),
            '${loaded.salesCount}',
            loaded.totalSalesAmount.toStringAsFixed(2),
            AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
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
              Text(amount, style: AppTheme.numericStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(InvoicesCubit cubit, InvoicesState state) {
    if (state is InvoicesLoading) {
      return LoadingIndicator(message: 'common.loading'.tr());
    }

    if (state is InvoicesLoaded) {
      return InvoiceList(
        invoices: state.filteredInvoices,
        selectedInvoiceId: state.selectedInvoiceId,
        onSelectInvoice: (id) => cubit.selectInvoice(id),
      );
    }

    return const SizedBox();
  }

  Widget _buildRightPane(BuildContext context, InvoicesState state) {
    if (state is InvoicesLoaded) {
      final selected = state.selectedInvoice;
      if (selected != null) {
        return InvoiceDetailPanel(invoiceData: selected);
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
