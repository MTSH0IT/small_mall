import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_cubit.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_state.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
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

  String? _getCustomerName(String? customerId) {
    if (customerId == null) return null;
    final cubit = context.read<POSCubit>();
    if (cubit.state is POSLoaded) {
      final state = cubit.state as POSLoaded;
      return state.customers.where((c) => c.customer.id == customerId).firstOrNull?.customer.name;
    }
    return null;
  }

  Future<void> _selectInvoice(Invoice invoice) async {
    final cubit = context.read<POSCubit>();
    final items = await cubit.getInvoiceItems(invoice.id);
    setState(() {
      _selectedInvoice = invoice;
      _selectedInvoiceItems = items;
      for (final c in _quantityControllers.values) {
        c.dispose();
      }
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
        final originalQty = _originalQuantities[item.id] ?? 0.0;

        if (qty > originalQty) {
          AppToast.warning(
            context,
            message: 'pos.return_qty_exceeded'.tr(
              namedArgs: {'qty': originalQty.toStringAsFixed(0)},
            ),
          );
          setState(() => _isSubmitting = false);
          return;
        }

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
      AppToast.warning(context, message: 'pos.return_reason'.tr());
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
        AppToast.success(context, message: 'pos.return_success'.tr());
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, message: '${'common.error'.tr()}: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
        width: 520,
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
    if (_invoices == null) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoices!.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: EmptyStateView(
            icon: Icons.receipt_long_outlined,
            title: 'pos.no_invoices'.tr(),
          ),
        ),
      );
    }

    final query = _searchQuery.trim().toLowerCase();
    final cleanQuery = query.replaceAll('#', '').trim();

    final filteredInvoices = _invoices!.where((invoice) {
      if (cleanQuery.isEmpty) return true;

      // 1. Match serial number
      final serialStr = invoice.serialNumber?.toString() ?? '';
      if (serialStr == cleanQuery || serialStr.contains(cleanQuery)) return true;

      // 2. Match ID prefix/full
      final idStr = invoice.id.toLowerCase();
      if (idStr.contains(cleanQuery)) return true;

      // 3. Match customer name
      final customerName = _getCustomerName(invoice.customerId)?.toLowerCase() ?? '';
      if (customerName.contains(query)) return true;

      // 4. Match total amount
      final totalStr = invoice.totalAmount.toStringAsFixed(2);
      if (totalStr.contains(cleanQuery) || invoice.totalAmount.toString().contains(cleanQuery)) return true;

      // 5. Match payment type
      if (invoice.paymentType == 'debt' &&
          (query.contains('دين') || query.contains('آجل') || query.contains('debt'))) {
        return true;
      }
      if (invoice.paymentType == 'cash' &&
          (query.contains('نقد') || query.contains('كاش') || query.contains('cash'))) {
        return true;
      }

      return false;
    }).toList();

    return SizedBox(
      height: 460,
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'pos.search_invoice_hint'.tr(),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Invoices List or Empty Search
          Expanded(
            child: filteredInvoices.isEmpty
                ? Center(
                    child: EmptyStateView(
                      icon: Icons.search_off_rounded,
                      title: 'pos.no_matching_invoices'.tr(),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredInvoices.length,
                    separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 1),
                    itemBuilder: (context, index) {
                      final invoice = filteredInvoices[index];
                      final customerName = _getCustomerName(invoice.customerId);
                      final paymentLabel =
                          invoice.paymentType == 'debt' ? 'pos.debt'.tr() : 'pos.cash'.tr();
                      final isDebt = invoice.paymentType == 'debt';
                      final serialText = invoice.serialNumber != null
                          ? '#${invoice.serialNumber}'
                          : '#${invoice.id.length >= 8 ? invoice.id.substring(0, 8) : invoice.id}';
                      final formattedDate =
                          intl.DateFormat('yyyy-MM-dd HH:mm').format(invoice.createdAt);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long_rounded,
                              color: AppColors.primary, size: 22),
                        ),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(5),
                                border:
                                    Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                serialText,
                                style: AppTheme.numericStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'invoices.invoice_id'.tr(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            if (customerName != null) ...[
                              const SizedBox(width: 8),
                              const Text('•', style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Text(
                                formattedDate,
                                style: AppTheme.numericStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('|', style: TextStyle(color: AppColors.border)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDebt
                                      ? AppColors.warning.withValues(alpha: 0.12)
                                      : AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  paymentLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDebt ? AppColors.warning : AppColors.success,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('|', style: TextStyle(color: AppColors.border)),
                              const SizedBox(width: 8),
                              Text(
                                invoice.totalAmount.toStringAsFixed(2),
                                style: AppTheme.numericStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            size: 14, color: AppColors.textSecondary),
                        onTap: () => _selectInvoice(invoice),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnForm(ThemeData theme) {
    if (_selectedInvoiceItems == null || _selectedInvoiceItems!.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: EmptyStateView(
            icon: Icons.inventory_2_outlined,
            title: 'invoices.empty_invoices'.tr(),
          ),
        ),
      );
    }

    final serialText = _selectedInvoice!.serialNumber != null
        ? '#${_selectedInvoice!.serialNumber}'
        : '#${_selectedInvoice!.id.length >= 8 ? _selectedInvoice!.id.substring(0, 8) : _selectedInvoice!.id}';
    final customerName = _getCustomerName(_selectedInvoice!.customerId);

    return SizedBox(
      height: 420,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    serialText,
                    style: AppTheme.numericStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'invoices.invoice_id'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (customerName != null) ...[
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${'common.total'.tr()}: ${_selectedInvoice!.totalAmount.toStringAsFixed(2)}',
                  style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
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
