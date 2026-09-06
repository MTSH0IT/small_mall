import 'package:easy_localization/easy_localization.dart';
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
        _quantityControllers[item.id] = TextEditingController(text: item.quantity.toString());
        _originalQuantities[item.id] = item.quantity;
      }
    });
  }

  String _getProductName(String productId) {
    final cubit = context.read<POSCubit>();
    if (cubit.state is POSLoaded) {
      final state = cubit.state as POSLoaded;
      final product = state.products.where((p) => p.product.id == productId).firstOrNull;
      if (product != null) return product.product.name;
    }
    return productId;
  }

  Future<void> _submitReturn() async {
    if (_selectedInvoice == null || _selectedInvoiceItems == null) return;
    setState(() => _isSubmitting = true);

    final returnItems = <Map<String, dynamic>>[];
    for (final item in _selectedInvoiceItems!) {
      final controller = _quantityControllers[item.id];
      if (controller != null) {
        final qty = double.tryParse(controller.text) ?? 0;
        if (qty > 0) {
          returnItems.add({
            'productId': item.productId,
            'quantity': qty,
            'priceUsed': item.priceUsed,
          });
        }
      }
    }

    if (returnItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('pos.return_reason'.tr())),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final cubit = context.read<POSCubit>();
      await cubit.createReturn(
        originalInvoiceId: _selectedInvoice!.id,
        itemsToReturn: returnItems,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('pos.return_success'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'common.error'.tr()}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    for (final c in _quantityControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.replay, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedInvoice == null ? 'pos.select_invoice_return'.tr() : 'pos.return_products'.tr(),
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
                child: Text('common.back'.tr()),
              ),
              PrimaryButton(
                label: 'pos.confirm_return'.tr(),
                icon: Icons.check,
                onPressed: _isSubmitting ? null : _submitReturn,
                isLoading: _isSubmitting,
              ),
            ],
    );
  }

  Widget _buildInvoiceList(ThemeData theme) {
    if (_invoices == null || _invoices!.isEmpty) {
      return Center(child: Text('pos.no_invoices'.tr()));
    }

    return SizedBox(
      height: 400,
      child: ListView.separated(
        itemCount: _invoices!.length,
        separatorBuilder: (_, _) => const Divider(color: AppColors.border),
        itemBuilder: (context, index) {
          final invoice = _invoices![index];
          final paymentLabel = invoice.paymentType == 'debt' ? 'pos.debt'.tr() : 'pos.cash'.tr();
          return ListTile(
            leading: const Icon(Icons.receipt_long, color: AppColors.primary),
            title: Text('${'invoices.invoice_id'.tr()} #${invoice.id.substring(0, 8)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${invoice.createdAt.toString().substring(0, 16)}  |  $paymentLabel  |  ${invoice.totalAmount.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
            onTap: () => _selectInvoice(invoice),
          );
        },
      ),
    );
  }

  Widget _buildReturnForm(ThemeData theme) {
    if (_selectedInvoiceItems == null || _selectedInvoiceItems!.isEmpty) {
      return Center(child: Text('invoices.empty_invoices'.tr()));
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
                Text('${'invoices.invoice_id'.tr()}: ${_selectedInvoice!.id.substring(0, 8)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${'common.total'.tr()}: ${_selectedInvoice!.totalAmount.toStringAsFixed(2)}',
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
                              '${'common.price'.tr()}: ${item.priceUsed.toStringAsFixed(2)}',
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
                            labelText: 'common.quantity'.tr(),
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
