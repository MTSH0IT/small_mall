import 'package:easy_localization/easy_localization.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/features/pos/data/pos_repository.dart';
import 'package:flutter/material.dart';

class InvoiceDetailPanel extends StatelessWidget {
  const InvoiceDetailPanel({
    super.key,
    required this.invoiceData,
  });
  final InvoiceWithDetails invoiceData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invoice = invoiceData.invoice;
    final isReturn = invoice.type == 'return';

    return Container(
      color: AppColors.surfaceElevated,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isReturn ? AppColors.danger.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isReturn ? Icons.replay : Icons.receipt_long,
                        size: 16,
                        color: isReturn ? AppColors.danger : AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isReturn ? 'invoices.return'.tr() : 'invoices.sale'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isReturn ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow(theme, 'invoices.invoice_id'.tr(), invoice.id.substring(0, 8)),
            _buildInfoRow(theme, 'invoices.invoice_date'.tr(), DateFormat('yyyy-MM-dd HH:mm').format(invoice.createdAt)),
            _buildInfoRow(theme, 'invoices.customer'.tr(), invoiceData.customerName ?? 'pos.walk_in_customer'.tr()),
            _buildInfoRow(theme, 'invoices.payment_method'.tr(), invoice.paymentType == 'cash' ? 'pos.cash'.tr() : 'pos.debt'.tr()),
            const Divider(height: 24),
            Text('inventory.products_title'.tr(), style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (invoiceData.items.isEmpty)
              Center(child: Text('invoices.empty_invoices'.tr()))
            else
              ...invoiceData.items.map((item) => _buildItemCard(theme, item)),
            const Divider(height: 24),
            _buildSummaryRow(theme, 'pos.subtotal'.tr(), invoiceData.itemsTotal),
            if (invoice.discount > 0)
              _buildSummaryRow(theme, 'pos.discount_amount'.tr(), -invoice.discount, color: AppColors.danger),
            const SizedBox(height: 8),
            _buildSummaryRow(
              theme,
              'common.total'.tr(),
              invoice.totalAmount,
              isBold: true,
              color: isReturn ? AppColors.danger : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ThemeData theme, InvoiceItemWithProduct item) {
    final qty = item.invoiceItem.quantity;
    final price = item.invoiceItem.priceUsed;
    final itemTotal = (price * qty) - item.invoiceItem.discount;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    '${qty.toStringAsFixed(0)} x ${price.toStringAsFixed(2)}',
                    style: theme.textTheme.labelSmall,
                  ),
                  if (item.invoiceItem.discount > 0)
                    Text(
                      '${'common.discount'.tr()}: ${item.invoiceItem.discount.toStringAsFixed(2)}',
                      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.danger),
                    ),
                ],
              ),
            ),
            Text(
              itemTotal.toStringAsFixed(2),
              style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(ThemeData theme, String label, double amount, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            amount.toStringAsFixed(2),
            style: AppTheme.numericStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 18 : 14,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
