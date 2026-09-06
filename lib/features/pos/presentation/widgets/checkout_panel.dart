import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/database/app_database.dart';
import 'package:small_mall/core/utils/theme.dart';
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
    required this.onCheckoutPressed,
  });

  final POSLoaded state;
  final bool isLoading;
  final ValueChanged<double> onInvoiceDiscountChanged;
  final ValueChanged<String> onPaymentTypeChanged;
  final ValueChanged<Customer?> onCustomerChanged;
  final VoidCallback onAddCustomerPressed;
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
      text: widget.state.invoiceDiscount > 0 ? widget.state.invoiceDiscount.toStringAsFixed(2) : '',
    );
  }

  @override
  void didUpdateWidget(covariant CheckoutPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.invoiceDiscount != widget.state.invoiceDiscount) {
      final current = double.tryParse(_discountController.text) ?? 0.0;
      if (current != widget.state.invoiceDiscount) {
        _discountController.text =
            widget.state.invoiceDiscount > 0 ? widget.state.invoiceDiscount.toStringAsFixed(2) : '';
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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtotal Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${'pos.subtotal'.tr()}:', style: theme.textTheme.bodyMedium),
              Text(
                state.cartSubtotal.toStringAsFixed(2),
                style: AppTheme.numericStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Discount total field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${'pos.discount_amount'.tr()}:', style: theme.textTheme.bodyMedium),
              SizedBox(
                width: 120,
                height: 38,
                child: TextField(
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.end,
                  style: AppTheme.numericStyle(fontSize: 14),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    hintText: '0.00',
                  ),
                  onChanged: (val) {
                    final discount = double.tryParse(val) ?? 0.0;
                    widget.onInvoiceDiscountChanged(discount);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Payment type toggle (stacked to prevent horizontal overflow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${'pos.payment_method'.tr()}:',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
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
            ],
          ),
          const SizedBox(height: 12),
          // Customer selector (stacked with empty/walk-in state and quick clear)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${'pos.customer'.tr()}:',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  if (state.selectedCustomer != null)
                    InkWell(
                      onTap: () => widget.onCustomerChanged(null),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close, size: 14, color: AppColors.danger),
                            const SizedBox(width: 4),
                            Text(
                              'pos.walk_in_customer'.tr(),
                              style: const TextStyle(
                                fontSize: 12,
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
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Customer?>(
                      key: ValueKey(state.selectedCustomer?.id),
                      initialValue: state.selectedCustomer,
                      isExpanded: true,
                      hint: Text('pos.select_customer'.tr(), overflow: TextOverflow.ellipsis),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        prefixIcon: Icon(
                          state.selectedCustomer == null ? Icons.person_outline : Icons.person,
                          color: state.selectedCustomer == null ? AppColors.textSecondary : AppColors.primary,
                          size: 20,
                        ),
                      ),
                      items: [
                        // Empty / Default Walk-in Customer Option
                        DropdownMenuItem<Customer?>(
                          value: null,
                          child: Text(
                            'pos.walk_in_customer'.tr(),
                            style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Registered Customers List
                        ...state.customers.map((c) {
                          return DropdownMenuItem<Customer?>(
                            value: c.customer,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(c.customer.name, overflow: TextOverflow.ellipsis),
                                ),
                                if (c.totalDebt > 0)
                                  Text(
                                    ' (${c.totalDebt.toStringAsFixed(1)})',
                                    style: AppTheme.numericStyle(
                                      fontSize: 12,
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: widget.onCustomerChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'customers.add_customer'.tr(),
                    icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
                    onPressed: widget.onAddCustomerPressed,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 16),
          // Total Amount Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${'pos.net_total'.tr()}:',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              Text(
                state.totalAmount.toStringAsFixed(2),
                style: AppTheme.numericStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Checkout Button
          PrimaryButton(
            label: state.paymentType == 'debt' ? 'pos.checkout_debt'.tr() : 'pos.checkout_cash'.tr(),
            icon: Icons.check,
            onPressed: widget.onCheckoutPressed,
            isLoading: widget.isLoading,
          ),
        ],
      ),
    );
  }
}
