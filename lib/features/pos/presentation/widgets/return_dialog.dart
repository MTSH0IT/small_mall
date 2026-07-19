import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_cubit.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReturnDialog extends StatefulWidget {
  const ReturnDialog({super.key});

  @override
  State<ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<ReturnDialog> {
  List<Invoice>? _invoices;
  Invoice? _selectedInvoice;
  List<InvoiceItem>? _selectedInvoiceItems;
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, double> _originalQuantities = {};
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final cubit = context.read<POSCubit>();
      final invoices = await cubit.getRecentSales();
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectInvoice(Invoice invoice) async {
    final cubit = context.read<POSCubit>();
    final items = await cubit.getInvoiceItems(invoice.id);
    setState(() {
      _selectedInvoice = invoice;
      _selectedInvoiceItems = items;
      _quantityControllers.clear();
      _originalQuantities.clear();
      for (final item in items) {
        _quantityControllers[item.id] = TextEditingController(text: item.quantity.toStringAsFixed(0));
        _originalQuantities[item.id] = item.quantity;
      }
    });
  }

  Future<void> _submitReturn() async {
    if (_selectedInvoice == null || _selectedInvoiceItems == null) return;

    final itemsToReturn = <Map<String, dynamic>>[];
    for (final item in _selectedInvoiceItems!) {
      final qtyText = _quantityControllers[item.id]?.text ?? '0';
      final returnQty = double.tryParse(qtyText) ?? 0;
      if (returnQty > 0) {
        itemsToReturn.add({
          'productId': item.productId,
          'quantity': returnQty,
          'priceUsed': item.priceUsed,
        });
      }
    }

    if (itemsToReturn.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final cubit = context.read<POSCubit>();
      await cubit.createReturn(
        originalInvoiceId: _selectedInvoice!.id,
        itemsToReturn: itemsToReturn,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSubmitting = false);
    }
  }

  String _getProductName(String productId) {
    final state = context.read<POSCubit>().state;
    if (state is POSLoaded) {
      final product = state.products.where((p) => p.product.id == productId).firstOrNull;
      return product?.product.name ?? productId;
    }
    return productId;
  }

  @override
  void dispose() {
    for (final ctrl in _quantityControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.replay, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedInvoice == null ? 'اختيار فاتورة للإرجاع' : 'إرجاع منتجات',
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _selectedInvoice == null
                  ? _buildInvoiceList(theme)
                  : _buildReturnForm(theme),
        ),
        actions: _selectedInvoice == null
            ? null
            : [
                TextButton(
                  onPressed: () => setState(() => _selectedInvoice = null),
                  child: const Text('رجوع'),
                ),
                PrimaryButton(
                  label: 'تأكيد الإرجاع',
                  icon: Icons.check,
                  onPressed: _isSubmitting ? null : _submitReturn,
                  isLoading: _isSubmitting,
                ),
              ],
      ),
    );
  }

  Widget _buildInvoiceList(ThemeData theme) {
    if (_invoices == null || _invoices!.isEmpty) {
      return const Text('لا توجد فواتير بيع سابقة');
    }

    return SizedBox(
      height: 400,
      child: ListView.separated(
        itemCount: _invoices!.length,
        separatorBuilder: (_, _) => const Divider(color: AppColors.border),
        itemBuilder: (context, index) {
          final invoice = _invoices![index];
          final paymentLabel = invoice.paymentType == 'debt' ? 'آجل' : 'نقدي';
          return ListTile(
            leading: const Icon(Icons.receipt_long, color: AppColors.primary),
            title: Text('فاتورة #${invoice.id.substring(0, 8)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${invoice.createdAt.toString().substring(0, 16)}  |  $paymentLabel  |  ${invoice.totalAmount.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textSecondary),
            onTap: () => _selectInvoice(invoice),
          );
        },
      ),
    );
  }

  Widget _buildReturnForm(ThemeData theme) {
    if (_selectedInvoiceItems == null || _selectedInvoiceItems!.isEmpty) {
      return const Text('لا توجد منتجات في هذه الفاتورة');
    }

    return SizedBox(
      height: 400,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text('فاتورة: ${_selectedInvoice!.id.substring(0, 8)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('المجموع: ${_selectedInvoice!.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _selectedInvoiceItems!.length,
              separatorBuilder: (_, _) => const Divider(color: AppColors.border),
              itemBuilder: (context, index) {
                final item = _selectedInvoiceItems![index];
                final productName = _getProductName(item.productId);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(productName,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              'السعر: ${item.priceUsed.toStringAsFixed(2)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _quantityControllers[item.id],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'الكمية',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
