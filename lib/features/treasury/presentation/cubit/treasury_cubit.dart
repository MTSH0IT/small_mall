import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/treasury/data/treasury_repository.dart';
import 'package:small_mall/features/treasury/presentation/cubit/treasury_state.dart';

class TreasuryCubit extends Cubit<TreasuryState> {
  TreasuryCubit(this._repository) : super(TreasuryInitial());

  final TreasuryRepository _repository;

  Future<void> loadTreasury({DateTime? startDate, DateTime? endDate}) async {
    final currentCatId = state is TreasuryLoaded
        ? (state as TreasuryLoaded).selectedCategoryId
        : null;
    final currentSubId = state is TreasuryLoaded
        ? (state as TreasuryLoaded).selectedSubcategoryId
        : null;
    final currentType = state is TreasuryLoaded
        ? (state as TreasuryLoaded).selectedTypeFilter
        : 'all';
    final currentCurr = state is TreasuryLoaded
        ? (state as TreasuryLoaded).selectedCurrency
        : null;
    final currentStart =
        startDate ??
        (state is TreasuryLoaded ? (state as TreasuryLoaded).startDate : null);
    final currentEnd =
        endDate ??
        (state is TreasuryLoaded ? (state as TreasuryLoaded).endDate : null);
    final currentQuery = state is TreasuryLoaded
        ? (state as TreasuryLoaded).searchQuery
        : '';
    final currentTab = state is TreasuryLoaded
        ? (state as TreasuryLoaded).selectedTabIndex
        : 0;
    final currentLedgerType = state is TreasuryLoaded
        ? (state as TreasuryLoaded).ledgerTypeFilter
        : 'all';
    final currentLedgerCurrency = state is TreasuryLoaded
        ? (state as TreasuryLoaded).ledgerCurrencyFilter
        : 'all';
    final currentLedgerQuery = state is TreasuryLoaded
        ? (state as TreasuryLoaded).ledgerSearchQuery
        : '';

    emit(TreasuryLoading());
    try {
      final mainCategories = await _repository.getCategories();
      final subcategories = await _repository.getAllSubcategories();
      final summaries = await _repository.getCategorySummaries(
        startDate: currentStart,
        endDate: currentEnd,
      );
      final transactions = await _repository.getTransactionsWithCategory(
        startDate: currentStart,
        endDate: currentEnd,
      );

      final vaultBalances = await _repository.getCurrentVaultBalances();
      final ledger = await _repository.getUnifiedLedger(
        startDate: currentStart,
        endDate: currentEnd,
      );

      emit(
        TreasuryLoaded(
          categories: mainCategories,
          subcategories: subcategories,
          categorySummaries: summaries,
          transactions: transactions,
          vaultBalanceSyp: vaultBalances['SYP'] ?? 0.0,
          vaultBalanceUsd: vaultBalances['USD'] ?? 0.0,
          unifiedLedger: ledger,
          selectedTabIndex: currentTab,
          ledgerTypeFilter: currentLedgerType,
          ledgerCurrencyFilter: currentLedgerCurrency,
          ledgerSearchQuery: currentLedgerQuery,
          selectedCategoryId: currentCatId,
          selectedSubcategoryId: currentSubId,
          selectedTypeFilter: currentType,
          selectedCurrency: currentCurr,
          startDate: currentStart,
          endDate: currentEnd,
          searchQuery: currentQuery,
        ),
      );
    } catch (e) {
      emit(TreasuryError(e.toString()));
    }
  }

  void setTabIndex(int index) {
    if (state is TreasuryLoaded) {
      emit((state as TreasuryLoaded).copyWith(selectedTabIndex: index));
    }
  }

  void setLedgerTypeFilter(String type) {
    if (state is TreasuryLoaded) {
      emit((state as TreasuryLoaded).copyWith(ledgerTypeFilter: type));
    }
  }

  void setLedgerCurrencyFilter(String currency) {
    if (state is TreasuryLoaded) {
      emit((state as TreasuryLoaded).copyWith(ledgerCurrencyFilter: currency));
    }
  }

  void setLedgerSearchQuery(String query) {
    if (state is TreasuryLoaded) {
      emit((state as TreasuryLoaded).copyWith(ledgerSearchQuery: query));
    }
  }

  void selectCategory(String? categoryId) {
    if (state is TreasuryLoaded) {
      emit(
        (state as TreasuryLoaded).copyWith(
          selectedCategoryId: () => categoryId,
          selectedSubcategoryId: () => null,
        ),
      );
    }
  }

  void selectSubcategory(String? subcategoryId) {
    if (state is TreasuryLoaded) {
      emit(
        (state as TreasuryLoaded).copyWith(
          selectedSubcategoryId: () => subcategoryId,
        ),
      );
    }
  }

  void setTypeFilter(String type) {
    if (state is TreasuryLoaded) {
      emit((state as TreasuryLoaded).copyWith(selectedTypeFilter: type));
    }
  }

  void setCurrencyFilter(String? currency) {
    if (state is TreasuryLoaded) {
      emit(
        (state as TreasuryLoaded).copyWith(selectedCurrency: () => currency),
      );
    }
  }

  void setSearchQuery(String query) {
    if (state is TreasuryLoaded) {
      emit((state as TreasuryLoaded).copyWith(searchQuery: query));
    }
  }

  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    await loadTreasury(startDate: start, endDate: end);
  }

  void clearError() {
    if (state is TreasuryLoaded) {
      emit((state as TreasuryLoaded).copyWith(errorMessage: () => null));
    }
  }

  Future<void> addTransaction({
    required String type,
    required double amount,
    required String categoryName,
    String? categoryId,
    String? subcategoryId,
    String? subcategoryName,
    String? personName,
    String? notes,
    String? currency,
    DateTime? createdAt,
  }) async {
    try {
      await _repository.addTransaction(
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
      );
      await loadTreasury();
    } catch (e) {
      if (state is TreasuryLoaded) {
        emit(
          (state as TreasuryLoaded).copyWith(errorMessage: () => e.toString()),
        );
      } else {
        emit(TreasuryError(e.toString()));
      }
    }
  }

  Future<void> updateTransaction({
    required String id,
    required String type,
    required double amount,
    required String categoryName,
    String? categoryId,
    String? subcategoryId,
    String? subcategoryName,
    String? personName,
    String? notes,
    String? currency,
    DateTime? createdAt,
  }) async {
    try {
      await _repository.updateTransaction(
        id: id,
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
      );
      await loadTreasury();
    } catch (e) {
      if (state is TreasuryLoaded) {
        emit(
          (state as TreasuryLoaded).copyWith(errorMessage: () => e.toString()),
        );
      } else {
        emit(TreasuryError(e.toString()));
      }
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await _repository.deleteTransaction(id);
      await loadTreasury();
    } catch (e) {
      if (state is TreasuryLoaded) {
        emit(
          (state as TreasuryLoaded).copyWith(errorMessage: () => e.toString()),
        );
      } else {
        emit(TreasuryError(e.toString()));
      }
    }
  }

  Future<TreasuryCategory?> addCategory({
    required String name,
    String type = 'both',
    String? description,
    String? parentId,
  }) async {
    try {
      final newCat = await _repository.addCategory(
        name: name,
        type: type,
        description: description,
        parentId: parentId,
      );
      await loadTreasury();
      return newCat;
    } catch (e) {
      if (state is TreasuryLoaded) {
        emit(
          (state as TreasuryLoaded).copyWith(errorMessage: () => e.toString()),
        );
      }
      return null;
    }
  }

  Future<TreasuryCategory?> addSubcategory({
    required String parentId,
    required String name,
    String type = 'both',
    String? description,
  }) async {
    return addCategory(
      parentId: parentId,
      name: name,
      type: type,
      description: description,
    );
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    String type = 'both',
    String? description,
  }) async {
    try {
      await _repository.updateCategory(
        id: id,
        name: name,
        type: type,
        description: description,
      );
      await loadTreasury();
    } catch (e) {
      if (state is TreasuryLoaded) {
        emit(
          (state as TreasuryLoaded).copyWith(errorMessage: () => e.toString()),
        );
      }
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _repository.deleteCategory(id);
      if (state is TreasuryLoaded &&
          (state as TreasuryLoaded).selectedCategoryId == id) {
        selectCategory(null);
      }
      await loadTreasury();
    } catch (e) {
      if (state is TreasuryLoaded) {
        emit(
          (state as TreasuryLoaded).copyWith(errorMessage: () => e.toString()),
        );
      }
    }
  }
}
