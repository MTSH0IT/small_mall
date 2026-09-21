import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:uuid/uuid.dart';

class CustomerWithDebts {

  CustomerWithDebts({
    required this.customer,
    required this.totalDebt,
    required this.openDebtsCount,
  });
  final Customer customer;
  final double totalDebt;
  final int openDebtsCount;
}

class DebtWithPayments {

  DebtWithPayments({
    required this.debt,
    required this.payments,
    this.invoice,
  });
  final Debt debt;
  final List<DebtPayment> payments;
  final Invoice? invoice;
}

class CustomersDebtsRepository {

  CustomersDebtsRepository(this._db, this._sync, this._logger);
  final AppDatabase _db;
  final SyncService _sync;
  final AppLogger _logger;
  final _uuid = const Uuid();

  // --- Customers ---

  Future<List<CustomerWithDebts>> getCustomers() async {
    _logger.debug('Fetching customers', context: LogContext.debts);
    final customers = await _db.select(_db.customers).get();
    final debtTotals = await _db.getCustomerDebtTotals();
    final openCounts = await _db.getCustomerOpenDebtsCount();

    return customers.map((cust) {
      return CustomerWithDebts(
        customer: cust,
        totalDebt: debtTotals[cust.id] ?? 0.0,
        openDebtsCount: openCounts[cust.id] ?? 0,
      );
    }).toList();
  }

  Future<Customer> addCustomer({
    required String name,
    required String? phone,
    required String? notes,
  }) async {
    _logger.info('Adding customer: $name, phone=$phone', context: LogContext.debts);
    final id = _uuid.v4();
    final now = DateTime.now();

    final customer = Customer(
      id: id,
      name: name,
      phone: phone,
      notes: notes,
      createdAt: now,
    );

    await _db.into(_db.customers).insert(customer);

    _sync.updatePendingCount();
    _sync.sync();

    return customer;
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    required String? phone,
    required String? notes,
  }) async {
    _logger.info('Updating customer: $id, name=$name', context: LogContext.debts);
    final companion = CustomersCompanion(
      name: Value(name),
      phone: Value(phone),
      notes: Value(notes),
      syncedAt: const Value(null),
    );

    await (_db.update(_db.customers)..where((t) => t.id.equals(id))).write(companion);

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<Map<String, dynamic>> checkCanDeleteCustomer(String id) async {
    final debtTotals = await _db.getCustomerDebtTotals();
    final remainingDebt = debtTotals[id] ?? 0.0;
    final openCounts = await _db.getCustomerOpenDebtsCount();
    final openCount = openCounts[id] ?? 0;

    if (remainingDebt > 0.0 || openCount > 0) {
      return {
        'canDelete': false,
        'reason': 'customers.cannot_delete_customer_has_debt'.tr(namedArgs: {
          'amount': remainingDebt.toStringAsFixed(2),
        }),
        'remainingDebt': remainingDebt,
      };
    }

    final invoices = await (_db.select(_db.invoices)..where((t) => t.customerId.equals(id))).get();

    // Count historical payment receipts for this customer to display in confirmation dialog
    final customerDebts = await (_db.select(_db.debts)..where((t) => t.customerId.equals(id))).get();
    int paymentsCount = 0;
    if (customerDebts.isNotEmpty) {
      final debtIds = customerDebts.map((d) => d.id).toSet();
      final payments = await (_db.select(_db.debtPayments)..where((t) => t.debtId.isIn(debtIds))).get();
      paymentsCount = payments.length;
    }

    return {
      'canDelete': true,
      'invoicesCount': invoices.length,
      'paymentsCount': paymentsCount,
    };
  }

  Future<void> deleteCustomer(String id) async {
    _logger.info('Deleting customer: $id', context: LogContext.debts);

    // 1. Verify if customer has active debt
    final debtTotals = await _db.getCustomerDebtTotals();
    final remainingDebt = debtTotals[id] ?? 0.0;
    final openCounts = await _db.getCustomerOpenDebtsCount();
    final openCount = openCounts[id] ?? 0;

    if (remainingDebt > 0.0 || openCount > 0) {
      throw Exception('customers.cannot_delete_customer_has_debt'.tr(namedArgs: {
        'amount': remainingDebt.toStringAsFixed(2),
      }));
    }

    final now = DateTime.now();

    await _db.transaction(() async {
      // 2. Unlink customerId from any past invoices so invoices remain as walk-in sales
      final linkedInvoices = await (_db.select(_db.invoices)..where((t) => t.customerId.equals(id))).get();
      for (final inv in linkedInvoices) {
        await (_db.update(_db.invoices)..where((t) => t.id.equals(inv.id))).write(
          const InvoicesCompanion(customerId: Value(null), syncedAt: Value(null)),
        );
      }

      // NOTE: We deliberately DO NOT delete debts or debtPayments!
      // Historical debt payments are cash inflows (سندات قبض) and must be preserved
      // in the ledger and financial reports to avoid accounting discrepancies.

      // 3. Record customer deletion for sync
      await _db.into(_db.deletedRecords).insert(
        DeletedRecordsCompanion.insert(
          id: _uuid.v4(),
          targetTable: 'customers',
          recordId: id,
          createdAt: now,
        ),
      );

      // 4. Delete customer record
      await (_db.delete(_db.customers)..where((t) => t.id.equals(id))).go();
    });

    _sync.updatePendingCount();
    _sync.sync();
  }

  // --- Debts & Payments ---

  Future<List<DebtWithPayments>> getCustomerDebts(String customerId) async {
    _logger.debug('Fetching debts for customer: $customerId', context: LogContext.debts);
    final debts = await (_db.select(_db.debts)
      ..where((t) => t.customerId.equals(customerId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

    if (debts.isEmpty) return [];

    final debtIds = debts.map((d) => d.id).toSet();
    final payments = await (_db.select(_db.debtPayments)
      ..where((t) => t.debtId.isIn(debtIds))).get();

    final invoiceIds = debts.map((d) => d.invoiceId).whereType<String>().toSet();
    final invoices = invoiceIds.isEmpty
        ? <Invoice>[]
        : await (_db.select(_db.invoices)..where((t) => t.id.isIn(invoiceIds))).get();

    final invoiceMap = {for (var inv in invoices) inv.id: inv};

    return debts.map((debt) {
      final debtPayments = payments.where((p) => p.debtId == debt.id).toList();
      final invoice = debt.invoiceId != null ? invoiceMap[debt.invoiceId] : null;

      return DebtWithPayments(
        debt: debt,
        payments: debtPayments,
        invoice: invoice,
      );
    }).toList();
  }

  Future<void> recordPayment({
    required String debtId,
    required double amountPaid,
  }) async {
    if (amountPaid <= 0) return;
    _logger.info('Recording payment: debt=$debtId, amount=$amountPaid', context: LogContext.debts);
    final now = DateTime.now();
    final paymentId = _uuid.v4();

    await _db.transaction(() async {
      final debtList = await (_db.select(_db.debts)..where((t) => t.id.equals(debtId))).get();
      if (debtList.isEmpty) {
        _logger.warning('Payment cancelled - debt not found: $debtId', context: LogContext.debts);
        return;
      }
      final debt = debtList.first;

      final newRemaining = (debt.remainingAmount - amountPaid).clamp(0.0, double.infinity);
      final newStatus = newRemaining <= 0 ? 'paid' : 'partial';

      // Update debt
      await (_db.update(_db.debts)..where((t) => t.id.equals(debtId))).write(DebtsCompanion(
        remainingAmount: Value(newRemaining),
        status: Value(newStatus),
        syncedAt: const Value(null),
      ));

      // Insert debt payment record
      final payment = DebtPayment(
        id: paymentId,
        debtId: debtId,
        amountPaid: amountPaid,
        paidAt: now,
        currency: debt.currency,
      );

      await _db.into(_db.debtPayments).insert(payment);
    });

    _sync.updatePendingCount();
    _sync.sync();
  }
}
