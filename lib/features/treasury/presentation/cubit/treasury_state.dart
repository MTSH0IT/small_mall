import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/treasury/data/models/treasury_ledger_item.dart';
import 'package:small_mall/features/treasury/data/treasury_repository.dart';

abstract class TreasuryState {
  const TreasuryState();
}

class TreasuryInitial extends TreasuryState {}

class TreasuryLoading extends TreasuryState {}

class TreasuryLoaded extends TreasuryState {
  const TreasuryLoaded({
    required this.categories,
    this.subcategories = const [],
    required this.categorySummaries,
    required this.transactions,
    this.vaultBalanceSyp = 0.0,
    this.vaultBalanceUsd = 0.0,
    this.unifiedLedger = const [],
    this.selectedTabIndex = 0, // 0: Unified Ledger, 1: Categories/Vouchers
    this.ledgerTypeFilter = 'all', // 'all', 'in', 'out'
    this.ledgerCurrencyFilter = 'all', // 'all', 'SYP', 'USD'
    this.ledgerSearchQuery = '',
    this.selectedCategoryId,
    this.selectedSubcategoryId,
    this.selectedTypeFilter = 'all', // 'all', 'in', 'out'
    this.selectedCurrency,
    this.startDate,
    this.endDate,
    this.searchQuery = '',
    this.errorMessage,
  });

  final List<TreasuryCategory> categories;
  final List<TreasuryCategory> subcategories;
  final List<TreasuryCategorySummary> categorySummaries;
  final List<TreasuryTransactionWithCategory> transactions;
  final double vaultBalanceSyp;
  final double vaultBalanceUsd;
  final List<TreasuryLedgerItem> unifiedLedger;
  final int selectedTabIndex;
  final String ledgerTypeFilter;
  final String ledgerCurrencyFilter;
  final String ledgerSearchQuery;
  final String? selectedCategoryId; // null = all
  final String? selectedSubcategoryId; // null = all in selected category
  final String selectedTypeFilter;
  final String? selectedCurrency;
  final DateTime? startDate;
  final DateTime? endDate;
  final String searchQuery;
  final String? errorMessage;

  List<TreasuryCategory> getSubcategoriesFor(String parentId) {
    return subcategories.where((s) => s.parentId == parentId).toList();
  }

  List<TreasuryTransactionWithCategory> get filteredTransactions {
    var result = transactions;

    if (selectedTypeFilter != 'all') {
      result = result
          .where((t) => t.transaction.type == selectedTypeFilter)
          .toList();
    }

    if (selectedCategoryId != null && selectedCategoryId!.isNotEmpty) {
      result = result
          .where((t) =>
              t.transaction.categoryId == selectedCategoryId ||
              (t.category != null && t.category!.id == selectedCategoryId))
          .toList();
    }

    if (selectedSubcategoryId != null && selectedSubcategoryId!.isNotEmpty) {
      result = result
          .where((t) =>
              t.transaction.subcategoryId == selectedSubcategoryId ||
              (t.subcategory != null &&
                  t.subcategory!.id == selectedSubcategoryId))
          .toList();
    }

    if (selectedCurrency != null && selectedCurrency!.isNotEmpty) {
      result = result
          .where((t) => t.transaction.currency == selectedCurrency)
          .toList();
    }

    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      result = result.where((t) {
        final tx = t.transaction;
        final cat = (tx.categoryName ?? t.category?.name ?? '').toLowerCase();
        final sub =
            (tx.subcategoryName ?? t.subcategory?.name ?? '').toLowerCase();
        final person = tx.personName?.toLowerCase() ?? '';
        final notes = tx.notes?.toLowerCase() ?? '';
        final amountStr = tx.amount.toString();
        final serial = tx.serialNumber != null ? '#${tx.serialNumber}' : '';
        return cat.contains(q) ||
            sub.contains(q) ||
            person.contains(q) ||
            notes.contains(q) ||
            amountStr.contains(q) ||
            serial.contains(q);
      }).toList();
    }

    return result;
  }

  List<TreasuryLedgerItem> get filteredLedger {
    var result = unifiedLedger;

    if (ledgerTypeFilter != 'all') {
      final isIn = ledgerTypeFilter == 'in';
      result = result.where((m) => m.isCashIn == isIn).toList();
    }

    if (ledgerCurrencyFilter != 'all') {
      result = result.where((m) => m.currency == ledgerCurrencyFilter).toList();
    }

    if (ledgerSearchQuery.trim().isNotEmpty) {
      final q = ledgerSearchQuery.trim().toLowerCase();
      result = result.where((m) {
        final title = m.title.toLowerCase();
        final party = m.partyName?.toLowerCase() ?? '';
        final ref = m.referenceNumber?.toLowerCase() ?? '';
        final notes = m.notes?.toLowerCase() ?? '';
        final amount = m.amount.toString();
        return title.contains(q) ||
            party.contains(q) ||
            ref.contains(q) ||
            notes.contains(q) ||
            amount.contains(q);
      }).toList();
    }

    return result;
  }

  // All transactions totals
  double get totalInSyp => transactions
      .where((t) => t.transaction.type == 'in' && t.transaction.currency != 'USD')
      .fold<double>(0.0, (sum, t) => sum + t.transaction.amount);

  double get totalOutSyp => transactions
      .where((t) => t.transaction.type == 'out' && t.transaction.currency != 'USD')
      .fold<double>(0.0, (sum, t) => sum + t.transaction.amount);

  double get netSyp => totalInSyp - totalOutSyp;

  double get totalInUsd => transactions
      .where((t) => t.transaction.type == 'in' && t.transaction.currency == 'USD')
      .fold<double>(0.0, (sum, t) => sum + t.transaction.amount);

  double get totalOutUsd => transactions
      .where((t) => t.transaction.type == 'out' && t.transaction.currency == 'USD')
      .fold<double>(0.0, (sum, t) => sum + t.transaction.amount);

  double get netUsd => totalInUsd - totalOutUsd;

  // Filtered transactions totals
  double get filteredTotalInSyp => filteredTransactions
      .where((t) => t.transaction.type == 'in' && t.transaction.currency != 'USD')
      .fold<double>(0.0, (sum, t) => sum + t.transaction.amount);

  double get filteredTotalOutSyp => filteredTransactions
      .where((t) => t.transaction.type == 'out' && t.transaction.currency != 'USD')
      .fold<double>(0.0, (sum, t) => sum + t.transaction.amount);

  double get filteredNetSyp => filteredTotalInSyp - filteredTotalOutSyp;

  double get filteredTotalInUsd => filteredTransactions
      .where((t) => t.transaction.type == 'in' && t.transaction.currency == 'USD')
      .fold<double>(0.0, (sum, t) => sum + t.transaction.amount);

  double get filteredTotalOutUsd => filteredTransactions
      .where((t) => t.transaction.type == 'out' && t.transaction.currency == 'USD')
      .fold<double>(0.0, (sum, t) => sum + t.transaction.amount);

  double get filteredNetUsd => filteredTotalInUsd - filteredTotalOutUsd;

  int get inCount =>
      transactions.where((t) => t.transaction.type == 'in').length;
  int get outCount =>
      transactions.where((t) => t.transaction.type == 'out').length;

  TreasuryLoaded copyWith({
    List<TreasuryCategory>? categories,
    List<TreasuryCategory>? subcategories,
    List<TreasuryCategorySummary>? categorySummaries,
    List<TreasuryTransactionWithCategory>? transactions,
    double? vaultBalanceSyp,
    double? vaultBalanceUsd,
    List<TreasuryLedgerItem>? unifiedLedger,
    int? selectedTabIndex,
    String? ledgerTypeFilter,
    String? ledgerCurrencyFilter,
    String? ledgerSearchQuery,
    String? Function()? selectedCategoryId,
    String? Function()? selectedSubcategoryId,
    String? selectedTypeFilter,
    String? Function()? selectedCurrency,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
    String? searchQuery,
    String? Function()? errorMessage,
  }) {
    return TreasuryLoaded(
      categories: categories ?? this.categories,
      subcategories: subcategories ?? this.subcategories,
      categorySummaries: categorySummaries ?? this.categorySummaries,
      transactions: transactions ?? this.transactions,
      vaultBalanceSyp: vaultBalanceSyp ?? this.vaultBalanceSyp,
      vaultBalanceUsd: vaultBalanceUsd ?? this.vaultBalanceUsd,
      unifiedLedger: unifiedLedger ?? this.unifiedLedger,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      ledgerTypeFilter: ledgerTypeFilter ?? this.ledgerTypeFilter,
      ledgerCurrencyFilter: ledgerCurrencyFilter ?? this.ledgerCurrencyFilter,
      ledgerSearchQuery: ledgerSearchQuery ?? this.ledgerSearchQuery,
      selectedCategoryId: selectedCategoryId != null
          ? selectedCategoryId()
          : this.selectedCategoryId,
      selectedSubcategoryId: selectedSubcategoryId != null
          ? selectedSubcategoryId()
          : this.selectedSubcategoryId,
      selectedTypeFilter: selectedTypeFilter ?? this.selectedTypeFilter,
      selectedCurrency: selectedCurrency != null
          ? selectedCurrency()
          : this.selectedCurrency,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class TreasuryError extends TreasuryState {
  const TreasuryError(this.message);
  final String message;
}
