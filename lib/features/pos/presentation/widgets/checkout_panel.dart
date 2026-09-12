import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_searchable_dropdown.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/pos/presentation/cubit/pos_state.dart';

class CheckoutPanel extends StatefulWidget {
  const CheckoutPanel({
    super.key,
    required this.state,
    required this.isLoading,
    required this.onInvoiceDiscountChanged,
    required this.onPaymentTypeChanged,
    required this.onCustomerChanged,
    required this.onAddCustomerPressed,
    this.onEditCustomerPressed,
    required this.onCheckoutPressed,
  });

  final POSLoaded state;
  final bool isLoading;
  final ValueChanged<double> onInvoiceDiscountChanged;
  final ValueChanged<String> onPaymentTypeChanged;
  final ValueChanged<Customer?> onCustomerChanged;
  final VoidCallback onAddCustomerPressed;
  final void Function(Customer)? onEditCustomerPressed;
  final VoidCallback? onCheckoutPressed;

  @override
  State<CheckoutPanel> createState() => _CheckoutPanelState();
}

class _CheckoutPanelState extends State<CheckoutPanel> {
  late TextEditingController _discountController;

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController(
      text: widget.state.invoiceDiscount > 0
          ? widget.state.invoiceDiscount.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void didUpdateWidget(covariant CheckoutPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.invoiceDiscount != widget.state.invoiceDiscount) {
      final current = double.tryParse(_discountController.text) ?? 0.0;
      if (current != widget.state.invoiceDiscount) {
        _discountController.text = widget.state.invoiceDiscount > 0
            ? widget.state.invoiceDiscount.toStringAsFixed(2)
            : '';
      }
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final isDebt = state.paymentType == 'debt';
    final hasNoCustomerOnDebt = isDebt && state.selectedCustomer == null;

    String checkoutButtonLabel;
    if (isDebt) {
      if (state.selectedCustomer != null) {
        checkoutButtonLabel =
            '${'pos.checkout_debt'.tr()} (${state.totalAmount.toStringAsFixed(2)})';
      } else {
        checkoutButtonLabel = 'pos.select_customer_first'.tr();
      }
    } else {
      checkoutButtonLabel =
          '${'pos.checkout_cash'.tr()} (${state.totalAmount.toStringAsFixed(2)})';
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${'pos.subtotal'.tr()}:',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    Text(
                      state.cartSubtotal.toStringAsFixed(2),
                      style: AppTheme.numericStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Extra Invoice Discount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${'pos.invoice_discount'.tr()}:',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    SizedBox(
                      width: 100,
                      height: 32,
                      child: TextField(
                        controller: _discountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.end,
                        style: AppTheme.numericStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          filled: true,
                          fillColor: AppColors.surfaceElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        onChanged: (val) {
                          final discount = double.tryParse(val) ?? 0.0;
                          widget.onInvoiceDiscountChanged(discount);
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16, color: AppColors.border),

                // Net Total
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
                    Text(
                      state.totalAmount.toStringAsFixed(2),
                      style: AppTheme.numericStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
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
                widget.onPaymentTypeChanged(selection.first);
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
                      onTap: () => widget.onCustomerChanged(null),
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
                      onChanged: widget.onCustomerChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (state.selectedCustomer != null && widget.onEditCustomerPressed != null)
                    IconButton(
                      tooltip: 'customers.edit_customer'.tr(),
                      icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => widget.onEditCustomerPressed!(state.selectedCustomer!),
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
                      onPressed: widget.onAddCustomerPressed,
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
            onPressed: (state.cart.isEmpty || hasNoCustomerOnDebt) ? null : widget.onCheckoutPressed,
            isLoading: widget.isLoading,
          ),
        ],
      ),
    );
  }
}
