import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/services/app_settings_service.dart';
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
  String _invoiceCurrency = AppCurrency.sypCode;

  final double _exchangeRate = AppSettingsService.usdExchangeRate;
  late bool _autoConvert = _exchangeRate > 0;

  double get _draftTotalAmount {
    return _draftItems.fold<double>(0.0, (sum, item) {
      final qty = (item['quantity'] as num).toDouble();
      final isUsd = _invoiceCurrency == AppCurrency.usdCode;
      final cost = isUsd
          ? ((item['unitCostUsd'] as num?)?.toDouble() ?? 0.0)
          : ((item['unitCostSyp'] as num?)?.toDouble() ?? (item['unitCost'] as num).toDouble());
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

    double initialRetailPriceSyp = productDetails.retailPriceSyp ?? 0.0;
    double initialWholesalePriceSyp = productDetails.wholesalePriceSyp ?? 0.0;
    double initialRetailPriceUsd = productDetails.retailPriceUsd ?? 0.0;
    double initialWholesalePriceUsd = productDetails.wholesalePriceUsd ?? 0.0;
    double initialCostSyp = productDetails.costPriceSyp;
    double initialCostUsd = productDetails.costPriceUsd;

    // Automatic calculation of missing currencies if exchange rate is configured
    if (_exchangeRate > 0) {
      if (initialCostSyp > 0 && initialCostUsd <= 0) {
        initialCostUsd = initialCostSyp / _exchangeRate;
      } else if (initialCostUsd > 0 && initialCostSyp <= 0) {
        initialCostSyp = initialCostUsd * _exchangeRate;
      }

      if (initialRetailPriceSyp > 0 && initialRetailPriceUsd <= 0) {
        initialRetailPriceUsd = initialRetailPriceSyp / _exchangeRate;
      } else if (initialRetailPriceUsd > 0 && initialRetailPriceSyp <= 0) {
        initialRetailPriceSyp = initialRetailPriceUsd * _exchangeRate;
      }

      if (initialWholesalePriceSyp > 0 && initialWholesalePriceUsd <= 0) {
        initialWholesalePriceUsd = initialWholesalePriceSyp / _exchangeRate;
      } else if (initialWholesalePriceUsd > 0 && initialWholesalePriceSyp <= 0) {
        initialWholesalePriceSyp = initialWholesalePriceUsd * _exchangeRate;
      }
    }

    final effectiveCost = _invoiceCurrency == AppCurrency.usdCode ? initialCostUsd : initialCostSyp;

    setState(() {
      _draftItems.add({
        'productId': productDetails.product.id,
        'productName': productDetails.product.name,
        'productCode': productDetails.product.code,
        'currency': _invoiceCurrency,
        'currencySymbol': AppCurrency.getSymbol(_invoiceCurrency),
        'currentStock': productDetails.currentStock,
        'quantity': 1.0,
        'unitCost': effectiveCost,
        'unitCostSyp': initialCostSyp,
        'unitCostUsd': initialCostUsd,
        'retailPriceSyp': initialRetailPriceSyp,
        'wholesalePriceSyp': initialWholesalePriceSyp,
        'retailPriceUsd': initialRetailPriceUsd,
        'wholesalePriceUsd': initialWholesalePriceUsd,
        'retailPrice': _invoiceCurrency == AppCurrency.usdCode ? initialRetailPriceUsd : initialRetailPriceSyp,
        'wholesalePrice': _invoiceCurrency == AppCurrency.usdCode ? initialWholesalePriceUsd : initialWholesalePriceSyp,
      });
    });
  }

  void _onCurrencyChanged(String newCurrency) {
    if (_invoiceCurrency == newCurrency) return;
    setState(() {
      _invoiceCurrency = newCurrency;
      for (final item in _draftItems) {
        item['currency'] = newCurrency;
        item['currencySymbol'] = AppCurrency.getSymbol(newCurrency);
        final costSyp = (item['unitCostSyp'] as num?)?.toDouble() ?? 0.0;
        final costUsd = (item['unitCostUsd'] as num?)?.toDouble() ?? 0.0;
        item['unitCost'] = newCurrency == AppCurrency.usdCode ? costUsd : costSyp;
        final retailSyp = (item['retailPriceSyp'] as num?)?.toDouble() ?? 0.0;
        final retailUsd = (item['retailPriceUsd'] as num?)?.toDouble() ?? 0.0;
        item['retailPrice'] = newCurrency == AppCurrency.usdCode ? retailUsd : retailSyp;
        final wholesaleSyp = (item['wholesalePriceSyp'] as num?)?.toDouble() ?? 0.0;
        final wholesaleUsd = (item['wholesalePriceUsd'] as num?)?.toDouble() ?? 0.0;
        item['wholesalePrice'] = newCurrency == AppCurrency.usdCode ? wholesaleUsd : wholesaleSyp;
      }
    });
  }

  Future<void> _handleSavePurchase() async {
    if (_draftItems.isEmpty) return;

    // Ensure active unitCost is aligned with the invoice currency for all items
    for (final item in _draftItems) {
      item['currency'] = _invoiceCurrency;
      final costSyp = (item['unitCostSyp'] as num?)?.toDouble() ?? 0.0;
      final costUsd = (item['unitCostUsd'] as num?)?.toDouble() ?? 0.0;
      item['unitCost'] = _invoiceCurrency == AppCurrency.usdCode ? costUsd : costSyp;
    }

    setState(() => _isSaving = true);
    try {
      await widget.cubit.recordPurchase(
        supplierId: widget.supplier.id,
        totalAmount: _draftTotalAmount,
        currency: _invoiceCurrency,
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
          maxWidth: 1040,
          maxHeight: 780,
        ),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header with Supplier Info & Invoice Currency Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
                          Row(
                            children: [
                              Text(
                                'suppliers.new_purchase_invoice'.tr(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.supplier.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'common.currency_select'.tr(),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    // Currency Selector Segment
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCurrencyButton(
                            label: 'common.currency_primary'.tr(),
                            code: AppCurrency.sypCode,
                            isSelected: _invoiceCurrency == AppCurrency.sypCode,
                            activeColor: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          _buildCurrencyButton(
                            label: 'common.currency_secondary'.tr(),
                            code: AppCurrency.usdCode,
                            isSelected: _invoiceCurrency == AppCurrency.usdCode,
                            activeColor: const Color(0xFF059669),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
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
                      const SizedBox(height: 12),

                      // Exchange Rate Status Banner & Toggle (Matches Products Screen)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _exchangeRate > 0
                              ? (_autoConvert
                                  ? const Color(0xFF10B981).withValues(alpha: 0.08)
                                  : Colors.amber.withValues(alpha: 0.08))
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _exchangeRate > 0
                                ? (_autoConvert
                                    ? const Color(0xFF10B981).withValues(alpha: 0.35)
                                    : Colors.amber.withValues(alpha: 0.35))
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _exchangeRate > 0
                                  ? (_autoConvert ? Icons.sync_alt_rounded : Icons.sync_disabled_rounded)
                                  : Icons.info_outline_rounded,
                              size: 18,
                              color: _exchangeRate > 0
                                  ? (_autoConvert ? const Color(0xFF059669) : Colors.amber.shade800)
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _exchangeRate > 0
                                        ? (_autoConvert
                                            ? 'inventory.auto_conversion_active'.tr(namedArgs: {
                                                'rate': (_exchangeRate % 1 == 0
                                                    ? _exchangeRate.toInt().toString()
                                                    : _exchangeRate.toString()),
                                              })
                                            : 'inventory.auto_conversion_paused'.tr())
                                        : 'inventory.no_exchange_rate_set'.tr(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _exchangeRate > 0
                                          ? (_autoConvert ? const Color(0xFF059669) : Colors.amber.shade900)
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  if (_exchangeRate > 0)
                                    Text(
                                      _autoConvert
                                          ? 'inventory.auto_conversion_hint_on'.tr()
                                          : 'inventory.auto_conversion_hint_off'.tr(),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: _autoConvert
                                            ? const Color(0xFF059669).withValues(alpha: 0.8)
                                            : Colors.amber.shade800,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_exchangeRate > 0)
                              Transform.scale(
                                scale: 0.8,
                                child: Switch(
                                  value: _autoConvert,
                                  activeThumbColor: const Color(0xFF059669),
                                  activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                                  onChanged: (val) {
                                    setState(() => _autoConvert = val);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

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
                                      key: ValueKey('${item['productId']}_$_invoiceCurrency'),
                                      item: item,
                                      invoiceCurrency: _invoiceCurrency,
                                      exchangeRate: _exchangeRate,
                                      autoConvert: _autoConvert,
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _invoiceCurrency == AppCurrency.usdCode
                                  ? '${_draftTotalAmount.toStringAsFixed(2)} \$'
                                  : '${_draftTotalAmount.toStringAsFixed(2)} ل.س',
                              style: AppTheme.numericStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _invoiceCurrency == AppCurrency.usdCode
                                    ? const Color(0xFF059669)
                                    : AppColors.primary,
                              ),
                            ),
                            if (_exchangeRate > 0 && _draftTotalAmount > 0)
                              Text(
                                _invoiceCurrency == AppCurrency.usdCode
                                    ? '≈ ${(_draftTotalAmount * _exchangeRate).toStringAsFixed(0)} ل.س'
                                    : '≈ ${(_draftTotalAmount / _exchangeRate).toStringAsFixed(2)} \$',
                                style: AppTheme.numericStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
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

  Widget _buildCurrencyButton({
    required String label,
    required String code,
    required bool isSelected,
    required Color activeColor,
  }) {
    return InkWell(
      onTap: () => _onCurrencyChanged(code),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor.withValues(alpha: 0.5) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 14,
              color: isSelected ? activeColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftItemRow extends StatefulWidget {
  const _DraftItemRow({
    super.key,
    required this.item,
    required this.invoiceCurrency,
    required this.exchangeRate,
    required this.autoConvert,
    required this.onChanged,
    required this.onRemove,
  });

  final Map<String, dynamic> item;
  final String invoiceCurrency;
  final double exchangeRate;
  final bool autoConvert;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_DraftItemRow> createState() => _DraftItemRowState();
}

class _DraftItemRowState extends State<_DraftItemRow> {
  late final TextEditingController _qtyController;
  late final TextEditingController _costSypController;
  late final TextEditingController _costUsdController;
  late final TextEditingController _retailSypController;
  late final TextEditingController _wholesaleSypController;
  late final TextEditingController _retailUsdController;
  late final TextEditingController _wholesaleUsdController;

  @override
  void initState() {
    super.initState();
    final qty = (widget.item['quantity'] as num).toDouble();
    final costSyp = (widget.item['unitCostSyp'] as num?)?.toDouble() ?? 0.0;
    final costUsd = (widget.item['unitCostUsd'] as num?)?.toDouble() ?? 0.0;
    final retailSyp = (widget.item['retailPriceSyp'] as num?)?.toDouble() ?? 0.0;
    final wholesaleSyp = (widget.item['wholesalePriceSyp'] as num?)?.toDouble() ?? 0.0;
    final retailUsd = (widget.item['retailPriceUsd'] as num?)?.toDouble() ?? 0.0;
    final wholesaleUsd = (widget.item['wholesalePriceUsd'] as num?)?.toDouble() ?? 0.0;

    _qtyController = TextEditingController(text: qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString());
    _costSypController = TextEditingController(text: costSyp > 0 ? AppSettingsService.formatSyp(costSyp) : '');
    _costUsdController = TextEditingController(text: costUsd > 0 ? AppSettingsService.formatUsd(costUsd) : '');
    _retailSypController = TextEditingController(text: retailSyp > 0 ? AppSettingsService.formatSyp(retailSyp) : '');
    _wholesaleSypController = TextEditingController(text: wholesaleSyp > 0 ? AppSettingsService.formatSyp(wholesaleSyp) : '');
    _retailUsdController = TextEditingController(text: retailUsd > 0 ? AppSettingsService.formatUsd(retailUsd) : '');
    _wholesaleUsdController = TextEditingController(text: wholesaleUsd > 0 ? AppSettingsService.formatUsd(wholesaleUsd) : '');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costSypController.dispose();
    _costUsdController.dispose();
    _retailSypController.dispose();
    _wholesaleSypController.dispose();
    _retailUsdController.dispose();
    _wholesaleUsdController.dispose();
    super.dispose();
  }

  void _onCostSypChanged(String val) {
    final text = val.trim();
    if (text.isEmpty) {
      widget.item['unitCostSyp'] = 0.0;
      if (widget.invoiceCurrency == AppCurrency.sypCode) widget.item['unitCost'] = 0.0;
      if (widget.autoConvert && widget.exchangeRate > 0) {
        if (_costUsdController.text.isNotEmpty) _costUsdController.text = '';
        widget.item['unitCostUsd'] = 0.0;
      }
      widget.onChanged();
      return;
    }

    final sypVal = AppSettingsService.parseNumber(text);
    if (sypVal != null) {
      widget.item['unitCostSyp'] = sypVal;
      if (widget.invoiceCurrency == AppCurrency.sypCode) {
        widget.item['unitCost'] = sypVal;
      }
      if (widget.autoConvert && widget.exchangeRate > 0) {
        final convertedUsd = sypVal / widget.exchangeRate;
        final formatted = AppSettingsService.formatUsd(convertedUsd);
        if (_costUsdController.text != formatted) {
          _costUsdController.text = formatted;
        }
        widget.item['unitCostUsd'] = convertedUsd;
        if (widget.invoiceCurrency == AppCurrency.usdCode) {
          widget.item['unitCost'] = convertedUsd;
        }
      }
      widget.onChanged();
    }
  }

  void _onCostUsdChanged(String val) {
    final text = val.trim();
    if (text.isEmpty) {
      widget.item['unitCostUsd'] = 0.0;
      if (widget.invoiceCurrency == AppCurrency.usdCode) widget.item['unitCost'] = 0.0;
      if (widget.autoConvert && widget.exchangeRate > 0) {
        if (_costSypController.text.isNotEmpty) _costSypController.text = '';
        widget.item['unitCostSyp'] = 0.0;
      }
      widget.onChanged();
      return;
    }

    final usdVal = AppSettingsService.parseNumber(text);
    if (usdVal != null) {
      widget.item['unitCostUsd'] = usdVal;
      if (widget.invoiceCurrency == AppCurrency.usdCode) {
        widget.item['unitCost'] = usdVal;
      }
      if (widget.autoConvert && widget.exchangeRate > 0) {
        final convertedSyp = usdVal * widget.exchangeRate;
        final formatted = AppSettingsService.formatSyp(convertedSyp);
        if (_costSypController.text != formatted) {
          _costSypController.text = formatted;
        }
        widget.item['unitCostSyp'] = convertedSyp;
        if (widget.invoiceCurrency == AppCurrency.sypCode) {
          widget.item['unitCost'] = convertedSyp;
        }
      }
      widget.onChanged();
    }
  }

  void _onRetailSypChanged(String val) {
    final text = val.trim();
    if (text.isEmpty) {
      widget.item['retailPriceSyp'] = null;
      widget.item['retailPrice'] = 0.0;
      if (widget.autoConvert && widget.exchangeRate > 0) {
        if (_retailUsdController.text.isNotEmpty) _retailUsdController.text = '';
        widget.item['retailPriceUsd'] = null;
      }
      widget.onChanged();
      return;
    }

    final sypVal = AppSettingsService.parseNumber(text);
    if (sypVal != null) {
      widget.item['retailPriceSyp'] = sypVal;
      if (widget.invoiceCurrency == AppCurrency.sypCode) widget.item['retailPrice'] = sypVal;
      if (widget.autoConvert && widget.exchangeRate > 0) {
        final convertedUsd = sypVal / widget.exchangeRate;
        final formatted = AppSettingsService.formatUsd(convertedUsd);
        if (_retailUsdController.text != formatted) {
          _retailUsdController.text = formatted;
        }
        widget.item['retailPriceUsd'] = convertedUsd;
      }
      widget.onChanged();
    }
  }

  void _onRetailUsdChanged(String val) {
    final text = val.trim();
    if (text.isEmpty) {
      widget.item['retailPriceUsd'] = null;
      if (widget.autoConvert && widget.exchangeRate > 0) {
        if (_retailSypController.text.isNotEmpty) _retailSypController.text = '';
        widget.item['retailPriceSyp'] = null;
        widget.item['retailPrice'] = 0.0;
      }
      widget.onChanged();
      return;
    }

    final usdVal = AppSettingsService.parseNumber(text);
    if (usdVal != null) {
      widget.item['retailPriceUsd'] = usdVal;
      if (widget.invoiceCurrency == AppCurrency.usdCode) widget.item['retailPrice'] = usdVal;
      if (widget.autoConvert && widget.exchangeRate > 0) {
        final convertedSyp = usdVal * widget.exchangeRate;
        final formatted = AppSettingsService.formatSyp(convertedSyp);
        if (_retailSypController.text != formatted) {
          _retailSypController.text = formatted;
        }
        widget.item['retailPriceSyp'] = convertedSyp;
      }
      widget.onChanged();
    }
  }

  void _onWholesaleSypChanged(String val) {
    final text = val.trim();
    if (text.isEmpty) {
      widget.item['wholesalePriceSyp'] = null;
      widget.item['wholesalePrice'] = 0.0;
      if (widget.autoConvert && widget.exchangeRate > 0) {
        if (_wholesaleUsdController.text.isNotEmpty) _wholesaleUsdController.text = '';
        widget.item['wholesalePriceUsd'] = null;
      }
      widget.onChanged();
      return;
    }

    final sypVal = AppSettingsService.parseNumber(text);
    if (sypVal != null) {
      widget.item['wholesalePriceSyp'] = sypVal;
      if (widget.invoiceCurrency == AppCurrency.sypCode) widget.item['wholesalePrice'] = sypVal;
      if (widget.autoConvert && widget.exchangeRate > 0) {
        final convertedUsd = sypVal / widget.exchangeRate;
        final formatted = AppSettingsService.formatUsd(convertedUsd);
        if (_wholesaleUsdController.text != formatted) {
          _wholesaleUsdController.text = formatted;
        }
        widget.item['wholesalePriceUsd'] = convertedUsd;
      }
      widget.onChanged();
    }
  }

  void _onWholesaleUsdChanged(String val) {
    final text = val.trim();
    if (text.isEmpty) {
      widget.item['wholesalePriceUsd'] = null;
      if (widget.autoConvert && widget.exchangeRate > 0) {
        if (_wholesaleSypController.text.isNotEmpty) _wholesaleSypController.text = '';
        widget.item['wholesalePriceSyp'] = null;
        widget.item['wholesalePrice'] = 0.0;
      }
      widget.onChanged();
      return;
    }

    final usdVal = AppSettingsService.parseNumber(text);
    if (usdVal != null) {
      widget.item['wholesalePriceUsd'] = usdVal;
      if (widget.invoiceCurrency == AppCurrency.usdCode) widget.item['wholesalePrice'] = usdVal;
      if (widget.autoConvert && widget.exchangeRate > 0) {
        final convertedSyp = usdVal * widget.exchangeRate;
        final formatted = AppSettingsService.formatSyp(convertedSyp);
        if (_wholesaleSypController.text != formatted) {
          _wholesaleSypController.text = formatted;
        }
        widget.item['wholesalePriceSyp'] = convertedSyp;
      }
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final qty = (widget.item['quantity'] as num).toDouble();
    final isUsd = widget.invoiceCurrency == AppCurrency.usdCode;
    final cost = isUsd
        ? ((widget.item['unitCostUsd'] as num?)?.toDouble() ?? 0.0)
        : ((widget.item['unitCostSyp'] as num?)?.toDouble() ?? (widget.item['unitCost'] as num).toDouble());
    final subtotal = qty * cost;
    final currentStock = (widget.item['currentStock'] as num?)?.toDouble() ?? 0.0;
    final code = widget.item['productCode'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Details Header
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
          const SizedBox(height: 12),

          // Row 1: Quantity, Unit Cost SYP, Unit Cost USD, Subtotal
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quantity
              Expanded(
                flex: 2,
                child: AppTextField(
                  label: 'common.quantity'.tr(),
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final numVal = AppSettingsService.parseNumber(val);
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
                  controller: _costSypController,
                  prefixIcon: isUsd
                      ? null
                      : const Icon(Icons.arrow_right_rounded, color: AppColors.primary, size: 18),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(
                      AppCurrency.baseSymbol,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: !isUsd ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: _onCostSypChanged,
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
                  prefixIcon: isUsd
                      ? const Icon(Icons.arrow_right_rounded, color: Color(0xFF059669), size: 18)
                      : null,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(
                      AppCurrency.secondarySymbol,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isUsd ? const Color(0xFF059669) : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: _onCostUsdChanged,
                ),
              ),
              const SizedBox(width: 10),
              // Subtotal Box
              Expanded(
                flex: 3,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'suppliers.item_subtotal'.tr(),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          Text(
                            '${subtotal.toStringAsFixed(2)} ${AppCurrency.getSymbol(widget.invoiceCurrency)}',
                            style: AppTheme.numericStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isUsd ? const Color(0xFF059669) : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (widget.exchangeRate > 0 && subtotal > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              isUsd
                                  ? '≈ ${(subtotal * widget.exchangeRate).toStringAsFixed(0)} ل.س'
                                  : '≈ ${(subtotal / widget.exchangeRate).toStringAsFixed(2)} \$',
                              style: AppTheme.numericStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Selling Prices (Retail & Wholesale in SYP and USD)
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
                    onChanged: _onRetailSypChanged,
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
                    onChanged: _onWholesaleSypChanged,
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
                    onChanged: _onRetailUsdChanged,
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
                    onChanged: _onWholesaleUsdChanged,
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
