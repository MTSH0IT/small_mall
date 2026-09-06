import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_state.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';

class InvoicesCubit extends Cubit<InvoicesState> {
  InvoicesCubit(this._posRepository) : super(InvoicesInitial());
  final POSRepository _posRepository;

  Future<void> loadInvoices() async {
    emit(InvoicesLoading());
    try {
      final invoices = await _posRepository.getAllInvoices();
      emit(InvoicesLoaded(invoices: invoices));
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
}
