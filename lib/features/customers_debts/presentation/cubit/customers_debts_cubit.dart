import 'package:artisan_gift_manager/features/customers_debts/data/customers_debts_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class CustomersDebtsState {}

class CustomersDebtsInitial extends CustomersDebtsState {}

class CustomersDebtsLoading extends CustomersDebtsState {}

class CustomersDebtsLoaded extends CustomersDebtsState {

  CustomersDebtsLoaded({
    required this.customers,
    this.selectedCustomerDebts,
    this.selectedCustomerId,
  });
  final List<CustomerWithDebts> customers;
  final List<DebtWithPayments>? selectedCustomerDebts;
  final String? selectedCustomerId;

  CustomersDebtsLoaded copyWith({
    List<CustomerWithDebts>? customers,
    List<DebtWithPayments>? Function()? selectedCustomerDebts,
    String? Function()? selectedCustomerId,
  }) {
    return CustomersDebtsLoaded(
      customers: customers ?? this.customers,
      selectedCustomerDebts: selectedCustomerDebts != null ? selectedCustomerDebts() : this.selectedCustomerDebts,
      selectedCustomerId: selectedCustomerId != null ? selectedCustomerId() : this.selectedCustomerId,
    );
  }
}

class CustomersDebtsError extends CustomersDebtsState {
  CustomersDebtsError(this.message);
  final String message;
}

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
          selectedCustomerId: () => customerId,
          selectedCustomerDebts: () => debts,
        ));
      } catch (e) {
        emit(CustomersDebtsError(e.toString()));
      }
    }
  }

  Future<void> addCustomer({
    required String name,
    required String? phone,
    required String? notes,
  }) async {
    try {
      await _repository.addCustomer(name: name, phone: phone, notes: notes);
      await loadCustomers();
    } catch (e) {
      emit(CustomersDebtsError(e.toString()));
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
      emit(CustomersDebtsError(e.toString()));
    }
  }
}
