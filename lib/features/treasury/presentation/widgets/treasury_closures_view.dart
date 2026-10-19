import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/treasury/data/models/treasury_closure.dart';

class TreasuryClosuresView extends StatelessWidget {
  const TreasuryClosuresView({
    super.key,
    required this.closures,
    required this.onStartClosure,
  });

  final List<TreasuryClosure> closures;
  final VoidCallback onStartClosure;

  void _showClosureDetails(BuildContext context, TreasuryClosure closure) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              '${'treasury.closure_serial'.tr()}: #${closure.serialNumber ?? 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date & Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'treasury.closed_at'.tr(),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      DateFormat('yyyy/MM/dd hh:mm a').format(closure.closedAt),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),

                // SYP Summary
                Text(
                  'treasury.vault_syp'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                _detailRow(
                  'treasury.expected_balance'.tr(),
                  '${closure.expectedBalanceSyp.toStringAsFixed(0)} ${AppCurrency.sypSymbol}',
                ),
                _detailRow(
                  'treasury.actual_counted'.tr(),
                  '${closure.actualBalanceSyp.toStringAsFixed(0)} ${AppCurrency.sypSymbol}',
                ),
                _detailRow(
                  'treasury.difference'.tr(),
                  '${closure.differenceSyp >= 0 ? '+' : ''}${closure.differenceSyp.toStringAsFixed(0)} ${AppCurrency.sypSymbol}',
                  color: closure.differenceSyp == 0
                      ? AppColors.success
                      : (closure.differenceSyp < 0
                          ? AppColors.danger
                          : AppColors.warning),
                ),
                const SizedBox(height: 6),
                _buildDenominationsListSyp(closure),

                const SizedBox(height: 16),
                const Divider(),

                // USD Summary
                Text(
                  'treasury.vault_usd'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                _detailRow(
                  'treasury.expected_balance'.tr(),
                  '${closure.expectedBalanceUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}',
                ),
                _detailRow(
                  'treasury.actual_counted'.tr(),
                  '${closure.actualBalanceUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}',
                ),
                _detailRow(
                  'treasury.difference'.tr(),
                  '${closure.differenceUsd >= 0 ? '+' : ''}${closure.differenceUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}',
                  color: closure.differenceUsd == 0
                      ? AppColors.success
                      : (closure.differenceUsd < 0
                          ? AppColors.danger
                          : AppColors.warning),
                ),
                const SizedBox(height: 6),
                _buildDenominationsListUsd(closure),

                if (closure.notes != null && closure.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  Text(
                    'treasury.notes'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(closure.notes!),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDenominationsListSyp(TreasuryClosure closure) {
    final d = closure.denominations;
    final items = <String>[];
    if (d.syp5000 > 0) items.add('5,000 × ${d.syp5000}');
    if (d.syp2000 > 0) items.add('2,000 × ${d.syp2000}');
    if (d.syp1000 > 0) items.add('1,000 × ${d.syp1000}');
    if (d.syp500 > 0) items.add('500 × ${d.syp500}');

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: items
            .map((item) => Chip(
                  label: Text(item, style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppColors.surfaceElevated,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDenominationsListUsd(TreasuryClosure closure) {
    final d = closure.denominations;
    final items = <String>[];
    if (d.usd100 > 0) items.add('\$100 × ${d.usd100}');
    if (d.usd50 > 0) items.add('\$50 × ${d.usd50}');
    if (d.usd20 > 0) items.add('\$20 × ${d.usd20}');
    if (d.usd10 > 0) items.add('\$10 × ${d.usd10}');
    if (d.usd5 > 0) items.add('\$5 × ${d.usd5}');
    if (d.usd1 > 0) items.add('\$1 × ${d.usd1}');

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: items
            .map((item) => Chip(
                  label: Text(item, style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppColors.surfaceElevated,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (closures.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyStateView(
                icon: Icons.inventory_2_outlined,
                title: 'treasury.no_closures'.tr(),
                description: 'treasury.no_closures_desc'.tr(),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'treasury.reconcile_btn'.tr(),
                icon: Icons.fact_check_outlined,
                onPressed: onStartClosure,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${'treasury.closures_count'.tr()}: ${closures.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              PrimaryButton(
                label: 'treasury.reconcile_btn'.tr(),
                icon: Icons.fact_check_outlined,
                onPressed: onStartClosure,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: closures.length,
              separatorBuilder: (_, i) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final closure = closures[index];
                final isBalanced = closure.isBalanced;
                final isShortage = closure.isShortage;
                final statusColor = isBalanced
                    ? AppColors.success
                    : (isShortage ? AppColors.danger : const Color(0xFFD97706));

                final statusText = isBalanced
                    ? 'treasury.status_balanced'.tr()
                    : (isShortage
                        ? 'treasury.status_shortage'.tr()
                        : 'treasury.status_surplus'.tr());

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppColors.border),
                  ),
                  color: AppColors.surfaceElevated,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showClosureDetails(context, closure),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Serial badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Z-REPORT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  '#${closure.serialNumber ?? index + 1}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Date & Time
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('yyyy/MM/dd hh:mm a')
                                      .format(closure.closedAt),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (closure.notes != null &&
                                    closure.notes!.isNotEmpty)
                                  Text(
                                    closure.notes!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // SYP Actual & Diff
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'treasury.vault_syp'.tr(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${closure.actualBalanceSyp.toStringAsFixed(0)} ${AppCurrency.sypSymbol}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                if (closure.differenceSyp.abs() > 0.01)
                                  Text(
                                    '${closure.differenceSyp >= 0 ? '+' : ''}${closure.differenceSyp.toStringAsFixed(0)} ${AppCurrency.sypSymbol}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: closure.differenceSyp < 0
                                          ? AppColors.danger
                                          : AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // USD Actual & Diff
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'treasury.vault_usd'.tr(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${closure.actualBalanceUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                if (closure.differenceUsd.abs() > 0.01)
                                  Text(
                                    '${closure.differenceUsd >= 0 ? '+' : ''}${closure.differenceUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: closure.differenceUsd < 0
                                          ? AppColors.danger
                                          : AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          const Icon(
                            Icons.chevron_left,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
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
