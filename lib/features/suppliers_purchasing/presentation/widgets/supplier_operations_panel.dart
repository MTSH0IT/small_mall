import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_table.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/inventory/data/inventory_repository.dart';
import 'package:small_mall/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/cubit/suppliers_purchasing_cubit.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/widgets/new_purchase_invoice_dialog.dart';
import 'package:small_mall/features/suppliers_purchasing/presentation/widgets/purchase_invoice_details_dialog.dart';

class SupplierOperationsPanel extends StatefulWidget {
  const SupplierOperationsPanel({
    super.key,
    required this.supplier,
    required this.availableProducts,
    required this.onEditSupplier,
  });

  final Supplier supplier;
  final List<ProductWithDetails> availableProducts;
  final VoidCallback onEditSupplier;

  @override
  State<SupplierOperationsPanel> createState() => _SupplierOperationsPanelState();
}

class _SupplierOperationsPanelState extends State<SupplierOperationsPanel> {
  bool _isLoadingInvoices = true;
  List<PurchaseInvoiceWithDetails> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void didUpdateWidget(covariant SupplierOperationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.supplier.id != widget.supplier.id) {
      _loadInvoices();
    }
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoadingInvoices = true);
    try {
      final cubit = context.read<SuppliersPurchasingCubit>();
      final list = await cubit.getSupplierInvoices(widget.supplier.id);
      if (mounted) {
        setState(() {
          _invoices = list;
          _isLoadingInvoices = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingInvoices = false);
      }
    }
  }

  double get _totalPurchasesAmount {
    return _invoices.fold<double>(0.0, (sum, inv) => sum + inv.invoice.totalAmount);
  }

  double get _totalPiecesPurchased {
    return _invoices.fold<double>(0.0, (sum, inv) => sum + inv.totalPieces);
  }

  void _openNewPurchaseInvoiceDialog() {
    final cubit = context.read<SuppliersPurchasingCubit>();
    NewPurchaseInvoiceDialog.show(
      context: context,
      supplier: widget.supplier,
      availableProducts: widget.availableProducts,
      cubit: cubit,
      onInvoiceCreated: _loadInvoices,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Supplier Header Card with "New Purchase Invoice" Button
          _buildSupplierHeader(),

          // 2. KPI Summary Cards (3 cards without "آخر عملية شراء")
          _buildKpiSection(),

          // 3. Operations & Invoices History Table
          Expanded(child: _buildOperationsHistorySection()),
        ],
      ),
    );
  }

  Widget _buildSupplierHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.local_shipping_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.supplier.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                      tooltip: 'suppliers.edit_supplier'.tr(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onEditSupplier,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (widget.supplier.phone != null && widget.supplier.phone!.isNotEmpty) ...[
                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        widget.supplier.phone!,
                        style: AppTheme.numericStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (widget.supplier.notes != null && widget.supplier.notes!.isNotEmpty) ...[
                      const Icon(Icons.note_alt_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.supplier.notes!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Prominent Button for New Purchase Invoice
          PrimaryButton(
            label: 'suppliers.new_purchase_invoice'.tr(),
            icon: Icons.add_shopping_cart_rounded,
            onPressed: _openNewPurchaseInvoiceDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSection() {
    final currency = 'common.currency'.tr();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              title: 'suppliers.total_amount'.tr(),
              value: '${_totalPurchasesAmount.toStringAsFixed(2)} $currency',
              icon: Icons.payments_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildKpiCard(
              title: 'suppliers.invoices_count'.tr(),
              value: '${_invoices.length}',
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF0284C7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildKpiCard(
              title: 'suppliers.total_pieces'.tr(),
              value: _totalPiecesPurchased.toStringAsFixed(0),
              icon: Icons.inventory_2_rounded,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppTheme.numericStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsHistorySection() {
    if (_isLoadingInvoices) {
      return LoadingIndicator(message: 'common.loading'.tr());
    }

    if (_invoices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: EmptyStateView(
            icon: Icons.receipt_long_outlined,
            title: 'suppliers.no_invoices_recorded'.tr(),
            action: PrimaryButton(
              label: 'suppliers.new_purchase_invoice'.tr(),
              icon: Icons.add_shopping_cart_rounded,
              onPressed: _openNewPurchaseInvoiceDialog,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'suppliers.operations_history'.tr(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_invoices.length}',
                    style: AppTheme.numericStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AppTable<PurchaseInvoiceWithDetails>(
              items: _invoices,
              emptyTitle: 'suppliers.no_invoices_recorded'.tr(),
              columns: [
                AppTableColumn<PurchaseInvoiceWithDetails>(
                  title: 'suppliers.invoice_ref'.tr(),
                  cellBuilder: (inv) {
                    final serialText = inv.serialNumber != null
                        ? '#${inv.serialNumber}'
                        : '#${inv.invoice.id.length >= 8 ? inv.invoice.id.substring(0, 8).toUpperCase() : inv.invoice.id.toUpperCase()}';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        serialText,
                        style: AppTheme.numericStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
                AppTableColumn<PurchaseInvoiceWithDetails>(
                  title: 'suppliers.invoice_date'.tr(),
                  cellBuilder: (inv) => Text(
                    intl.DateFormat('yyyy/MM/dd  HH:mm').format(inv.invoice.createdAt),
                    style: AppTheme.numericStyle(fontSize: 12),
                  ),
                ),
                AppTableColumn<PurchaseInvoiceWithDetails>(
                  title: 'suppliers.items_count'.tr(),
                  numeric: true,
                  cellBuilder: (inv) => Text(
                    '${inv.itemsCount}',
                    style: AppTheme.numericStyle(fontSize: 13),
                  ),
                ),
                AppTableColumn<PurchaseInvoiceWithDetails>(
                  title: 'suppliers.total_pieces'.tr(),
                  numeric: true,
                  cellBuilder: (inv) => Text(
                    inv.totalPieces.toStringAsFixed(0),
                    style: AppTheme.numericStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                AppTableColumn<PurchaseInvoiceWithDetails>(
                  title: 'suppliers.total_amount'.tr(),
                  numeric: true,
                  cellBuilder: (inv) => Text(
                    '${inv.invoice.totalAmount.toStringAsFixed(2)} ${'common.currency'.tr()}',
                    style: AppTheme.numericStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                AppTableColumn<PurchaseInvoiceWithDetails>(
                  title: 'common.actions'.tr(),
                  cellBuilder: (inv) => IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 20, color: AppColors.primary),
                    tooltip: 'suppliers.view_invoice'.tr(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => PurchaseInvoiceDetailsDialog.show(context, inv),
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
