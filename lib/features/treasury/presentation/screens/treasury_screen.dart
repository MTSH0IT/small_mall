import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/core/constants/app_currency.dart';
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
import 'package:small_mall/features/currency_exchange/presentation/widgets/new_exchange_dialog.dart';
import 'package:small_mall/features/treasury/data/treasury_repository.dart';
import 'package:small_mall/features/treasury/presentation/cubit/treasury_cubit.dart';
import 'package:small_mall/features/treasury/presentation/cubit/treasury_state.dart';
import 'package:small_mall/features/treasury/presentation/widgets/treasury_category_form_dialog.dart';
import 'package:small_mall/features/treasury/presentation/widgets/treasury_ledger_view.dart';
import 'package:small_mall/features/treasury/presentation/widgets/treasury_transaction_form_dialog.dart';
import 'package:small_mall/features/treasury/presentation/widgets/treasury_vault_cards.dart';

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Category Dialogs ---

  void _showAddCategoryDialog(BuildContext context, TreasuryCubit cubit) {
    showDialog(
      context: context,
      builder: (_) => TreasuryCategoryFormDialog(
        onSave: ({required name, required type, description, parentId}) =>
            cubit.addCategory(
          name: name,
          type: type,
          description: description,
          parentId: parentId,
        ),
      ),
    );
  }

  void _showEditCategoryDialog(
    BuildContext context,
    TreasuryCubit cubit,
    TreasuryCategory category,
  ) {
    showDialog(
      context: context,
      builder: (_) => TreasuryCategoryFormDialog(
        initialCategory: category,
        onSave: ({required name, required type, description, parentId}) =>
            cubit.updateCategory(
          id: category.id,
          name: name,
          type: type,
          description: description,
        ),
      ),
    );
  }

  void _showDeleteCategoryDialog(
    BuildContext context,
    TreasuryCubit cubit,
    TreasuryCategory category,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'treasury.delete_category'.tr(),
          style: const TextStyle(color: AppColors.danger),
        ),
        content: Text(
          'treasury.confirm_delete_category'.tr(args: [category.name]),
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

  // --- Subcategory Dialogs ---

  void _showAddSubcategoryDialog(
    BuildContext context,
    TreasuryCubit cubit,
    TreasuryCategory parentCategory,
  ) {
    showDialog(
      context: context,
      builder: (_) => TreasuryCategoryFormDialog(
        parentId: parentCategory.id,
        parentName: parentCategory.name,
        defaultType: parentCategory.type,
        onSave: ({required name, required type, description, parentId}) =>
            cubit.addSubcategory(
          parentId: parentCategory.id,
          name: name,
          type: type,
          description: description,
        ),
      ),
    );
  }

  void _showEditSubcategoryDialog(
    BuildContext context,
    TreasuryCubit cubit,
    TreasuryCategory subcategory,
    TreasuryCategory parentCategory,
  ) {
    showDialog(
      context: context,
      builder: (_) => TreasuryCategoryFormDialog(
        initialCategory: subcategory,
        parentId: parentCategory.id,
        parentName: parentCategory.name,
        defaultType: subcategory.type,
        onSave: ({required name, required type, description, parentId}) =>
            cubit.updateCategory(
          id: subcategory.id,
          name: name,
          type: type,
          description: description,
        ),
      ),
    );
  }

  void _showDeleteSubcategoryDialog(
    BuildContext context,
    TreasuryCubit cubit,
    TreasuryCategory subcategory,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'treasury.delete_subcategory'.tr(),
          style: const TextStyle(color: AppColors.danger),
        ),
        content: Text(
          'treasury.confirm_delete_subcategory'.tr(args: [subcategory.name]),
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
              await cubit.deleteCategory(subcategory.id);
            },
          ),
        ],
      ),
    );
  }

  // --- Transaction Dialogs ---

  void _showAddTransactionDialog(
    BuildContext context,
    TreasuryCubit cubit,
    List<TreasuryCategory> categories,
    List<TreasuryCategory> subcategories, {
    String defaultType = 'in',
    String? preselectedCategoryId,
    String? preselectedSubcategoryId,
  }) {
    showDialog(
      context: context,
      builder: (_) => TreasuryTransactionFormDialog(
        categories: categories,
        subcategories: subcategories,
        defaultType: defaultType,
        preselectedCategoryId: preselectedCategoryId,
        preselectedSubcategoryId: preselectedSubcategoryId,
        onQuickAddCategory: (type) async {
          String? createdName;
          String? createdType;
          String? createdDesc;
          await showDialog(
            context: context,
            builder: (_) => TreasuryCategoryFormDialog(
              defaultType: type,
              onSave: ({required name, required type, description, parentId}) async {
                createdName = name;
                createdType = type;
                createdDesc = description;
              },
            ),
          );
          if (createdName != null) {
            final repo = getIt<TreasuryRepository>();
            final newCat = await repo.addCategory(
              name: createdName!,
              type: createdType ?? 'both',
              description: createdDesc,
            );
            cubit.loadTreasury();
            return newCat;
          }
          return null;
        },
        onQuickAddSubcategory: (parentId, type) async {
          String? createdName;
          String? createdType;
          String? createdDesc;
          final parentCat =
              categories.where((c) => c.id == parentId).firstOrNull;
          await showDialog(
            context: context,
            builder: (_) => TreasuryCategoryFormDialog(
              parentId: parentId,
              parentName: parentCat?.name,
              defaultType: type,
              onSave: ({required name, required type, description, parentId}) async {
                createdName = name;
                createdType = type;
                createdDesc = description;
              },
            ),
          );
          if (createdName != null) {
            final repo = getIt<TreasuryRepository>();
            final newSub = await repo.addSubcategory(
              parentId: parentId,
              name: createdName!,
              type: createdType ?? 'both',
              description: createdDesc,
            );
            cubit.loadTreasury();
            return newSub;
          }
          return null;
        },
        onSave: ({
          required type,
          required amount,
          required categoryName,
          categoryId,
          subcategoryId,
          subcategoryName,
          personName,
          notes,
          currency,
          required createdAt,
        }) =>
            cubit.addTransaction(
          type: type,
          amount: amount,
          categoryName: categoryName,
          categoryId: categoryId,
          subcategoryId: subcategoryId,
          subcategoryName: subcategoryName,
          personName: personName,
          notes: notes,
          currency: currency,
          createdAt: createdAt,
        ),
      ),
    );
  }

  void _showEditTransactionDialog(
    BuildContext context,
    TreasuryCubit cubit,
    List<TreasuryCategory> categories,
    List<TreasuryCategory> subcategories,
    TreasuryTransactionWithCategory item,
  ) {
    showDialog(
      context: context,
      builder: (_) => TreasuryTransactionFormDialog(
        categories: categories,
        subcategories: subcategories,
        initialTransaction: item.transaction,
        defaultType: item.transaction.type,
        preselectedCategoryId: item.transaction.categoryId,
        preselectedSubcategoryId: item.transaction.subcategoryId,
        onQuickAddCategory: (type) async {
          String? createdName;
          String? createdType;
          String? createdDesc;
          await showDialog(
            context: context,
            builder: (_) => TreasuryCategoryFormDialog(
              defaultType: type,
              onSave: ({required name, required type, description, parentId}) async {
                createdName = name;
                createdType = type;
                createdDesc = description;
              },
            ),
          );
          if (createdName != null) {
            final repo = getIt<TreasuryRepository>();
            final newCat = await repo.addCategory(
              name: createdName!,
              type: createdType ?? 'both',
              description: createdDesc,
            );
            cubit.loadTreasury();
            return newCat;
          }
          return null;
        },
        onQuickAddSubcategory: (parentId, type) async {
          String? createdName;
          String? createdType;
          String? createdDesc;
          final parentCat =
              categories.where((c) => c.id == parentId).firstOrNull;
          await showDialog(
            context: context,
            builder: (_) => TreasuryCategoryFormDialog(
              parentId: parentId,
              parentName: parentCat?.name,
              defaultType: type,
              onSave: ({required name, required type, description, parentId}) async {
                createdName = name;
                createdType = type;
                createdDesc = description;
              },
            ),
          );
          if (createdName != null) {
            final repo = getIt<TreasuryRepository>();
            final newSub = await repo.addSubcategory(
              parentId: parentId,
              name: createdName!,
              type: createdType ?? 'both',
              description: createdDesc,
            );
            cubit.loadTreasury();
            return newSub;
          }
          return null;
        },
        onSave: ({
          required type,
          required amount,
          required categoryName,
          categoryId,
          subcategoryId,
          subcategoryName,
          personName,
          notes,
          currency,
          required createdAt,
        }) =>
            cubit.updateTransaction(
          id: item.transaction.id,
          type: type,
          amount: amount,
          categoryName: categoryName,
          categoryId: categoryId,
          subcategoryId: subcategoryId,
          subcategoryName: subcategoryName,
          personName: personName,
          notes: notes,
          currency: currency,
          createdAt: createdAt,
        ),
      ),
    );
  }

  void _showDeleteTransactionDialog(
    BuildContext context,
    TreasuryCubit cubit,
    TreasuryTransactionWithCategory item,
  ) {
    final tx = item.transaction;
    final isCashIn = tx.type == 'in';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'treasury.delete_movement'.tr(),
          style: const TextStyle(color: AppColors.danger),
        ),
        content: Text(
          'treasury.confirm_delete_movement'.tr(
            args: [
              '${tx.amount.toStringAsFixed(2)} ${AppCurrency.getSymbol(tx.currency)} (${isCashIn ? 'treasury.cash_in'.tr() : 'treasury.cash_out'.tr()})',
            ],
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
              await cubit.deleteTransaction(tx.id);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(
    BuildContext context,
    TreasuryCubit cubit,
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
      final start = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
        0,
        0,
        0,
      );
      final end = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
      );
      cubit.setDateRange(start, end);
    }
  }


  Future<void> _showExchangeDialog(
    BuildContext context,
    TreasuryCubit cubit,
  ) async {
    final result = await NewExchangeDialog.show(context);
    if (result != null) {
      cubit.loadTreasury();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TreasuryCubit>(
      create: (_) => TreasuryCubit(getIt<TreasuryRepository>())..loadTreasury(),
      child: BlocConsumer<TreasuryCubit, TreasuryState>(
        listener: (context, state) {
          if (state is TreasuryError) {
            AppToast.error(context, message: state.message);
          } else if (state is TreasuryLoaded && state.errorMessage != null) {
            AppToast.error(context, message: state.errorMessage!);
            context.read<TreasuryCubit>().clearError();
          }
        },
        builder: (context, state) {
          final cubit = context.read<TreasuryCubit>();

          return AppScreenScaffold(
            title: 'treasury.main_treasury_title'.tr(),
            onRefresh: () => cubit.loadTreasury(),
            body: state is TreasuryLoading
                ? LoadingIndicator(message: 'common.loading'.tr())
                : state is TreasuryLoaded
                    ? _buildLoadedContent(context, cubit, state)
                    : const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  Widget _buildLoadedContent(
    BuildContext context,
    TreasuryCubit cubit,
    TreasuryLoaded state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Hero Vault Balances & Quick Actions Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TreasuryVaultCards(
            vaultBalanceSyp: state.vaultBalanceSyp,
            vaultBalanceUsd: state.vaultBalanceUsd,
            onCashIn: () => _showAddTransactionDialog(
              context,
              cubit,
              state.categories,
              state.subcategories,
              defaultType: 'in',
              preselectedCategoryId: state.selectedCategoryId,
              preselectedSubcategoryId: state.selectedSubcategoryId,
            ),
            onCashOut: () => _showAddTransactionDialog(
              context,
              cubit,
              state.categories,
              state.subcategories,
              defaultType: 'out',
              preselectedCategoryId: state.selectedCategoryId,
              preselectedSubcategoryId: state.selectedSubcategoryId,
            ),
            onExchange: () => _showExchangeDialog(context, cubit),
            onRefresh: () => cubit.loadTreasury(),
          ),
        ),

        // 2. Navigation Tabs (Ledger, Categories/Manual Vouchers)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  title: 'treasury.tab_ledger'.tr(),
                  icon: Icons.receipt_long,
                  badge: '${state.unifiedLedger.length}',
                  isSelected: state.selectedTabIndex == 0,
                  onTap: () => cubit.setTabIndex(0),
                ),
                _buildTabButton(
                  title: 'treasury.tab_categories'.tr(),
                  icon: Icons.category_outlined,
                  isSelected: state.selectedTabIndex == 1,
                  onTap: () => cubit.setTabIndex(1),
                ),
              ],
            ),
          ),
        ),

        // 3. Tab Body
        Expanded(
          child: IndexedStack(
            index: state.selectedTabIndex,
            children: [
              // Tab 0: Unified Running Balance Ledger
              TreasuryLedgerView(
                ledger: state.filteredLedger,
                selectedTypeFilter: state.ledgerTypeFilter,
                selectedCurrencyFilter: state.ledgerCurrencyFilter,
                searchQuery: state.ledgerSearchQuery,
                startDate: state.startDate,
                endDate: state.endDate,
                onTypeFilterChanged: (type) => cubit.setLedgerTypeFilter(type),
                onCurrencyFilterChanged: (curr) => cubit.setLedgerCurrencyFilter(curr),
                onSearchChanged: (q) => cubit.setLedgerSearchQuery(q),
                onSelectDateRange: () => _selectDateRange(
                  context,
                  cubit,
                  state.startDate,
                  state.endDate,
                ),
                onClearDateRange: () => cubit.setDateRange(null, null),
              ),

              // Tab 1: Manual Vouchers & Categories (SplitPaneLayout)
              SplitPaneLayout(
                leftFlex: 2,
                rightFlex: 3,
                leftChild: _buildLeftPane(context, cubit, state),
                rightChild: _buildRightPane(context, cubit, state),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : AppColors.border,
                    ),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // LEFT PANE: Categories & Subcategories List (Exact match to Expenses)
  // =========================================================================

  Widget _buildLeftPane(
    BuildContext context,
    TreasuryCubit cubit,
    TreasuryLoaded state,
  ) {
    final summariesMap = {
      for (final s in state.categorySummaries) s.category.id: s,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Categories Heading + Add Category Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'treasury.categories_heading'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddCategoryDialog(context, cubit),
                icon: const Icon(Icons.add, size: 18),
                label: Text('treasury.add_category_btn'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // "All Movements" Selection Card (Identical pattern to Expenses)
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
                    child: const Icon(
                      Icons.all_inbox_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'treasury.all_movements'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: state.selectedCategoryId == null
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${state.transactions.length} ${'treasury.operations_count'.tr()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.netSyp != 0 || state.netUsd == 0)
                        Text(
                          '${state.netSyp >= 0 ? '+' : ''}${state.netSyp.toStringAsFixed(2)} ${AppCurrency.sypSymbol}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: state.selectedCategoryId == null
                                ? AppColors.primary
                                : (state.netSyp >= 0
                                    ? AppColors.success
                                    : const Color(0xFFDC2626)),
                          ),
                        ),
                      if (state.netUsd != 0) ...[
                        if (state.netSyp != 0 || state.netUsd == 0)
                          const SizedBox(height: 2),
                        Text(
                          '${state.netUsd >= 0 ? '+' : ''}${state.netUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: state.netUsd >= 0
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Categories & Subcategories List
          Expanded(
            child: state.categories.isEmpty
                ? EmptyStateView(
                    icon: Icons.category_outlined,
                    title: 'treasury.no_categories'.tr(),
                    description: 'treasury.no_categories_desc'.tr(),
                  )
                : ListView.separated(
                    itemCount: state.categories.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final cat = state.categories[index];
                      final isSelected = state.selectedCategoryId == cat.id;
                      final summary = summariesMap[cat.id];
                      final catTotalSyp = summary?.totalAmountSyp ?? 0.0;
                      final catTotalUsd = summary?.totalAmountUsd ?? 0.0;
                      final catCount = summary?.count ?? 0;
                      final subcategories = state.getSubcategoriesFor(cat.id);

                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.06)
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                              onTap: () {
                                if (isSelected &&
                                    state.selectedSubcategoryId != null) {
                                  cubit.selectSubcategory(null);
                                } else {
                                  cubit.selectCategory(
                                      isSelected ? null : cat.id);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                          Row(
                                            children: [
                                              Text(
                                                '$catCount ${'treasury.operations_count'.tr()}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                              if (subcategories.isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  '• ${subcategories.length} ${'treasury.subcategories'.tr()}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isSelected
                                                        ? AppColors.primary
                                                        : AppColors
                                                            .textSecondary,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (catTotalSyp != 0 || catTotalUsd == 0)
                                          Text(
                                            '${catTotalSyp >= 0 ? '+' : ''}${catTotalSyp.toStringAsFixed(2)} ${AppCurrency.sypSymbol}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : (catTotalSyp >= 0
                                                      ? AppColors.success
                                                      : const Color(0xFFDC2626)),
                                            ),
                                          ),
                                        if (catTotalUsd != 0)
                                          Text(
                                            '${catTotalUsd >= 0 ? '+' : ''}${catTotalUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: catTotalUsd >= 0
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.add_circle_outline,
                                                  size: 16),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              color: AppColors.primary,
                                              tooltip:
                                                  'treasury.add_subcategory'
                                                      .tr(),
                                              onPressed: () =>
                                                  _showAddSubcategoryDialog(
                                                context,
                                                cubit,
                                                cat,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 16),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              color: AppColors.textSecondary,
                                              tooltip: 'common.edit'.tr(),
                                              onPressed: () =>
                                                  _showEditCategoryDialog(
                                                context,
                                                cubit,
                                                cat,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 16),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              color: AppColors.danger,
                                              tooltip: 'common.delete'.tr(),
                                              onPressed: () =>
                                                  _showDeleteCategoryDialog(
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
                            ),
                            if (isSelected) ...[
                              const Divider(height: 1),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                color: Colors.grey.shade50,
                                child: subcategories.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4, horizontal: 4),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.subdirectory_arrow_right,
                                              size: 14,
                                              color: AppColors.textSecondary
                                                  .withValues(alpha: 0.6),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'treasury.no_subcategory'.tr(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary
                                                      .withValues(alpha: 0.7),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              icon: const Icon(Icons.add,
                                                  size: 12),
                                              label: Text(
                                                'treasury.add_subcategory'.tr(),
                                                style: const TextStyle(
                                                    fontSize: 11),
                                              ),
                                              onPressed: () =>
                                                  _showAddSubcategoryDialog(
                                                context,
                                                cubit,
                                                cat,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (state.selectedSubcategoryId !=
                                              null)
                                            InkWell(
                                              onTap: () =>
                                                  cubit.selectSubcategory(null),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                        horizontal: 6),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                        Icons
                                                            .filter_alt_off_outlined,
                                                        size: 13,
                                                        color:
                                                            AppColors.primary),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'treasury.all_movements'
                                                          .tr(),
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ...subcategories.map((sub) {
                                            final isSubSelected = state
                                                    .selectedSubcategoryId ==
                                                sub.id;
                                            final subSummary = summary
                                                ?.subcategories
                                                .where((s) =>
                                                    s.category.id == sub.id)
                                                .firstOrNull;
                                            final subTotalSyp =
                                                subSummary?.totalAmountSyp ??
                                                    0.0;
                                            final subTotalUsd =
                                                subSummary?.totalAmountUsd ??
                                                    0.0;
                                            final subCount =
                                                subSummary?.count ?? 0;

                                            return Container(
                                              margin:
                                                  const EdgeInsets.only(top: 4),
                                              decoration: BoxDecoration(
                                                color: isSubSelected
                                                    ? AppColors.primary
                                                        .withValues(alpha: 0.12)
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isSubSelected
                                                      ? AppColors.primary
                                                      : Colors.grey.shade200,
                                                  width:
                                                      isSubSelected ? 1.5 : 1,
                                                ),
                                              ),
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                onTap: () {
                                                  if (isSubSelected) {
                                                    cubit
                                                        .selectSubcategory(null);
                                                  } else {
                                                    cubit.selectSubcategory(
                                                        sub.id);
                                                  }
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .subdirectory_arrow_right,
                                                        size: 14,
                                                        color: isSubSelected
                                                            ? AppColors.primary
                                                            : AppColors
                                                                .textSecondary,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              sub.name,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    isSubSelected
                                                                        ? FontWeight
                                                                            .bold
                                                                        : FontWeight
                                                                            .w500,
                                                                color: isSubSelected
                                                                    ? AppColors
                                                                        .primary
                                                                    : AppColors
                                                                        .textPrimary,
                                                              ),
                                                            ),
                                                            Text(
                                                              '$subCount ${'treasury.operations_count'.tr()}',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: AppColors
                                                                    .textSecondary
                                                                    .withValues(
                                                                        alpha:
                                                                            0.8),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          if (subTotalSyp != 0 || subTotalUsd == 0)
                                                            Text(
                                                              '${subTotalSyp >= 0 ? '+' : ''}${subTotalSyp.toStringAsFixed(2)} ${AppCurrency.sypSymbol}',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: isSubSelected
                                                                    ? AppColors
                                                                        .primary
                                                                    : (subTotalSyp >= 0
                                                                        ? AppColors
                                                                            .success
                                                                        : const Color(
                                                                            0xFFDC2626)),
                                                              ),
                                                            ),
                                                          if (subTotalUsd != 0)
                                                            Text(
                                                              '${subTotalUsd >= 0 ? '+' : ''}${subTotalUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}',
                                                              style:
                                                                  TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: subTotalUsd >= 0
                                                                    ? const Color(0xFF059669)
                                                                    : const Color(0xFFDC2626),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(width: 6),
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.edit_outlined,
                                                            size: 14),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                        color: AppColors
                                                            .textSecondary,
                                                        tooltip:
                                                            'treasury.edit_subcategory'
                                                                .tr(),
                                                        onPressed: () =>
                                                            _showEditSubcategoryDialog(
                                                          context,
                                                          cubit,
                                                          sub,
                                                          cat,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons
                                                                .delete_outline,
                                                            size: 14),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                        color:
                                                            AppColors.danger,
                                                        tooltip:
                                                            'treasury.delete_subcategory'
                                                                .tr(),
                                                        onPressed: () =>
                                                            _showDeleteSubcategoryDialog(
                                                          context,
                                                          cubit,
                                                          sub,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // RIGHT PANE: Filtered Transactions History & Controls (Matching Expenses)
  // =========================================================================

  Widget _buildRightPane(
    BuildContext context,
    TreasuryCubit cubit,
    TreasuryLoaded state,
  ) {
    final filtered = state.filteredTransactions;

    // Determine current category title
    String categoryTitle = 'treasury.all_movements'.tr();
    if (state.selectedCategoryId != null) {
      final found = state.categories
          .where((c) => c.id == state.selectedCategoryId)
          .firstOrNull;
      if (found != null) {
        categoryTitle = found.name;
      }
    }

    String? subcategoryTitle;
    if (state.selectedSubcategoryId != null) {
      final foundSub = state.subcategories
          .where((s) => s.id == state.selectedSubcategoryId)
          .firstOrNull;
      if (foundSub != null) {
        subcategoryTitle = foundSub.name;
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Bar: Breadcrumb + Cash In & Out Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    categoryTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subcategoryTitle != null) ...[
                    const Icon(Icons.chevron_right,
                        size: 18, color: AppColors.textSecondary),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            subcategoryTitle,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => cubit.selectSubcategory(null),
                            child: const Icon(Icons.close,
                                size: 14, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filtered.length} ${'treasury.operations_count'.tr()}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cash In Button
                  ElevatedButton.icon(
                    onPressed: () => _showAddTransactionDialog(
                      context,
                      cubit,
                      state.categories,
                      state.subcategories,
                      defaultType: 'in',
                      preselectedCategoryId: state.selectedCategoryId,
                      preselectedSubcategoryId: state.selectedSubcategoryId,
                    ),
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    label: Text('treasury.cash_in'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cash Out Button
                  ElevatedButton.icon(
                    onPressed: () => _showAddTransactionDialog(
                      context,
                      cubit,
                      state.categories,
                      state.subcategories,
                      defaultType: 'out',
                      preselectedCategoryId: state.selectedCategoryId,
                      preselectedSubcategoryId: state.selectedSubcategoryId,
                    ),
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    label: Text('treasury.cash_out'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters Bar: Search + Date Range + Type Filter Chips + Reset
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'treasury.search_transactions'.tr(),
                  hint: 'treasury.search_hint'.tr(),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Type Toggle Filter (All / In / Out)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTypeFilterChip(
                      'all',
                      'treasury.all_types'.tr(),
                      state.selectedTypeFilter,
                      cubit,
                    ),
                    _buildTypeFilterChip(
                      'in',
                      'treasury.in_only'.tr(),
                      state.selectedTypeFilter,
                      cubit,
                    ),
                    _buildTypeFilterChip(
                      'out',
                      'treasury.out_only'.tr(),
                      state.selectedTypeFilter,
                      cubit,
                    ),
                  ],
                ),
              ),
              if (state.startDate != null ||
                  state.searchQuery.isNotEmpty ||
                  state.selectedCategoryId != null ||
                  state.selectedSubcategoryId != null ||
                  state.selectedTypeFilter != 'all') ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'expenses.clear_filters'.tr(),
                  icon: const Icon(Icons.clear, color: AppColors.danger),
                  onPressed: () {
                    _searchController.clear();
                    cubit.setSearchQuery('');
                    cubit.setDateRange(null, null);
                    cubit.selectCategory(null);
                    cubit.setTypeFilter('all');
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Stat Summary Card: Gradient Banner matching ExpensesScreen
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.04),
                ],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'treasury.total_in_selection'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    // Inflow Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_downward,
                            size: 14,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          if (state.filteredTotalInSyp > 0 || state.filteredTotalInUsd == 0)
                            Text(
                              '+${state.filteredTotalInSyp.toStringAsFixed(0)} ${AppCurrency.sypSymbol}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          if (state.filteredTotalInSyp > 0 && state.filteredTotalInUsd > 0)
                            const Text(
                              ' | ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          if (state.filteredTotalInUsd > 0)
                            Text(
                              '+${state.filteredTotalInUsd.toStringAsFixed(0)} ${AppCurrency.usdSymbol}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Outflow Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_upward,
                            size: 14,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 4),
                          if (state.filteredTotalOutSyp > 0 || state.filteredTotalOutUsd == 0)
                            Text(
                              '-${state.filteredTotalOutSyp.toStringAsFixed(0)} ${AppCurrency.sypSymbol}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          if (state.filteredTotalOutSyp > 0 && state.filteredTotalOutUsd > 0)
                            const Text(
                              ' | ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          if (state.filteredTotalOutUsd > 0)
                            Text(
                              '-${state.filteredTotalOutUsd.toStringAsFixed(0)} ${AppCurrency.usdSymbol}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Net Balance
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.filteredNetSyp != 0 || state.filteredNetUsd == 0)
                          Text(
                            '${state.filteredNetSyp >= 0 ? '+' : ''}${state.filteredNetSyp.toStringAsFixed(2)} ${AppCurrency.sypSymbol}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: state.filteredNetSyp >= 0
                                  ? AppColors.success
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        if (state.filteredNetUsd != 0) ...[
                          if (state.filteredNetSyp != 0 || state.filteredNetUsd == 0)
                            const SizedBox(height: 2),
                          Text(
                            '${state.filteredNetUsd >= 0 ? '+' : ''}${state.filteredNetUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: state.filteredNetUsd >= 0
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
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
                    title: 'treasury.no_transactions'.tr(),
                    description: 'treasury.no_transactions_desc'.tr(),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final tx = item.transaction;
                      final isCashIn = tx.type == 'in';
                      final accent = isCashIn
                          ? AppColors.success
                          : const Color(0xFFDC2626);
                      final sign = isCashIn ? '+' : '-';
                      final currSymbol = AppCurrency.getSymbol(tx.currency);
                      final subName = item.subcategory?.name ??
                          (tx.subcategoryName != null &&
                                  tx.subcategoryName!.isNotEmpty
                              ? tx.subcategoryName
                              : null);

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
                              // Date & Time Box (Identical to ExpensesScreen)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat('dd/MM').format(tx.createdAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('yyyy').format(tx.createdAt),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Details: Badges + Notes
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        // Serial Number Chip
                                        if (tx.serialNumber != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Text(
                                              '#${tx.serialNumber}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),

                                        // Movement Type Badge (In / Out)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                accent.withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isCashIn
                                                    ? Icons.arrow_downward
                                                    : Icons.arrow_upward,
                                                size: 12,
                                                color: accent,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isCashIn
                                                    ? 'treasury.cash_in'.tr()
                                                    : 'treasury.cash_out'.tr(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: accent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Category Badge (Main)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.category?.name ??
                                                tx.categoryName ??
                                                'عام',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),

                                        // Subcategory Badge (if present)
                                        if (subName != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons
                                                      .subdirectory_arrow_right,
                                                  size: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  subName,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // Beneficiary / Person Name Badge
                                        if (tx.personName != null &&
                                            tx.personName!.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blueGrey
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.person_outline,
                                                  size: 13,
                                                  color: Colors.blueGrey,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  tx.personName!,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blueGrey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),

                                    // Notes (if present)
                                    if (tx.notes != null &&
                                        tx.notes!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.notes,
                                            size: 13,
                                            color: AppColors.textSecondary
                                                .withValues(alpha: 0.7),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              tx.notes!,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Amount Column
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$sign${tx.amount.toStringAsFixed(2)} $currSymbol',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: accent,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('HH:mm').format(tx.createdAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),

                              // Actions
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                color: AppColors.textSecondary,
                                tooltip: 'common.edit'.tr(),
                                onPressed: () => _showEditTransactionDialog(
                                  context,
                                  cubit,
                                  state.categories,
                                  state.subcategories,
                                  item,
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 16),
                                color: AppColors.danger,
                                tooltip: 'common.delete'.tr(),
                                onPressed: () => _showDeleteTransactionDialog(
                                  context,
                                  cubit,
                                  item,
                                ),
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

  Widget _buildTypeFilterChip(
    String type,
    String label,
    String selectedType,
    TreasuryCubit cubit,
  ) {
    final isSelected = selectedType == type;
    return InkWell(
      onTap: () => cubit.setTypeFilter(type),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
