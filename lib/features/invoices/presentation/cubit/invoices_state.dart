import 'package:flutter/material.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';

abstract class InvoicesState {}

class InvoicesInitial extends InvoicesState {}

class InvoicesLoading extends InvoicesState {}

class InvoicesLoaded extends InvoicesState {
  InvoicesLoaded({
    required this.invoices,
    this.selectedInvoiceId,
    this.typeFilter = 'all',
    this.dateFilter = 'all',
    this.customDateRange,
    this.searchQuery = '',
  });

  final List<InvoiceWithDetails> invoices;
  final String? selectedInvoiceId;
  final String typeFilter;
  final String dateFilter;
  final DateTimeRange? customDateRange;
  final String searchQuery;

  List<InvoiceWithDetails> get filteredInvoices {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final yesterdayEnd = DateTime(yesterdayStart.year, yesterdayStart.month, yesterdayStart.day, 23, 59, 59, 999);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final cleanQuery = searchQuery.trim().toLowerCase().replaceAll('#', '');

    return invoices.where((i) {
      // 1. Type filter
      if (typeFilter != 'all' && i.invoice.type != typeFilter) {
        return false;
      }

      // 2. Date filter
      final createdAt = i.invoice.createdAt;
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
        final serial = i.invoice.serialNumber?.toString() ?? '';
        final idStr = i.invoice.id.toLowerCase();
        final customer = (i.customerName ?? '').toLowerCase();
        final totalStr = i.invoice.totalAmount.toStringAsFixed(2);
        final totalInt = i.invoice.totalAmount.toStringAsFixed(0);

        final isNumeric = int.tryParse(cleanQuery) != null;
        final matchesSerial = isNumeric ? serial == cleanQuery : serial.contains(cleanQuery);
        final matchesCustomer = customer.contains(cleanQuery);
        final matchesId = cleanQuery.length >= 3 && idStr.contains(cleanQuery);
        final matchesTotal = isNumeric
            ? (totalInt == cleanQuery || totalStr == cleanQuery)
            : totalStr.contains(cleanQuery);

        if (!matchesSerial && !matchesCustomer && !matchesId && !matchesTotal) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  InvoiceWithDetails? get selectedInvoice {
    if (selectedInvoiceId == null) return null;
    return invoices.where((i) => i.invoice.id == selectedInvoiceId).firstOrNull;
  }

  InvoicesLoaded copyWith({
    List<InvoiceWithDetails>? invoices,
    String? selectedInvoiceId,
    bool clearSelectedInvoice = false,
    String? typeFilter,
    String? dateFilter,
    DateTimeRange? customDateRange,
    bool clearCustomDateRange = false,
    String? searchQuery,
  }) {
    return InvoicesLoaded(
      invoices: invoices ?? this.invoices,
      selectedInvoiceId: clearSelectedInvoice ? null : (selectedInvoiceId ?? this.selectedInvoiceId),
      typeFilter: typeFilter ?? this.typeFilter,
      dateFilter: dateFilter ?? this.dateFilter,
      customDateRange: clearCustomDateRange ? null : (customDateRange ?? this.customDateRange),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  double get totalSalesAmount => filteredInvoices
      .where((i) => i.invoice.type == 'sale')
      .fold<double>(0.0, (sum, i) => sum + i.invoice.totalAmount);

  double get totalReturnsAmount => filteredInvoices
      .where((i) => i.invoice.type == 'return')
      .fold<double>(0.0, (sum, i) => sum + i.invoice.totalAmount);

  int get salesCount => filteredInvoices.where((i) => i.invoice.type == 'sale').length;
  int get returnsCount => filteredInvoices.where((i) => i.invoice.type == 'return').length;
}

class InvoicesError extends InvoicesState {
  InvoicesError(this.message);
  final String message;
}
