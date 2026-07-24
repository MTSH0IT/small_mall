import 'package:drift/drift.dart';
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
    final debts = await _db.select(_db.debts).get();

    return customers.map((cust) {
      final customerDebts = debts.where((d) => d.customerId == cust.id).toList();
      final totalDebt = customerDebts.fold<double>(0.0, (sum, d) => sum + d.remainingAmount);
      final openDebtsCount = customerDebts.where((d) => d.status != 'paid').length;

      return CustomerWithDebts(
        customer: cust,
        totalDebt: totalDebt,
        openDebtsCount: openDebtsCount,
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

    await _sync.enqueue('customers', id, 'insert', {
      'id': id,
      'name': name,
      'phone': phone,
      'notes': notes,
      'created_at': now.toIso8601String(),
    });

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
    );

    await (_db.update(_db.customers)..where((t) => t.id.equals(id))).write(companion);

    await _sync.enqueue('customers', id, 'update', {
      'id': id,
      'name': name,
      'phone': phone,
      'notes': notes,
    });
  }

  // --- Debts & Payments ---

  Future<List<DebtWithPayments>> getCustomerDebts(String customerId) async {
    _logger.debug('Fetching debts for customer: $customerId', context: LogContext.debts);
    final debts = await (_db.select(_db.debts)..where((t) => t.customerId.equals(customerId))).get();
    final payments = await _db.select(_db.debtPayments).get();
    final invoices = await _db.select(_db.invoices).get();

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
    _logger.info('Recording payment: debt=$debtId, amount=$amountPaid', context: LogContext.debts);
    final now = DateTime.now();
    final paymentId = _uuid.v4();

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
    ));

    await _sync.enqueue('debts', debtId, 'update', {
      'id': debtId,
      'remaining_amount': newRemaining,
      'status': newStatus,
    });

    // Insert debt payment record
    final payment = DebtPayment(
      id: paymentId,
      debtId: debtId,
      amountPaid: amountPaid,
      paidAt: now,
    );

    await _db.into(_db.debtPayments).insert(payment);

    await _sync.enqueue('debt_payments', paymentId, 'insert', {
      'id': paymentId,
      'debt_id': debtId,
      'amount_paid': amountPaid,
      'paid_at': now.toIso8601String(),
    });
  }
}
