import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/utils/theme.dart';

class TreasuryVaultCards extends StatelessWidget {
  const TreasuryVaultCards({
    super.key,
    required this.vaultBalanceSyp,
    required this.vaultBalanceUsd,
    required this.onCashIn,
    required this.onCashOut,
    required this.onExchange,
    this.onRefresh,
  });

  final double vaultBalanceSyp;
  final double vaultBalanceUsd;
  final VoidCallback onCashIn;
  final VoidCallback onCashOut;
  final VoidCallback onExchange;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'treasury.main_treasury_title'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'treasury.main_treasury_subtitle'.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'common.retry'.tr(),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Two Equal Hero Vault Cards: SYP & USD
          Row(
            children: [
              // SYP Vault Card
              Expanded(
                child: _buildVaultHeroCard(
                  title: 'treasury.vault_syp'.tr(),
                  amountText: '${vaultBalanceSyp.toStringAsFixed(0)} ${AppCurrency.sypSymbol}',
                  currencyCode: AppCurrency.sypCode,
                  icon: Icons.money,
                  gradientColors: [
                    const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                    const Color(0xFF3B82F6).withValues(alpha: 0.04),
                  ],
                  borderColor: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  accentColor: const Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(width: 16),
              // USD Vault Card
              Expanded(
                child: _buildVaultHeroCard(
                  title: 'treasury.vault_usd'.tr(),
                  amountText: '\$${vaultBalanceUsd.toStringAsFixed(2)}',
                  currencyCode: AppCurrency.usdCode,
                  icon: Icons.attach_money,
                  gradientColors: [
                    const Color(0xFF065F46).withValues(alpha: 0.08),
                    const Color(0xFF10B981).withValues(alpha: 0.04),
                  ],
                  borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                  accentColor: const Color(0xFF047857),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick Action Toolbar
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Cash In Button
              ElevatedButton.icon(
                onPressed: onCashIn,
                icon: const Icon(Icons.arrow_downward, size: 16),
                label: Text('treasury.deposit_cash_btn'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // Cash Out Button
              ElevatedButton.icon(
                onPressed: onCashOut,
                icon: const Icon(Icons.arrow_upward, size: 16),
                label: Text('treasury.withdraw_cash_btn'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // Currency Exchange Button
              OutlinedButton.icon(
                onPressed: onExchange,
                icon: const Icon(Icons.currency_exchange, size: 16),
                label: Text('treasury.exchange_currency_btn'.tr()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVaultHeroCard({
    required String title,
    required String amountText,
    required String currencyCode,
    required IconData icon,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      currencyCode,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                amountText,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
        ],
      ),
    );
  }
}
