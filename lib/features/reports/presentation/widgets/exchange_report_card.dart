import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/features/currency_exchange/presentation/widgets/new_exchange_dialog.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';

class ExchangeReportCard extends StatelessWidget {
  const ExchangeReportCard({
    super.key,
    required this.drawerData,
    this.onExchangeRecorded,
  });

  final CashDrawerReportData drawerData;
  final VoidCallback? onExchangeRecorded;

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF0284C7);

    final beforeSyp = drawerData.balanceBeforeSyp;
    final beforeUsd = drawerData.balanceBeforeUsd;

    final netExSyp = drawerData.netExchangeSyp;
    final netExUsd = drawerData.netExchangeUsd;

    final afterSyp = drawerData.balanceAfterSyp;
    final afterUsd = drawerData.balanceAfterUsd;

    final count = drawerData.exchangeCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tealColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: tealColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.currency_exchange, color: tealColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'reports.exchange_card_title'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        count > 0
                            ? '$count ${'reports.exchange_operations_count'.tr()}'
                            : 'reports.no_exchanges_in_period'.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text('reports.new_exchange_btn'.tr()),
                style: FilledButton.styleFrom(
                  backgroundColor: tealColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final res = await NewExchangeDialog.show(context);
                  if (res != null) {
                    onExchangeRecorded?.call();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3 Accounting Stages (Before Exchange -> Net Exchange Impact -> After Exchange)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              final beforeCard = _buildStageCard(
                title: 'reports.balance_before_exchange'.tr(),
                subtitle: 'reports.balance_before_exchange_desc'.tr(),
                sypAmount: beforeSyp,
                usdAmount: beforeUsd,
                icon: Icons.account_balance_wallet_outlined,
                baseColor: AppColors.primary,
                showSign: false,
              );

              final impactCard = _buildImpactCard(
                sypNet: netExSyp,
                usdNet: netExUsd,
                sypIn: drawerData.exchangeInSyp,
                sypOut: drawerData.exchangeOutSyp,
                usdIn: drawerData.exchangeInUsd,
                usdOut: drawerData.exchangeOutUsd,
              );

              final afterCard = _buildStageCard(
                title: 'reports.balance_after_exchange'.tr(),
                subtitle: 'reports.balance_after_exchange_desc'.tr(),
                sypAmount: afterSyp,
                usdAmount: afterUsd,
                icon: Icons.check_circle_outline,
                baseColor: const Color(0xFF059669),
                isHighlighted: true,
                showSign: false,
              );

              if (isNarrow) {
                return Column(
                  children: [
                    beforeCard,
                    const SizedBox(height: 12),
                    impactCard,
                    const SizedBox(height: 12),
                    afterCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: beforeCard),
                  const SizedBox(width: 12),
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: impactCard),
                  const SizedBox(width: 12),
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: afterCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStageCard({
    required String title,
    required String subtitle,
    required double sypAmount,
    required double usdAmount,
    required IconData icon,
    required Color baseColor,
    bool isHighlighted = false,
    bool showSign = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlighted ? baseColor.withValues(alpha: 0.07) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted ? baseColor.withValues(alpha: 0.4) : AppColors.border,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: baseColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isHighlighted ? baseColor : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${showSign && sypAmount > 0 ? '+' : ''}${sypAmount.toStringAsFixed(2)} ${AppCurrency.primarySymbol}',
            style: AppTheme.numericStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? baseColor : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${showSign && usdAmount > 0 ? '+' : ''}${usdAmount.toStringAsFixed(2)} \$',
            style: AppTheme.numericStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF059669),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactCard({
    required double sypNet,
    required double usdNet,
    required double sypIn,
    required double sypOut,
    required double usdIn,
    required double usdOut,
  }) {
    const teal = Color(0xFF0284C7);
    final sypColor = sypNet > 0 ? AppColors.success : (sypNet < 0 ? AppColors.danger : AppColors.textPrimary);
    final usdColor = usdNet > 0 ? AppColors.success : (usdNet < 0 ? AppColors.danger : AppColors.textPrimary);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: teal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_alt, size: 18, color: teal),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'reports.exchange_net_impact'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${sypNet >= 0 ? '+' : ''}${sypNet.toStringAsFixed(2)} ${AppCurrency.primarySymbol}',
                style: AppTheme.numericStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: sypColor,
                ),
              ),
              if (sypIn > 0 || sypOut > 0)
                Text(
                  '+${sypIn.toStringAsFixed(0)} / -${sypOut.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${usdNet >= 0 ? '+' : ''}${usdNet.toStringAsFixed(2)} \$',
                style: AppTheme.numericStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: usdColor,
                ),
              ),
              if (usdIn > 0 || usdOut > 0)
                Text(
                  '+${usdIn.toStringAsFixed(1)} / -${usdOut.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'reports.exchange_impact_desc'.tr(),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
