import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';

abstract class CustomersDebtsState {}

class CustomersDebtsInitial extends CustomersDebtsState {}

class CustomersDebtsLoading extends CustomersDebtsState {}

class CustomersDebtsLoaded extends CustomersDebtsState {
  CustomersDebtsLoaded({
    required this.customers,
    this.selectedCustomerDebts,
    this.selectedCustomerId,
    this.errorMessage,
  });
  final List<CustomerWithDebts> customers;
  final List<DebtWithPayments>? selectedCustomerDebts;
  final String? selectedCustomerId;
  final String? errorMessage;

  CustomersDebtsLoaded copyWith({
    List<CustomerWithDebts>? customers,
    List<DebtWithPayments>? selectedCustomerDebts,
    String? selectedCustomerId,
    String? errorMessage,
  }) {
    return CustomersDebtsLoaded(
      customers: customers ?? this.customers,
      selectedCustomerDebts: selectedCustomerDebts ?? this.selectedCustomerDebts,
      selectedCustomerId: selectedCustomerId ?? this.selectedCustomerId,
      errorMessage: errorMessage,
    );
  }
}

class CustomersDebtsError extends CustomersDebtsState {
  CustomersDebtsError(this.message);
  final String message;
}
