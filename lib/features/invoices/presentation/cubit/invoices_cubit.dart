import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
}
