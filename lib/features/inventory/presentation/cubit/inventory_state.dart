import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';

abstract class InventoryState {}

class InventoryInitial extends InventoryState {}

class InventoryLoading extends InventoryState {}

class InventoryLoaded extends InventoryState {
  InventoryLoaded({required this.products, required this.categories});
  final List<ProductWithDetails> products;
  final List<Category> categories;
}

class InventoryError extends InventoryState {
  InventoryError(this.message);
  final String message;
}
