import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/logging/app_logger.dart';
import 'package:small_mall/core/logging/log_context.dart';
import 'package:small_mall/core/sync/sync_service.dart';
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
    required String paymentType,
    required List<Map<String, dynamic>> items,
  }) async {
    _logger.info('Creating sale: amount=$totalAmount, payment=$paymentType, items=${items.length}',
        context: LogContext.pos);
    final invoiceId = _uuid.v4();
    final now = DateTime.now();
    final serialNumber = await _db.getNextInvoiceSerialNumber();

    await _db.transaction(() async {
      final invoice = Invoice(
        id: invoiceId,
        serialNumber: serialNumber,
        type: 'sale',
        customerId: customerId,
        totalAmount: totalAmount,
        discount: discount,
        paymentType: paymentType,
        createdAt: now,
      );

      // Insert Invoice
      await _db.into(_db.invoices).insert(invoice);

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
      }

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
      }
    });

    _sync.updatePendingCount();
    _sync.sync();
    _logger.debug('Sale created: invoiceId=$invoiceId', context: LogContext.pos);
  }

  // Record return of products
  Future<void> createReturn({
    required String originalInvoiceId,
    required List<Map<String, dynamic>> itemsToReturn,
  }) async {
    _logger.info('Creating return for invoice $originalInvoiceId, items=${itemsToReturn.length}',
        context: LogContext.pos);
    final now = DateTime.now();
    final returnInvoiceId = _uuid.v4();
    final serialNumber = await _db.getNextInvoiceSerialNumber();

    final originalInvoice = await (_db.select(_db.invoices)..where((t) => t.id.equals(originalInvoiceId))).getSingleOrNull();
    if (originalInvoice == null) {
      _logger.warning('Return cancelled - original invoice not found: $originalInvoiceId', context: LogContext.pos);
      return;
    }

    double totalReturnVal = 0.0;
    for (final item in itemsToReturn) {
      totalReturnVal += (item['quantity'] as num).toDouble() * (item['priceUsed'] as num).toDouble();
    }

    await _db.transaction(() async {
      final returnInvoice = Invoice(
        id: returnInvoiceId,
        serialNumber: serialNumber,
        type: 'return',
        customerId: originalInvoice.customerId,
        totalAmount: totalReturnVal,
        discount: 0.0,
        paymentType: originalInvoice.paymentType,
        createdAt: now,
      );

      // Insert return invoice record
      await _db.into(_db.invoices).insert(returnInvoice);

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
                syncedAt: const Value(null),
              ));
        }
      }
    });

    _sync.updatePendingCount();
    _sync.sync();
  }

  Future<List<Invoice>> getRecentSales() async {
    _logger.debug('Fetching recent sales', context: LogContext.pos);
    return (_db.select(_db.invoices)
          ..where((t) => t.type.equals('sale'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId) async {
    _logger.debug('Fetching items for invoice $invoiceId', context: LogContext.pos);
    return (_db.select(_db.invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).get();
  }

  Future<List<InvoiceWithDetails>> getAllInvoices() async {
    _logger.debug('Fetching all invoices', context: LogContext.pos);
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
          productName: product?.name ?? 'common.deleted_product'.tr(),
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
    _logger.debug('Fetching invoice by id: $invoiceId', context: LogContext.pos);
    final invoice = await (_db.select(_db.invoices)..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
    if (invoice == null) {
      _logger.warning('Invoice not found: $invoiceId', context: LogContext.pos);
      return null;
    }

    final items = await (_db.select(_db.invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).get();
    final customer = invoice.customerId != null
        ? await (_db.select(_db.customers)..where((t) => t.id.equals(invoice.customerId!))).getSingleOrNull()
        : null;

    final productIds = items.map((i) => i.productId).toSet();
    final products = await (_db.select(_db.products)..where((t) => t.id.isIn(productIds))).get();
    final productMap = {for (var p in products) p.id: p};

    final itemsWithProducts = items.map((item) {
      final product = productMap[item.productId];
      return InvoiceItemWithProduct(
        invoiceItem: item,
        productName: product?.name ?? 'common.deleted_product'.tr(),
      );
    }).toList();

    return InvoiceWithDetails(
      invoice: invoice,
      items: itemsWithProducts,
      customerName: customer?.name,
    );
  }

  /// Check if invoice can be safely deleted or has paid debts
  Future<Map<String, dynamic>> canDeleteInvoice(String invoiceId) async {
    final debts = await (_db.select(_db.debts)..where((t) => t.invoiceId.equals(invoiceId))).get();
    if (debts.isNotEmpty) {
      for (final debt in debts) {
        final payments = await (_db.select(_db.debtPayments)..where((t) => t.debtId.equals(debt.id))).get();
        if (payments.isNotEmpty) {
          return {
            'canDelete': false,
            'reason': 'has_debt_payments',
          };
        }
      }
    }
    return {'canDelete': true};
  }

  /// Delete an invoice and reverse its stock movements & debt
  Future<void> deleteInvoice(String invoiceId) async {
    _logger.info('Deleting invoice $invoiceId', context: LogContext.pos);
    final check = await canDeleteInvoice(invoiceId);
    if (check['canDelete'] != true) {
      throw Exception('invoices.delete_invoice_debt_has_payments_warning'.tr());
    }

    final now = DateTime.now();

    await _db.transaction(() async {
      // 1. Delete associated debts & record deletion
      final debts = await (_db.select(_db.debts)..where((t) => t.invoiceId.equals(invoiceId))).get();
      for (final d in debts) {
        await (_db.delete(_db.debts)..where((t) => t.id.equals(d.id))).go();
        await _db.into(_db.deletedRecords).insert(
              DeletedRecordsCompanion.insert(
                id: _uuid.v4(),
                targetTable: 'debts',
                recordId: d.id,
                createdAt: now,
              ),
            );
      }

      // 2. Delete stock movements associated with this invoice & record deletion
      final movements = await (_db.select(_db.stockMovements)..where((t) => t.referenceId.equals(invoiceId))).get();
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

      // 3. Delete invoice items & record deletion
      final items = await (_db.select(_db.invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).get();
      for (final item in items) {
        await (_db.delete(_db.invoiceItems)..where((t) => t.id.equals(item.id))).go();
        await _db.into(_db.deletedRecords).insert(
              DeletedRecordsCompanion.insert(
                id: _uuid.v4(),
                targetTable: 'invoice_items',
                recordId: item.id,
                createdAt: now,
              ),
            );
      }

      // 4. Delete invoice & record deletion
      await (_db.delete(_db.invoices)..where((t) => t.id.equals(invoiceId))).go();
      await _db.into(_db.deletedRecords).insert(
            DeletedRecordsCompanion.insert(
              id: _uuid.v4(),
              targetTable: 'invoices',
              recordId: invoiceId,
              createdAt: now,
            ),
          );
    });

    _sync.updatePendingCount();
    _sync.sync();
    _logger.info('Invoice $invoiceId deleted successfully', context: LogContext.pos);
  }

  /// Update invoice details: customer, paymentType, discount, and items
  Future<void> updateInvoice({
    required String invoiceId,
    required String? customerId,
    required String paymentType,
    required double discount,
    required List<Map<String, dynamic>> items,
  }) async {
    _logger.info(
      'Updating invoice $invoiceId: customer=$customerId, payment=$paymentType, discount=$discount, items=${items.length}',
      context: LogContext.pos,
    );

    final invoice = await (_db.select(_db.invoices)..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
    if (invoice == null) {
      throw Exception('Invoice not found: $invoiceId');
    }

    final isReturn = invoice.type == 'return';
    final now = DateTime.now();

    // Calculate new total
    double subtotal = 0.0;
    for (final it in items) {
      final qty = (it['quantity'] as num).toDouble();
      final price = (it['priceUsed'] as num).toDouble();
      final itemDiscount = (it['discount'] as num?)?.toDouble() ?? 0.0;
      subtotal += (qty * price) - itemDiscount;
    }
    final newTotalAmount = (subtotal - discount).clamp(0.0, double.infinity);

    await _db.transaction(() async {
      // 1. Delete previous stock movements for this invoice & record deletion
      final oldMovements = await (_db.select(_db.stockMovements)..where((t) => t.referenceId.equals(invoiceId))).get();
      for (final m in oldMovements) {
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

      // 2. Delete previous invoice items & record deletion
      final oldItems = await (_db.select(_db.invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).get();
      for (final item in oldItems) {
        await (_db.delete(_db.invoiceItems)..where((t) => t.id.equals(item.id))).go();
        await _db.into(_db.deletedRecords).insert(
              DeletedRecordsCompanion.insert(
                id: _uuid.v4(),
                targetTable: 'invoice_items',
                recordId: item.id,
                createdAt: now,
              ),
            );
      }

      // 3. Insert new invoice items & new stock movements
      for (final item in items) {
        final itemId = _uuid.v4();
        final prodId = item['productId'] as String;
        final priceUsed = (item['priceUsed'] as num).toDouble();
        final qty = (item['quantity'] as num).toDouble();
        final itemDiscount = (item['discount'] as num?)?.toDouble() ?? 0.0;

        final invItem = InvoiceItem(
          id: itemId,
          invoiceId: invoiceId,
          productId: prodId,
          priceUsed: priceUsed,
          quantity: qty,
          discount: itemDiscount,
        );
        await _db.into(_db.invoiceItems).insert(invItem);

        // Stock movement: negative for sale, positive for return
        final movementId = _uuid.v4();
        final movement = StockMovement(
          id: movementId,
          productId: prodId,
          type: isReturn ? 'return' : 'sale',
          quantity: isReturn ? qty : -qty,
          createdAt: now,
          referenceId: invoiceId,
        );
        await _db.into(_db.stockMovements).insert(movement);
      }

      // 4. Handle debt updates
      final existingDebts = await (_db.select(_db.debts)..where((t) => t.invoiceId.equals(invoiceId))).get();
      if (paymentType == 'debt' && customerId != null) {
        if (existingDebts.isNotEmpty) {
          final debt = existingDebts.first;
          final payments = await (_db.select(_db.debtPayments)..where((t) => t.debtId.equals(debt.id))).get();
          final totalPaid = payments.fold<double>(0.0, (sum, p) => sum + p.amountPaid);
          final newRemaining = (newTotalAmount - totalPaid).clamp(0.0, double.infinity);
          final newStatus = newRemaining <= 0 ? 'paid' : (totalPaid > 0 ? 'partial' : 'open');

          await (_db.update(_db.debts)..where((t) => t.id.equals(debt.id)))
              .write(DebtsCompanion(
                customerId: Value(customerId),
                amount: Value(newTotalAmount),
                remainingAmount: Value(newRemaining),
                status: Value(newStatus),
                syncedAt: const Value(null),
              ));
        } else {
          final debtId = _uuid.v4();
          final debt = Debt(
            id: debtId,
            customerId: customerId,
            invoiceId: invoiceId,
            amount: newTotalAmount,
            remainingAmount: newTotalAmount,
            status: 'open',
            createdAt: now,
          );
          await _db.into(_db.debts).insert(debt);
        }
      } else {
        // Cash payment: remove existing debts if no payments exist
        if (existingDebts.isNotEmpty) {
          for (final debt in existingDebts) {
            final payments = await (_db.select(_db.debtPayments)..where((t) => t.debtId.equals(debt.id))).get();
            if (payments.isNotEmpty) {
              throw Exception('invoices.delete_invoice_debt_has_payments_warning'.tr());
            }
            await (_db.delete(_db.debts)..where((t) => t.id.equals(debt.id))).go();
            await _db.into(_db.deletedRecords).insert(
                  DeletedRecordsCompanion.insert(
                    id: _uuid.v4(),
                    targetTable: 'debts',
                    recordId: debt.id,
                    createdAt: now,
                  ),
                );
          }
        }
      }

      // 5. Update invoice record
      await (_db.update(_db.invoices)..where((t) => t.id.equals(invoiceId)))
          .write(InvoicesCompanion(
            customerId: Value(customerId),
            totalAmount: Value(newTotalAmount),
            discount: Value(discount),
            paymentType: Value(paymentType),
            syncedAt: const Value(null),
          ));
    });

    _sync.updatePendingCount();
    _sync.sync();
    _logger.info('Invoice $invoiceId updated successfully', context: LogContext.pos);
  }
}
