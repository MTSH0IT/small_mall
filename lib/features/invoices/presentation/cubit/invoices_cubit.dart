import 'package:artisan_gift_manager/features/invoices/presentation/cubit/invoices_state.dart';
import 'package:artisan_gift_manager/features/pos/data/pos_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    emit(InvoicesLoaded(
      invoices: loaded.invoices,
      selectedInvoiceId: invoiceId,
      typeFilter: loaded.typeFilter,
    ));
  }

  void setTypeFilter(String filter) {
    if (state is! InvoicesLoaded) return;
    final loaded = state as InvoicesLoaded;
    emit(InvoicesLoaded(
      invoices: loaded.invoices,
      selectedInvoiceId: loaded.selectedInvoiceId,
      typeFilter: filter,
    ));
  }
}
