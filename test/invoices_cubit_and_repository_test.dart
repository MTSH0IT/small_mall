import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_state.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';

void main() {
  group('InvoicesState Filtering & Serial Search Tests', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12, 0);
    final yesterday = today.subtract(const Duration(days: 1));
    final tenDaysAgo = today.subtract(const Duration(days: 10));

    final testInvoices = [
      InvoiceWithDetails(
        invoice: Invoice(
          id: 'inv-uuid-001',
          serialNumber: 1,
          type: 'sale',
          customerId: 'cust-1',
          totalAmount: 250.0,
          discount: 10.0,
          paymentType: 'cash',
          createdAt: today,
        ),
        items: [],
        customerName: 'أحمد محمد',
      ),
      InvoiceWithDetails(
        invoice: Invoice(
          id: 'inv-uuid-002',
          serialNumber: 2,
          type: 'sale',
          customerId: 'cust-2',
          totalAmount: 500.0,
          discount: 0.0,
          paymentType: 'debt',
          createdAt: yesterday,
        ),
        items: [],
        customerName: 'سارة خالد',
      ),
      InvoiceWithDetails(
        invoice: Invoice(
          id: 'inv-uuid-003',
          serialNumber: 3,
          type: 'return',
          customerId: 'cust-1',
          totalAmount: 100.0,
          discount: 0.0,
          paymentType: 'cash',
          createdAt: today,
        ),
        items: [],
        customerName: 'أحمد محمد',
      ),
      InvoiceWithDetails(
        invoice: Invoice(
          id: 'inv-uuid-004',
          serialNumber: 4,
          type: 'sale',
          customerId: null,
          totalAmount: 75.0,
          discount: 0.0,
          paymentType: 'cash',
          createdAt: tenDaysAgo,
        ),
        items: [],
        customerName: null,
      ),
    ];

    test('initial state returns all invoices with correct totals', () {
      final state = InvoicesLoaded(invoices: testInvoices);

      expect(state.filteredInvoices.length, 4);
      expect(state.salesCount, 3);
      expect(state.returnsCount, 1);
      expect(state.totalSalesAmount, 825.0);
      expect(state.totalReturnsAmount, 100.0);
    });

    test('filters by type sale and return properly', () {
      final saleState = InvoicesLoaded(invoices: testInvoices, typeFilter: 'sale');
      expect(saleState.filteredInvoices.length, 3);
      expect(saleState.filteredInvoices.every((i) => i.invoice.type == 'sale'), isTrue);

      final returnState = InvoicesLoaded(invoices: testInvoices, typeFilter: 'return');
      expect(returnState.filteredInvoices.length, 1);
      expect(returnState.filteredInvoices.first.invoice.serialNumber, 3);
      expect(returnState.totalReturnsAmount, 100.0);
    });

    test('filters by date: today and yesterday', () {
      final todayState = InvoicesLoaded(invoices: testInvoices, dateFilter: 'today');
      expect(todayState.filteredInvoices.length, 2);
      expect(todayState.filteredInvoices.map((i) => i.invoice.serialNumber).toList(), [1, 3]);
      expect(todayState.salesCount, 1);
      expect(todayState.returnsCount, 1);
      expect(todayState.totalSalesAmount, 250.0);

      final yesterdayState = InvoicesLoaded(invoices: testInvoices, dateFilter: 'yesterday');
      expect(yesterdayState.filteredInvoices.length, 1);
      expect(yesterdayState.filteredInvoices.first.invoice.serialNumber, 2);
      expect(yesterdayState.totalSalesAmount, 500.0);
    });

    test('filters by custom date range', () {
      final range = DateTimeRange(
        start: tenDaysAgo.subtract(const Duration(days: 1)),
        end: tenDaysAgo.add(const Duration(days: 1)),
      );
      final customState = InvoicesLoaded(
        invoices: testInvoices,
        dateFilter: 'custom',
        customDateRange: range,
      );

      expect(customState.filteredInvoices.length, 1);
      expect(customState.filteredInvoices.first.invoice.serialNumber, 4);
    });

    test('search by serial number exact and with # prefix', () {
      final search1 = InvoicesLoaded(invoices: testInvoices, searchQuery: '1');
      expect(search1.filteredInvoices.length, 1);
      expect(search1.filteredInvoices.first.invoice.serialNumber, 1);

      final searchHash2 = InvoicesLoaded(invoices: testInvoices, searchQuery: '#2');
      expect(searchHash2.filteredInvoices.length, 1);
      expect(searchHash2.filteredInvoices.first.invoice.serialNumber, 2);
      expect(searchHash2.filteredInvoices.first.customerName, 'سارة خالد');
    });

    test('search by customer name', () {
      final searchCustomer = InvoicesLoaded(invoices: testInvoices, searchQuery: 'سارة');
      expect(searchCustomer.filteredInvoices.length, 1);
      expect(searchCustomer.filteredInvoices.first.customerName, 'سارة خالد');

      final searchAhmed = InvoicesLoaded(invoices: testInvoices, searchQuery: 'أحمد');
      expect(searchAhmed.filteredInvoices.length, 2);
    });

    test('search by total amount', () {
      final searchAmount = InvoicesLoaded(invoices: testInvoices, searchQuery: '500');
      expect(searchAmount.filteredInvoices.length, 1);
      expect(searchAmount.filteredInvoices.first.invoice.totalAmount, 500.0);
    });

    test('combines search and filters simultaneously', () {
      final combined = InvoicesLoaded(
        invoices: testInvoices,
        typeFilter: 'sale',
        dateFilter: 'today',
        searchQuery: 'أحمد',
      );

      expect(combined.filteredInvoices.length, 1);
      expect(combined.filteredInvoices.first.invoice.serialNumber, 1);
    });
  });
}
