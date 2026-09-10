import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  IntColumn get serialNumber => integer().nullable()();
  TextColumn get code => text().nullable()();
  TextColumn get name => text()();
  TextColumn get categoryId => text().nullable()();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  RealColumn get minStockAlert => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProductPrices extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get priceLabel => text()(); // e.g. wholesale, retail, promo
  RealColumn get priceValue => real()();

  @override
  Set<Column> get primaryKey => {id};
}

class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get type => text()(); // sale, purchase, return, adjustment
  RealColumn get quantity => real()();
  TextColumn get referenceId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Invoices extends Table {
  TextColumn get id => text()();
  IntColumn get serialNumber => integer().nullable()();
  TextColumn get type => text()(); // sale, return
  TextColumn get customerId => text().nullable()();
  RealColumn get totalAmount => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  TextColumn get paymentType => text()(); // cash, debt
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class InvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text()();
  TextColumn get productId => text()();
  RealColumn get priceUsed => real()();
  RealColumn get quantity => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Debts extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get invoiceId => text().nullable()();
  RealColumn get amount => real()();
  RealColumn get remainingAmount => real()();
  TextColumn get status => text()(); // open, paid, partial
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DebtPayments extends Table {
  TextColumn get id => text()();
  TextColumn get debtId => text()();
  RealColumn get amountPaid => real()();
  DateTimeColumn get paidAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PurchaseInvoices extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text()();
  RealColumn get totalAmount => real()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PurchaseItems extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseInvoiceId => text()();
  TextColumn get productId => text()();
  RealColumn get quantity => real()();
  RealColumn get unitCost => real()();

  @override
  Set<Column> get primaryKey => {id};
}

class DeletedRecords extends Table {
  TextColumn get id => text()();
  TextColumn get targetTable => text()();
  TextColumn get recordId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get targetTable => text()();
  TextColumn get recordId => text()();
  TextColumn get operation => text()(); // insert, update, delete
  TextColumn get payload => text()(); // json representation of row
  TextColumn get status => text()(); // pending, failed, synced
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ExpenseCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  RealColumn get amount => real()();
  TextColumn get notes => text().nullable()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Categories,
  Products,
  ProductPrices,
  StockMovements,
  Customers,
  Invoices,
  InvoiceItems,
  Debts,
  DebtPayments,
  Suppliers,
  PurchaseInvoices,
  PurchaseItems,
  DeletedRecords,
  SyncQueue,
  ExpenseCategories,
  Expenses,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(categories, categories.syncedAt);
            await m.addColumn(stockMovements, stockMovements.syncedAt);
            await m.addColumn(customers, customers.syncedAt);
            await m.addColumn(debts, debts.syncedAt);
            await m.addColumn(debtPayments, debtPayments.syncedAt);
            await m.addColumn(suppliers, suppliers.syncedAt);
            await m.addColumn(purchaseInvoices, purchaseInvoices.syncedAt);
            await m.createTable(deletedRecords);
          }
          if (from < 3) {
            await m.addColumn(products, products.code);
          }
          if (from < 4) {
            await m.addColumn(products, products.serialNumber);
          }
          if (from < 5) {
            await m.addColumn(invoices, invoices.serialNumber);
            // Backfill serial numbers for existing invoices ordered by createdAt
            final existingInvoices = await (select(invoices)
                  ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
                .get();
            for (int i = 0; i < existingInvoices.length; i++) {
              final inv = existingInvoices[i];
              if (inv.serialNumber == null) {
                await (update(invoices)..where((t) => t.id.equals(inv.id)))
                    .write(InvoicesCompanion(serialNumber: Value(i + 1)));
              }
            }
          }
          if (from < 6) {
            await m.createTable(expenseCategories);
            await m.createTable(expenses);

            final defaultCategories = [
              'الرواتب والأجور',
              'الإيجار',
              'فواتير ومرافق',
              'طعام وضيافة',
              'صيانة ونظافة',
              'شحن ونقل وتوصيل',
              'مصاريف عامة أخرى',
            ];
            final now = DateTime.now();
            for (final catName in defaultCategories) {
              await into(expenseCategories).insert(
                ExpenseCategoriesCompanion.insert(
                  id: 'exp-cat-${catName.hashCode.abs()}',
                  name: catName,
                  createdAt: now,
                ),
              );
            }
          }
        },
      );

  /// Get the next available product serial number
  Future<int> getNextProductSerialNumber() async {
    final maxExp = products.serialNumber.max();
    final query = selectOnly(products)..addColumns([maxExp]);
    final row = await query.getSingleOrNull();
    final currentMax = row?.read(maxExp) ?? 0;
    return currentMax + 1;
  }

  /// Get the next available invoice serial number
  Future<int> getNextInvoiceSerialNumber() async {
    final maxExp = invoices.serialNumber.max();
    final query = selectOnly(invoices)..addColumns([maxExp]);
    final row = await query.getSingleOrNull();
    final currentMax = row?.read(maxExp) ?? 0;
    return currentMax + 1;
  }

  /// Fast SQL aggregation for all product stock balances
  Future<Map<String, double>> getAllStockBalances() async {
    final qtySum = stockMovements.quantity.sum();
    final query = selectOnly(stockMovements)
      ..addColumns([stockMovements.productId, qtySum])
      ..groupBy([stockMovements.productId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(stockMovements.productId)!: row.read(qtySum) ?? 0.0,
    };
  }

  /// Fast SQL aggregation for a single product's stock balance
  Future<double> getProductStock(String prodId) async {
    final qtySum = stockMovements.quantity.sum();
    final query = selectOnly(stockMovements)
      ..addColumns([qtySum])
      ..where(stockMovements.productId.equals(prodId));
    final row = await query.getSingleOrNull();
    return row?.read(qtySum) ?? 0.0;
  }

  /// Fast SQL sum of all outstanding debt amounts
  Future<double> getTotalRemainingDebts() async {
    final remainingSum = debts.remainingAmount.sum();
    final query = selectOnly(debts)..addColumns([remainingSum]);
    final row = await query.getSingleOrNull();
    return row?.read(remainingSum) ?? 0.0;
  }

  /// Fast SQL sum of remaining debts per customer
  Future<Map<String, double>> getCustomerDebtTotals() async {
    final remainingSum = debts.remainingAmount.sum();
    final query = selectOnly(debts)
      ..addColumns([debts.customerId, remainingSum])
      ..groupBy([debts.customerId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(debts.customerId)!: row.read(remainingSum) ?? 0.0,
    };
  }

  /// Fast SQL count of open debts per customer
  Future<Map<String, int>> getCustomerOpenDebtsCount() async {
    final countExp = debts.id.count();
    final query = selectOnly(debts)
      ..addColumns([debts.customerId, countExp])
      ..where(debts.status.equals('paid').not())
      ..groupBy([debts.customerId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(debts.customerId)!: row.read(countExp) ?? 0,
    };
  }

  /// Fast SQL sum of expenses in a period
  Future<double> getTotalExpensesInPeriod(DateTime start, DateTime end) async {
    final amountSum = expenses.amount.sum();
    final query = selectOnly(expenses)
      ..addColumns([amountSum])
      ..where(expenses.createdAt.isBiggerOrEqualValue(start) &
          expenses.createdAt.isSmallerOrEqualValue(end));
    final row = await query.getSingleOrNull();
    return row?.read(amountSum) ?? 0.0;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'small_mall.db'));
    return NativeDatabase.createInBackground(file);
  });
}
