import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_state.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_state.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';

void main() {
  group('UnifiedTransactionRecord Multi-Currency Tests', () {
    test('Identifies multi-currency transactions and calculates separated totals', () {
      final record = UnifiedTransactionRecord(
        id: 'tx-1',
        type: UnifiedTransactionType.sale,
        createdAt: DateTime.now(),
        totalAmount: 13.50,
        currency: 'USD',
        items: const [
          UnifiedTransactionItem(
            productName: 'Item 1',
            quantity: 1.0,
            unitPrice: 1.50,
            currency: 'USD',
          ),
          UnifiedTransactionItem(
            productName: 'Item 2',
            quantity: 1.0,
            unitPrice: 12.0,
            currency: 'SYP',
          ),
        ],
      );

      expect(record.hasMultipleCurrencies, isTrue);
      expect(record.totalUsd, equals(1.50));
      expect(record.totalSyp, equals(12.0));
    });

    test('Single-currency transaction returns false for hasMultipleCurrencies', () {
      final record = UnifiedTransactionRecord(
        id: 'tx-2',
        type: UnifiedTransactionType.sale,
        createdAt: DateTime.now(),
        totalAmount: 50.0,
        currency: 'SYP',
        items: const [
          UnifiedTransactionItem(
            productName: 'Item A',
            quantity: 2.0,
            unitPrice: 25.0,
            currency: 'SYP',
          ),
        ],
      );

      expect(record.hasMultipleCurrencies, isFalse);
      expect(record.totalSyp, equals(50.0));
      expect(record.totalUsd, equals(0.0));
    });
  });

  group('POSLoaded Multi-Currency Tests', () {
    test('Separates subtotals and net amounts by currency in cart', () {
      final now = DateTime.now();
      final p1 = Product(
        id: 'p1',
        name: 'Product 1',
        costPrice: 1.0,
        costPriceUsd: 1.0,
        isActive: true,
        minStockAlert: 0.0,
        createdAt: now,
        updatedAt: now,
        currency: 'USD',
      );
      final p2 = Product(
        id: 'p2',
        name: 'Product 2',
        costPrice: 10.0,
        costPriceUsd: 0.0,
        isActive: true,
        minStockAlert: 0.0,
        createdAt: now,
        updatedAt: now,
        currency: 'SYP',
      );

      final pr1 = const ProductPrice(
        id: 'pr1',
        productId: 'p1',
        priceLabel: 'retail',
        priceValue: 1.50,
        currency: 'USD',
      );
      final pr2 = const ProductPrice(
        id: 'pr2',
        productId: 'p2',
        priceLabel: 'retail',
        priceValue: 12.0,
        currency: 'SYP',
      );

      final state = POSLoaded(
        products: [],
        customers: [],
        cart: [
          CartItem(
            productDetails: ProductWithDetails(
              product: p1,
              prices: [pr1],
              currentStock: 5.0,
            ),
            selectedPrice: pr1,
            quantity: 1.0,
          ),
          CartItem(
            productDetails: ProductWithDetails(
              product: p2,
              prices: [pr2],
              currentStock: 10.0,
            ),
            selectedPrice: pr2,
            quantity: 1.0,
          ),
        ],
        invoiceDiscount: 2.0,
        paymentType: 'cash',
      );

      expect(state.hasMultipleCurrencies, isTrue);
      expect(state.subtotalUsd, equals(1.50));
      expect(state.subtotalSyp, equals(12.0));
      expect(state.totalUsd, equals(1.50));
      // Discount applied to SYP: 12.0 - 2.0 = 10.0
      expect(state.totalSyp, equals(10.0));
    });
  });

  group('CustomerWithDebts Multi-Currency Tests', () {
    test('Correctly separates SYP and USD debts and reports debt flags', () {
      final now = DateTime.now();
      final customer = Customer(
        id: 'c1',
        name: 'زبون تجريبي',
        phone: '0999123456',
        createdAt: now,
      );

      final customerWithDebts = CustomerWithDebts(
        customer: customer,
        totalDebt: 50000.0,
        totalDebtSyp: 50000.0,
        totalDebtUsd: 25.0,
        openDebtsCount: 2,
      );

      expect(customerWithDebts.hasDebt, isTrue);
      expect(customerWithDebts.hasBothCurrencies, isTrue);
      expect(customerWithDebts.totalDebtSyp, equals(50000.0));
      expect(customerWithDebts.totalDebtUsd, equals(25.0));

      final customerSypOnly = CustomerWithDebts(
        customer: customer,
        totalDebt: 50000.0,
        totalDebtSyp: 50000.0,
        totalDebtUsd: 0.0,
        openDebtsCount: 1,
      );

      expect(customerSypOnly.hasDebt, isTrue);
      expect(customerSypOnly.hasBothCurrencies, isFalse);

      final customerZeroDebt = CustomerWithDebts(
        customer: customer,
        totalDebt: 0.0,
        totalDebtSyp: 0.0,
        totalDebtUsd: 0.0,
        openDebtsCount: 0,
      );

      expect(customerZeroDebt.hasDebt, isFalse);
      expect(customerZeroDebt.hasBothCurrencies, isFalse);
    });
  });

  group('InvoicesLoaded Multi-Currency Ledger Aggregation Tests', () {
    test('Correctly separates SYP and USD totals across sales, purchases, and expenses', () {
      final now = DateTime.now();
      final txs = [
        UnifiedTransactionRecord(
          id: 'tx-s1',
          type: UnifiedTransactionType.sale,
          createdAt: now,
          totalAmount: 10000.0,
          currency: 'SYP',
        ),
        UnifiedTransactionRecord(
          id: 'tx-s2',
          type: UnifiedTransactionType.sale,
          createdAt: now,
          totalAmount: 50.0,
          currency: 'USD',
        ),
        UnifiedTransactionRecord(
          id: 'tx-p1',
          type: UnifiedTransactionType.purchase,
          createdAt: now,
          totalAmount: 8000.0,
          currency: 'SYP',
        ),
        UnifiedTransactionRecord(
          id: 'tx-p2',
          type: UnifiedTransactionType.purchase,
          createdAt: now,
          totalAmount: 30.0,
          currency: 'USD',
        ),
        UnifiedTransactionRecord(
          id: 'tx-e1',
          type: UnifiedTransactionType.expense,
          createdAt: now,
          totalAmount: 1500.0,
          currency: 'SYP',
        ),
        UnifiedTransactionRecord(
          id: 'tx-e2',
          type: UnifiedTransactionType.expense,
          createdAt: now,
          totalAmount: 5.0,
          currency: 'USD',
        ),
      ];

      final state = InvoicesLoaded(transactions: txs);

      expect(state.salesCount, equals(2));
      expect(state.totalSalesAmountSyp, equals(10000.0));
      expect(state.totalSalesAmountUsd, equals(50.0));

      expect(state.purchasesCount, equals(2));
      expect(state.totalPurchasesAmountSyp, equals(8000.0));
      expect(state.totalPurchasesAmountUsd, equals(30.0));

      expect(state.expensesCount, equals(2));
      expect(state.totalExpensesAmountSyp, equals(1500.0));
      expect(state.totalExpensesAmountUsd, equals(5.0));
    });
  });

  group('InventoryAndDebtsReportData Multi-Currency Tests', () {
    test('Retains separate SYP and USD debt amounts and calculates collection rate', () {
      final report = InventoryAndDebtsReportData(
        totalInventoryCost: 100000.0,
        totalActiveProducts: 15,
        lowStockProductsCount: 2,
        adjustmentsCostInPeriod: 0.0,
        adjustmentsCountInPeriod: 0,
        totalOutstandingDebts: 20000.0,
        newDebtsIssuedInPeriod: 30000.0,
        debtsCollectedInPeriod: 20000.0,
        totalOutstandingDebtsSyp: 20000.0,
        totalOutstandingDebtsUsd: 15.0,
        newDebtsIssuedInPeriodSyp: 30000.0,
        newDebtsIssuedInPeriodUsd: 10.0,
        debtsCollectedInPeriodSyp: 20000.0,
        debtsCollectedInPeriodUsd: 5.0,
      );

      expect(report.totalOutstandingDebtsSyp, equals(20000.0));
      expect(report.totalOutstandingDebtsUsd, equals(15.0));
      expect(report.newDebtsIssuedInPeriodSyp, equals(30000.0));
      expect(report.newDebtsIssuedInPeriodUsd, equals(10.0));
      expect(report.debtsCollectedInPeriodSyp, equals(20000.0));
      expect(report.debtsCollectedInPeriodUsd, equals(5.0));
      expect(report.collectionRate, closeTo(40.0, 0.01));
    });
  });
}
