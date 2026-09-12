import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';
import 'package:small_mall/features/customers_debts/presentation/cubit/customers_debts_state.dart';

class CustomersDebtsCubit extends Cubit<CustomersDebtsState> {

  CustomersDebtsCubit(this._repository) : super(CustomersDebtsInitial());
  final CustomersDebtsRepository _repository;

  Future<void> loadCustomers() async {
    emit(CustomersDebtsLoading());
    try {
      final list = await _repository.getCustomers();
      emit(CustomersDebtsLoaded(customers: list));
    } catch (e) {
      emit(CustomersDebtsError(e.toString()));
    }
  }

  Future<void> selectCustomer(String customerId) async {
    final currentState = state;
    if (currentState is CustomersDebtsLoaded) {
      try {
        final debts = await _repository.getCustomerDebts(customerId);
        emit(currentState.copyWith(
          selectedCustomerId: customerId,
          selectedCustomerDebts: debts,
          errorMessage: null,
        ));
      } catch (e) {
        emit(currentState.copyWith(errorMessage: e.toString()));
      }
    }
  }

  Future<void> addCustomer({
    required String name,
    required String? phone,
    required String? notes,
  }) async {
    try {
      final newCustomer = await _repository.addCustomer(name: name, phone: phone, notes: notes);
      final list = await _repository.getCustomers();
      final debts = await _repository.getCustomerDebts(newCustomer.id);
      emit(CustomersDebtsLoaded(
        customers: list,
        selectedCustomerId: newCustomer.id,
        selectedCustomerDebts: debts,
      ));
    } catch (e) {
      if (state is CustomersDebtsLoaded) {
        emit((state as CustomersDebtsLoaded).copyWith(errorMessage: e.toString()));
      } else {
        emit(CustomersDebtsError(e.toString()));
      }
    }
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    required String? phone,
    required String? notes,
  }) async {
    try {
      await _repository.updateCustomer(id: id, name: name, phone: phone, notes: notes);
      final list = await _repository.getCustomers();
      final debts = await _repository.getCustomerDebts(id);
      emit(CustomersDebtsLoaded(
        customers: list,
        selectedCustomerId: id,
        selectedCustomerDebts: debts,
      ));
    } catch (e) {
      if (state is CustomersDebtsLoaded) {
        emit((state as CustomersDebtsLoaded).copyWith(errorMessage: e.toString()));
      } else {
        emit(CustomersDebtsError(e.toString()));
      }
    }
  }

  Future<void> recordPayment({
    required String customerId,
    required String debtId,
    required double amountPaid,
  }) async {
    try {
      await _repository.recordPayment(debtId: debtId, amountPaid: amountPaid);
      // Reload the active customer's debts and the overall customer list
      final list = await _repository.getCustomers();
      final debts = await _repository.getCustomerDebts(customerId);
      emit(CustomersDebtsLoaded(
        customers: list,
        selectedCustomerId: customerId,
        selectedCustomerDebts: debts,
      ));
    } catch (e) {
      if (state is CustomersDebtsLoaded) {
        emit((state as CustomersDebtsLoaded).copyWith(errorMessage: e.toString()));
      } else {
        emit(CustomersDebtsError(e.toString()));
      }
    }
  }
}
