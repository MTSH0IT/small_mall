import 'package:flutter/material.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';

abstract class InvoicesState {}

class InvoicesInitial extends InvoicesState {}

class InvoicesLoading extends InvoicesState {}

class InvoicesLoaded extends InvoicesState {
  InvoicesLoaded({
    List<UnifiedTransactionRecord>? transactions,
    List<InvoiceWithDetails>? invoices,
    String? selectedTransactionId,
    String? selectedInvoiceId,
    this.typeFilter = 'all',
    this.dateFilter = 'all',
    this.customDateRange,
    this.searchQuery = '',
  })  : transactions = transactions ?? (invoices != null ? _convertInvoices(invoices) : const []),
        selectedTransactionId = selectedTransactionId ?? selectedInvoiceId;

  final List<UnifiedTransactionRecord> transactions;
  final String? selectedTransactionId;
  final String typeFilter;
  final String dateFilter;
  final DateTimeRange? customDateRange;
  final String searchQuery;

  static List<UnifiedTransactionRecord> _convertInvoices(List<InvoiceWithDetails> invoices) {
    final asc = List<InvoiceWithDetails>.from(invoices)
      ..sort((a, b) => a.invoice.createdAt.compareTo(b.invoice.createdAt));
    final fallbackMap = <String, int>{};
    for (int i = 0; i < asc.length; i++) {
      fallbackMap[asc[i].invoice.id] = i + 1;
    }

    return invoices.map((inv) {
      final isReturn = inv.invoice.type == 'return';
      final isDebt = inv.invoice.paymentType == 'debt';
      final UnifiedTransactionType type;
      if (isReturn) {
        type = UnifiedTransactionType.returnSale;
      } else if (isDebt) {
        type = UnifiedTransactionType.debtInvoice;
      } else {
        type = UnifiedTransactionType.sale;
      }

      final items = inv.items.map((item) {
        return UnifiedTransactionItem(
          productName: item.productName,
          quantity: item.invoiceItem.quantity,
          unitPrice: item.invoiceItem.priceUsed,
          discount: item.invoiceItem.discount,
        );
      }).toList();

      final serial = inv.invoice.serialNumber ?? fallbackMap[inv.invoice.id];

      return UnifiedTransactionRecord(
        id: inv.invoice.id,
        globalSerialNumber: serial,
        serialNumber: serial,
        type: type,
        createdAt: inv.invoice.createdAt,
        totalAmount: inv.invoice.totalAmount,
        partyName: inv.customerName,
        paymentType: inv.invoice.paymentType,
        discount: inv.invoice.discount,
        items: items,
        rawInvoice: inv,
      );
    }).toList();
  }

  // Backwards compatibility getter
  List<InvoiceWithDetails> get filteredInvoices {
    return filteredTransactions
        .where((t) => t.rawInvoice != null)
        .map((t) => t.rawInvoice!)
        .toList();
  }

  InvoiceWithDetails? get selectedInvoice => selectedTransaction?.rawInvoice;

  List<UnifiedTransactionRecord> get filteredTransactions {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final yesterdayEnd = DateTime(yesterdayStart.year, yesterdayStart.month, yesterdayStart.day, 23, 59, 59, 999);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final isExplicitSerial = searchQuery.trim().startsWith('#');
    final cleanQuery = searchQuery.trim().toLowerCase().replaceAll('#', '');

    return transactions.where((t) {
      // 1. Type filter
      if (typeFilter != 'all') {
        if (typeFilter == 'sale') {
          if (t.type != UnifiedTransactionType.sale && t.type != UnifiedTransactionType.debtInvoice) {
            return false;
          }
        } else if (typeFilter == 'debt_invoice' || typeFilter == 'debt') {
          if (t.type != UnifiedTransactionType.debtInvoice && t.paymentType != 'debt') {
            return false;
          }
        } else if (t.typeCode != typeFilter) {
          return false;
        }
      }

      // 2. Date filter
      final createdAt = t.createdAt;
      if (dateFilter == 'today') {
        if (createdAt.isBefore(todayStart) || createdAt.isAfter(todayEnd)) {
          return false;
        }
      } else if (dateFilter == 'yesterday') {
        if (createdAt.isBefore(yesterdayStart) || createdAt.isAfter(yesterdayEnd)) {
          return false;
        }
      } else if (dateFilter == 'this_week') {
        if (createdAt.isBefore(weekStart) || createdAt.isAfter(todayEnd)) {
          return false;
        }
      } else if (dateFilter == 'this_month') {
        if (createdAt.isBefore(monthStart) || createdAt.isAfter(todayEnd)) {
          return false;
        }
      } else if (dateFilter == 'custom' && customDateRange != null) {
        final start = DateTime(customDateRange!.start.year, customDateRange!.start.month, customDateRange!.start.day);
        final end = DateTime(customDateRange!.end.year, customDateRange!.end.month, customDateRange!.end.day, 23, 59, 59, 999);
        if (createdAt.isBefore(start) || createdAt.isAfter(end)) {
          return false;
        }
      }

      // 3. Search query
      if (cleanQuery.isNotEmpty) {
        final serial = t.serialNumber?.toString() ?? '';
        final globalSerial = t.globalSerialNumber?.toString() ?? '';

        if (isExplicitSerial) {
          return serial == cleanQuery || globalSerial == cleanQuery;
        }

        final idStr = t.id.toLowerCase();
        final party = (t.partyName ?? '').toLowerCase();
        final notes = (t.notes ?? '').toLowerCase();
        final totalStr = t.totalAmount.toStringAsFixed(2);
        final totalInt = t.totalAmount.toStringAsFixed(0);

        final isNumeric = int.tryParse(cleanQuery) != null;
        final matchesSerial = isNumeric
            ? (serial == cleanQuery || globalSerial == cleanQuery)
            : (serial.contains(cleanQuery) || globalSerial.contains(cleanQuery));
        final matchesParty = party.contains(cleanQuery);
        final matchesNotes = notes.contains(cleanQuery);
        final matchesId = cleanQuery.length >= 3 && idStr.contains(cleanQuery);
        final matchesTotal = isNumeric
            ? (totalInt == cleanQuery || totalStr == cleanQuery)
            : totalStr.contains(cleanQuery);

        if (!matchesSerial && !matchesParty && !matchesNotes && !matchesId && !matchesTotal) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  UnifiedTransactionRecord? get selectedTransaction {
    if (selectedTransactionId == null) return null;
    return transactions.where((t) => t.id == selectedTransactionId).firstOrNull;
  }

  InvoicesLoaded copyWith({
    List<UnifiedTransactionRecord>? transactions,
    List<InvoiceWithDetails>? invoices,
    String? selectedTransactionId,
    String? selectedInvoiceId,
    bool clearSelectedTransaction = false,
    bool clearSelectedInvoice = false,
    String? typeFilter,
    String? dateFilter,
    DateTimeRange? customDateRange,
    bool clearCustomDateRange = false,
    String? searchQuery,
  }) {
    final resolvedTransactions = transactions ??
        (invoices != null ? _convertInvoices(invoices) : this.transactions);
    final shouldClear = clearSelectedTransaction || clearSelectedInvoice;
    final resolvedSelectedId = shouldClear
        ? null
        : (selectedTransactionId ?? selectedInvoiceId ?? this.selectedTransactionId);

    return InvoicesLoaded(
      transactions: resolvedTransactions,
      selectedTransactionId: resolvedSelectedId,
      typeFilter: typeFilter ?? this.typeFilter,
      dateFilter: dateFilter ?? this.dateFilter,
      customDateRange: clearCustomDateRange ? null : (customDateRange ?? this.customDateRange),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  // Summary Metrics
  double get totalSalesAmount => filteredTransactions
      .where((t) => t.type == UnifiedTransactionType.sale || t.type == UnifiedTransactionType.debtInvoice)
      .fold<double>(0.0, (sum, t) => sum + t.totalAmount);

  double get totalReturnsAmount => filteredTransactions
      .where((t) => t.type == UnifiedTransactionType.returnSale)
      .fold<double>(0.0, (sum, t) => sum + t.totalAmount);

  double get totalPurchasesAmount => filteredTransactions
      .where((t) => t.type == UnifiedTransactionType.purchase)
      .fold<double>(0.0, (sum, t) => sum + t.totalAmount);

  double get totalExpensesAmount => filteredTransactions
      .where((t) => t.type == UnifiedTransactionType.expense)
      .fold<double>(0.0, (sum, t) => sum + t.totalAmount);

  double get totalDebtPaymentsAmount => filteredTransactions
      .where((t) => t.type == UnifiedTransactionType.debtPayment)
      .fold<double>(0.0, (sum, t) => sum + t.totalAmount);

  double get totalDebtInvoicesAmount => filteredTransactions
      .where((t) => t.type == UnifiedTransactionType.debtInvoice)
      .fold<double>(0.0, (sum, t) => sum + t.totalAmount);

  int get salesCount => filteredTransactions
      .where((t) => t.type == UnifiedTransactionType.sale || t.type == UnifiedTransactionType.debtInvoice)
      .length;
  int get returnsCount => filteredTransactions.where((t) => t.type == UnifiedTransactionType.returnSale).length;
  int get purchasesCount => filteredTransactions.where((t) => t.type == UnifiedTransactionType.purchase).length;
  int get expensesCount => filteredTransactions.where((t) => t.type == UnifiedTransactionType.expense).length;
  int get debtPaymentsCount => filteredTransactions.where((t) => t.type == UnifiedTransactionType.debtPayment).length;
  int get debtInvoicesCount => filteredTransactions.where((t) => t.type == UnifiedTransactionType.debtInvoice).length;
  int get adjustmentsCount => filteredTransactions.where((t) => t.type == UnifiedTransactionType.adjustment).length;
}

class InvoicesError extends InvoicesState {
  InvoicesError(this.message);
  final String message;
}
