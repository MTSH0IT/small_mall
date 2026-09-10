import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_state.dart';

void main() {
  group('CartItem Custom Price Tests', () {
    final testProduct = ProductWithDetails(
      product: Product(
        id: 'prod-001',
        code: '628100123456',
        name: 'عطر مسك فاخر',
        categoryId: 'cat-1',
        costPrice: 40.0,
        isActive: true,
        minStockAlert: 5.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      category: null,
      prices: [
        const ProductPrice(
          id: 'price-1',
          productId: 'prod-001',
          priceLabel: 'retail',
          priceValue: 100.0,
        ),
      ],
      currentStock: 20.0,
    );

    final basePrice = testProduct.prices.first;

    test('default price is used when customPrice is null', () {
      final item = CartItem(
        productDetails: testProduct,
        selectedPrice: basePrice,
        quantity: 2.0,
      );

      expect(item.unitPrice, 100.0);
      expect(item.hasCustomPrice, isFalse);
      expect(item.subtotal, 200.0);
    });

    test('custom price overrides unit price and subtotal properly', () {
      final item = CartItem(
        productDetails: testProduct,
        selectedPrice: basePrice,
        quantity: 2.0,
        customPrice: 85.0,
      );

      expect(item.unitPrice, 85.0);
      expect(item.hasCustomPrice, isTrue);
      expect(item.subtotal, 170.0);
    });

    test('custom price combines correctly with discount', () {
      final item = CartItem(
        productDetails: testProduct,
        selectedPrice: basePrice,
        quantity: 3.0,
        customPrice: 90.0,
        discount: 20.0,
      );

      expect(item.unitPrice, 90.0);
      expect(item.subtotal, 250.0); // (90 * 3) - 20 = 250
    });

    test('copyWith can clear custom price back to default', () {
      final item = CartItem(
        productDetails: testProduct,
        selectedPrice: basePrice,
        quantity: 1.0,
        customPrice: 75.0,
      );

      expect(item.hasCustomPrice, isTrue);

      final resetItem = item.copyWith(clearCustomPrice: true);
      expect(resetItem.hasCustomPrice, isFalse);
      expect(resetItem.unitPrice, 100.0);
      expect(resetItem.subtotal, 100.0);
    });
  });

  group('Barcode and Code Search Tests', () {
    final p1 = ProductWithDetails(
      product: Product(
        id: 'P-101',
        serialNumber: 1,
        code: '1234567890123',
        name: 'ساعة يد ذهبية',
        categoryId: null,
        costPrice: 150.0,
        isActive: true,
        minStockAlert: 2.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      category: null,
      prices: [],
      currentStock: 10.0,
    );

    final p2 = ProductWithDetails(
      product: Product(
        id: 'P-102',
        serialNumber: 2,
        code: '9876543210987',
        name: 'محفظة جلدية',
        categoryId: null,
        costPrice: 50.0,
        isActive: true,
        minStockAlert: 2.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      category: null,
      prices: [],
      currentStock: 5.0,
    );

    final products = [p1, p2];

    test('matches exact barcode/code', () {
      const scannedCode = '1234567890123';
      final match = products.where((p) => p.product.code == scannedCode).firstOrNull;

      expect(match, isNotNull);
      expect(match?.product.name, 'ساعة يد ذهبية');
    });

    test('matches serial number (product ID)', () {
      const searchedSerial = 2;
      final match = products.where((p) => p.product.serialNumber == searchedSerial).firstOrNull;

      expect(match, isNotNull);
      expect(match?.product.name, 'محفظة جلدية');
    });
  });
}
