import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/expenses/data/expenses_repository.dart';
import 'package:small_mall/features/expenses/presentation/cubit/expenses_state.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';

void main() {
  group('ExpensesState Filtering & Calculation Tests', () {
    final now = DateTime.now();

    final catSalaries = ExpenseCategory(
      id: 'cat-salaries',
      name: 'الرواتب والأجور',
      description: 'رواتب العمال والموظفين',
      createdAt: now,
    );

    final catRent = ExpenseCategory(
      id: 'cat-rent',
      name: 'الإيجار',
      description: 'إيجار المحل الشهري',
      createdAt: now,
    );

    final catBills = ExpenseCategory(
      id: 'cat-bills',
      name: 'فواتير ومرافق',
      description: 'كهرباء ومياه وإنترنت',
      createdAt: now,
    );

    final testExpenses = [
      ExpenseWithCategory(
        expense: Expense(
          id: 'exp-1',
          categoryId: 'cat-salaries',
          amount: 3000.0,
          notes: 'راتب المحاسب لشهر أغسطس',
          createdAt: now,
        ),
        category: catSalaries,
      ),
      ExpenseWithCategory(
        expense: Expense(
          id: 'exp-2',
          categoryId: 'cat-rent',
          amount: 5000.0,
          notes: 'إيجار المعرض',
          createdAt: now,
        ),
        category: catRent,
      ),
      ExpenseWithCategory(
        expense: Expense(
          id: 'exp-3',
          categoryId: 'cat-bills',
          amount: 450.0,
          notes: 'فاتورة الكهرباء',
          createdAt: now,
        ),
        category: catBills,
      ),
      ExpenseWithCategory(
        expense: Expense(
          id: 'exp-4',
          categoryId: 'cat-salaries',
          amount: 1500.0,
          notes: 'مكافأة العامل',
          createdAt: now,
        ),
        category: catSalaries,
      ),
    ];

    test('Initial loaded state returns all expenses and total sum', () {
      final state = ExpensesLoaded(
        categories: [catSalaries, catRent, catBills],
        categorySummaries: [],
        expenses: testExpenses,
        totalAmount: 9950.0,
      );

      expect(state.filteredExpenses.length, equals(4));
      expect(state.filteredTotalAmount, equals(9950.0));
    });

    test('Filtering by category returns only matching expenses', () {
      final state = ExpensesLoaded(
        categories: [catSalaries, catRent, catBills],
        categorySummaries: [],
        expenses: testExpenses,
        selectedCategoryId: 'cat-salaries',
        totalAmount: 9950.0,
      );

      final filtered = state.filteredExpenses;
      expect(filtered.length, equals(2));
      expect(filtered.every((e) => e.expense.categoryId == 'cat-salaries'), isTrue);
      expect(state.filteredTotalAmount, equals(4500.0)); // 3000 + 1500
    });

    test('Filtering by search query in notes', () {
      final state = ExpensesLoaded(
        categories: [catSalaries, catRent, catBills],
        categorySummaries: [],
        expenses: testExpenses,
        searchQuery: 'كهرباء',
        totalAmount: 9950.0,
      );

      final filtered = state.filteredExpenses;
      expect(filtered.length, equals(1));
      expect(filtered.first.expense.amount, equals(450.0));
      expect(state.filteredTotalAmount, equals(450.0));
    });

    test('Filtering by search query in category name', () {
      final state = ExpensesLoaded(
        categories: [catSalaries, catRent, catBills],
        categorySummaries: [],
        expenses: testExpenses,
        searchQuery: 'الإيجار',
        totalAmount: 9950.0,
      );

      final filtered = state.filteredExpenses;
      expect(filtered.length, equals(1));
      expect(filtered.first.expense.id, equals('exp-2'));
      expect(state.filteredTotalAmount, equals(5000.0));
    });

    test('Combining category filter and search query', () {
      final state = ExpensesLoaded(
        categories: [catSalaries, catRent, catBills],
        categorySummaries: [],
        expenses: testExpenses,
        selectedCategoryId: 'cat-salaries',
        searchQuery: 'مكافأة',
        totalAmount: 9950.0,
      );

      final filtered = state.filteredExpenses;
      expect(filtered.length, equals(1));
      expect(filtered.first.expense.id, equals('exp-4'));
      expect(state.filteredTotalAmount, equals(1500.0));
    });
  });

  group('Net Profit with Store Expenses Calculations', () {
    test('Calculates gross profit and net profit correctly when profitable', () {
      final report = ProfitReportData(
        totalRevenue: 20000.0,
        totalCost: 12000.0,
        grossProfit: 8000.0, // 20000 - 12000
        totalExpenses: 3500.0,
        netProfit: 4500.0, // 8000 - 3500
      );

      expect(report.totalRevenue, equals(20000.0));
      expect(report.totalCost, equals(12000.0));
      expect(report.grossProfit, equals(8000.0));
      expect(report.totalExpenses, equals(3500.0));
      expect(report.netProfit, equals(4500.0));
      expect(report.totalProfit, equals(4500.0)); // alias works
    });

    test('Calculates net loss when operational expenses exceed gross profit', () {
      final report = ProfitReportData(
        totalRevenue: 10000.0,
        totalCost: 7000.0,
        grossProfit: 3000.0,
        totalExpenses: 5000.0,
        netProfit: -2000.0, // 3000 - 5000 = -2000
      );

      expect(report.grossProfit, equals(3000.0));
      expect(report.totalExpenses, equals(5000.0));
      expect(report.netProfit, equals(-2000.0));
      expect(report.netProfit.isNegative, isTrue);
    });

    test('Zero sales period accounts for operational expenses as net loss', () {
      const double periodExpenses = 2500.0;
      final report = ProfitReportData(
        totalRevenue: 0.0,
        totalCost: 0.0,
        grossProfit: 0.0,
        totalExpenses: periodExpenses,
        netProfit: -periodExpenses,
      );

      expect(report.grossProfit, equals(0.0));
      expect(report.totalExpenses, equals(2500.0));
      expect(report.netProfit, equals(-2500.0));
    });
  });
}
