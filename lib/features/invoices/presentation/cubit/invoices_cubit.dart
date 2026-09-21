import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_state.dart';

class InvoicesCubit extends Cubit<InvoicesState> {
  InvoicesCubit(this._invoicesRepository) : super(InvoicesInitial());
  final InvoicesRepository _invoicesRepository;

  Future<void> loadInvoices({String? preserveSelectedId}) async {
    final currentState = state;
    if (currentState is! InvoicesLoaded) {
      emit(InvoicesLoading());
    }
    try {
      final transactions = await _invoicesRepository.getAllTransactions();
      if (currentState is InvoicesLoaded) {
        emit(currentState.copyWith(
          transactions: transactions,
          selectedTransactionId: preserveSelectedId ?? currentState.selectedTransactionId,
        ));
      } else {
        emit(InvoicesLoaded(
          transactions: transactions,
          selectedTransactionId: preserveSelectedId,
        ));
      }
    } catch (e) {
      emit(InvoicesError(e.toString()));
    }
  }

  void selectTransaction(String? transactionId) {
    if (state is! InvoicesLoaded) return;
    final loaded = state as InvoicesLoaded;
    emit(loaded.copyWith(selectedTransactionId: transactionId));
  }

  // Alias for backward compatibility
  void selectInvoice(String? invoiceId) => selectTransaction(invoiceId);

  void setTypeFilter(String filter) {
    if (state is! InvoicesLoaded) return;
    final loaded = state as InvoicesLoaded;
    emit(loaded.copyWith(typeFilter: filter));
  }

  void setDateFilter(String filter, {DateTimeRange? range}) {
    if (state is! InvoicesLoaded) return;
    final loaded = state as InvoicesLoaded;
    emit(loaded.copyWith(
      dateFilter: filter,
      customDateRange: range,
      clearCustomDateRange: range == null && filter != 'custom',
    ));
  }

  void setSearchQuery(String query) {
    if (state is! InvoicesLoaded) return;
    final loaded = state as InvoicesLoaded;
    emit(loaded.copyWith(searchQuery: query));
  }

  Future<Map<String, dynamic>> checkCanDelete(String invoiceId) =>
      _invoicesRepository.canDeleteInvoice(invoiceId);

  Future<Map<String, dynamic>> checkCanDeleteTransaction(UnifiedTransactionRecord transaction) =>
      _invoicesRepository.canDeleteTransaction(transaction);

  Future<bool> deleteInvoice(String invoiceId) async {
    try {
      await _invoicesRepository.deleteInvoice(invoiceId);
      if (state is InvoicesLoaded) {
        final loaded = state as InvoicesLoaded;
        final remaining = loaded.transactions.where((t) => t.id != invoiceId).toList();
        final newSelectedId = loaded.selectedTransactionId == invoiceId ? null : loaded.selectedTransactionId;
        emit(loaded.copyWith(
          transactions: remaining,
          selectedTransactionId: newSelectedId,
          clearSelectedTransaction: newSelectedId == null,
        ));
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteTransaction(UnifiedTransactionRecord transaction) async {
    try {
      await _invoicesRepository.deleteTransaction(transaction);
      if (state is InvoicesLoaded) {
        final loaded = state as InvoicesLoaded;
        final remaining = loaded.transactions.where((t) => t.id != transaction.id).toList();
        final newSelectedId = loaded.selectedTransactionId == transaction.id ? null : loaded.selectedTransactionId;
        emit(loaded.copyWith(
          transactions: remaining,
          selectedTransactionId: newSelectedId,
          clearSelectedTransaction: newSelectedId == null,
        ));
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateInvoice({
    required String invoiceId,
    required String? customerId,
    required String paymentType,
    required double discount,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await _invoicesRepository.updateInvoice(
        invoiceId: invoiceId,
        customerId: customerId,
        paymentType: paymentType,
        discount: discount,
        items: items,
      );
      await loadInvoices(preserveSelectedId: invoiceId);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PurchaseItem>> getPurchaseItems(String purchaseInvoiceId) =>
      _invoicesRepository.getPurchaseItems(purchaseInvoiceId);

  Future<List<Supplier>> getSuppliers() => _invoicesRepository.getSuppliers();

  Future<List<ExpenseCategory>> getExpenseCategories() => _invoicesRepository.getExpenseCategories();

  Future<void> updatePurchaseInvoice({
    required String purchaseInvoiceId,
    required String supplierId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await _invoicesRepository.updatePurchaseInvoice(
        purchaseInvoiceId: purchaseInvoiceId,
        supplierId: supplierId,
        items: items,
      );
      await loadInvoices(preserveSelectedId: purchaseInvoiceId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateExpense({
    required String expenseId,
    required String categoryId,
    required double amount,
    required String currency,
    String? notes,
    required DateTime createdAt,
  }) async {
    try {
      await _invoicesRepository.updateExpense(
        expenseId: expenseId,
        categoryId: categoryId,
        amount: amount,
        currency: currency,
        notes: notes,
        createdAt: createdAt,
      );
      await loadInvoices(preserveSelectedId: expenseId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateDebtPayment({
    required String paymentId,
    required double newAmount,
    required DateTime paidAt,
  }) async {
    try {
      await _invoicesRepository.updateDebtPayment(
        paymentId: paymentId,
        newAmount: newAmount,
        paidAt: paidAt,
      );
      await loadInvoices(preserveSelectedId: paymentId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateAdjustment({
    required String movementId,
    required double quantity,
    String? reason,
  }) async {
    try {
      await _invoicesRepository.updateAdjustment(
        movementId: movementId,
        quantity: quantity,
        reason: reason,
      );
      await loadInvoices(preserveSelectedId: movementId);
    } catch (e) {
      rethrow;
    }
  }
}
