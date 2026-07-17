import 'package:artisan_gift_manager/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';

abstract class SuppliersPurchasingState {}

class SuppliersPurchasingInitial extends SuppliersPurchasingState {}

class SuppliersPurchasingLoading extends SuppliersPurchasingState {}

class SuppliersPurchasingLoaded extends SuppliersPurchasingState {
  SuppliersPurchasingLoaded({required this.suppliers});
  final List<SupplierWithPurchases> suppliers;
}

class SuppliersPurchasingError extends SuppliersPurchasingState {
  SuppliersPurchasingError(this.message);
  final String message;
}
