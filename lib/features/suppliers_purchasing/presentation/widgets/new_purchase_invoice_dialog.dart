import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
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

    final initialRetailPriceSyp = productDetails.retailPriceSyp ?? 0.0;
    final initialWholesalePriceSyp = productDetails.wholesalePriceSyp ?? 0.0;
    final initialRetailPriceUsd = productDetails.retailPriceUsd ?? 0.0;
    final initialWholesalePriceUsd = productDetails.wholesalePriceUsd ?? 0.0;
    final initialCostSyp = productDetails.costPriceSyp;
    final initialCostUsd = productDetails.costPriceUsd;

    setState(() {
      _draftItems.add({
        'productId': productDetails.product.id,
        'productName': productDetails.product.name,
        'productCode': productDetails.product.code,
        'currency': productDetails.currency,
        'currencySymbol': productDetails.currencySymbol,
        'currentStock': productDetails.currentStock,
        'quantity': 1.0,
        'unitCost': initialCostSyp,
        'unitCostSyp': initialCostSyp,
        'unitCostUsd': initialCostUsd,
        'retailPriceSyp': initialRetailPriceSyp,
        'wholesalePriceSyp': initialWholesalePriceSyp,
        'retailPriceUsd': initialRetailPriceUsd,
        'wholesalePriceUsd': initialWholesalePriceUsd,
        'retailPrice': initialRetailPriceSyp > 0 ? initialRetailPriceSyp : initialRetailPriceUsd,
        'wholesalePrice': initialWholesalePriceSyp > 0 ? initialWholesalePriceSyp : initialWholesalePriceUsd,
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
          maxWidth: 980,
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
  late final TextEditingController _costUsdController;
  late final TextEditingController _retailSypController;
  late final TextEditingController _wholesaleSypController;
  late final TextEditingController _retailUsdController;
  late final TextEditingController _wholesaleUsdController;

  @override
  void initState() {
    super.initState();
    final qty = (widget.item['quantity'] as num).toDouble();
    final cost = (widget.item['unitCost'] as num).toDouble();
    final costUsd = (widget.item['unitCostUsd'] as num?)?.toDouble() ?? 0.0;
    final retailSyp = (widget.item['retailPriceSyp'] as num?)?.toDouble() ?? 0.0;
    final wholesaleSyp = (widget.item['wholesalePriceSyp'] as num?)?.toDouble() ?? 0.0;
    final retailUsd = (widget.item['retailPriceUsd'] as num?)?.toDouble() ?? 0.0;
    final wholesaleUsd = (widget.item['wholesalePriceUsd'] as num?)?.toDouble() ?? 0.0;

    _qtyController = TextEditingController(text: qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString());
    _costController = TextEditingController(text: cost.toStringAsFixed(2));
    _costUsdController = TextEditingController(text: costUsd > 0 ? costUsd.toStringAsFixed(costUsd % 1 == 0 ? 0 : 2) : '');
    _retailSypController = TextEditingController(text: retailSyp > 0 ? retailSyp.toStringAsFixed(retailSyp % 1 == 0 ? 0 : 1) : '');
    _wholesaleSypController = TextEditingController(text: wholesaleSyp > 0 ? wholesaleSyp.toStringAsFixed(wholesaleSyp % 1 == 0 ? 0 : 1) : '');
    _retailUsdController = TextEditingController(text: retailUsd > 0 ? retailUsd.toStringAsFixed(retailUsd % 1 == 0 ? 0 : 2) : '');
    _wholesaleUsdController = TextEditingController(text: wholesaleUsd > 0 ? wholesaleUsd.toStringAsFixed(wholesaleUsd % 1 == 0 ? 0 : 2) : '');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    _costUsdController.dispose();
    _retailSypController.dispose();
    _wholesaleSypController.dispose();
    _retailUsdController.dispose();
    _wholesaleUsdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qty = (widget.item['quantity'] as num).toDouble();
    final cost = (widget.item['unitCost'] as num).toDouble();
    final subtotal = qty * cost;
    final currentStock = (widget.item['currentStock'] as num?)?.toDouble() ?? 0.0;
    final code = widget.item['productCode'] as String?;
    final currencySymbol = (widget.item['currencySymbol'] as String?) ?? AppCurrency.primarySymbol;
    final currencyCode = (widget.item['currency'] as String?) ?? AppCurrency.primaryCode;

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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: currencyCode == AppCurrency.secondaryCode
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: currencyCode == AppCurrency.secondaryCode
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : AppColors.primary.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        currencySymbol,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: currencyCode == AppCurrency.secondaryCode
                              ? const Color(0xFF059669)
                              : AppColors.primary,
                        ),
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
                flex: 2,
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
              const SizedBox(width: 8),
              // Unit Cost SYP (سعر الشراء ل.س)
              Expanded(
                flex: 3,
                child: AppTextField(
                  label: 'suppliers.unit_cost_syp'.tr(),
                  controller: _costController,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(
                      AppCurrency.baseSymbol,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    final numVal = double.tryParse(val);
                    if (numVal != null && numVal >= 0) {
                      widget.item['unitCost'] = numVal;
                      widget.item['unitCostSyp'] = numVal;
                      widget.onChanged();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Unit Cost USD (سعر الشراء $)
              Expanded(
                flex: 3,
                child: AppTextField(
                  label: 'suppliers.unit_cost_usd'.tr(),
                  hint: '0.00',
                  controller: _costUsdController,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(
                      AppCurrency.secondarySymbol,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    widget.item['unitCostUsd'] = double.tryParse(val) ?? 0.0;
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Subtotal
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'suppliers.item_subtotal'.tr(),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        '${subtotal.toStringAsFixed(2)} ${AppCurrency.baseSymbol}',
                        style: AppTheme.numericStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Selling Prices Row (SYP & USD)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                // Retail SYP
                Expanded(
                  child: AppTextField(
                    label: 'inventory.retail_price_syp'.tr(),
                    hint: '0',
                    controller: _retailSypController,
                    suffixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                      child: Text(
                        AppCurrency.baseSymbol,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) {
                      widget.item['retailPriceSyp'] = double.tryParse(val);
                      widget.item['retailPrice'] = double.tryParse(val) ?? 0.0;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Wholesale SYP
                Expanded(
                  child: AppTextField(
                    label: 'inventory.wholesale_price_syp'.tr(),
                    hint: '0',
                    controller: _wholesaleSypController,
                    suffixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                      child: Text(
                        AppCurrency.baseSymbol,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) {
                      widget.item['wholesalePriceSyp'] = double.tryParse(val);
                      widget.item['wholesalePrice'] = double.tryParse(val) ?? 0.0;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Retail USD
                Expanded(
                  child: AppTextField(
                    label: 'inventory.retail_price_usd'.tr(),
                    hint: '0.00',
                    controller: _retailUsdController,
                    suffixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                      child: Text(
                        AppCurrency.secondarySymbol,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) {
                      widget.item['retailPriceUsd'] = double.tryParse(val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Wholesale USD
                Expanded(
                  child: AppTextField(
                    label: 'inventory.wholesale_price_usd'.tr(),
                    hint: '0.00',
                    controller: _wholesaleUsdController,
                    suffixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                      child: Text(
                        AppCurrency.secondarySymbol,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) {
                      widget.item['wholesalePriceUsd'] = double.tryParse(val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
