import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';
import 'package:small_mall/features/customers_debts/presentation/cubit/customers_debts_cubit.dart';
import 'package:small_mall/features/customers_debts/presentation/cubit/customers_debts_state.dart';
import 'package:small_mall/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/cubit/suppliers_purchasing_cubit.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/cubit/suppliers_purchasing_state.dart';

void main() {
  late AppDatabase db;
  late AppLogger logger;
  late SyncService sync;
  late CustomersDebtsRepository customersRepo;
  late SuppliersPurchasingRepository suppliersRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = AppLogger();
    sync = SyncService(db, logger);
    customersRepo = CustomersDebtsRepository(db, sync, logger);
    suppliersRepo = SuppliersPurchasingRepository(db, sync, logger);
  });

  tearDown(() async {
    await db.close();
  });

  group('Customers Deletion & Safety Rules Tests', () {
    test('cannot delete customer when active debt exists', () async {
      // 1. Add customer
      final customer = await customersRepo.addCustomer(
        name: 'عميل آجل',
        phone: '0501112233',
        notes: 'ملاحظة',
      );

      // 2. Insert active debt
      await db.into(db.debts).insert(
        Debt(
          id: 'debt-001',
          customerId: customer.id,
          amount: 500.0,
          remainingAmount: 500.0,
          status: 'open',
          createdAt: DateTime.now(),
          currency: 'SYP',
        ),
      );

      // 3. checkCanDeleteCustomer returns false
      final check = await customersRepo.checkCanDeleteCustomer(customer.id);
      expect(check['canDelete'], isFalse);
      expect(check['remainingDebt'], 500.0);

      // 4. deleteCustomer throws exception
      expect(() => customersRepo.deleteCustomer(customer.id), throwsException);

      // 5. Customer is still in database
      final customers = await customersRepo.getCustomers();
      expect(customers.any((c) => c.customer.id == customer.id), isTrue);
    });

    test('deletes customer cleanly when debt is settled (remaining 0)', () async {
      // 1. Add customer
      final customer = await customersRepo.addCustomer(
        name: 'عميل مسدد',
        phone: '0509998877',
        notes: null,
      );

      // 2. Insert invoice linked to customer
      await db.into(db.invoices).insert(
        Invoice(
          id: 'inv-001',
          serialNumber: 1,
          type: 'sale',
          customerId: customer.id,
          totalAmount: 150.0,
          discount: 0.0,
          paymentType: 'cash',
          createdAt: DateTime.now(),
          currency: 'SYP',
        ),
      );

      // 3. Insert fully paid debt and payment record
      await db.into(db.debts).insert(
        Debt(
          id: 'debt-002',
          customerId: customer.id,
          amount: 100.0,
          remainingAmount: 0.0,
          status: 'paid',
          createdAt: DateTime.now(),
          currency: 'SYP',
        ),
      );
      await db.into(db.debtPayments).insert(
        DebtPayment(
          id: 'dp-001',
          debtId: 'debt-002',
          amountPaid: 100.0,
          paidAt: DateTime.now(),
          currency: 'SYP',
        ),
      );

      // 4. checkCanDeleteCustomer returns true and indicates 1 linked invoice and 1 payment
      final check = await customersRepo.checkCanDeleteCustomer(customer.id);
      expect(check['canDelete'], isTrue);
      expect(check['invoicesCount'], 1);
      expect(check['paymentsCount'], 1);

      // 5. Delete customer
      await customersRepo.deleteCustomer(customer.id);

      // 6. Verify customer removed from database
      final customers = await customersRepo.getCustomers();
      expect(customers.any((c) => c.customer.id == customer.id), isFalse);

      // 7. CRITICAL ACCOUNTING CHECK: Verify debt payment was PRESERVED in database
      final payment = await (db.select(db.debtPayments)..where((t) => t.id.equals('dp-001'))).getSingleOrNull();
      expect(payment, isNotNull);
      expect(payment!.amountPaid, 100.0);

      // 8. Verify debt record was also PRESERVED
      final debt = await (db.select(db.debts)..where((t) => t.id.equals('debt-002'))).getSingleOrNull();
      expect(debt, isNotNull);

      // 9. Verify invoice customerId was safely unlinked to null
      final invoice = await (db.select(db.invoices)..where((t) => t.id.equals('inv-001'))).getSingle();
      expect(invoice.customerId, isNull);

      // 10. Verify customer deletion recorded in deleted_records, but payments NOT in deleted_records
      final deletedCust = await (db.select(db.deletedRecords)..where((t) => t.recordId.equals(customer.id))).get();
      expect(deletedCust.isNotEmpty, isTrue);
      expect(deletedCust.first.targetTable, 'customers');

      final deletedPayments = await (db.select(db.deletedRecords)..where((t) => t.recordId.equals('dp-001'))).get();
      expect(deletedPayments.isEmpty, isTrue);
    });

    test('CustomersDebtsCubit handles delete customer correctly', () async {
      final cubit = CustomersDebtsCubit(customersRepo);
      await cubit.loadCustomers();

      final customer = await customersRepo.addCustomer(
        name: 'عميل للتجربة',
        phone: null,
        notes: null,
      );
      await cubit.selectCustomer(customer.id);

      var state = cubit.state as CustomersDebtsLoaded;
      expect(state.selectedCustomerId, customer.id);

      await cubit.deleteCustomer(customer.id);

      state = cubit.state as CustomersDebtsLoaded;
      expect(state.selectedCustomerId, isNull);
      expect(state.customers.any((c) => c.customer.id == customer.id), isFalse);
    });
  });

  group('Suppliers Deletion & Purchases Integrity Tests', () {
    test('checkCanDeleteSupplier and deletes supplier without invoices', () async {
      // 1. Add supplier
      final supplier = await suppliersRepo.addSupplier(
        name: 'مورد جديد',
        phone: '0555555555',
        notes: 'مورد إلكترونيات',
      );

      // 2. checkCanDeleteSupplier returns 0 invoices
      final check = await suppliersRepo.checkCanDeleteSupplier(supplier.id);
      expect(check['canDelete'], isTrue);
      expect(check['invoicesCount'], 0);

      // 3. Delete supplier
      await suppliersRepo.deleteSupplier(supplier.id);

      // 4. Verify supplier deleted
      final suppliers = await suppliersRepo.getSuppliers();
      expect(suppliers.any((s) => s.supplier.id == supplier.id), isFalse);

      // 5. Verify recorded in deleted_records
      final deleted = await (db.select(db.deletedRecords)..where((t) => t.recordId.equals(supplier.id))).get();
      expect(deleted.isNotEmpty, isTrue);
      expect(deleted.first.targetTable, 'suppliers');
    });

    test('deletes supplier while preserving purchase invoices history', () async {
      // 1. Add supplier
      final supplier = await suppliersRepo.addSupplier(
        name: 'مورد الهدايا',
        phone: '0551234567',
        notes: null,
      );

      // 2. Insert purchase invoice for this supplier
      await db.into(db.purchaseInvoices).insert(
        PurchaseInvoice(
          id: 'pi-001',
          supplierId: supplier.id,
          totalAmount: 1200.0,
          createdAt: DateTime.now(),
          currency: 'SYP',
        ),
      );

      // 3. checkCanDeleteSupplier returns invoicesCount = 1
      final check = await suppliersRepo.checkCanDeleteSupplier(supplier.id);
      expect(check['canDelete'], isTrue);
      expect(check['invoicesCount'], 1);

      // 4. Delete supplier
      await suppliersRepo.deleteSupplier(supplier.id);

      // 5. Supplier removed from suppliers list
      final suppliers = await suppliersRepo.getSuppliers();
      expect(suppliers.any((s) => s.supplier.id == supplier.id), isFalse);

      // 6. Purchase invoice is preserved in purchaseInvoices table
      final pi = await (db.select(db.purchaseInvoices)..where((t) => t.id.equals('pi-001'))).getSingleOrNull();
      expect(pi, isNotNull);
      expect(pi!.totalAmount, 1200.0);
    });

    test('SuppliersPurchasingCubit handles delete supplier correctly', () async {
      final cubit = SuppliersPurchasingCubit(suppliersRepo);
      await cubit.loadSuppliers();

      final supplier = await suppliersRepo.addSupplier(
        name: 'مورد سريع',
        phone: null,
        notes: null,
      );
      await cubit.loadSuppliers();

      var state = cubit.state as SuppliersPurchasingLoaded;
      expect(state.suppliers.any((s) => s.supplier.id == supplier.id), isTrue);

      await cubit.deleteSupplier(supplier.id);

      state = cubit.state as SuppliersPurchasingLoaded;
      expect(state.suppliers.any((s) => s.supplier.id == supplier.id), isFalse);
    });
  });
}
