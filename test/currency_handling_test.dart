import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_state.dart';

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
}
