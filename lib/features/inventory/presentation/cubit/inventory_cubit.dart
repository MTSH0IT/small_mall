import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:artisan_gift_manager/features/inventory/data/inventory_repository.dart';
import 'package:artisan_gift_manager/core/database/app_database.dart';

abstract class InventoryState {}

class InventoryInitial extends InventoryState {}

class InventoryLoading extends InventoryState {}

class InventoryLoaded extends InventoryState {
  final List<ProductWithDetails> products;
  final List<Category> categories;

  InventoryLoaded({required this.products, required this.categories});
}

class InventoryError extends InventoryState {
  final String message;
  InventoryError(this.message);
}

class InventoryCubit extends Cubit<InventoryState> {
  final InventoryRepository _repository;

  InventoryCubit(this._repository) : super(InventoryInitial());

  Future<void> loadInventory() async {
    emit(InventoryLoading());
    try {
      final products = await _repository.getProducts();
      final categories = await _repository.getCategories();
      // Filter out deleted/inactive products
      final activeProducts = products.where((p) => p.product.isActive).toList();
      emit(InventoryLoaded(products: activeProducts, categories: categories));
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> addProduct({
    required String name,
    required String? categoryId,
    required double costPrice,
    required double minStockAlert,
    required List<Map<String, dynamic>> prices,
    required double initialStock,
  }) async {
    try {
      await _repository.addProduct(
        name: name,
        categoryId: categoryId,
        costPrice: costPrice,
        minStockAlert: minStockAlert,
        prices: prices,
        initialStock: initialStock,
      );
      await loadInventory();
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required String? categoryId,
    required double costPrice,
    required double minStockAlert,
    required List<Map<String, dynamic>> prices,
  }) async {
    try {
      await _repository.updateProduct(
        id: id,
        name: name,
        categoryId: categoryId,
        costPrice: costPrice,
        minStockAlert: minStockAlert,
        prices: prices,
      );
      await loadInventory();
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _repository.deleteProduct(id);
      await loadInventory();
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> adjustStock(String productId, double quantity, String reason) async {
    try {
      await _repository.adjustStock(productId, quantity, reason);
      await loadInventory();
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> addCategory(String name) async {
    try {
      await _repository.addCategory(name);
      await loadInventory();
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }
}
