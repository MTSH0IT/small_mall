import 'package:artisan_gift_manager/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

class SuppliersPurchasingCubit extends Cubit<SuppliersPurchasingState> {

  SuppliersPurchasingCubit(this._repository) : super(SuppliersPurchasingInitial());
  final SuppliersPurchasingRepository _repository;

  Future<void> loadSuppliers() async {
    emit(SuppliersPurchasingLoading());
    try {
      final list = await _repository.getSuppliers();
      emit(SuppliersPurchasingLoaded(suppliers: list));
    } catch (e) {
      emit(SuppliersPurchasingError(e.toString()));
    }
  }

  Future<void> addSupplier({
    required String name,
    required String? phone,
    required String? notes,
  }) async {
    try {
      await _repository.addSupplier(name: name, phone: phone, notes: notes);
      await loadSuppliers();
    } catch (e) {
      emit(SuppliersPurchasingError(e.toString()));
    }
  }

  Future<void> recordPurchase({
    required String supplierId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await _repository.recordPurchase(
        supplierId: supplierId,
        totalAmount: totalAmount,
        items: items,
      );
      await loadSuppliers();
    } catch (e) {
      emit(SuppliersPurchasingError(e.toString()));
    }
  }
}
