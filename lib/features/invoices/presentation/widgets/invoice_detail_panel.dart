import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_cubit.dart';
import 'package:small_mall/features/invoices/presentation/widgets/delete_invoice_dialog.dart';
import 'package:small_mall/features/invoices/presentation/widgets/edit_adjustment_dialog.dart';
import 'package:small_mall/features/invoices/presentation/widgets/edit_debt_payment_dialog.dart';
import 'package:small_mall/features/invoices/presentation/widgets/edit_expense_dialog.dart';
import 'package:small_mall/features/invoices/presentation/widgets/edit_invoice_dialog.dart';
import 'package:small_mall/features/invoices/presentation/widgets/edit_purchase_invoice_dialog.dart';

class InvoiceDetailPanel extends StatelessWidget {
  const InvoiceDetailPanel({
    super.key,
    required this.transaction,
  });

  final UnifiedTransactionRecord transaction;

  Color _getTypeColor(UnifiedTransactionType type) {
    switch (type) {
      case UnifiedTransactionType.sale:
        return AppColors.success;
      case UnifiedTransactionType.returnSale:
        return AppColors.danger;
      case UnifiedTransactionType.purchase:
        return const Color(0xFF2563EB);
      case UnifiedTransactionType.expense:
        return const Color(0xFFEA580C);
      case UnifiedTransactionType.debtPayment:
        return const Color(0xFF7C3AED);
      case UnifiedTransactionType.debtInvoice:
        return AppColors.warning;
      case UnifiedTransactionType.adjustment:
        return const Color(0xFF0D9488);
    }
  }

  IconData _getTypeIcon(UnifiedTransactionType type) {
    switch (type) {
      case UnifiedTransactionType.sale:
        return Icons.point_of_sale;
      case UnifiedTransactionType.returnSale:
        return Icons.replay;
      case UnifiedTransactionType.purchase:
        return Icons.local_shipping;
      case UnifiedTransactionType.expense:
        return Icons.account_balance_wallet;
      case UnifiedTransactionType.debtPayment:
        return Icons.payments;
      case UnifiedTransactionType.debtInvoice:
        return Icons.request_quote;
      case UnifiedTransactionType.adjustment:
        return Icons.tune;
    }
  }

  void _openEditDialog(BuildContext context, InvoicesCubit cubit) {
    switch (transaction.type) {
      case UnifiedTransactionType.sale:
      case UnifiedTransactionType.returnSale:
      case UnifiedTransactionType.debtInvoice:
        if (transaction.rawInvoice != null) {
          EditInvoiceDialog.show(context, transaction.rawInvoice!, cubit);
        }
        break;
      case UnifiedTransactionType.purchase:
        EditPurchaseInvoiceDialog.show(context, transaction, cubit);
        break;
      case UnifiedTransactionType.expense:
        EditExpenseDialog.show(context, transaction, cubit);
        break;
      case UnifiedTransactionType.debtPayment:
        EditDebtPaymentDialog.show(context, transaction, cubit);
        break;
      case UnifiedTransactionType.adjustment:
        EditAdjustmentDialog.show(context, transaction, cubit);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<InvoicesCubit>();
    final typeColor = _getTypeColor(transaction.type);
    final typeIcon = _getTypeIcon(transaction.type);
    final globalText = transaction.globalSerialNumber != null
        ? '#${transaction.globalSerialNumber}'
        : (transaction.serialNumber != null ? '#${transaction.serialNumber}' : '#${transaction.id.substring(0, 8)}');
    final departmentSerialText = transaction.serialNumber != null
        ? '#${transaction.serialNumber}'
        : '-';

    return Container(
      color: AppColors.surfaceElevated,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top action bar
            Row(
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 16, color: typeColor),
                      const SizedBox(width: 6),
                      Text(
                        transaction.typeLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (transaction.paymentType != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: transaction.paymentType == 'debt'
                          ? AppColors.warning.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      transaction.paymentType == 'debt' ? 'pos.debt'.tr() : 'pos.cash'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: transaction.paymentType == 'debt' ? AppColors.warning : AppColors.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                if (transaction.hasMultipleCurrencies)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'عملتان (${AppCurrency.sypSymbol} + ${AppCurrency.usdSymbol})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (transaction.currency == AppCurrency.usdCode
                              ? const Color(0xFF059669)
                              : AppColors.primary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${AppCurrency.fromCode(transaction.currency).nameAr} (${transaction.currencySymbol})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: transaction.currency == AppCurrency.usdCode
                            ? const Color(0xFF059669)
                            : AppColors.primary,
                      ),
                    ),
                  ),
                const Spacer(),
                // Universal Edit and Delete buttons for ALL transaction types
                OutlinedButton.icon(
                  onPressed: () => _openEditDialog(context, cubit),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text('common.edit'.tr()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => DeleteTransactionDialog.show(context, transaction, cubit),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text('common.delete'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Prominent Serial Header
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '${transaction.typeLabel} $departmentSerialText',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '${'invoices.global_serial_number'.tr()}: $globalText',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Metadata info rows
            _buildInfoRow(theme, 'invoices.global_serial_number'.tr(), globalText),
            _buildInfoRow(theme, 'invoices.type_serial_number'.tr(), '${transaction.typeLabel} $departmentSerialText'),
            _buildInfoRow(theme, 'invoices.invoice_date'.tr(), DateFormat('yyyy-MM-dd HH:mm').format(transaction.createdAt)),
            _buildInfoRow(
              theme,
              'common.currency_select'.tr(),
              transaction.hasMultipleCurrencies
                  ? '${AppCurrency.primary.nameAr} (${AppCurrency.primary.symbol}) + ${AppCurrency.secondary.nameAr} (${AppCurrency.secondary.symbol})'
                  : '${AppCurrency.fromCode(transaction.currency).nameAr} (${transaction.currencySymbol})',
            ),

            if (transaction.isSale || transaction.isReturn || transaction.isDebtInvoice)
              _buildInfoRow(theme, 'invoices.customer'.tr(), transaction.partyName ?? 'pos.walk_in_customer'.tr()),
            if (transaction.isPurchase)
              _buildInfoRow(theme, 'invoices.supplier'.tr(), transaction.partyName ?? 'invoices.supplier'.tr()),
            if (transaction.isExpense)
              _buildInfoRow(theme, 'invoices.expense_category'.tr(), transaction.partyName ?? 'invoices.expense_category'.tr()),
            if (transaction.isDebtPayment)
              _buildInfoRow(theme, 'invoices.customer'.tr(), transaction.partyName ?? 'invoices.customer'.tr()),
            if (transaction.isAdjustment)
              _buildInfoRow(theme, 'inventory.product_name'.tr(), transaction.partyName ?? 'invoices.adjustment'.tr()),

            if (transaction.paymentType != null)
              _buildInfoRow(theme, 'invoices.payment_method'.tr(), transaction.paymentType == 'debt' ? 'pos.debt'.tr() : 'pos.cash'.tr()),

            if (transaction.notes != null && transaction.notes!.isNotEmpty)
              _buildInfoRow(theme, 'invoices.reason'.tr(), transaction.notes!),

            _buildInfoRow(theme, 'UUID', transaction.id, isMuted: true),

            const Divider(height: 24),

            // Items List or Operation Details
            if (transaction.items.isNotEmpty) ...[
              Text(
                transaction.isAdjustment ? 'inventory.adjustments'.tr() : 'inventory.products_title'.tr(),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...transaction.items.map((item) => _buildItemCard(theme, item, transaction.type)),
              const Divider(height: 24),
              if (transaction.discount > 0)
                _buildSummaryRow(
                  theme,
                  'pos.discount_amount'.tr(),
                  -transaction.discount,
                  color: AppColors.danger,
                  currencySymbol: transaction.currencySymbol,
                ),
            ] else if (transaction.isExpense) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('invoices.expense_category'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(transaction.partyName ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('common.notes'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(transaction.notes!, style: const TextStyle(fontSize: 14)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (transaction.isDebtPayment) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('invoices.customer'.tr(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(transaction.partyName ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (transaction.notes != null) ...[
                      const SizedBox(height: 8),
                      Text(transaction.notes!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Total Amount
            if (transaction.hasMultipleCurrencies) ...[
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'common.total'.tr(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'عملتان منفصلتان',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (transaction.totalUsd > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF059669),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${'common.total'.tr()} (${AppCurrency.usdSymbol}):',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${transaction.totalUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}',
                            style: AppTheme.numericStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    if (transaction.totalUsd > 0 && transaction.totalSyp > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                    if (transaction.totalSyp > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${'common.total'.tr()} (${AppCurrency.sypSymbol}):',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${transaction.totalSyp.toStringAsFixed(2)} ${AppCurrency.sypSymbol}',
                            style: AppTheme.numericStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ] else ...[
              _buildSummaryRow(
                theme,
                'common.total'.tr(),
                transaction.totalAmount,
                isBold: true,
                color: typeColor,
                currencySymbol: transaction.currencySymbol,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value, {bool isMuted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isMuted ? FontWeight.normal : FontWeight.w500,
                color: isMuted ? AppColors.textSecondary : AppColors.textPrimary,
                fontSize: isMuted ? 11 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ThemeData theme, UnifiedTransactionItem item, UnifiedTransactionType type) {
    final qty = item.quantity;
    final price = item.unitPrice;
    final itemTotal = (price * qty.abs()) - item.discount;

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
                    type == UnifiedTransactionType.adjustment
                        ? '${'invoices.adjusted_qty'.tr()}: ${qty > 0 ? "+$qty" : qty}'
                        : '${qty.toStringAsFixed(0)} × ${price.toStringAsFixed(2)} ${item.currencySymbol}',
                    style: theme.textTheme.labelSmall,
                  ),
                  if (item.discount > 0)
                    Text(
                      '${'common.discount'.tr()}: ${item.discount.toStringAsFixed(2)} ${item.currencySymbol}',
                      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.danger),
                    ),
                ],
              ),
            ),
            Text(
              type == UnifiedTransactionType.adjustment
                  ? '${qty > 0 ? "+$qty" : qty} ${'inventory.pieces'.tr()}'
                  : '${itemTotal.toStringAsFixed(2)} ${item.currencySymbol}',
              style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    ThemeData theme,
    String label,
    double amount, {
    bool isBold = false,
    Color? color,
    String? currencySymbol,
  }) {
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
            '${amount.toStringAsFixed(2)}${currencySymbol != null ? ' $currencySymbol' : ''}',
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
