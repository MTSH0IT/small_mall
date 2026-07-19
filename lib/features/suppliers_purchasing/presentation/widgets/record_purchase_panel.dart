import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:flutter/material.dart';

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
      final qty = item['quantity'] as double;
      final cost = item['unitCost'] as double;
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
            'تسجيل فاتورة مشتريات من المورد: ${widget.selectedSupplier.name}',
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
                child: DropdownButtonFormField<ProductWithDetails>(
                  key: ValueKey('${widget.selectedSupplier.id}_${_purchaseItems.length}'), // Reset dropdown when supplier changes or item is added
                  hint: const Text('اختر منتجاً لإضافته للفاتورة'),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  items: widget.availableProducts.map((p) {
                    return DropdownMenuItem(value: p, child: Text(p.product.name));
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
                ? const Center(child: Text('لم يتم إضافة أي منتجات للفاتورة بعد'))
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
                        final subtotal = (item['quantity'] as double) * (item['unitCost'] as double);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(item['productName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _purchaseItems.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  // Quantity Field
                                  Expanded(
                                    child: AppTextField(
                                      label: 'الكمية المشتراة',
                                      hint: 'الكمية',
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        setState(() {
                                          _purchaseItems[index]['quantity'] = double.tryParse(val) ?? 1.0;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Unit Cost Field
                                  Expanded(
                                    child: AppTextField(
                                      label: 'سعر التكلفة الجديد',
                                      hint: 'التكلفة بالقطعة',
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (val) {
                                        setState(() {
                                          _purchaseItems[index]['unitCost'] = double.tryParse(val) ?? 0.0;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('المجموع:', style: theme.textTheme.labelSmall),
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
                'إجمالي قيمة المشتريات:',
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
            label: 'تأكيد وحفظ فاتورة المشتريات',
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
