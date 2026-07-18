import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:artisan_gift_manager/features/customers_debts/data/customers_debts_repository.dart';
import 'package:artisan_gift_manager/features/inventory/data/inventory_repository.dart';
import 'package:artisan_gift_manager/features/pos/data/pos_repository.dart';
import 'package:artisan_gift_manager/features/pos/presentation/cubit/pos_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class POSCubit extends Cubit<POSState> {
  POSCubit(
    this._posRepository,
    this._inventoryRepository,
    this._customersRepository,
  ) : super(POSInitial());
  final POSRepository _posRepository;
  final InventoryRepository _inventoryRepository;
  final CustomersDebtsRepository _customersRepository;

  Future<void> loadPOSData() async {
    emit(POSLoading());
    try {
      final products = await _inventoryRepository.getProducts();
      final customers = await _customersRepository.getCustomers();
      final activeProducts = products.where((p) => p.product.isActive).toList();

      emit(POSLoaded(
        products: activeProducts,
        customers: customers,
        cart: [],
        invoiceDiscount: 0.0,
        paymentType: 'cash',
      ));
    } catch (e) {
      emit(POSError(e.toString()));
    }
  }

  void addToCart(ProductWithDetails product, ProductPrice price) {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;

    final existingIndex = loaded.cart.indexWhere(
      (item) =>
          item.productDetails.product.id == product.product.id &&
          item.selectedPrice.id == price.id,
    );

    final updatedCart = List<CartItem>.from(loaded.cart);

    if (existingIndex >= 0) {
      final existingItem = updatedCart[existingIndex];
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

    emit(POSLoaded(
      products: loaded.products,
      customers: loaded.customers,
      cart: updatedCart,
      selectedCustomer: loaded.selectedCustomer,
      invoiceDiscount: loaded.invoiceDiscount,
      paymentType: loaded.paymentType,
    ));
  }

  void updateCartItemQuantity(int index, double quantity) {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;

    final updatedCart = List<CartItem>.from(loaded.cart);
    if (index >= 0 && index < updatedCart.length) {
      final item = updatedCart[index];
      updatedCart[index] = CartItem(
        productDetails: item.productDetails,
        selectedPrice: item.selectedPrice,
        quantity: quantity,
        discount: item.discount,
      );
      emit(POSLoaded(
        products: loaded.products,
        customers: loaded.customers,
        cart: updatedCart,
        selectedCustomer: loaded.selectedCustomer,
        invoiceDiscount: loaded.invoiceDiscount,
        paymentType: loaded.paymentType,
      ));
    }
  }

  void updateCartItemDiscount(int index, double discount) {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;

    final updatedCart = List<CartItem>.from(loaded.cart);
    if (index >= 0 && index < updatedCart.length) {
      final item = updatedCart[index];
      updatedCart[index] = CartItem(
        productDetails: item.productDetails,
        selectedPrice: item.selectedPrice,
        quantity: item.quantity,
        discount: discount,
      );
      emit(POSLoaded(
        products: loaded.products,
        customers: loaded.customers,
        cart: updatedCart,
        selectedCustomer: loaded.selectedCustomer,
        invoiceDiscount: loaded.invoiceDiscount,
        paymentType: loaded.paymentType,
      ));
    }
  }

  void removeFromCart(int index) {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;

    final updatedCart = List<CartItem>.from(loaded.cart);
    if (index >= 0 && index < updatedCart.length) {
      updatedCart.removeAt(index);
      emit(POSLoaded(
        products: loaded.products,
        customers: loaded.customers,
        cart: updatedCart,
        selectedCustomer: loaded.selectedCustomer,
        invoiceDiscount: loaded.invoiceDiscount,
        paymentType: loaded.paymentType,
      ));
    }
  }

  void clearCart() {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;
    emit(POSLoaded(
      products: loaded.products,
      customers: loaded.customers,
      cart: [],
      selectedCustomer: null,
      invoiceDiscount: 0.0,
      paymentType: 'cash',
    ));
  }

  void selectCustomer(Customer? customer) {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;
    emit(POSLoaded(
      products: loaded.products,
      customers: loaded.customers,
      cart: loaded.cart,
      selectedCustomer: customer,
      invoiceDiscount: loaded.invoiceDiscount,
      paymentType: loaded.paymentType,
    ));
  }

  void setInvoiceDiscount(double discount) {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;
    emit(POSLoaded(
      products: loaded.products,
      customers: loaded.customers,
      cart: loaded.cart,
      selectedCustomer: loaded.selectedCustomer,
      invoiceDiscount: discount,
      paymentType: loaded.paymentType,
    ));
  }

  void setPaymentType(String type) {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;
    emit(POSLoaded(
      products: loaded.products,
      customers: loaded.customers,
      cart: loaded.cart,
      selectedCustomer: loaded.selectedCustomer,
      invoiceDiscount: loaded.invoiceDiscount,
      paymentType: type,
    ));
  }

  Future<void> checkout() async {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;

    if (loaded.cart.isEmpty) return;
    if (loaded.paymentType == 'debt' && loaded.selectedCustomer == null) {
      emit(POSError('يجب اختيار عميل للبيع بالآجل'));
      return;
    }

    emit(POSLoading());

    try {
      final items = loaded.cart.map((item) => {
            'productId': item.productDetails.product.id,
            'priceUsed': item.selectedPrice.priceValue,
            'quantity': item.quantity,
            'discount': item.discount,
          }).toList();

      await _posRepository.createSale(
        customerId: loaded.selectedCustomer?.id,
        totalAmount: loaded.totalAmount,
        discount: loaded.invoiceDiscount,
        paymentType: loaded.paymentType,
        items: items,
      );

      emit(POSCheckoutSuccess());
      await loadPOSData();
    } catch (e) {
      emit(POSError(e.toString()));
    }
  }
}