import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_screen_scaffold.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/split_pane_layout.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_cubit.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_state.dart';
import 'package:small_mall/features/invoices/presentation/widgets/invoice_detail_panel.dart';
import 'package:small_mall/features/invoices/presentation/widgets/invoice_list.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
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
            title: 'الفواتير',
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
          _buildFilterChips(cubit, state),
          const SizedBox(height: 12),
          if (state is InvoicesLoaded) _buildSummaryCards(state),
          const SizedBox(height: 12),
          Expanded(child: _buildInvoiceList(cubit, state)),
        ],
      ),
    );
  }

  Widget _buildFilterChips(InvoicesCubit cubit, InvoicesState state) {
    final currentFilter = state is InvoicesLoaded ? state.typeFilter : 'all';

    return Row(
      children: [
        ChoiceChip(
          label: const Text('الكل'),
          selected: currentFilter == 'all',
          onSelected: (_) => cubit.setTypeFilter('all'),
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            color: currentFilter == 'all' ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('مبيعات'),
          selected: currentFilter == 'sale',
          onSelected: (_) => cubit.setTypeFilter('sale'),
          selectedColor: AppColors.success,
          labelStyle: TextStyle(
            color: currentFilter == 'sale' ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('مرتجعات'),
          selected: currentFilter == 'return',
          onSelected: (_) => cubit.setTypeFilter('return'),
          selectedColor: AppColors.danger,
          labelStyle: TextStyle(
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
            'المبيعات',
            '${loaded.salesCount}',
            loaded.totalSalesAmount.toStringAsFixed(2),
            AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniStat(
            'المرتجعات',
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
              Text('$count فاتورة', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(amount, style: AppTheme.numericStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(InvoicesCubit cubit, InvoicesState state) {
    if (state is InvoicesLoading) {
      return const LoadingIndicator(message: 'جاري تحميل الفواتير...');
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
      return const Center(
        child: Text('اختر فاتورة من القائمة لعرض التفاصيل'),
      );
    }

    return const SizedBox();
  }
}
