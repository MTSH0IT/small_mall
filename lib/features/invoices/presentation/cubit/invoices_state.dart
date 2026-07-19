import 'package:artisan_gift_manager/features/pos/data/pos_repository.dart';

abstract class InvoicesState {}

class InvoicesInitial extends InvoicesState {}

class InvoicesLoading extends InvoicesState {}

class InvoicesLoaded extends InvoicesState {
  InvoicesLoaded({
    required this.invoices,
    this.selectedInvoiceId,
    this.typeFilter = 'all',
  });
  final List<InvoiceWithDetails> invoices;
  final String? selectedInvoiceId;
  final String typeFilter;

  List<InvoiceWithDetails> get filteredInvoices {
    if (typeFilter == 'all') return invoices;
    return invoices.where((i) => i.invoice.type == typeFilter).toList();
  }

  InvoiceWithDetails? get selectedInvoice {
    if (selectedInvoiceId == null) return null;
    try {
      return invoices.firstWhere((i) => i.invoice.id == selectedInvoiceId);
    } catch (_) {
      return null;
    }
  }

  double get totalSalesAmount => invoices
      .where((i) => i.invoice.type == 'sale')
      .fold<double>(0.0, (sum, i) => sum + i.invoice.totalAmount);

  double get totalReturnsAmount => invoices
      .where((i) => i.invoice.type == 'return')
      .fold<double>(0.0, (sum, i) => sum + i.invoice.totalAmount);

  int get salesCount => invoices.where((i) => i.invoice.type == 'sale').length;
  int get returnsCount => invoices.where((i) => i.invoice.type == 'return').length;
}

class InvoicesError extends InvoicesState {
  InvoicesError(this.message);
  final String message;
}
