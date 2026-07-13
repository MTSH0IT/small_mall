import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:artisan_gift_manager/features/customers_debts/data/customers_debts_repository.dart';
import 'package:artisan_gift_manager/features/inventory/data/inventory_repository.dart';
import 'package:artisan_gift_manager/features/pos/data/pos_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CartItem { // discount per item

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
  final String paymentType; // 'cash' or 'debt'
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

class POSCubit extends Cubit<POSState> {

  POSCubit(
    this._posRepository,
    this._inventoryRepository,
    this._customersRepository,
  ) : super(POSState(
          products: [],
          customers: [],
          cart: [],
          invoiceDiscount: 0.0,
          paymentType: 'cash',
          status: POSStatus.idle,
        ));
  final POSRepository _posRepository;
  final InventoryRepository _inventoryRepository;
  final CustomersDebtsRepository _customersRepository;

  Future<void> loadPOSData() async {
    try {
      final products = await _inventoryRepository.getProducts();
      final customers = await _customersRepository.getCustomers();
      final activeProducts = products.where((p) => p.product.isActive).toList();

      emit(state.copyWith(
        products: activeProducts,
        customers: customers,
        status: POSStatus.idle,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: POSStatus.error,
        errorMessage: () => e.toString(),
      ));
    }
  }

  void addToCart(ProductWithDetails product, ProductPrice price) {
    final existingIndex = state.cart.indexWhere(
      (item) => item.productDetails.product.id == product.product.id && item.selectedPrice.id == price.id,
    );

    final updatedCart = List<CartItem>.from(state.cart);

    if (existingIndex >= 0) {
      final existingItem = updatedCart[existingIndex];
      // Check stock limit
      if (existingItem.quantity + 1 <= product.currentStock) {
        updatedCart[existingIndex] = CartItem(
          productDetails: product,
          selectedPrice: price,
          quantity: existingItem.quantity + 1,
          discount: existingItem.discount,
        );
      }
    } else {
      updatedCart.add(CartItem(
        productDetails: product,
        selectedPrice: price,
        quantity: 1.0,
      ));
    }

    emit(state.copyWith(cart: updatedCart));
  }

  void updateCartItemQuantity(int index, double quantity) {
    final updatedCart = List<CartItem>.from(state.cart);
    if (index >= 0 && index < updatedCart.length) {
      final item = updatedCart[index];
      // Ensure we don't exceed stock limit (but allow adjustments if stock is offline/adjusted)
      updatedCart[index] = CartItem(
        productDetails: item.productDetails,
        selectedPrice: item.selectedPrice,
        quantity: quantity,
        discount: item.discount,
      );
      emit(state.copyWith(cart: updatedCart));
    }
  }

  void updateCartItemDiscount(int index, double discount) {
    final updatedCart = List<CartItem>.from(state.cart);
    if (index >= 0 && index < updatedCart.length) {
      final item = updatedCart[index];
      updatedCart[index] = CartItem(
        productDetails: item.productDetails,
        selectedPrice: item.selectedPrice,
        quantity: item.quantity,
        discount: discount,
      );
      emit(state.copyWith(cart: updatedCart));
    }
  }

  void removeFromCart(int index) {
    final updatedCart = List<CartItem>.from(state.cart);
    if (index >= 0 && index < updatedCart.length) {
      updatedCart.removeAt(index);
      emit(state.copyWith(cart: updatedCart));
    }
  }

  void clearCart() {
    emit(state.copyWith(
      cart: [],
      selectedCustomer: () => null,
      invoiceDiscount: 0.0,
      paymentType: 'cash',
    ));
  }

  void selectCustomer(Customer? customer) {
    emit(state.copyWith(selectedCustomer: () => customer));
  }

  void setInvoiceDiscount(double discount) {
    emit(state.copyWith(invoiceDiscount: discount));
  }

  void setPaymentType(String type) {
    emit(state.copyWith(paymentType: type));
  }

  Future<void> checkout() async {
    if (state.cart.isEmpty) return;
    if (state.paymentType == 'debt' && state.selectedCustomer == null) {
      emit(state.copyWith(
        status: POSStatus.error,
        errorMessage: () => 'يجب اختيار عميل للبيع بالآجل',
      ));
      return;
    }

    emit(state.copyWith(status: POSStatus.loading));

    try {
      final items = state.cart.map((item) => {
            'productId': item.productDetails.product.id,
            'priceUsed': item.selectedPrice.priceValue,
            'quantity': item.quantity,
            'discount': item.discount,
          }).toList();

      await _posRepository.createSale(
        customerId: state.selectedCustomer?.id,
        totalAmount: state.totalAmount,
        discount: state.invoiceDiscount,
        paymentType: state.paymentType,
        items: items,
      );

      emit(state.copyWith(status: POSStatus.success));
      clearCart();
      await loadPOSData(); // Reload inventory counts
    } catch (e) {
      emit(state.copyWith(
        status: POSStatus.error,
        errorMessage: () => e.toString(),
      ));
    }
  }
}
