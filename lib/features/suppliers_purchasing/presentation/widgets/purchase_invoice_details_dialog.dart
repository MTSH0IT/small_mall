import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_table.dart';
import 'package:small_mall/features/suppliers_purchasing/data/suppliers_purchasing_repository.dart';

class PurchaseInvoiceDetailsDialog extends StatelessWidget {
  const PurchaseInvoiceDetailsDialog({
    super.key,
    required this.invoiceDetails,
  });

  final PurchaseInvoiceWithDetails invoiceDetails;

  static Future<void> show(BuildContext context, PurchaseInvoiceWithDetails invoiceDetails) {
    return showDialog(
      context: context,
      builder: (ctx) => PurchaseInvoiceDetailsDialog(invoiceDetails: invoiceDetails),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoice = invoiceDetails.invoice;
    final supplier = invoiceDetails.supplier;
    final serialText = invoiceDetails.serialNumber != null
        ? '#${invoiceDetails.serialNumber}'
        : '#${invoice.id.length >= 8 ? invoice.id.substring(0, 8).toUpperCase() : invoice.id.toUpperCase()}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 900,
          maxHeight: 700,
        ),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
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
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'suppliers.invoice_details'.tr(),
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
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  serialText,
                                  style: AppTheme.numericStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${supplier?.name ?? '-'} • ${intl.DateFormat('yyyy/MM/dd  HH:mm').format(invoice.createdAt)}',
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

              // KPI Cards
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        icon: Icons.payments_outlined,
                        color: AppColors.primary,
                        title: 'suppliers.total_amount'.tr(),
                        value: '${invoice.totalAmount.toStringAsFixed(2)} ${'common.currency'.tr()}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        icon: Icons.category_outlined,
                        color: const Color(0xFF0284C7),
                        title: 'suppliers.items_count'.tr(),
                        value: '${invoiceDetails.itemsCount}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.success,
                        title: 'suppliers.total_pieces'.tr(),
                        value: invoiceDetails.totalPieces.toStringAsFixed(0),
                      ),
                    ),
                  ],
                ),
              ),

              // Table
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: AppTable<PurchaseItemWithProduct>(
                    items: invoiceDetails.items,
                    emptyTitle: 'suppliers.no_products_added'.tr(),
                    columns: [
                      AppTableColumn<PurchaseItemWithProduct>(
                        title: '#',
                        cellBuilder: (item) {
                          final index = invoiceDetails.items.indexOf(item) + 1;
                          return Text('$index', style: AppTheme.numericStyle(fontSize: 12));
                        },
                      ),
                      AppTableColumn<PurchaseItemWithProduct>(
                        title: 'inventory.product_name'.tr(),
                        cellBuilder: (item) {
                          final prod = item.product;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                prod?.name ?? 'common.deleted_product'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (prod?.code != null && prod!.code!.isNotEmpty)
                                Text(
                                  prod.code!,
                                  style: AppTheme.numericStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                            ],
                          );
                        },
                      ),
                      AppTableColumn<PurchaseItemWithProduct>(
                        title: 'suppliers.unit_cost'.tr(),
                        numeric: true,
                        cellBuilder: (item) => Text(
                          '${item.item.unitCost.toStringAsFixed(2)} ${'common.currency'.tr()}',
                          style: AppTheme.numericStyle(fontSize: 13),
                        ),
                      ),
                      AppTableColumn<PurchaseItemWithProduct>(
                        title: 'common.quantity'.tr(),
                        numeric: true,
                        cellBuilder: (item) => Text(
                          item.item.quantity.toStringAsFixed(0),
                          style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      AppTableColumn<PurchaseItemWithProduct>(
                        title: 'suppliers.item_subtotal'.tr(),
                        numeric: true,
                        cellBuilder: (item) => Text(
                          '${item.subtotal.toStringAsFixed(2)} ${'common.currency'.tr()}',
                          style: AppTheme.numericStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: Text('common.close'.tr()),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildSummaryCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
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
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.numericStyle(
                    fontSize: 15,
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
}
