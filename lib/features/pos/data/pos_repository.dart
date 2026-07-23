import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/sync/sync_service.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class InvoiceItemWithProduct {

  InvoiceItemWithProduct({
    required this.invoiceItem,
    required this.productName,
  });
  final InvoiceItem invoiceItem;
  final String productName;
}

class InvoiceWithDetails {

  InvoiceWithDetails({
    required this.invoice,
    required this.items,
    this.customerName,
  });
  final Invoice invoice;
  final List<InvoiceItemWithProduct> items;
  final String? customerName;

  double get itemsTotal => items.fold<double>(
    0.0,
    (sum, item) => sum + (item.invoiceItem.priceUsed * item.invoiceItem.quantity) - item.invoiceItem.discount,
  );
}

class POSRepository {

  POSRepository(this._db, this._sync, this._logger);
  final AppDatabase _db;
  final SyncService _sync;
  final AppLogger _logger;
  final _uuid = const Uuid();

  Future<void> createSale({
    required String? customerId,
    required double totalAmount,
    required double discount,
    required String paymentType, // 'cash' or 'debt'
    required List<Map<String, dynamic>> items, // productId, priceUsed, quantity, discount
  }) async {
    final invoiceId = _uuid.v4();
    final now = DateTime.now();

    final invoice = Invoice(
      id: invoiceId,
      type: 'sale',
      customerId: customerId,
      totalAmount: totalAmount,
      discount: discount,
      paymentType: paymentType,
      createdAt: now,
    );

    // Insert Invoice
    await _db.into(_db.invoices).insert(invoice);
    await _sync.enqueue('invoices', invoiceId, 'insert', {
      'id': invoiceId,
      'type': 'sale',
      'customer_id': customerId,
      'total_amount': totalAmount,
      'discount': discount,
      'payment_type': paymentType,
      'created_at': now.toIso8601String(),
    });

    // Insert Invoice Items & Stock Movements
    for (final item in items) {
      final itemId = _uuid.v4();
      final prodId = item['productId'] as String;
      final priceUsed = (item['priceUsed'] as num).toDouble();
      final qty = (item['quantity'] as num).toDouble();
      final itemDiscount = (item['discount'] as num).toDouble();

      final invItem = InvoiceItem(
        id: itemId,
        invoiceId: invoiceId,
        productId: prodId,
        priceUsed: priceUsed,
        quantity: qty,
        discount: itemDiscount,
      );

      await _db.into(_db.invoiceItems).insert(invItem);
      await _sync.enqueue('invoice_items', itemId, 'insert', {
        'id': itemId,
        'invoice_id': invoiceId,
        'product_id': prodId,
        'price_used': priceUsed,
        'quantity': qty,
        'discount': itemDiscount,
      });

      // Write Stock Movement (negative quantity for sale)
      final movementId = _uuid.v4();
      final movement = StockMovement(
        id: movementId,
        productId: prodId,
        type: 'sale',
        quantity: -qty,
        createdAt: now,
        referenceId: invoiceId,
      );

      await _db.into(_db.stockMovements).insert(movement);
      await _sync.enqueue('stock_movements', movementId, 'insert', {
        'id': movementId,
        'product_id': prodId,
        'type': 'sale',
        'quantity': -qty,
        'created_at': now.toIso8601String(),
        'reference_id': invoiceId,
      });
    }

    // Insert Debt if payment type is credit/debt
    if (paymentType == 'debt' && customerId != null) {
      final debtId = _uuid.v4();
      final debt = Debt(
        id: debtId,
        customerId: customerId,
        invoiceId: invoiceId,
        amount: totalAmount,
        remainingAmount: totalAmount,
        status: 'open',
        createdAt: now,
      );

      await _db.into(_db.debts).insert(debt);
      await _sync.enqueue('debts', debtId, 'insert', {
        'id': debtId,
        'customer_id': customerId,
        'invoice_id': invoiceId,
        'amount': totalAmount,
        'remaining_amount': totalAmount,
        'status': 'open',
        'created_at': now.toIso8601String(),
      });
    }
  }

  // Record return of products
  Future<void> createReturn({
    required String originalInvoiceId,
    required List<Map<String, dynamic>> itemsToReturn, // productId, quantity, priceUsed
  }) async {
    final now = DateTime.now();
    final returnInvoiceId = _uuid.v4();

    // Fetch original invoice
    final originalInvoice = await (_db.select(_db.invoices)..where((t) => t.id.equals(originalInvoiceId))).getSingleOrNull();
    if (originalInvoice == null) return;

    double totalReturnVal = 0.0;
    for (final item in itemsToReturn) {
      totalReturnVal += (item['quantity'] as num).toDouble() * (item['priceUsed'] as num).toDouble();
    }

    final returnInvoice = Invoice(
      id: returnInvoiceId,
      type: 'return',
      customerId: originalInvoice.customerId,
      totalAmount: totalReturnVal,
      discount: 0.0,
      paymentType: originalInvoice.paymentType,
      createdAt: now,
    );

    // Insert return invoice record
    await _db.into(_db.invoices).insert(returnInvoice);
    await _sync.enqueue('invoices', returnInvoiceId, 'insert', {
      'id': returnInvoiceId,
      'type': 'return',
      'customer_id': originalInvoice.customerId,
      'total_amount': totalReturnVal,
      'discount': 0.0,
      'payment_type': originalInvoice.paymentType,
      'created_at': now.toIso8601String(),
    });

    // Write return items and restore stock
    for (final item in itemsToReturn) {
      final itemId = _uuid.v4();
      final prodId = item['productId'] as String;
      final qty = (item['quantity'] as num).toDouble();
      final priceUsed = (item['priceUsed'] as num).toDouble();

      final invItem = InvoiceItem(
        id: itemId,
        invoiceId: returnInvoiceId,
        productId: prodId,
        priceUsed: priceUsed,
        quantity: qty,
        discount: 0.0,
      );

      await _db.into(_db.invoiceItems).insert(invItem);
      await _sync.enqueue('invoice_items', itemId, 'insert', {
        'id': itemId,
        'invoice_id': returnInvoiceId,
        'product_id': prodId,
        'price_used': priceUsed,
        'quantity': qty,
        'discount': 0.0,
      });

      // Stock movement: POSITIVE quantity to restore stock
      final movementId = _uuid.v4();
      final movement = StockMovement(
        id: movementId,
        productId: prodId,
        type: 'return',
        quantity: qty,
        createdAt: now,
        referenceId: returnInvoiceId,
      );

      await _db.into(_db.stockMovements).insert(movement);
      await _sync.enqueue('stock_movements', movementId, 'insert', {
        'id': movementId,
        'product_id': prodId,
        'type': 'return',
        'quantity': qty,
        'created_at': now.toIso8601String(),
        'reference_id': returnInvoiceId,
      });
    }

    // Adjust debt if this was a credit sale
    if (originalInvoice.paymentType == 'debt' && originalInvoice.customerId != null) {
      final debts = await (_db.select(_db.debts)
            ..where((t) => t.invoiceId.equals(originalInvoiceId)))
          .get();

      if (debts.isNotEmpty) {
        final debt = debts.first;
        final newRemaining = (debt.remainingAmount - totalReturnVal).clamp(0.0, double.infinity);
        final newStatus = newRemaining <= 0 ? 'paid' : 'partial';

        await (_db.update(_db.debts)..where((t) => t.id.equals(debt.id)))
            .write(DebtsCompanion(
              remainingAmount: Value(newRemaining),
              status: Value(newStatus),
            ));

        await _sync.enqueue('debts', debt.id, 'update', {
          'id': debt.id,
          'remaining_amount': newRemaining,
          'status': newStatus,
        });
      }
    }
  }

  Future<List<Invoice>> getRecentSales() async {
    return (_db.select(_db.invoices)
          ..where((t) => t.type.equals('sale'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId) async {
    return (_db.select(_db.invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).get();
  }

  Future<List<InvoiceWithDetails>> getAllInvoices() async {
    final invoices = await (_db.select(_db.invoices)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    final allItems = await _db.select(_db.invoiceItems).get();
    final allCustomers = await _db.select(_db.customers).get();
    final allProducts = await _db.select(_db.products).get();

    final customerMap = {for (var c in allCustomers) c.id: c};
    final productMap = {for (var p in allProducts) p.id: p};

    return invoices.map((invoice) {
      final items = allItems.where((i) => i.invoiceId == invoice.id).map((item) {
        final product = productMap[item.productId];
        return InvoiceItemWithProduct(
          invoiceItem: item,
          productName: product?.name ?? 'منتج محذوف',
        );
      }).toList();

      final customer = invoice.customerId != null ? customerMap[invoice.customerId] : null;

      return InvoiceWithDetails(
        invoice: invoice,
        items: items,
        customerName: customer?.name,
      );
    }).toList();
  }

  Future<InvoiceWithDetails?> getInvoiceById(String invoiceId) async {
    final allInvoices = await getAllInvoices();
    try {
      return allInvoices.firstWhere((i) => i.invoice.id == invoiceId);
    } catch (_) {
      return null;
    }
  }
}
