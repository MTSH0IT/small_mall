import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';
import 'package:uuid/uuid.dart';

enum UnifiedTransactionType {
  sale,
  returnSale,
  purchase,
  expense,
  debtPayment,
  debtInvoice,
  adjustment,
}

class UnifiedTransactionItem {
  const UnifiedTransactionItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0.0,
    this.currency = AppCurrency.defaultCode,
  });

  final String productName;
  final double quantity;
  final double unitPrice;
  final double discount;
  final String currency;

  String get currencySymbol => AppCurrency.getSymbol(currency);
  double get total => (quantity * unitPrice) - discount;
}

class UnifiedTransactionRecord {
  const UnifiedTransactionRecord({
    required this.id,
    this.globalSerialNumber,
    this.serialNumber,
    required this.type,
    required this.createdAt,
    required this.totalAmount,
    this.currency = AppCurrency.defaultCode,
    this.partyName,
    this.paymentType,
    this.discount = 0.0,
    this.notes,
    this.items = const [],
    this.rawInvoice,
    this.rawPurchaseInvoice,
    this.rawExpense,
    this.rawDebtPayment,
    this.rawStockMovement,
  });

  final String id;
  final int? globalSerialNumber; // Chronological global serial number across all operations
  final int? serialNumber; // Specific serial number within the department/type
  final UnifiedTransactionType type;
  final DateTime createdAt;
  final double totalAmount;
  final String currency;
  final String? partyName; // Customer, Supplier, or Expense Category
  final String? paymentType; // 'cash', 'debt', etc.
  final double discount;
  final String? notes;
  final List<UnifiedTransactionItem> items;

  String get currencySymbol => AppCurrency.getSymbol(currency);

  bool get hasMultipleCurrencies {
    if (items.isEmpty) return false;
    final first = items.first.currency;
    return items.any((i) => i.currency != first);
  }

  Set<String> get currencies {
    if (items.isEmpty) return {currency};
    return items.map((i) => i.currency).toSet();
  }

  double totalForCurrency(String currencyCode) {
    return items
        .where((i) => i.currency == currencyCode)
        .fold<double>(0.0, (sum, i) => sum + i.total);
  }

  double get totalSyp {
    if (!hasMultipleCurrencies) {
      return currency != AppCurrency.usdCode ? totalAmount : 0.0;
    }
    final raw = totalForCurrency(AppCurrency.sypCode);
    if (currency != AppCurrency.usdCode && discount > 0) {
      return (raw - discount).clamp(0.0, double.infinity);
    }
    return raw;
  }

  double get totalUsd {
    if (!hasMultipleCurrencies) {
      return currency == AppCurrency.usdCode ? totalAmount : 0.0;
    }
    final raw = totalForCurrency(AppCurrency.usdCode);
    if (currency == AppCurrency.usdCode && discount > 0) {
      return (raw - discount).clamp(0.0, double.infinity);
    }
    return raw;
  }

  // Reference to original records when needed
  final InvoiceWithDetails? rawInvoice;
  final PurchaseInvoice? rawPurchaseInvoice;
  final Expense? rawExpense;
  final DebtPayment? rawDebtPayment;
  final StockMovement? rawStockMovement;

  bool get isSale => type == UnifiedTransactionType.sale;
  bool get isReturn => type == UnifiedTransactionType.returnSale;
  bool get isPurchase => type == UnifiedTransactionType.purchase;
  bool get isExpense => type == UnifiedTransactionType.expense;
  bool get isDebtPayment => type == UnifiedTransactionType.debtPayment;
  bool get isDebtInvoice => type == UnifiedTransactionType.debtInvoice;
  bool get isAdjustment => type == UnifiedTransactionType.adjustment;

  String get typeCode {
    switch (type) {
      case UnifiedTransactionType.sale:
        return 'sale';
      case UnifiedTransactionType.returnSale:
        return 'return';
      case UnifiedTransactionType.purchase:
        return 'purchase';
      case UnifiedTransactionType.expense:
        return 'expense';
      case UnifiedTransactionType.debtPayment:
        return 'debt_payment';
      case UnifiedTransactionType.debtInvoice:
        return 'debt_invoice';
      case UnifiedTransactionType.adjustment:
        return 'adjustment';
    }
  }

  String get typeLabel {
    switch (type) {
      case UnifiedTransactionType.sale:
        return 'invoices.sale'.tr();
      case UnifiedTransactionType.returnSale:
        return 'invoices.return'.tr();
      case UnifiedTransactionType.purchase:
        return 'invoices.purchase'.tr();
      case UnifiedTransactionType.expense:
        return 'invoices.expense'.tr();
      case UnifiedTransactionType.debtPayment:
        return 'invoices.debt_payment'.tr();
      case UnifiedTransactionType.debtInvoice:
        return 'invoices.debt_invoice'.tr();
      case UnifiedTransactionType.adjustment:
        return 'invoices.adjustment'.tr();
    }
  }

  UnifiedTransactionRecord copyWith({
    String? id,
    int? globalSerialNumber,
    int? serialNumber,
    UnifiedTransactionType? type,
    DateTime? createdAt,
    double? totalAmount,
    String? currency,
    String? partyName,
    String? paymentType,
    double? discount,
    String? notes,
    List<UnifiedTransactionItem>? items,
    InvoiceWithDetails? rawInvoice,
    PurchaseInvoice? rawPurchaseInvoice,
    Expense? rawExpense,
    DebtPayment? rawDebtPayment,
    StockMovement? rawStockMovement,
  }) {
    return UnifiedTransactionRecord(
      id: id ?? this.id,
      globalSerialNumber: globalSerialNumber ?? this.globalSerialNumber,
      serialNumber: serialNumber ?? this.serialNumber,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      partyName: partyName ?? this.partyName,
      paymentType: paymentType ?? this.paymentType,
      discount: discount ?? this.discount,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      rawInvoice: rawInvoice ?? this.rawInvoice,
      rawPurchaseInvoice: rawPurchaseInvoice ?? this.rawPurchaseInvoice,
      rawExpense: rawExpense ?? this.rawExpense,
      rawDebtPayment: rawDebtPayment ?? this.rawDebtPayment,
      rawStockMovement: rawStockMovement ?? this.rawStockMovement,
    );
  }
}

class InvoicesRepository {
  InvoicesRepository(this._db, this._posRepository, this._logger, [SyncService? sync])
      : _sync = sync;

  final AppDatabase _db;
  final POSRepository _posRepository;
  final AppLogger _logger;
  final SyncService? _sync;
  final _uuid = const Uuid();

  Future<List<UnifiedTransactionRecord>> getAllTransactions() async {
    _logger.debug('Fetching all unified transactions', context: LogContext.pos);

    final List<UnifiedTransactionRecord> records = [];

    // Parallel fetch of base tables to optimize query time
    final results = await Future.wait([
      _fetchSalesAndReturns(), // 0: Sales & returns with details
      _fetchPurchases(), // 1: Purchases with details
      _fetchExpenses(), // 2: Expenses with category
      _fetchDebtPayments(), // 3: Debt payments with customer
      _fetchAdjustments(), // 4: Stock adjustments with product
    ]);

    records.addAll(results[0]);
    records.addAll(results[1]);
    records.addAll(results[2]);
    records.addAll(results[3]);
    records.addAll(results[4]);

    // Order ascending by creation date to assign chronological global serial numbers
    records.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final List<UnifiedTransactionRecord> recordsWithGlobal = [];
    for (int i = 0; i < records.length; i++) {
      recordsWithGlobal.add(records[i].copyWith(globalSerialNumber: i + 1));
    }

    // Order descending by creation date for display
    recordsWithGlobal.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return recordsWithGlobal;
  }

  Future<List<UnifiedTransactionRecord>> _fetchSalesAndReturns() async {
    final invoicesWithDetails = await _posRepository.getAllInvoices();
    return invoicesWithDetails.map((inv) {
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
          currency: item.invoiceItem.currency,
        );
      }).toList();

      return UnifiedTransactionRecord(
        id: inv.invoice.id,
        serialNumber: inv.invoice.serialNumber,
        type: type,
        createdAt: inv.invoice.createdAt,
        totalAmount: inv.invoice.totalAmount,
        currency: inv.invoice.currency,
        partyName: inv.customerName,
        paymentType: inv.invoice.paymentType,
        discount: inv.invoice.discount,
        items: items,
        rawInvoice: inv,
      );
    }).toList();
  }

  Future<List<UnifiedTransactionRecord>> _fetchPurchases() async {
    final purchases = await (_db.select(_db.purchaseInvoices)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();

    if (purchases.isEmpty) return [];

    final allItems = await _db.select(_db.purchaseItems).get();
    final allSuppliers = await _db.select(_db.suppliers).get();
    final allProducts = await _db.select(_db.products).get();

    final supplierMap = {for (final s in allSuppliers) s.id: s.name};
    final productMap = {for (final p in allProducts) p.id: p.name};

    // Calculate serial numbers based on ascending order
    final ascPurchases = List<PurchaseInvoice>.from(purchases)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final serialMap = <String, int>{};
    for (int i = 0; i < ascPurchases.length; i++) {
      serialMap[ascPurchases[i].id] = i + 1;
    }

    return purchases.map((p) {
      final items = allItems.where((i) => i.purchaseInvoiceId == p.id).map((item) {
        return UnifiedTransactionItem(
          productName: productMap[item.productId] ?? 'common.deleted_product'.tr(),
          quantity: item.quantity,
          unitPrice: item.unitCost,
          currency: item.currency,
        );
      }).toList();

      return UnifiedTransactionRecord(
        id: p.id,
        serialNumber: serialMap[p.id],
        type: UnifiedTransactionType.purchase,
        createdAt: p.createdAt,
        totalAmount: p.totalAmount,
        currency: p.currency,
        partyName: supplierMap[p.supplierId] ?? 'invoices.supplier'.tr(),
        paymentType: 'cash',
        items: items,
        rawPurchaseInvoice: p,
      );
    }).toList();
  }

  Future<List<UnifiedTransactionRecord>> _fetchExpenses() async {
    final expenses = await (_db.select(_db.expenses)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();

    if (expenses.isEmpty) return [];

    final allCategories = await _db.select(_db.expenseCategories).get();
    final categoryMap = {for (final c in allCategories) c.id: c.name};

    final ascExpenses = List<Expense>.from(expenses)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final serialMap = <String, int>{};
    for (int i = 0; i < ascExpenses.length; i++) {
      serialMap[ascExpenses[i].id] = i + 1;
    }

    return expenses.map((e) {
      return UnifiedTransactionRecord(
        id: e.id,
        serialNumber: serialMap[e.id],
        type: UnifiedTransactionType.expense,
        createdAt: e.createdAt,
        totalAmount: e.amount,
        currency: e.currency,
        partyName: categoryMap[e.categoryId] ?? 'invoices.expense_category'.tr(),
        notes: e.notes,
        rawExpense: e,
      );
    }).toList();
  }

  Future<List<UnifiedTransactionRecord>> _fetchDebtPayments() async {
    final payments = await (_db.select(_db.debtPayments)
          ..orderBy([(t) => OrderingTerm.desc(t.paidAt)]))
        .get();

    if (payments.isEmpty) return [];

    final allDebts = await _db.select(_db.debts).get();
    final allCustomers = await _db.select(_db.customers).get();

    final debtMap = {for (final d in allDebts) d.id: d};
    final customerMap = {for (final c in allCustomers) c.id: c.name};

    final ascPayments = List<DebtPayment>.from(payments)
      ..sort((a, b) => a.paidAt.compareTo(b.paidAt));
    final serialMap = <String, int>{};
    for (int i = 0; i < ascPayments.length; i++) {
      serialMap[ascPayments[i].id] = i + 1;
    }

    return payments.map((dp) {
      final debt = debtMap[dp.debtId];
      final customerName = debt != null ? customerMap[debt.customerId] : null;

      return UnifiedTransactionRecord(
        id: dp.id,
        serialNumber: serialMap[dp.id],
        type: UnifiedTransactionType.debtPayment,
        createdAt: dp.paidAt,
        totalAmount: dp.amountPaid,
        currency: dp.currency,
        partyName: customerName ?? 'common.deleted_customer'.tr(),
        notes: debt != null ? '${'customers.remaining_debt'.tr()}: ${debt.remainingAmount.toStringAsFixed(2)} ${AppCurrency.getSymbol(debt.currency)}' : null,
        rawDebtPayment: dp,
      );
    }).toList();
  }

  Future<List<UnifiedTransactionRecord>> _fetchAdjustments() async {
    final adjustments = await (_db.select(_db.stockMovements)
          ..where((t) => t.type.equals('adjustment'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();

    if (adjustments.isEmpty) return [];

    final allProducts = await _db.select(_db.products).get();
    final productMap = {for (final p in allProducts) p.id: p};

    final ascAdjustments = List<StockMovement>.from(adjustments)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final serialMap = <String, int>{};
    for (int i = 0; i < ascAdjustments.length; i++) {
      serialMap[ascAdjustments[i].id] = i + 1;
    }

    return adjustments.map((m) {
      final product = productMap[m.productId];
      final productName = product?.name ?? 'common.deleted_product'.tr();
      final cost = product?.costPrice ?? 0.0;
      final totalValue = (m.quantity.abs() * cost);
      final currency = product?.currency ?? AppCurrency.sypCode;

      return UnifiedTransactionRecord(
        id: m.id,
        serialNumber: serialMap[m.id],
        type: UnifiedTransactionType.adjustment,
        createdAt: m.createdAt,
        totalAmount: totalValue,
        currency: currency,
        partyName: productName,
        notes: m.referenceId, // reason stored in referenceId
        items: [
          UnifiedTransactionItem(
            productName: productName,
            quantity: m.quantity,
            unitPrice: cost,
            currency: currency,
          ),
        ],
        rawStockMovement: m,
      );
    }).toList();
  }

  // Universal Transaction Management (Sale, Purchase, Expense, Debt Payment, Adjustment)
  Future<Map<String, dynamic>> canDeleteInvoice(String invoiceId) =>
      _posRepository.canDeleteInvoice(invoiceId);

  Future<void> deleteInvoice(String invoiceId) =>
      _posRepository.deleteInvoice(invoiceId);

  Future<Map<String, dynamic>> canDeleteTransaction(UnifiedTransactionRecord transaction) async {
    if (transaction.isSale || transaction.isReturn || transaction.isDebtInvoice) {
      return _posRepository.canDeleteInvoice(transaction.id);
    }
    return {'canDelete': true};
  }

  Future<void> deleteTransaction(UnifiedTransactionRecord transaction) async {
    final now = DateTime.now();

    if (transaction.isSale || transaction.isReturn || transaction.isDebtInvoice) {
      await _posRepository.deleteInvoice(transaction.id);
      return;
    }

    if (transaction.isPurchase) {
      final purchaseId = transaction.id;
      await _db.transaction(() async {
        final movements = await (_db.select(_db.stockMovements)..where((t) => t.referenceId.equals(purchaseId))).get();
        for (final m in movements) {
          await (_db.delete(_db.stockMovements)..where((t) => t.id.equals(m.id))).go();
          await _db.into(_db.deletedRecords).insert(
                DeletedRecordsCompanion.insert(
                  id: _uuid.v4(),
                  targetTable: 'stock_movements',
                  recordId: m.id,
                  createdAt: now,
                ),
              );
        }

        final items = await (_db.select(_db.purchaseItems)..where((t) => t.purchaseInvoiceId.equals(purchaseId))).get();
        for (final item in items) {
          await (_db.delete(_db.purchaseItems)..where((t) => t.id.equals(item.id))).go();
          await _db.into(_db.deletedRecords).insert(
                DeletedRecordsCompanion.insert(
                  id: _uuid.v4(),
                  targetTable: 'purchase_items',
                  recordId: item.id,
                  createdAt: now,
                ),
              );
        }

        await (_db.delete(_db.purchaseInvoices)..where((t) => t.id.equals(purchaseId))).go();
        await _db.into(_db.deletedRecords).insert(
              DeletedRecordsCompanion.insert(
                id: _uuid.v4(),
                targetTable: 'purchase_invoices',
                recordId: purchaseId,
                createdAt: now,
              ),
            );
      });
      _sync?.updatePendingCount();
      _sync?.sync();
      return;
    }

    if (transaction.isExpense) {
      final expenseId = transaction.id;
      await _db.into(_db.deletedRecords).insert(
            DeletedRecordsCompanion.insert(
              id: _uuid.v4(),
              targetTable: 'expenses',
              recordId: expenseId,
              createdAt: now,
            ),
          );
      await (_db.delete(_db.expenses)..where((t) => t.id.equals(expenseId))).go();
      _sync?.updatePendingCount();
      _sync?.sync();
      return;
    }

    if (transaction.isDebtPayment) {
      final paymentId = transaction.id;
      await _db.transaction(() async {
        final payment = await (_db.select(_db.debtPayments)..where((t) => t.id.equals(paymentId))).getSingleOrNull();
        if (payment != null) {
          final debt = await (_db.select(_db.debts)..where((t) => t.id.equals(payment.debtId))).getSingleOrNull();
          if (debt != null) {
            final newRemaining = (debt.remainingAmount + payment.amountPaid).clamp(0.0, debt.amount);
            await (_db.update(_db.debts)..where((t) => t.id.equals(debt.id))).write(
                  DebtsCompanion(
                    remainingAmount: Value(newRemaining),
                    status: const Value('open'),
                    syncedAt: const Value(null),
                  ),
                );
          }
          await (_db.delete(_db.debtPayments)..where((t) => t.id.equals(payment.id))).go();
          await _db.into(_db.deletedRecords).insert(
                DeletedRecordsCompanion.insert(
                  id: _uuid.v4(),
                  targetTable: 'debt_payments',
                  recordId: payment.id,
                  createdAt: now,
                ),
              );
        }
      });
      _sync?.updatePendingCount();
      _sync?.sync();
      return;
    }

    if (transaction.isAdjustment) {
      final movementId = transaction.id;
      await (_db.delete(_db.stockMovements)..where((t) => t.id.equals(movementId))).go();
      await _db.into(_db.deletedRecords).insert(
            DeletedRecordsCompanion.insert(
              id: _uuid.v4(),
              targetTable: 'stock_movements',
              recordId: movementId,
              createdAt: now,
            ),
          );
      _sync?.updatePendingCount();
      _sync?.sync();
      return;
    }
  }

  Future<void> updateInvoice({
    required String invoiceId,
    required String? customerId,
    required String paymentType,
    required double discount,
    required List<Map<String, dynamic>> items,
  }) =>
      _posRepository.updateInvoice(
        invoiceId: invoiceId,
        customerId: customerId,
        paymentType: paymentType,
        discount: discount,
        items: items,
      );

  Future<List<PurchaseItem>> getPurchaseItems(String purchaseInvoiceId) async {
    return (_db.select(_db.purchaseItems)..where((t) => t.purchaseInvoiceId.equals(purchaseInvoiceId))).get();
  }

  Future<List<Supplier>> getSuppliers() async {
    return (_db.select(_db.suppliers)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<List<ExpenseCategory>> getExpenseCategories() async {
    return (_db.select(_db.expenseCategories)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<void> updatePurchaseInvoice({
    required String purchaseInvoiceId,
    required String supplierId,
    required List<Map<String, dynamic>> items,
  }) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      double totalAmount = 0.0;
      for (final it in items) {
        final q = (it['quantity'] as num).toDouble();
        final c = (it['unitCost'] as num).toDouble();
        totalAmount += (q * c);
      }

      await (_db.update(_db.purchaseInvoices)..where((t) => t.id.equals(purchaseInvoiceId))).write(
            PurchaseInvoicesCompanion(
              supplierId: Value(supplierId),
              totalAmount: Value(totalAmount),
              syncedAt: const Value(null),
            ),
          );

      final existingItems = await (_db.select(_db.purchaseItems)
            ..where((t) => t.purchaseInvoiceId.equals(purchaseInvoiceId)))
          .get();
      final existingIds = existingItems.map((e) => e.id).toSet();
      final keptIds = items.map((e) => e['id'] as String?).whereType<String>().toSet();

      final toDelete = existingIds.difference(keptIds);
      for (final delId in toDelete) {
        final delItem = existingItems.firstWhere((e) => e.id == delId);
        await (_db.delete(_db.stockMovements)
              ..where((t) => t.referenceId.equals(purchaseInvoiceId) & t.productId.equals(delItem.productId)))
            .go();
        await (_db.delete(_db.purchaseItems)..where((t) => t.id.equals(delId))).go();
        await _db.into(_db.deletedRecords).insert(
              DeletedRecordsCompanion.insert(
                id: _uuid.v4(),
                targetTable: 'purchase_items',
                recordId: delId,
                createdAt: now,
              ),
            );
      }

      for (final it in items) {
        final itemId = it['id'] as String?;
        final prodId = it['productId'] as String;
        final qty = (it['quantity'] as num).toDouble();
        final cost = (it['unitCost'] as num).toDouble();
        final curr = (it['currency'] as String?) ?? AppCurrency.defaultCode;

        if (itemId != null && existingIds.contains(itemId)) {
          await (_db.update(_db.purchaseItems)..where((t) => t.id.equals(itemId))).write(
                PurchaseItemsCompanion(
                  quantity: Value(qty),
                  unitCost: Value(cost),
                  currency: Value(curr),
                ),
              );
          await (_db.update(_db.stockMovements)
                ..where((t) => t.referenceId.equals(purchaseInvoiceId) & t.productId.equals(prodId)))
              .write(
                StockMovementsCompanion(
                  quantity: Value(qty),
                ),
              );
        } else {
          final newId = _uuid.v4();
          await _db.into(_db.purchaseItems).insert(
                PurchaseItem(
                  id: newId,
                  purchaseInvoiceId: purchaseInvoiceId,
                  productId: prodId,
                  quantity: qty,
                  unitCost: cost,
                  currency: curr,
                ),
              );
          await _db.into(_db.stockMovements).insert(
                StockMovement(
                  id: _uuid.v4(),
                  productId: prodId,
                  type: 'purchase',
                  quantity: qty,
                  createdAt: now,
                  referenceId: purchaseInvoiceId,
                ),
              );
        }
      }
    });

    _sync?.updatePendingCount();
    _sync?.sync();
  }

  Future<void> updateExpense({
    required String expenseId,
    required String categoryId,
    required double amount,
    required String currency,
    String? notes,
    required DateTime createdAt,
  }) async {
    await (_db.update(_db.expenses)..where((t) => t.id.equals(expenseId))).write(
          ExpensesCompanion(
            categoryId: Value(categoryId),
            amount: Value(amount),
            currency: Value(currency),
            notes: Value(notes),
            createdAt: Value(createdAt),
            syncedAt: const Value(null),
          ),
        );
    _sync?.updatePendingCount();
    _sync?.sync();
  }

  Future<void> updateDebtPayment({
    required String paymentId,
    required double newAmount,
    required DateTime paidAt,
  }) async {
    await _db.transaction(() async {
      final payment = await (_db.select(_db.debtPayments)..where((t) => t.id.equals(paymentId))).getSingleOrNull();
      if (payment == null) return;

      final debt = await (_db.select(_db.debts)..where((t) => t.id.equals(payment.debtId))).getSingleOrNull();
      if (debt != null) {
        final diff = newAmount - payment.amountPaid;
        final newRemaining = (debt.remainingAmount - diff).clamp(0.0, debt.amount);
        final newStatus = newRemaining <= 0.001 ? 'paid' : 'open';
        await (_db.update(_db.debts)..where((t) => t.id.equals(debt.id))).write(
              DebtsCompanion(
                remainingAmount: Value(newRemaining),
                status: Value(newStatus),
                syncedAt: const Value(null),
              ),
            );
      }

      await (_db.update(_db.debtPayments)..where((t) => t.id.equals(paymentId))).write(
            DebtPaymentsCompanion(
              amountPaid: Value(newAmount),
              paidAt: Value(paidAt),
              syncedAt: const Value(null),
            ),
          );
    });
    _sync?.updatePendingCount();
    _sync?.sync();
  }

  Future<void> updateAdjustment({
    required String movementId,
    required double quantity,
    String? reason,
  }) async {
    await (_db.update(_db.stockMovements)..where((t) => t.id.equals(movementId))).write(
          StockMovementsCompanion(
            quantity: Value(quantity),
            referenceId: Value(reason),
          ),
        );
    _sync?.updatePendingCount();
    _sync?.sync();
  }
}
