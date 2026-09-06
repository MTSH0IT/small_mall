import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_state.dart';

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
        updatedCart[existingIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + 1,
        );
      }
    } else {
      if (product.currentStock < 1.0) return; // Prevent adding out-of-stock item
      updatedCart.add(CartItem(
        productDetails: product,
        selectedPrice: price,
        quantity: 1.0,
      ));
    }

    emit(loaded.copyWith(cart: updatedCart));
  }

  void updateCartItemQuantity(int index, double quantity) {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;

    final updatedCart = List<CartItem>.from(loaded.cart);
    if (index >= 0 && index < updatedCart.length) {
      final item = updatedCart[index];
      if (quantity <= 0) {
        removeFromCart(index);
        return;
      }
      final validQty = quantity.clamp(1.0, item.productDetails.currentStock);
      updatedCart[index] = item.copyWith(quantity: validQty);
      emit(loaded.copyWith(cart: updatedCart));
    }
  }

  void updateCartItemDiscount(int index, double discount) {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;

    final updatedCart = List<CartItem>.from(loaded.cart);
    if (index >= 0 && index < updatedCart.length) {
      final item = updatedCart[index];
      final maxDiscount = item.selectedPrice.priceValue * item.quantity;
      final validDiscount = discount.clamp(0.0, maxDiscount);
      updatedCart[index] = item.copyWith(discount: validDiscount);
      emit(loaded.copyWith(cart: updatedCart));
    }
  }

  void removeFromCart(int index) {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;

    final updatedCart = List<CartItem>.from(loaded.cart);
    if (index >= 0 && index < updatedCart.length) {
      updatedCart.removeAt(index);
      emit(loaded.copyWith(cart: updatedCart));
    }
  }

  void clearCart() {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;
    emit(loaded.copyWith(
      cart: [],
      clearCustomer: true,
      invoiceDiscount: 0.0,
      paymentType: 'cash',
    ));
  }

  void selectCustomer(Customer? customer) {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;
    emit(loaded.copyWith(
      selectedCustomer: customer,
      clearCustomer: customer == null,
    ));
  }

  void setInvoiceDiscount(double discount) {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;
    emit(loaded.copyWith(
      invoiceDiscount: discount.clamp(0.0, double.infinity),
    ));
  }

  void setPaymentType(String type) {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;
    emit(loaded.copyWith(paymentType: type));
  }

  Future<void> createReturn({
    required String originalInvoiceId,
    required List<Map<String, dynamic>> itemsToReturn,
  }) async {
    emit(POSLoading());
    try {
      await _posRepository.createReturn(
        originalInvoiceId: originalInvoiceId,
        itemsToReturn: itemsToReturn,
      );

      emit(POSCheckoutSuccess());
      await loadPOSData();
    } catch (e) {
      emit(POSError(e.toString()));
    }
  }

  Future<List<Invoice>> getRecentSales() {
    return _posRepository.getRecentSales();
  }

  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId) {
    return _posRepository.getInvoiceItems(invoiceId);
  }

  Future<void> checkout() async {
    if (state is! POSLoaded) return;
    final loaded = state as POSLoaded;

    if (loaded.cart.isEmpty) return;
    if (loaded.paymentType == 'debt' && loaded.selectedCustomer == null) {
      emit(POSError('pos.debt_warning_no_customer'.tr()));
      return;
    }

    emit(loaded.copyWith(isCheckingOut: true));

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
      emit(loaded.copyWith(isCheckingOut: false));
      emit(POSError(e.toString()));
    }
  }
}