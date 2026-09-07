import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';

void main() {
  group('Product Category & Search Filtering Tests', () {
    final cat1 = const Category(id: 'cat-1', name: 'عطور');
    final cat2 = const Category(id: 'cat-2', name: 'ساعات');

    final p1 = ProductWithDetails(
      product: Product(
        id: 'p1',
        name: 'عطر الورد',
        categoryId: 'cat-1',
        costPrice: 50,
        isActive: true,
        minStockAlert: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      category: cat1,
      prices: [],
      currentStock: 10,
    );

    final p2 = ProductWithDetails(
      product: Product(
        id: 'p2',
        name: 'ساعة يد كلاسيك',
        categoryId: 'cat-2',
        costPrice: 150,
        isActive: true,
        minStockAlert: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      category: cat2,
      prices: [],
      currentStock: 5,
    );

    final p3 = ProductWithDetails(
      product: Product(
        id: 'p3',
        name: 'هدية بدون تصنيف',
        categoryId: null,
        costPrice: 20,
        isActive: true,
        minStockAlert: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      category: null,
      prices: [],
      currentStock: 15,
    );

    final products = [p1, p2, p3];

    List<ProductWithDetails> filterProducts({
      required List<ProductWithDetails> items,
      required String query,
      String? selectedCategoryId,
    }) {
      final q = query.trim().toLowerCase();
      return items.where((p) {
        final matchesSearch = q.isEmpty || p.product.name.toLowerCase().contains(q);

        final bool matchesCategory;
        if (selectedCategoryId == null) {
          matchesCategory = true;
        } else if (selectedCategoryId == '__uncategorized__') {
          matchesCategory = p.product.categoryId == null;
        } else {
          matchesCategory = p.product.categoryId == selectedCategoryId;
        }

        return matchesSearch && matchesCategory;
      }).toList();
    }

    test('returns all products when no category selected and query is empty', () {
      final result = filterProducts(items: products, query: '', selectedCategoryId: null);
      expect(result.length, equals(3));
    });

    test('filters by specific category', () {
      final result1 = filterProducts(items: products, query: '', selectedCategoryId: 'cat-1');
      expect(result1.length, equals(1));
      expect(result1.first.product.id, equals('p1'));

      final result2 = filterProducts(items: products, query: '', selectedCategoryId: 'cat-2');
      expect(result2.length, equals(1));
      expect(result2.first.product.id, equals('p2'));
    });

    test('filters uncategorized products', () {
      final result = filterProducts(items: products, query: '', selectedCategoryId: '__uncategorized__');
      expect(result.length, equals(1));
      expect(result.first.product.id, equals('p3'));
    });

    test('combines category filter and search query', () {
      final result = filterProducts(items: products, query: 'ساعة', selectedCategoryId: 'cat-2');
      expect(result.length, equals(1));
      expect(result.first.product.name, equals('ساعة يد كلاسيك'));

      // Different category with search query that doesn't match
      final resultEmpty = filterProducts(items: products, query: 'ساعة', selectedCategoryId: 'cat-1');
      expect(resultEmpty.isEmpty, isTrue);
    });
  });
}
