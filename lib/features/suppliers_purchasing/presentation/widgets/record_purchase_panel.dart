import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_searchable_dropdown.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';

class RecordPurchasePanel extends StatefulWidget {
  const RecordPurchasePanel({
    super.key,
    required this.selectedSupplier,
    required this.availableProducts,
    required this.onConfirmPurchase,
  });

  final Supplier selectedSupplier;
  final List<ProductWithDetails> availableProducts;
  final Future<void> Function(List<Map<String, dynamic>> items, double totalAmount) onConfirmPurchase;

  @override
  State<RecordPurchasePanel> createState() => _RecordPurchasePanelState();
}

class _RecordPurchasePanelState extends State<RecordPurchasePanel> {
  final List<Map<String, dynamic>> _purchaseItems = [];

  double get _totalPurchaseAmount {
    return _purchaseItems.fold<double>(0.0, (sum, item) {
      final qty = (item['quantity'] as num).toDouble();
      final cost = (item['unitCost'] as num).toDouble();
      return sum + (qty * cost);
    });
  }

  void _addPurchaseItemRow(Product product) {
    final existing = _purchaseItems.any((item) => item['productId'] == product.id);
    if (existing) return;

    setState(() {
      _purchaseItems.add({
        'productId': product.id,
        'productName': product.name,
        'quantity': 1.0,
        'unitCost': product.costPrice,
      });
    });
  }

  @override
  void didUpdateWidget(covariant RecordPurchasePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSupplier.id != widget.selectedSupplier.id) {
      _purchaseItems.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Info
          Text(
            'suppliers.record_purchase_from'.tr(args: [widget.selectedSupplier.name]),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          // Product Selector dropdown for adding rows
          Row(
            children: [
              Expanded(
                child: AppSearchableDropdown<ProductWithDetails>(
                  key: ValueKey('${widget.selectedSupplier.id}_${_purchaseItems.length}'),
                  hint: 'suppliers.select_product_to_add'.tr(),
                  prefixIcon: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  itemSearchText: (p) => '${p.product.name} ${p.product.code ?? ''}',
                  items: widget.availableProducts.map((p) {
                    return DropdownMenuItem<ProductWithDetails>(
                      value: p,
                      child: Text(
                        p.product.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (prod) {
                    if (prod != null) {
                      _addPurchaseItemRow(prod.product);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Purchase Items Table/List
          Expanded(
            child: _purchaseItems.isEmpty
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
                      itemCount: _purchaseItems.length,
                      separatorBuilder: (_, _) => const Divider(color: AppColors.border),
                      itemBuilder: (context, index) {
                        final item = _purchaseItems[index];
                        return _PurchaseItemRow(
                          key: ValueKey(item['productId']),
                          item: item,
                          onChanged: () => setState(() {}),
                          onRemove: () {
                            setState(() {
                              _purchaseItems.removeAt(index);
                            });
                          },
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          // Footer / Checkout
          const Divider(color: AppColors.border, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'suppliers.total_purchase_value'.tr(),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              Text(
                _totalPurchaseAmount.toStringAsFixed(2),
                style: AppTheme.numericStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'suppliers.confirm_save_purchase'.tr(),
            icon: Icons.check,
            onPressed: _purchaseItems.isEmpty
                ? null
                : () async {
                    await widget.onConfirmPurchase(_purchaseItems, _totalPurchaseAmount);
                    setState(() {
                      _purchaseItems.clear();
                    });
                  },
          ),
        ],
      ),
    );
  }
}

class _PurchaseItemRow extends StatefulWidget {
  const _PurchaseItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final Map<String, dynamic> item;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_PurchaseItemRow> createState() => _PurchaseItemRowState();
}

class _PurchaseItemRowState extends State<_PurchaseItemRow> {
  late final TextEditingController _qtyController;
  late final TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    final qty = (widget.item['quantity'] as num).toDouble();
    final cost = (widget.item['unitCost'] as num).toDouble();
    _qtyController = TextEditingController(text: qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString());
    _costController = TextEditingController(text: cost.toString());
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qty = (widget.item['quantity'] as num).toDouble();
    final cost = (widget.item['unitCost'] as num).toDouble();
    final subtotal = qty * cost;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.item['productName'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          Row(
            children: [
              // Quantity Field
              Expanded(
                child: AppTextField(
                  label: 'suppliers.purchased_quantity'.tr(),
                  hint: 'common.quantity'.tr(),
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final parsed = double.tryParse(val) ?? 1.0;
                    widget.item['quantity'] = parsed;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Unit Cost Field
              Expanded(
                child: AppTextField(
                  label: 'suppliers.new_cost_price'.tr(),
                  hint: 'suppliers.cost_per_unit'.tr(),
                  controller: _costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    final parsed = double.tryParse(val) ?? 0.0;
                    widget.item['unitCost'] = parsed;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${'common.total'.tr()}:', style: theme.textTheme.labelSmall),
                  Text(
                    subtotal.toStringAsFixed(2),
                    style: AppTheme.numericStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
