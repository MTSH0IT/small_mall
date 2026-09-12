import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/loading_indicator.dart';
import 'package:small_mall/core/widgets/price_tag_chip.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/customers_debts/data/customers_debts_repository.dart';

class CustomerDetailsPanel extends StatelessWidget {
  const CustomerDetailsPanel({
    super.key,
    required this.customerData,
    required this.debts,
    required this.onRecordPayment,
    required this.onEditCustomer,
  });

  final CustomerWithDebts customerData;
  final List<DebtWithPayments>? debts;
  final ValueChanged<DebtWithPayments> onRecordPayment;
  final VoidCallback onEditCustomer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Header Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  customerData.customer.name,
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    color: AppColors.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: onEditCustomer,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (customerData.customer.phone != null && customerData.customer.phone!.trim().isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(customerData.customer.phone!.trim(), style: AppTheme.numericStyle()),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${'customers.balance'.tr()}:', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Text(
                          customerData.totalDebt.toStringAsFixed(2),
                          style: AppTheme.numericStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: customerData.totalDebt > 0 ? AppColors.accent : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (customerData.customer.notes != null && customerData.customer.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.sticky_note_2_outlined, size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'common.notes'.tr(),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                customerData.customer.notes!.trim(),
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textPrimary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Debts List
          Text(
            'customers.debt_history'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          if (debts == null)
            LoadingIndicator(message: 'common.loading'.tr())
          else if (debts!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: EmptyStateView(
                icon: Icons.check_circle_outline,
                title: 'customers.no_debts'.tr(),
                description: 'customers.debt_free'.tr(),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: debts!.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final debtData = debts![index];
                final dateStr = DateFormat('yyyy/MM/dd hh:mm a').format(debtData.debt.createdAt);

                final statusStr = debtData.debt.status == 'paid'
                    ? 'customers.settled'.tr()
                    : (debtData.debt.status == 'partial' ? 'customers.partial'.tr() : 'customers.has_debt'.tr());
                final statusColor = debtData.debt.status == 'paid'
                    ? AppColors.success
                    : (debtData.debt.status == 'partial' ? AppColors.primary : AppColors.danger);

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${'pos.debt'.tr()} - $dateStr',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          PriceTagChip(
                            label: statusStr,
                            backgroundColor: statusColor,
                            cutSize: 6,
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.border, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${'common.total'.tr()}:', style: theme.textTheme.labelSmall),
                              Text(debtData.debt.amount.toStringAsFixed(2), style: AppTheme.numericStyle()),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${'suppliers.remaining_amount'.tr()}:', style: theme.textTheme.labelSmall),
                              Text(
                                debtData.debt.remainingAmount.toStringAsFixed(2),
                                style: AppTheme.numericStyle(
                                  fontWeight: FontWeight.bold,
                                  color: debtData.debt.remainingAmount > 0 ? AppColors.accent : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          if (debtData.debt.remainingAmount > 0)
                            PrimaryButton(
                              label: 'customers.record_payment'.tr(),
                              icon: Icons.payments,
                              onPressed: () => onRecordPayment(debtData),
                            ),
                        ],
                      ),
                      if (debtData.payments.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('customers.debt_history'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(height: 4),
                        ...debtData.payments.map((p) {
                          final payDate = DateFormat('yyyy/MM/dd hh:mm a').format(p.paidAt);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(payDate, style: theme.textTheme.labelSmall),
                                Text(
                                  '- ${p.amountPaid.toStringAsFixed(2)}',
                                  style: AppTheme.numericStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
