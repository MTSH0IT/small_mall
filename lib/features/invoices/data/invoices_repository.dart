import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';

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
  InvoicesRepository(this._db, this._posRepository, this._logger);

  final AppDatabase _db;
  final POSRepository _posRepository;
  final AppLogger _logger;

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

  // Pass-through functions for POS sales & returns management
  Future<Map<String, dynamic>> canDeleteInvoice(String invoiceId) =>
      _posRepository.canDeleteInvoice(invoiceId);

  Future<void> deleteInvoice(String invoiceId) =>
      _posRepository.deleteInvoice(invoiceId);

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
}
