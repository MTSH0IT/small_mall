import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:artisan_gift_manager/features/customers_debts/data/customers_debts_repository.dart';
import 'package:artisan_gift_manager/features/inventory/data/inventory_repository.dart';

class CartItem {
  CartItem({
    required this.productDetails,
    required this.selectedPrice,
    this.quantity = 1.0,
    this.discount = 0.0,
  });
  final ProductWithDetails productDetails;
  final ProductPrice selectedPrice;
  double quantity;
  double discount;

  double get subtotal => (selectedPrice.priceValue * quantity) - discount;
}

enum POSStatus { idle, loading, success, error }

class POSState {
  POSState({
    required this.products,
    required this.customers,
    required this.cart,
    this.selectedCustomer,
    required this.invoiceDiscount,
    required this.paymentType,
    required this.status,
    this.errorMessage,
  });
  final List<ProductWithDetails> products;
  final List<CustomerWithDebts> customers;
  final List<CartItem> cart;
  final Customer? selectedCustomer;
  final double invoiceDiscount;
  final String paymentType;
  final POSStatus status;
  final String? errorMessage;

  POSState copyWith({
    List<ProductWithDetails>? products,
    List<CustomerWithDebts>? customers,
    List<CartItem>? cart,
    Customer? Function()? selectedCustomer,
    double? invoiceDiscount,
    String? paymentType,
    POSStatus? status,
    String? Function()? errorMessage,
  }) {
    return POSState(
      products: products ?? this.products,
      customers: customers ?? this.customers,
      cart: cart ?? this.cart,
      selectedCustomer: selectedCustomer != null ? selectedCustomer() : this.selectedCustomer,
      invoiceDiscount: invoiceDiscount ?? this.invoiceDiscount,
      paymentType: paymentType ?? this.paymentType,
      status: status ?? this.status,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  double get cartSubtotal => cart.fold<double>(0.0, (sum, item) => sum + item.subtotal);
  double get totalAmount => (cartSubtotal - invoiceDiscount).clamp(0.0, double.infinity);
}
