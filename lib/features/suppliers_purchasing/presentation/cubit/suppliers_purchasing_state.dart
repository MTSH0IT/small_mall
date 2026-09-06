import 'package:small_mall/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';

abstract class SuppliersPurchasingState {}

class SuppliersPurchasingInitial extends SuppliersPurchasingState {}

class SuppliersPurchasingLoading extends SuppliersPurchasingState {}

class SuppliersPurchasingLoaded extends SuppliersPurchasingState {
  SuppliersPurchasingLoaded({
    required this.suppliers,
    this.errorMessage,
  });
  final List<SupplierWithPurchases> suppliers;
  final String? errorMessage;

  SuppliersPurchasingLoaded copyWith({
    List<SupplierWithPurchases>? suppliers,
    String? errorMessage,
  }) {
    return SuppliersPurchasingLoaded(
      suppliers: suppliers ?? this.suppliers,
      errorMessage: errorMessage,
    );
  }
}

class SuppliersPurchasingError extends SuppliersPurchasingState {
  SuppliersPurchasingError(this.message);
  final String message;
}
