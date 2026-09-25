import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/expenses/data/expenses_repository.dart';

abstract class ExpensesState {
  const ExpensesState();
}

class ExpensesInitial extends ExpensesState {}

class ExpensesLoading extends ExpensesState {}

class ExpensesLoaded extends ExpensesState {
  const ExpensesLoaded({
    required this.categories,
    this.subcategories = const [],
    required this.categorySummaries,
    required this.expenses,
    this.selectedCategoryId,
    this.selectedSubcategoryId,
    this.startDate,
    this.endDate,
    this.searchQuery = '',
    required this.totalAmount,
    this.errorMessage,
  });

  final List<ExpenseCategory> categories;
  final List<ExpenseCategory> subcategories;
  final List<CategoryExpenseSummary> categorySummaries;
  final List<ExpenseWithCategory> expenses;
  final String? selectedCategoryId; // null = all categories
  final String? selectedSubcategoryId; // null = all subcategories in selected category
  final DateTime? startDate;
  final DateTime? endDate;
  final String searchQuery;
  final double totalAmount;
  final String? errorMessage;

  List<ExpenseCategory> getSubcategoriesFor(String parentId) {
    return subcategories.where((s) => s.parentId == parentId).toList();
  }

  List<ExpenseWithCategory> get filteredExpenses {
    var result = expenses;
    if (selectedCategoryId != null && selectedCategoryId!.isNotEmpty) {
      result = result.where((e) => e.expense.categoryId == selectedCategoryId).toList();
    }
    if (selectedSubcategoryId != null && selectedSubcategoryId!.isNotEmpty) {
      result = result.where((e) => e.expense.subcategoryId == selectedSubcategoryId).toList();
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      result = result.where((e) {
        final catName = e.category?.name.toLowerCase() ?? '';
        final subName = e.subcategory?.name.toLowerCase() ?? '';
        final notes = e.expense.notes?.toLowerCase() ?? '';
        final amountStr = e.expense.amount.toString();
        return catName.contains(q) || subName.contains(q) || notes.contains(q) || amountStr.contains(q);
      }).toList();
    }
    return result;
  }

  double get filteredTotalAmount {
    return filteredExpenses.fold(0.0, (sum, item) => sum + item.expense.amount);
  }

  double get filteredTotalSyp {
    return filteredExpenses
        .where((e) => e.expense.currency != 'USD')
        .fold(0.0, (sum, item) => sum + item.expense.amount);
  }

  double get filteredTotalUsd {
    return filteredExpenses
        .where((e) => e.expense.currency == 'USD')
        .fold(0.0, (sum, item) => sum + item.expense.amount);
  }

  double get totalSyp {
    return expenses
        .where((e) => e.expense.currency != 'USD')
        .fold(0.0, (sum, item) => sum + item.expense.amount);
  }

  double get totalUsd {
    return expenses
        .where((e) => e.expense.currency == 'USD')
        .fold(0.0, (sum, item) => sum + item.expense.amount);
  }

  ExpensesLoaded copyWith({
    List<ExpenseCategory>? categories,
    List<ExpenseCategory>? subcategories,
    List<CategoryExpenseSummary>? categorySummaries,
    List<ExpenseWithCategory>? expenses,
    String? Function()? selectedCategoryId,
    String? Function()? selectedSubcategoryId,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
    String? searchQuery,
    double? totalAmount,
    String? Function()? errorMessage,
  }) {
    return ExpensesLoaded(
      categories: categories ?? this.categories,
      subcategories: subcategories ?? this.subcategories,
      categorySummaries: categorySummaries ?? this.categorySummaries,
      expenses: expenses ?? this.expenses,
      selectedCategoryId: selectedCategoryId != null ? selectedCategoryId() : this.selectedCategoryId,
      selectedSubcategoryId: selectedSubcategoryId != null ? selectedSubcategoryId() : this.selectedSubcategoryId,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      searchQuery: searchQuery ?? this.searchQuery,
      totalAmount: totalAmount ?? this.totalAmount,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class ExpensesError extends ExpensesState {
  const ExpensesError(this.message);

  final String message;
}
