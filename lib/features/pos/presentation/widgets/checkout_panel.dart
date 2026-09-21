import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_searchable_dropdown.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_state.dart';

class CheckoutPanel extends StatelessWidget {
  const CheckoutPanel({
    super.key,
    required this.state,
    required this.isLoading,
    this.onInvoiceDiscountChanged,
    this.onCustomTotalChanged,
    required this.onPaymentTypeChanged,
    required this.onCustomerChanged,
    required this.onAddCustomerPressed,
    this.onEditCustomerPressed,
    required this.onCheckoutPressed,
  });

  final POSLoaded state;
  final bool isLoading;
  final ValueChanged<double>? onInvoiceDiscountChanged;
  final void Function({double? syp, double? usd, bool clearSyp, bool clearUsd})? onCustomTotalChanged;
  final ValueChanged<String> onPaymentTypeChanged;
  final ValueChanged<Customer?> onCustomerChanged;
  final VoidCallback onAddCustomerPressed;
  final void Function(Customer)? onEditCustomerPressed;
  final VoidCallback? onCheckoutPressed;

  Future<void> _showEditTotalDialog({
    required BuildContext context,
    required String currencyCode,
    required double originalSubtotal,
    required double currentTotal,
    required bool hasCustomTotal,
  }) async {
    final isSyp = currencyCode == AppCurrency.sypCode;
    final currencySymbol = AppCurrency.getSymbol(currencyCode);
    final currencyName = AppCurrency.fromCode(currencyCode).nameAr;
    final controller = TextEditingController(text: currentTotal.toStringAsFixed(2));

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تعديل المجموع النهائي ($currencyName)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المجموع الأصلي: ${originalSubtotal.toStringAsFixed(2)} $currencySymbol',
                      style: AppTheme.numericStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    if (hasCustomTotal)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.shade700, width: 0.8),
                        ),
                        child: Text(
                          'pos.modified_price'.tr(),
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTheme.numericStyle(fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'المبلغ النهائي المطلوب',
                  prefixIcon: const Icon(Icons.calculate_outlined, size: 20),
                  suffixText: currencySymbol,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            if (hasCustomTotal)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('استعادة الأصلي'),
                onPressed: () {
                  if (isSyp) {
                    onCustomTotalChanged?.call(clearSyp: true);
                  } else {
                    onCustomTotalChanged?.call(clearUsd: true);
                  }
                  Navigator.pop(ctx);
                },
              )
            else
              const SizedBox.shrink(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('common.cancel'.tr()),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final val = double.tryParse(controller.text.trim());
                    if (val != null && val >= 0) {
                      if (isSyp) {
                        onCustomTotalChanged?.call(syp: val);
                      } else {
                        onCustomTotalChanged?.call(usd: val);
                      }
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text('common.save'.tr()),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditableTotalChip({
    required BuildContext context,
    required String currencyCode,
    required double originalSubtotal,
    required double currentTotal,
    required bool hasCustomTotal,
  }) {
    final isUsd = currencyCode == AppCurrency.usdCode;
    final currencySymbol = AppCurrency.getSymbol(currencyCode);
    final defaultColor = isUsd ? const Color(0xFF059669) : AppColors.primary;

    return InkWell(
      onTap: () => _showEditTotalDialog(
        context: context,
        currencyCode: currencyCode,
        originalSubtotal: originalSubtotal,
        currentTotal: currentTotal,
        hasCustomTotal: hasCustomTotal,
      ),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: hasCustomTotal
              ? Colors.amber.withValues(alpha: 0.12)
              : defaultColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasCustomTotal
                ? Colors.amber.shade700
                : defaultColor.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasCustomTotal) ...[
              Text(
                '${originalSubtotal.toStringAsFixed(2)} ',
                style: AppTheme.numericStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ).copyWith(decoration: TextDecoration.lineThrough),
              ),
            ],
            Text(
              '${currentTotal.toStringAsFixed(2)} $currencySymbol',
              style: AppTheme.numericStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: hasCustomTotal ? Colors.amber.shade900 : defaultColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit_outlined,
              size: 14,
              color: hasCustomTotal ? Colors.amber.shade800 : defaultColor,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDebt = state.paymentType == 'debt';
    final hasNoCustomerOnDebt = isDebt && state.selectedCustomer == null;

    final totalSummary = state.hasMultipleCurrencies
        ? '${state.totalUsd > 0 ? '${state.totalUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}' : ''}'
          '${state.totalUsd > 0 && state.totalSyp > 0 ? ' + ' : ''}'
          '${state.totalSyp > 0 ? '${state.totalSyp.toStringAsFixed(2)} ${AppCurrency.sypSymbol}' : ''}'
        : '${state.totalAmount.toStringAsFixed(2)} ${state.cartCurrencySymbol}';

    String checkoutButtonLabel;
    if (isDebt) {
      if (state.selectedCustomer != null) {
        checkoutButtonLabel =
            '${'pos.checkout_debt'.tr()} ($totalSummary)';
      } else {
        checkoutButtonLabel = 'pos.select_customer_first'.tr();
      }
    } else {
      checkoutButtonLabel =
          '${'pos.checkout_cash'.tr()} ($totalSummary)';
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Calculation Summary Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Subtotal
                if (state.hasMultipleCurrencies)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'pos.subtotal'.tr()}:',
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (state.subtotalUsd > 0)
                            Text(
                              '${state.subtotalUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}',
                              style: AppTheme.numericStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          if (state.subtotalSyp > 0)
                            Text(
                              '${state.subtotalSyp.toStringAsFixed(2)} ${AppCurrency.sypSymbol}',
                              style: AppTheme.numericStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${'pos.subtotal'.tr()}:',
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                      Text(
                        '${state.cartSubtotal.toStringAsFixed(2)} ${state.cartCurrencySymbol}',
                        style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                const Divider(height: 16, color: AppColors.border),

                // Net Total
                if (state.hasMultipleCurrencies)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${'pos.net_total'.tr()}:',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (state.subtotalUsd > 0 || state.hasCustomTotalUsd)
                            _buildEditableTotalChip(
                              context: context,
                              currencyCode: AppCurrency.usdCode,
                              originalSubtotal: state.subtotalUsd,
                              currentTotal: state.totalUsd,
                              hasCustomTotal: state.hasCustomTotalUsd,
                            ),
                          if ((state.subtotalUsd > 0 || state.hasCustomTotalUsd) &&
                              (state.subtotalSyp > 0 || state.hasCustomTotalSyp))
                            const SizedBox(height: 6),
                          if (state.subtotalSyp > 0 || state.hasCustomTotalSyp)
                            _buildEditableTotalChip(
                              context: context,
                              currencyCode: AppCurrency.sypCode,
                              originalSubtotal: state.subtotalSyp,
                              currentTotal: state.totalSyp,
                              hasCustomTotal: state.hasCustomTotalSyp,
                            ),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${'pos.net_total'.tr()}:',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      _buildEditableTotalChip(
                        context: context,
                        currencyCode: state.cartCurrency,
                        originalSubtotal: state.cartSubtotal,
                        currentTotal: state.cartCurrency == AppCurrency.usdCode ? state.totalUsd : state.totalSyp,
                        hasCustomTotal: state.cartCurrency == AppCurrency.usdCode ? state.hasCustomTotalUsd : state.hasCustomTotalSyp,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Payment Method Selector
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment<String>(
                  value: 'cash',
                  label: Text('pos.cash'.tr(), overflow: TextOverflow.ellipsis),
                  icon: const Icon(Icons.payments_outlined, size: 16),
                ),
                ButtonSegment<String>(
                  value: 'debt',
                  label: Text('pos.debt'.tr(), overflow: TextOverflow.ellipsis),
                  icon: const Icon(Icons.assignment_ind_outlined, size: 16),
                ),
              ],
              selected: {state.paymentType},
              onSelectionChanged: (selection) {
                onPaymentTypeChanged(selection.first);
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primary,
                selectedForegroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Customer Selector
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${'pos.customer'.tr()}:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hasNoCustomerOnDebt ? AppColors.danger : AppColors.textPrimary,
                    ),
                  ),
                  if (state.selectedCustomer != null)
                    InkWell(
                      onTap: () => onCustomerChanged(null),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close, size: 13, color: AppColors.danger),
                            const SizedBox(width: 2),
                            Text(
                              'pos.walk_in_customer'.tr(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.danger,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: AppSearchableDropdown<Customer?>(
                      key: ValueKey(state.selectedCustomer?.id),
                      value: state.selectedCustomer,
                      hint: 'pos.select_customer'.tr(),
                      fillColor: hasNoCustomerOnDebt
                          ? AppColors.danger.withValues(alpha: 0.05)
                          : AppColors.surface,
                      borderColor: hasNoCustomerOnDebt ? AppColors.danger : AppColors.border,
                      prefixIcon: Icon(
                        state.selectedCustomer == null ? Icons.person_outline : Icons.person,
                        color: state.selectedCustomer == null
                            ? AppColors.textSecondary
                            : AppColors.primary,
                        size: 18,
                      ),
                      itemSearchText: (c) {
                        if (c == null) return 'pos.walk_in_customer'.tr();
                        final phone = c.phone ?? '';
                        final notes = c.notes ?? '';
                        return '${c.name} $phone $notes';
                      },
                      searchMatchFn: (item, searchValue) {
                        if (item.value == null) {
                          final q = searchValue.trim().toLowerCase();
                          return q.isEmpty || 'pos.walk_in_customer'.tr().toLowerCase().contains(q);
                        }
                        final c = item.value!;
                        final rawQuery = searchValue.trim().toLowerCase();
                        if (rawQuery.isEmpty) return true;
                        final normalizedQuery = rawQuery
                            .replaceAll('٠', '0')
                            .replaceAll('١', '1')
                            .replaceAll('٢', '2')
                            .replaceAll('٣', '3')
                            .replaceAll('٤', '4')
                            .replaceAll('٥', '5')
                            .replaceAll('٦', '6')
                            .replaceAll('٧', '7')
                            .replaceAll('٨', '8')
                            .replaceAll('٩', '9');

                        final nameMatch = c.name.toLowerCase().contains(rawQuery) ||
                            c.name.toLowerCase().contains(normalizedQuery);
                        final phoneMatch = c.phone != null &&
                            (c.phone!.toLowerCase().contains(rawQuery) ||
                                c.phone!.toLowerCase().contains(normalizedQuery));
                        final notesMatch = c.notes != null &&
                            c.notes!.toLowerCase().contains(rawQuery);
                        return nameMatch || phoneMatch || notesMatch;
                      },
                      items: [
                        DropdownMenuItem<Customer?>(
                          value: null,
                          child: Text(
                            'pos.walk_in_customer'.tr(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...state.customers.map((c) {
                          final hasPhone = c.customer.phone != null &&
                              c.customer.phone!.trim().isNotEmpty;
                          return DropdownMenuItem<Customer?>(
                            value: c.customer,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          c.customer.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (hasPhone) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: AppColors.primary.withValues(alpha: 0.2),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            c.customer.phone!.trim(),
                                            style: AppTheme.numericStyle(
                                              fontSize: 11,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (c.totalDebt > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      c.totalDebt.toStringAsFixed(1),
                                      style: AppTheme.numericStyle(
                                        fontSize: 11,
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: onCustomerChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (state.selectedCustomer != null && onEditCustomerPressed != null)
                    IconButton(
                      tooltip: 'customers.edit_customer'.tr(),
                      icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => onEditCustomerPressed!(state.selectedCustomer!),
                    )
                  else
                    IconButton(
                      tooltip: 'customers.add_customer'.tr(),
                      icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: onAddCustomerPressed,
                    ),
                ],
              ),
              if (state.selectedCustomer?.notes != null &&
                  state.selectedCustomer!.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1.5),
                        child: Icon(
                          Icons.sticky_note_2_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          state.selectedCustomer!.notes!.trim(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (hasNoCustomerOnDebt) ...[
                const SizedBox(height: 4),
                Text(
                  'pos.debt_select_customer_hint'.tr(),
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Checkout Action Button
          PrimaryButton(
            label: checkoutButtonLabel,
            icon: isDebt ? Icons.assignment_turned_in_rounded : Icons.check_circle_outline_rounded,
            onPressed: (state.cart.isEmpty || hasNoCustomerOnDebt) ? null : onCheckoutPressed,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}
