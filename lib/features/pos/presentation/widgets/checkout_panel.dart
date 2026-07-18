import 'package:artisan_gift_manager/core/database/app_database.dart';
import 'package:artisan_gift_manager/core/utils/theme.dart';
import 'package:artisan_gift_manager/core/widgets/primary_button.dart';
import 'package:artisan_gift_manager/features/pos/presentation/cubit/pos_state.dart';
import 'package:flutter/material.dart';

class CheckoutPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtotal Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المجموع الفرعي:', style: theme.textTheme.bodyMedium),
              Text(
                state.cartSubtotal.toStringAsFixed(2),
                style: AppTheme.numericStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Discount total field
          Row(
            children: [
              Text('خصم إضافي:', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppTheme.numericStyle(fontSize: 14),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      hintText: '0.00',
                    ),
                    onChanged: (val) {
                      final discount = double.tryParse(val) ?? 0.0;
                      onInvoiceDiscountChanged(discount);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Payment type toggle
          Row(
            children: [
              Text('طريقة الدفع:', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 16),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'cash',
                      label: Text('نقدي'),
                      icon: Icon(Icons.payments_outlined, size: 16),
                    ),
                    ButtonSegment<String>(
                      value: 'debt',
                      label: Text('آجل / دين'),
                      icon: Icon(Icons.assignment_ind_outlined, size: 16),
                    ),
                  ],
                  selected: {state.paymentType},
                  onSelectionChanged: (selection) {
                    onPaymentTypeChanged(selection.first);
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.primary,
                    selectedForegroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Customer selector (Required for debt, optional for cash)
          Row(
            children: [
              Text('العميل:', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<Customer>(
                  initialValue: state.selectedCustomer,
                  hint: const Text('اختر عميلاً (اختياري)'),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  items: state.customers.map((c) {
                    return DropdownMenuItem<Customer>(
                      value: c.customer,
                      child: Text('${c.customer.name} (دين: ${c.totalDebt.toStringAsFixed(1)})'),
                    );
                  }).toList(),
                  onChanged: onCustomerChanged,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
                onPressed: onAddCustomerPressed,
              )
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 16),
          // Total Amount Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المجموع النهائي:',
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
            label: state.paymentType == 'debt' ? 'تأكيد البيع الآجل' : 'تأكيد البيع النقدي',
            icon: Icons.check,
            onPressed: onCheckoutPressed,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}
