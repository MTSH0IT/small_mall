import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';

class CartItem {
  const CartItem({
    required this.productDetails,
    required this.selectedPrice,
    this.quantity = 1.0,
    this.discount = 0.0,
    this.customPrice,
  });
  final ProductWithDetails productDetails;
  final ProductPrice selectedPrice;
  final double quantity;
  final double discount;
  final double? customPrice;

  double get unitPrice => customPrice ?? selectedPrice.priceValue;
  bool get hasCustomPrice => customPrice != null && customPrice != selectedPrice.priceValue;

  double get subtotal => (unitPrice * quantity) - discount;

  CartItem copyWith({
    ProductWithDetails? productDetails,
    ProductPrice? selectedPrice,
    double? quantity,
    double? discount,
    double? customPrice,
    bool clearCustomPrice = false,
  }) {
    return CartItem(
      productDetails: productDetails ?? this.productDetails,
      selectedPrice: selectedPrice ?? this.selectedPrice,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      customPrice: clearCustomPrice ? null : (customPrice ?? this.customPrice),
    );
  }
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
    this.isCheckingOut = false,
  });
  final List<ProductWithDetails> products;
  final List<CustomerWithDebts> customers;
  final List<CartItem> cart;
  final Customer? selectedCustomer;
  final double invoiceDiscount;
  final String paymentType;
  final bool isCheckingOut;

  double get cartSubtotal => cart.fold<double>(0.0, (sum, item) => sum + item.subtotal);
  double get totalAmount => (cartSubtotal - invoiceDiscount).clamp(0.0, double.infinity);

  POSLoaded copyWith({
    List<ProductWithDetails>? products,
    List<CustomerWithDebts>? customers,
    List<CartItem>? cart,
    Customer? selectedCustomer,
    bool clearCustomer = false,
    double? invoiceDiscount,
    String? paymentType,
    bool? isCheckingOut,
  }) {
    return POSLoaded(
      products: products ?? this.products,
      customers: customers ?? this.customers,
      cart: cart ?? this.cart,
      selectedCustomer: clearCustomer ? null : (selectedCustomer ?? this.selectedCustomer),
      invoiceDiscount: invoiceDiscount ?? this.invoiceDiscount,
      paymentType: paymentType ?? this.paymentType,
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
    );
  }
}

class POSCheckoutSuccess extends POSState {}

class POSError extends POSState {
  POSError(this.message);
  final String message;
}
