import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_state.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';

class InvoicesCubit extends Cubit<InvoicesState> {
  InvoicesCubit(this._posRepository) : super(InvoicesInitial());
  final POSRepository _posRepository;

  Future<void> loadInvoices({String? preserveSelectedId}) async {
    final currentState = state;
    if (currentState is! InvoicesLoaded) {
      emit(InvoicesLoading());
    }
    try {
      final invoices = await _posRepository.getAllInvoices();
      if (currentState is InvoicesLoaded) {
        emit(currentState.copyWith(
          invoices: invoices,
          selectedInvoiceId: preserveSelectedId ?? currentState.selectedInvoiceId,
        ));
      } else {
        emit(InvoicesLoaded(
          invoices: invoices,
          selectedInvoiceId: preserveSelectedId,
        ));
      }
    } catch (e) {
      emit(InvoicesError(e.toString()));
    }
  }

  void selectInvoice(String? invoiceId) {
    if (state is! InvoicesLoaded) return;
    final loaded = state as InvoicesLoaded;
    emit(loaded.copyWith(selectedInvoiceId: invoiceId));
  }

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

  Future<bool> deleteInvoice(String invoiceId) async {
    try {
      await _posRepository.deleteInvoice(invoiceId);
      if (state is InvoicesLoaded) {
        final loaded = state as InvoicesLoaded;
        final remaining = loaded.invoices.where((i) => i.invoice.id != invoiceId).toList();
        final newSelectedId = loaded.selectedInvoiceId == invoiceId ? null : loaded.selectedInvoiceId;
        emit(loaded.copyWith(
          invoices: remaining,
          selectedInvoiceId: newSelectedId,
          clearSelectedInvoice: newSelectedId == null,
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
      await _posRepository.updateInvoice(
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

  Future<Map<String, dynamic>> checkCanDelete(String invoiceId) async {
    return _posRepository.canDeleteInvoice(invoiceId);
  }
}
