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
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/core/widgets/split_pane_layout.dart';
import 'package:small_mall/features/expenses/data/expenses_repository.dart';
import 'package:small_mall/features/expenses/presentation/cubit/expenses_cubit.dart';
import 'package:small_mall/features/expenses/presentation/cubit/expenses_state.dart';
import 'package:small_mall/features/expenses/presentation/widgets/category_form_dialog.dart';
import 'package:small_mall/features/expenses/presentation/widgets/expense_form_dialog.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddCategoryDialog(BuildContext context, ExpensesCubit cubit) {
    showDialog(
      context: context,
      builder: (_) => CategoryFormDialog(
        onSave: ({required name, description}) =>
            cubit.addCategory(name: name, description: description),
      ),
    );
  }

  void _showEditCategoryDialog(
    BuildContext context,
    ExpensesCubit cubit,
    ExpenseCategory category,
  ) {
    showDialog(
      context: context,
      builder: (_) => CategoryFormDialog(
        initialCategory: category,
        onSave: ({required name, description}) =>
            cubit.updateCategory(id: category.id, name: name, description: description),
      ),
    );
  }

  void _showDeleteCategoryDialog(
    BuildContext context,
    ExpensesCubit cubit,
    ExpenseCategory category,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('expenses.delete_category'.tr(),
            style: const TextStyle(color: AppColors.danger)),
        content: Text(
          'expenses.confirm_delete_category'
              .tr(args: [category.name]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
          PrimaryButton(
            label: 'common.delete'.tr(),
            backgroundColor: AppColors.danger,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await cubit.deleteCategory(category.id);
            },
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(
    BuildContext context,
    ExpensesCubit cubit,
    List<ExpenseCategory> categories,
    String? preselectedCategoryId,
  ) {
    if (categories.isEmpty) {
      AppToast.error(context, message: 'expenses.no_categories_warning'.tr());
      return;
    }

    showDialog(
      context: context,
      builder: (_) => ExpenseFormDialog(
        categories: categories,
        preselectedCategoryId: preselectedCategoryId,
        onSave: ({
          required categoryId,
          required amount,
          notes,
          required createdAt,
        }) =>
            cubit.addExpense(
          categoryId: categoryId,
          amount: amount,
          notes: notes,
          createdAt: createdAt,
        ),
      ),
    );
  }

  void _showEditExpenseDialog(
    BuildContext context,
    ExpensesCubit cubit,
    List<ExpenseCategory> categories,
    ExpenseWithCategory item,
  ) {
    showDialog(
      context: context,
      builder: (_) => ExpenseFormDialog(
        categories: categories,
        initialExpense: item.expense,
        onSave: ({
          required categoryId,
          required amount,
          notes,
          required createdAt,
        }) =>
            cubit.updateExpense(
          id: item.expense.id,
          categoryId: categoryId,
          amount: amount,
          notes: notes,
          createdAt: createdAt,
        ),
      ),
    );
  }

  void _showDeleteExpenseDialog(
    BuildContext context,
    ExpensesCubit cubit,
    ExpenseWithCategory item,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('expenses.delete_expense'.tr(),
            style: const TextStyle(color: AppColors.danger)),
        content: Text(
          'expenses.confirm_delete_expense'.tr(
            args: [item.expense.amount.toStringAsFixed(2)],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
          PrimaryButton(
            label: 'common.delete'.tr(),
            backgroundColor: AppColors.danger,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await cubit.deleteExpense(item.expense.id);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(
    BuildContext context,
    ExpensesCubit cubit,
    DateTime? currentStart,
    DateTime? currentEnd,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: currentStart != null && currentEnd != null
          ? DateTimeRange(start: currentStart, end: currentEnd)
          : null,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: context.locale,
    );

    if (picked != null) {
      final start = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
      final end = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      cubit.setDateRange(start, end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ExpensesCubit>(
      create: (_) => ExpensesCubit(getIt<ExpensesRepository>())..loadExpenses(),
      child: BlocConsumer<ExpensesCubit, ExpensesState>(
        listener: (context, state) {
          if (state is ExpensesError) {
            AppToast.error(context, message: state.message);
          } else if (state is ExpensesLoaded && state.errorMessage != null) {
            AppToast.error(context, message: state.errorMessage!);
            context.read<ExpensesCubit>().clearError();
          }
        },
        builder: (context, state) {
          final cubit = context.read<ExpensesCubit>();

          return AppScreenScaffold(
            title: 'expenses.title'.tr(),
            onRefresh: () => cubit.loadExpenses(),
            body: state is ExpensesLoading
                ? LoadingIndicator(message: 'common.loading'.tr())
                : state is ExpensesLoaded
                    ? SplitPaneLayout(
                        leftFlex: 2,
                        rightFlex: 3,
                        leftChild: _buildLeftPane(context, cubit, state),
                        rightChild: _buildRightPane(context, cubit, state),
                      )
                    : const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  // --- Left Pane: Categories List & Summary ---

  Widget _buildLeftPane(
    BuildContext context,
    ExpensesCubit cubit,
    ExpensesLoaded state,
  ) {
    final summariesMap = {
      for (final s in state.categorySummaries) s.category.id: s
    };

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Category Title + Add Category Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'expenses.categories_heading'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddCategoryDialog(context, cubit),
                icon: const Icon(Icons.add, size: 18),
                label: Text('expenses.add_category_btn'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // "All Categories" Selection Card
          InkWell(
            onTap: () => cubit.selectCategory(null),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: state.selectedCategoryId == null
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.selectedCategoryId == null
                      ? AppColors.primary
                      : Colors.grey.shade200,
                  width: state.selectedCategoryId == null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.all_inbox_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'expenses.all_categories'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: state.selectedCategoryId == null
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${state.expenses.length} ${'expenses.operations_count'.tr()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    state.totalAmount.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: state.selectedCategoryId == null
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Categories List
          Expanded(
            child: state.categories.isEmpty
                ? EmptyStateView(
                    icon: Icons.category_outlined,
                    title: 'expenses.no_categories'.tr(),
                    description: 'expenses.no_categories_desc'.tr(),
                  )
                : ListView.separated(
                    itemCount: state.categories.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final cat = state.categories[index];
                      final isSelected = state.selectedCategoryId == cat.id;
                      final summary = summariesMap[cat.id];
                      final catTotal = summary?.totalAmount ?? 0.0;
                      final catCount = summary?.count ?? 0;

                      return InkWell(
                        onTap: () => cubit.selectCategory(cat.id),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isSelected
                                          ? AppColors.primary
                                          : Colors.grey.shade400)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 20,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (cat.description != null &&
                                        cat.description!.isNotEmpty)
                                      Text(
                                        cat.description!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    Text(
                                      '$catCount ${'expenses.operations_count'.tr()}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    catTotal.toStringAsFixed(2),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        color: AppColors.textSecondary,
                                        onPressed: () => _showEditCategoryDialog(
                                          context,
                                          cubit,
                                          cat,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        color: AppColors.danger,
                                        onPressed: () => _showDeleteCategoryDialog(
                                          context,
                                          cubit,
                                          cat,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- Right Pane: Filtered Transactions History ---

  Widget _buildRightPane(
    BuildContext context,
    ExpensesCubit cubit,
    ExpensesLoaded state,
  ) {
    final filtered = state.filteredExpenses;
    final filteredTotal = state.filteredTotalAmount;

    // Determine current category name
    String categoryTitle = 'expenses.all_categories'.tr();
    if (state.selectedCategoryId != null) {
      final found = state.categories
          .where((c) => c.id == state.selectedCategoryId)
          .firstOrNull;
      if (found != null) {
        categoryTitle = found.name;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Bar: Category Title + New Expense Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    categoryTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filtered.length} ${'expenses.operations_count'.tr()}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddExpenseDialog(
                  context,
                  cubit,
                  state.categories,
                  state.selectedCategoryId,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text('expenses.add_expense_btn'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters Bar: Search Field + Date Range Picker + Reset
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'expenses.search_expenses'.tr(),
                  hint: 'expenses.search_hint'.tr(),
                  controller: _searchController,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  onChanged: (val) => cubit.setSearchQuery(val),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _selectDateRange(
                  context,
                  cubit,
                  state.startDate,
                  state.endDate,
                ),
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(
                  state.startDate != null && state.endDate != null
                      ? '${DateFormat('MM/dd').format(state.startDate!)} - ${DateFormat('MM/dd').format(state.endDate!)}'
                      : 'expenses.filter_period'.tr(),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (state.startDate != null || state.searchQuery.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'expenses.clear_filters'.tr(),
                  icon: const Icon(Icons.clear, color: AppColors.danger),
                  onPressed: () {
                    _searchController.clear();
                    cubit.setSearchQuery('');
                    cubit.setDateRange(null, null);
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Stat Card: Filtered Total Spent
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warning.withValues(alpha: 0.12),
                  AppColors.warning.withValues(alpha: 0.04),
                ],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, color: AppColors.warning, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'expenses.total_spent_in_selection'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  filteredTotal.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Transactions Table / List
          Expanded(
            child: filtered.isEmpty
                ? EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'expenses.no_expenses'.tr(),
                    description: 'expenses.no_expenses_desc'.tr(),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final exp = item.expense;
                      final catName = item.category?.name ?? 'expenses.uncategorized'.tr();

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              // Date & Time Box
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat('dd/MM').format(exp.createdAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('yyyy').format(exp.createdAt),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Details: Category + Notes
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        catName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    if (exp.notes != null && exp.notes!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        exp.notes!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Amount
                              Text(
                                exp.amount.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Actions: Edit / Delete
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    color: AppColors.textSecondary,
                                    tooltip: 'common.edit'.tr(),
                                    onPressed: () => _showEditExpenseDialog(
                                      context,
                                      cubit,
                                      state.categories,
                                      item,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    color: AppColors.danger,
                                    tooltip: 'common.delete'.tr(),
                                    onPressed: () => _showDeleteExpenseDialog(
                                      context,
                                      cubit,
                                      item,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
