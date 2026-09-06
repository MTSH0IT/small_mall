import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';

abstract class InventoryState {}

class InventoryInitial extends InventoryState {}

class InventoryLoading extends InventoryState {}

class InventoryLoaded extends InventoryState {
  InventoryLoaded({
    required this.products,
    required this.categories,
    this.errorMessage,
  });
  final List<ProductWithDetails> products;
  final List<Category> categories;
  final String? errorMessage;

  InventoryLoaded copyWith({
    List<ProductWithDetails>? products,
    List<Category>? categories,
    String? errorMessage,
    bool clearError = false,
  }) {
    return InventoryLoaded(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class InventoryError extends InventoryState {
  InventoryError(this.message);
  final String message;
}
