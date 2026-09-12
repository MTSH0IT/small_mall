import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_searchable_dropdown.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/cubit/suppliers_purchasing_cubit.dart';

class NewPurchaseInvoiceDialog extends StatefulWidget {
  const NewPurchaseInvoiceDialog({
    super.key,
    required this.supplier,
    required this.availableProducts,
    required this.cubit,
    required this.onInvoiceCreated,
  });

  final Supplier supplier;
  final List<ProductWithDetails> availableProducts;
  final SuppliersPurchasingCubit cubit;
  final VoidCallback onInvoiceCreated;

  static Future<bool?> show({
    required BuildContext context,
    required Supplier supplier,
    required List<ProductWithDetails> availableProducts,
    required SuppliersPurchasingCubit cubit,
    required VoidCallback onInvoiceCreated,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NewPurchaseInvoiceDialog(
        supplier: supplier,
        availableProducts: availableProducts,
        cubit: cubit,
        onInvoiceCreated: onInvoiceCreated,
      ),
    );
  }

  @override
  State<NewPurchaseInvoiceDialog> createState() => _NewPurchaseInvoiceDialogState();
}

class _NewPurchaseInvoiceDialogState extends State<NewPurchaseInvoiceDialog> {
  final List<Map<String, dynamic>> _draftItems = [];
  bool _isSaving = false;

  double get _draftTotalAmount {
    return _draftItems.fold<double>(0.0, (sum, item) {
      final qty = (item['quantity'] as num).toDouble();
      final cost = (item['unitCost'] as num).toDouble();
      return sum + (qty * cost);
    });
  }

  double get _draftTotalPieces {
    return _draftItems.fold<double>(0.0, (sum, item) {
      return sum + (item['quantity'] as num).toDouble();
    });
  }

  void _addDraftItem(ProductWithDetails productDetails) {
    final existing = _draftItems.any((item) => item['productId'] == productDetails.product.id);
    if (existing) {
      AppToast.warning(context, message: 'suppliers.product_already_added'.tr());
      return;
    }

    setState(() {
      _draftItems.add({
        'productId': productDetails.product.id,
        'productName': productDetails.product.name,
        'productCode': productDetails.product.code,
        'currentStock': productDetails.currentStock,
        'quantity': 1.0,
        'unitCost': productDetails.product.costPrice,
      });
    });
  }

  Future<void> _handleSavePurchase() async {
    if (_draftItems.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await widget.cubit.recordPurchase(
        supplierId: widget.supplier.id,
        totalAmount: _draftTotalAmount,
        items: _draftItems,
      );

      if (mounted) {
        AppToast.success(context, message: 'suppliers.purchase_recorded'.tr());
        widget.onInvoiceCreated();
        Navigator.of(context).pop(true);
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 950,
          maxHeight: 750,
        ),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'suppliers.new_purchase_invoice'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.supplier.name,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'common.close'.tr(),
                    ),
                  ],
                ),
              ),

              // 2. Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Product selector dropdown
                      AppSearchableDropdown<ProductWithDetails>(
                        key: ValueKey('new_purchase_${widget.supplier.id}_${_draftItems.length}'),
                        hint: 'suppliers.select_product_to_add'.tr(),
                        prefixIcon: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        itemSearchText: (p) => '${p.product.name} ${p.product.code ?? ''}',
                        items: widget.availableProducts.map((p) {
                          return DropdownMenuItem<ProductWithDetails>(
                            value: p,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.product.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    '${'inventory.current_stock'.tr()}: ${p.currentStock.toStringAsFixed(0)}',
                                    style: AppTheme.numericStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (p) {
                          if (p != null) {
                            _addDraftItem(p);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Items List or Empty State
                      Expanded(
                        child: _draftItems.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: EmptyStateView(
                                    icon: Icons.add_shopping_cart_outlined,
                                    title: 'suppliers.no_products_added'.tr(),
                                    description: 'suppliers.select_product_to_add'.tr(),
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _draftItems.length,
                                  separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 16),
                                  itemBuilder: (context, index) {
                                    final item = _draftItems[index];
                                    return _DraftItemRow(
                                      key: ValueKey(item['productId']),
                                      item: item,
                                      onChanged: () => setState(() {}),
                                      onRemove: () {
                                        setState(() {
                                          _draftItems.removeAt(index);
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Footer Summary & Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${'suppliers.items_count'.tr()}: ',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        Text(
                          '${_draftItems.length}',
                          style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${'suppliers.total_pieces'.tr()}: ',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        Text(
                          _draftTotalPieces.toStringAsFixed(0),
                          style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 24),
                        Text(
                          '${'suppliers.total_amount'.tr()}: ',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          '${_draftTotalAmount.toStringAsFixed(2)} ${'common.currency'.tr()}',
                          style: AppTheme.numericStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('common.cancel'.tr()),
                        ),
                        const SizedBox(width: 12),
                        PrimaryButton(
                          label: 'suppliers.confirm_save_purchase'.tr(),
                          icon: Icons.check_circle_outline_rounded,
                          isLoading: _isSaving,
                          onPressed: _draftItems.isEmpty || _isSaving ? null : _handleSavePurchase,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftItemRow extends StatefulWidget {
  const _DraftItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final Map<String, dynamic> item;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_DraftItemRow> createState() => _DraftItemRowState();
}

class _DraftItemRowState extends State<_DraftItemRow> {
  late final TextEditingController _qtyController;
  late final TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    final qty = (widget.item['quantity'] as num).toDouble();
    final cost = (widget.item['unitCost'] as num).toDouble();
    _qtyController = TextEditingController(text: qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString());
    _costController = TextEditingController(text: cost.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qty = (widget.item['quantity'] as num).toDouble();
    final cost = (widget.item['unitCost'] as num).toDouble();
    final subtotal = qty * cost;
    final currentStock = (widget.item['currentStock'] as num?)?.toDouble() ?? 0.0;
    final code = widget.item['productCode'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.item['productName'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (code != null && code.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        code,
                        style: AppTheme.numericStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${'inventory.current_stock'.tr()}: ${currentStock.toStringAsFixed(0)}',
                        style: AppTheme.numericStyle(fontSize: 11, color: const Color(0xFF0284C7)),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.danger, size: 18),
                tooltip: 'common.delete'.tr(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Quantity
              Expanded(
                flex: 3,
                child: AppTextField(
                  label: 'common.quantity'.tr(),
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final numVal = double.tryParse(val);
                    if (numVal != null && numVal > 0) {
                      widget.item['quantity'] = numVal;
                      widget.onChanged();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Unit Cost
              Expanded(
                flex: 3,
                child: AppTextField(
                  label: 'suppliers.unit_cost'.tr(),
                  controller: _costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    final numVal = double.tryParse(val);
                    if (numVal != null && numVal >= 0) {
                      widget.item['unitCost'] = numVal;
                      widget.onChanged();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Subtotal
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'suppliers.item_subtotal'.tr(),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${subtotal.toStringAsFixed(2)} ${'common.currency'.tr()}',
                      style: AppTheme.numericStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
