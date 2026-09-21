import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/features/expenses/data/expenses_repository.dart';
import 'package:small_mall/features/expenses/presentation/cubit/expenses_state.dart';

class ExpensesCubit extends Cubit<ExpensesState> {
  ExpensesCubit(this._repository) : super(ExpensesInitial());

  final ExpensesRepository _repository;

  Future<void> loadExpenses({
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final currentSelectedId = categoryId ??
        (state is ExpensesLoaded
            ? (state as ExpensesLoaded).selectedCategoryId
            : null);
    final currentStart = startDate ??
        (state is ExpensesLoaded ? (state as ExpensesLoaded).startDate : null);
    final currentEnd = endDate ??
        (state is ExpensesLoaded ? (state as ExpensesLoaded).endDate : null);
    final currentQuery =
        state is ExpensesLoaded ? (state as ExpensesLoaded).searchQuery : '';

    emit(ExpensesLoading());
    try {
      final categories = await _repository.getCategories();
      final subcategories = await _repository.getAllSubcategories();
      final summaries = await _repository.getCategorySummaries(
        startDate: currentStart,
        endDate: currentEnd,
      );
      final expenses = await _repository.getExpenses(
        startDate: currentStart,
        endDate: currentEnd,
      );
      final total = await _repository.getTotalExpenses(
        startDate: currentStart,
        endDate: currentEnd,
      );

      emit(ExpensesLoaded(
        categories: categories,
        subcategories: subcategories,
        categorySummaries: summaries,
        expenses: expenses,
        selectedCategoryId: currentSelectedId,
        selectedSubcategoryId: state is ExpensesLoaded ? (state as ExpensesLoaded).selectedSubcategoryId : null,
        startDate: currentStart,
        endDate: currentEnd,
        searchQuery: currentQuery,
        totalAmount: total,
      ));
    } catch (e) {
      emit(ExpensesError(e.toString()));
    }
  }

  void selectCategory(String? categoryId) {
    if (state is ExpensesLoaded) {
      emit((state as ExpensesLoaded).copyWith(
        selectedCategoryId: () => categoryId,
        selectedSubcategoryId: () => null,
      ));
    }
  }

  void selectSubcategory(String? subcategoryId) {
    if (state is ExpensesLoaded) {
      emit((state as ExpensesLoaded).copyWith(
        selectedSubcategoryId: () => subcategoryId,
      ));
    }
  }

  void setSearchQuery(String query) {
    if (state is ExpensesLoaded) {
      emit((state as ExpensesLoaded).copyWith(
        searchQuery: query,
      ));
    }
  }

  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    await loadExpenses(
      startDate: start,
      endDate: end,
    );
  }

  Future<void> addCategory({
    required String name,
    String? description,
    String? parentId,
  }) async {
    try {
      await _repository.addCategory(name: name, description: description, parentId: parentId);
      await loadExpenses();
    } catch (e) {
      if (state is ExpensesLoaded) {
        emit((state as ExpensesLoaded).copyWith(errorMessage: () => e.toString()));
      } else {
        emit(ExpensesError(e.toString()));
      }
    }
  }

  Future<void> addSubcategory({
    required String parentId,
    required String name,
    String? description,
  }) async {
    try {
      await _repository.addSubcategory(
        parentId: parentId,
        name: name,
        description: description,
      );
      await loadExpenses();
    } catch (e) {
      if (state is ExpensesLoaded) {
        emit((state as ExpensesLoaded).copyWith(errorMessage: () => e.toString()));
      } else {
        emit(ExpensesError(e.toString()));
      }
    }
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    String? description,
  }) async {
    try {
      await _repository.updateCategory(
        id: id,
        name: name,
        description: description,
      );
      await loadExpenses();
    } catch (e) {
      if (state is ExpensesLoaded) {
        emit((state as ExpensesLoaded).copyWith(errorMessage: () => e.toString()));
      } else {
        emit(ExpensesError(e.toString()));
      }
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _repository.deleteCategory(id);
      if (state is ExpensesLoaded) {
        final loaded = state as ExpensesLoaded;
        if (loaded.selectedCategoryId == id) {
          selectCategory(null);
        } else if (loaded.selectedSubcategoryId == id) {
          selectSubcategory(null);
        }
      }
      await loadExpenses();
    } catch (e) {
      if (state is ExpensesLoaded) {
        emit((state as ExpensesLoaded).copyWith(errorMessage: () => e.toString().replaceAll('Exception: ', '')));
      } else {
        emit(ExpensesError(e.toString()));
      }
    }
  }

  Future<void> addExpense({
    required String categoryId,
    String? subcategoryId,
    required double amount,
    String? notes,
    DateTime? createdAt,
  }) async {
    try {
      await _repository.addExpense(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        amount: amount,
        notes: notes,
        createdAt: createdAt,
      );
      await loadExpenses();
    } catch (e) {
      if (state is ExpensesLoaded) {
        emit((state as ExpensesLoaded).copyWith(errorMessage: () => e.toString()));
      } else {
        emit(ExpensesError(e.toString()));
      }
    }
  }

  Future<void> updateExpense({
    required String id,
    required String categoryId,
    String? subcategoryId,
    required double amount,
    String? notes,
    DateTime? createdAt,
  }) async {
    try {
      await _repository.updateExpense(
        id: id,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        amount: amount,
        notes: notes,
        createdAt: createdAt,
      );
      await loadExpenses();
    } catch (e) {
      if (state is ExpensesLoaded) {
        emit((state as ExpensesLoaded).copyWith(errorMessage: () => e.toString()));
      } else {
        emit(ExpensesError(e.toString()));
      }
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _repository.deleteExpense(id);
      await loadExpenses();
    } catch (e) {
      if (state is ExpensesLoaded) {
        emit((state as ExpensesLoaded).copyWith(errorMessage: () => e.toString()));
      } else {
        emit(ExpensesError(e.toString()));
      }
    }
  }

  void clearError() {
    if (state is ExpensesLoaded) {
      emit((state as ExpensesLoaded).copyWith(errorMessage: () => null));
    }
  }
}
