import 'package:drift/drift.dart' show OrderingTerm;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/di/injection.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_searchable_dropdown.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_cubit.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';

class EditInvoiceDialog extends StatefulWidget {
  const EditInvoiceDialog({
    super.key,
    required this.invoiceData,
    required this.cubit,
  });

  final InvoiceWithDetails invoiceData;
  final InvoicesCubit cubit;

  static Future<void> show(BuildContext context, InvoiceWithDetails invoiceData, InvoicesCubit cubit) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditInvoiceDialog(
        invoiceData: invoiceData,
        cubit: cubit,
      ),
    );
  }

  @override
  State<EditInvoiceDialog> createState() => _EditInvoiceDialogState();
}

class _EditableItem {
  _EditableItem({
    required this.productId,
    required this.productName,
    required this.priceUsed,
    required this.quantity,
    required this.discount,
  });

  final String productId;
  final String productName;
  double priceUsed;
  double quantity;
  double discount;

  double get total => (priceUsed * quantity) - discount;
}

class _EditInvoiceDialogState extends State<EditInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _discountController = TextEditingController();

  String? _selectedCustomerId;
  String _selectedPaymentType = 'cash';
  List<Customer> _customers = [];
  bool _isLoadingCustomers = true;
  bool _isSaving = false;

  late List<_EditableItem> _items;

  @override
  void initState() {
    super.initState();
    final inv = widget.invoiceData.invoice;
    _selectedCustomerId = inv.customerId;
    _selectedPaymentType = inv.paymentType;
    _discountController.text = inv.discount > 0 ? inv.discount.toStringAsFixed(2) : '0';

    _items = widget.invoiceData.items.map((it) {
      return _EditableItem(
        productId: it.invoiceItem.productId,
        productName: it.productName,
        priceUsed: it.invoiceItem.priceUsed,
        quantity: it.invoiceItem.quantity,
        discount: it.invoiceItem.discount,
      );
    }).toList();

    _loadCustomers();
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final db = getIt<AppDatabase>();
      final customers = await (db.select(db.customers)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
      if (mounted) {
        setState(() {
          _customers = customers;
          _isLoadingCustomers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCustomers = false);
      }
    }
  }

  double get _subtotal => _items.fold<double>(0.0, (sum, it) => sum + it.total);

  double get _discount {
    final parsed = double.tryParse(_discountController.text.trim()) ?? 0.0;
    return parsed.clamp(0.0, _subtotal);
  }

  double get _netTotal => (_subtotal - _discount).clamp(0.0, double.infinity);

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      AppToast.error(context, message: 'pos.empty_cart'.tr());
      return;
    }

    if (_selectedPaymentType == 'debt' && _selectedCustomerId == null) {
      AppToast.error(context, message: 'pos.debt_warning_no_customer'.tr());
      return;
    }

    setState(() => _isSaving = true);

    try {
      final itemsPayload = _items.map((it) => {
        'productId': it.productId,
        'priceUsed': it.priceUsed,
        'quantity': it.quantity,
        'discount': it.discount,
      }).toList();

      await widget.cubit.updateInvoice(
        invoiceId: widget.invoiceData.invoice.id,
        customerId: _selectedCustomerId,
        paymentType: _selectedPaymentType,
        discount: _discount,
        items: itemsPayload,
      );

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, message: 'invoices.invoice_updated_success'.tr());
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
    final theme = Theme.of(context);
    final inv = widget.invoiceData.invoice;
    final displayId = inv.serialNumber != null ? '${inv.serialNumber}' : inv.id.substring(0, 8);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surfaceElevated,
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Title & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.edit_note_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'invoices.edit_dialog_title'.tr(namedArgs: {'id': displayId}),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Customer & Payment Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Dropdown
                          Expanded(
                            flex: 3,
                            child: _isLoadingCustomers
                                ? const Center(child: LinearProgressIndicator())
                                : AppSearchableDropdown<String?>(
                                    label: 'invoices.customer'.tr(),
                                    value: _selectedCustomerId,
                                    prefixIcon: const Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
                                    itemSearchText: (id) {
                                      if (id == null) return 'pos.walk_in_customer'.tr();
                                      final c = _customers.where((x) => x.id == id).firstOrNull;
                                      return c?.name ?? '';
                                    },
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('pos.walk_in_customer'.tr()),
                                      ),
                                      ..._customers.map((c) => DropdownMenuItem<String?>(
                                            value: c.id,
                                            child: Text(c.name),
                                          )),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedCustomerId = val;
                                        if (val == null && _selectedPaymentType == 'debt') {
                                          _selectedPaymentType = 'cash';
                                        }
                                      });
                                    },
                                  ),
                          ),
                          const SizedBox(width: 12),
                          // Payment Method
                          Expanded(
                            flex: 2,
                            child: AppSearchableDropdown<String>(
                              label: 'invoices.payment_method'.tr(),
                              value: _selectedPaymentType,
                              isSearchable: false,
                              prefixIcon: const Icon(Icons.payment_outlined, size: 18, color: AppColors.textSecondary),
                              items: [
                                DropdownMenuItem(value: 'cash', child: Text('pos.cash'.tr())),
                                DropdownMenuItem(value: 'debt', child: Text('pos.debt'.tr())),
                              ],
                              onChanged: (val) {
                                if (val == null) return;
                                if (val == 'debt' && _selectedCustomerId == null) {
                                  AppToast.warning(context, message: 'pos.select_customer_first'.tr());
                                  return;
                                }
                                setState(() => _selectedPaymentType = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // 2. Items List
                      Text('invoices.edit_items_title'.tr(), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.priceUsed.toStringAsFixed(2)} × ${item.quantity.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Quantity Controls
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                                        color: item.quantity > 1 ? AppColors.primary : AppColors.textSecondary,
                                        onPressed: item.quantity > 1
                                            ? () {
                                                setState(() => item.quantity -= 1);
                                              }
                                            : null,
                                        splashRadius: 16,
                                      ),
                                      Container(
                                        constraints: const BoxConstraints(minWidth: 32),
                                        alignment: Alignment.center,
                                        child: Text(
                                          item.quantity.toStringAsFixed(0),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, size: 20),
                                        color: AppColors.primary,
                                        onPressed: () {
                                          setState(() => item.quantity += 1);
                                        },
                                        splashRadius: 16,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  // Line Total
                                  SizedBox(
                                    width: 75,
                                    child: Text(
                                      item.total.toStringAsFixed(2),
                                      textAlign: TextAlign.end,
                                      style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  // Delete Item (if more than 1 item)
                                  if (_items.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                                      onPressed: () {
                                        setState(() => _items.removeAt(index));
                                      },
                                      splashRadius: 16,
                                    )
                                  else
                                    const SizedBox(width: 40),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Discount Field & Summary
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _discountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              ],
                              decoration: InputDecoration(
                                labelText: 'pos.invoice_discount'.tr(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                prefixIcon: const Icon(Icons.discount_outlined, size: 18),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Summary Box
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('pos.subtotal'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      Text(_subtotal.toStringAsFixed(2), style: AppTheme.numericStyle(fontSize: 12)),
                                    ],
                                  ),
                                  if (_discount > 0) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('pos.discount_amount'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                                        Text('-${_discount.toStringAsFixed(2)}', style: AppTheme.numericStyle(fontSize: 12, color: AppColors.danger)),
                                      ],
                                    ),
                                  ],
                                  const Divider(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('common.total'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text(
                                        _netTotal.toStringAsFixed(2),
                                        style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Actions Row
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
                      backgroundColor: AppColors.primary,
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
}
