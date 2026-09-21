import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_searchable_dropdown.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_cubit.dart';

class _EditablePurchaseItem {
  _EditablePurchaseItem({
    this.id,
    required this.productId,
    required this.productName,
    required this.unitCost,
    required this.quantity,
    required this.currency,
  });

  final String? id;
  final String productId;
  final String productName;
  double unitCost;
  double quantity;
  String currency;

  String get currencySymbol => AppCurrency.getSymbol(currency);
  double get total => unitCost * quantity;
}

class EditPurchaseInvoiceDialog extends StatefulWidget {
  const EditPurchaseInvoiceDialog({
    super.key,
    required this.transaction,
    required this.cubit,
  });

  final UnifiedTransactionRecord transaction;
  final InvoicesCubit cubit;

  static Future<void> show(
    BuildContext context,
    UnifiedTransactionRecord transaction,
    InvoicesCubit cubit,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditPurchaseInvoiceDialog(
        transaction: transaction,
        cubit: cubit,
      ),
    );
  }

  @override
  State<EditPurchaseInvoiceDialog> createState() => _EditPurchaseInvoiceDialogState();
}

class _EditPurchaseInvoiceDialogState extends State<EditPurchaseInvoiceDialog> {
  String? _selectedSupplierId;
  List<Supplier> _suppliers = [];
  bool _isLoading = true;
  bool _isSaving = false;
  List<_EditablePurchaseItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = getIt<AppDatabase>();
      final suppliers = await widget.cubit.getSuppliers();
      final purchaseItems = await widget.cubit.getPurchaseItems(widget.transaction.id);

      final productIds = purchaseItems.map((i) => i.productId).toSet();
      final products = await (db.select(db.products)..where((t) => t.id.isIn(productIds))).get();
      final productMap = {for (final p in products) p.id: p.name};

      final items = purchaseItems.map((pi) {
        return _EditablePurchaseItem(
          id: pi.id,
          productId: pi.productId,
          productName: productMap[pi.productId] ?? 'common.deleted_product'.tr(),
          unitCost: pi.unitCost,
          quantity: pi.quantity,
          currency: pi.currency,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _suppliers = suppliers;
          _selectedSupplierId = widget.transaction.rawPurchaseInvoice?.supplierId;
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.error(context, message: e.toString());
      }
    }
  }

  double get _subtotalUsd => _items
      .where((it) => it.currency == AppCurrency.usdCode)
      .fold<double>(0.0, (sum, it) => sum + it.total);

  double get _subtotalSyp => _items
      .where((it) => it.currency != AppCurrency.usdCode)
      .fold<double>(0.0, (sum, it) => sum + it.total);

  bool get _hasMultipleCurrencies => _subtotalUsd > 0 && _subtotalSyp > 0;

  Future<void> _showEditItemPriceDialog(_EditablePurchaseItem item) async {
    final qty = item.quantity;
    final unitCostController = TextEditingController(text: item.unitCost.toStringAsFixed(2));
    final lineTotalController = TextEditingController(text: item.total.toStringAsFixed(2));
    bool isUpdating = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تعديل سعر التكلفة للقطعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(item.productName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: unitCostController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'سعر التكلفة (${item.currencySymbol})',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    if (isUpdating) return;
                    isUpdating = true;
                    final unitCost = double.tryParse(val) ?? 0.0;
                    lineTotalController.text = (unitCost * qty).toStringAsFixed(2);
                    isUpdating = false;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lineTotalController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'الإجمالي للبند (${item.currencySymbol})',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    if (isUpdating) return;
                    isUpdating = true;
                    final total = double.tryParse(val) ?? 0.0;
                    if (qty > 0) {
                      unitCostController.text = (total / qty).toStringAsFixed(2);
                    }
                    isUpdating = false;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                final newCost = double.tryParse(unitCostController.text);
                if (newCost != null && newCost >= 0) {
                  setState(() {
                    item.unitCost = newCost;
                  });
                }
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: Text('common.save'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSave() async {
    if (_items.isEmpty) {
      AppToast.warning(context, message: 'invoices.items_cannot_be_empty'.tr());
      return;
    }
    if (_selectedSupplierId == null) {
      AppToast.warning(context, message: 'الرجاء اختيار المورد');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final itemsPayload = _items.map((it) => {
        'id': it.id,
        'productId': it.productId,
        'quantity': it.quantity,
        'unitCost': it.unitCost,
        'currency': it.currency,
      }).toList();

      await widget.cubit.updatePurchaseInvoice(
        purchaseInvoiceId: widget.transaction.id,
        supplierId: _selectedSupplierId!,
        items: itemsPayload,
      );

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, message: 'تم تحديث فاتورة الشراء بنجاح');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.error(context, message: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.transaction;
    final displayId = tr.globalSerialNumber != null
        ? '#${tr.globalSerialNumber}'
        : (tr.serialNumber != null ? '#${tr.serialNumber}' : '#${tr.id.substring(0, 8)}');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surfaceElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit_note, color: Color(0xFF2563EB), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'تعديل بيانات فاتورة الشراء $displayId',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        IconButton(
                          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Supplier selection
                    AppSearchableDropdown<String>(
                      items: _suppliers
                          .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.phone != null && s.phone!.isNotEmpty ? '${s.name} (${s.phone})' : s.name),
                              ))
                          .toList(),
                      label: 'المورد',
                      hint: 'اختر المورد',
                      prefixIcon: const Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.textSecondary),
                      value: _selectedSupplierId,
                      onChanged: (id) => setState(() => _selectedSupplierId = id),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'أصناف فاتورة الشراء',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),

                    // Items list
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _items.isEmpty
                            ? Center(
                                child: Text('invoices.no_items'.tr(), style: const TextStyle(color: AppColors.textSecondary)),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(8),
                                itemCount: _items.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final it = _items[index];
                                  return _buildItemRow(it, index);
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Totals summary card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_hasMultipleCurrencies) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('المجموع بالليرة السورية:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text(
                                  '${_subtotalSyp.toStringAsFixed(2)} ${AppCurrency.sypSymbol}',
                                  style: AppTheme.numericStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('المجموع بالدولار:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text(
                                  '${_subtotalUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}',
                                  style: AppTheme.numericStyle(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('المجموع الإجمالي:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                Text(
                                  _subtotalUsd > 0
                                      ? '${_subtotalUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}'
                                      : '${_subtotalSyp.toStringAsFixed(2)} ${AppCurrency.sypSymbol}',
                                  style: AppTheme.numericStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _subtotalUsd > 0 ? const Color(0xFF059669) : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                          child: Text('common.cancel'.tr()),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text('common.save'.tr()),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildItemRow(_EditablePurchaseItem item, int index) {
    final isUsd = item.currency == AppCurrency.usdCode;
    final currColor = isUsd ? const Color(0xFF059669) : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => _items.removeAt(index)),
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
            tooltip: 'common.delete'.tr(),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.productName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: currColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: currColor.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        item.currencySymbol,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: currColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () => _showEditItemPriceDialog(item),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)} × ${item.unitCost.toStringAsFixed(2)} ${item.currencySymbol}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_outlined, size: 13, color: currColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  if (item.quantity > 1) {
                    setState(() => item.quantity -= 1);
                  } else {
                    setState(() => _items.removeAt(index));
                  }
                },
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(
                width: 38,
                child: Text(
                  item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => item.quantity += 1),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _showEditItemPriceDialog(item),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: currColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: currColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.total.toStringAsFixed(2),
                    style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 13, color: currColor),
                  ),
                  const SizedBox(width: 2),
                  Text(item.currencySymbol, style: TextStyle(fontSize: 10, color: currColor)),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_outlined, size: 12, color: currColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
