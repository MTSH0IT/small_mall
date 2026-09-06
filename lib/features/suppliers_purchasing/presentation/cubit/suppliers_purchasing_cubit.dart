import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/cubit/suppliers_purchasing_state.dart';

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
      if (state is SuppliersPurchasingLoaded) {
        emit((state as SuppliersPurchasingLoaded).copyWith(errorMessage: e.toString()));
      } else {
        emit(SuppliersPurchasingError(e.toString()));
      }
    }
  }

  Future<void> updateSupplier({
    required String id,
    required String name,
    required String? phone,
    required String? notes,
  }) async {
    try {
      await _repository.updateSupplier(id: id, name: name, phone: phone, notes: notes);
      await loadSuppliers();
    } catch (e) {
      if (state is SuppliersPurchasingLoaded) {
        emit((state as SuppliersPurchasingLoaded).copyWith(errorMessage: e.toString()));
      } else {
        emit(SuppliersPurchasingError(e.toString()));
      }
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
      if (state is SuppliersPurchasingLoaded) {
        emit((state as SuppliersPurchasingLoaded).copyWith(errorMessage: e.toString()));
      } else {
        emit(SuppliersPurchasingError(e.toString()));
      }
    }
  }
}
