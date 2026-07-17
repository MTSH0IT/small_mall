import 'package:artisan_gift_manager/features/customers_debts/data/customers_debts_repository.dart';

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
