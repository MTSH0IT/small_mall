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

abstract class POSState {}

class POSInitial extends POSState {}

class POSLoading extends POSState {}

class POSLoaded extends POSState {
  POSLoaded({
    required this.products,
    required this.customers,
    required this.cart,
    this.selectedCustomer,
    required this.invoiceDiscount,
    required this.paymentType,
  });
  final List<ProductWithDetails> products;
  final List<CustomerWithDebts> customers;
  final List<CartItem> cart;
  final Customer? selectedCustomer;
  final double invoiceDiscount;
  final String paymentType;

  double get cartSubtotal => cart.fold<double>(0.0, (sum, item) => sum + item.subtotal);
  double get totalAmount => (cartSubtotal - invoiceDiscount).clamp(0.0, double.infinity);
}

class POSCheckoutSuccess extends POSState {}

class POSError extends POSState {
  POSError(this.message);
  final String message;
}
