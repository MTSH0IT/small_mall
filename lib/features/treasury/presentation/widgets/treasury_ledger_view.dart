import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/features/treasury/data/models/treasury_ledger_item.dart';

class TreasuryLedgerView extends StatelessWidget {
  const TreasuryLedgerView({
    super.key,
    required this.ledger,
    required this.selectedTypeFilter,
    required this.selectedCurrencyFilter,
    required this.searchQuery,
    required this.startDate,
    required this.endDate,
    required this.onTypeFilterChanged,
    required this.onCurrencyFilterChanged,
    required this.onSearchChanged,
    required this.onSelectDateRange,
    required this.onClearDateRange,
  });

  final List<TreasuryLedgerItem> ledger;
  final String selectedTypeFilter;
  final String selectedCurrencyFilter;
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<String> onTypeFilterChanged;
  final ValueChanged<String> onCurrencyFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSelectDateRange;
  final VoidCallback onClearDateRange;

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController(text: searchQuery);
    searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: searchController.text.length),
    );

    // Calculate totals for filtered ledger
    double totalInSyp = 0.0;
    double totalOutSyp = 0.0;
    double totalInUsd = 0.0;
    double totalOutUsd = 0.0;

    for (final item in ledger) {
      if (item.currency == 'USD') {
        if (item.isCashIn) {
          totalInUsd += item.amount;
        } else {
          totalOutUsd += item.amount;
        }
      } else {
        if (item.isCashIn) {
          totalInSyp += item.amount;
        } else {
          totalOutSyp += item.amount;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Toolbar
          Row(
            children: [
              // Search Input
              Expanded(
                flex: 3,
                child: AppTextField(
                  label: 'treasury.search_transactions'.tr(),
                  hint: 'treasury.search_hint'.tr(),
                  controller: searchController,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: 12),

              // Date Range Picker Button
              OutlinedButton.icon(
                onPressed: onSelectDateRange,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  startDate != null && endDate != null
                      ? '${DateFormat('yyyy/MM/dd').format(startDate!)} - ${DateFormat('yyyy/MM/dd').format(endDate!)}'
                      : 'reports.all_time'.tr(),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  side: BorderSide(
                    color: startDate != null ? AppColors.primary : AppColors.border,
                  ),
                ),
              ),
              if (startDate != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onClearDateRange,
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'reports.reset_dates'.tr(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Filters Row: Type & Currency Chips + Mini Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  // Movement Type Chips
                  _buildFilterChip(
                    label: 'treasury.all_types'.tr(),
                    selected: selectedTypeFilter == 'all',
                    onSelected: () => onTypeFilterChanged('all'),
                  ),
                  _buildFilterChip(
                    label: 'treasury.inflow'.tr(),
                    selected: selectedTypeFilter == 'in',
                    icon: Icons.arrow_downward,
                    selectedColor: AppColors.success,
                    onSelected: () => onTypeFilterChanged('in'),
                  ),
                  _buildFilterChip(
                    label: 'treasury.outflow'.tr(),
                    selected: selectedTypeFilter == 'out',
                    icon: Icons.arrow_upward,
                    selectedColor: AppColors.danger,
                    onSelected: () => onTypeFilterChanged('out'),
                  ),
                  const SizedBox(width: 12),
                  // Currency Chips
                  _buildFilterChip(
                    label: 'common.all'.tr(),
                    selected: selectedCurrencyFilter == 'all',
                    onSelected: () => onCurrencyFilterChanged('all'),
                  ),
                  _buildFilterChip(
                    label: AppCurrency.sypSymbol,
                    selected: selectedCurrencyFilter == AppCurrency.sypCode,
                    onSelected: () => onCurrencyFilterChanged(AppCurrency.sypCode),
                  ),
                  _buildFilterChip(
                    label: AppCurrency.usdSymbol,
                    selected: selectedCurrencyFilter == AppCurrency.usdCode,
                    onSelected: () => onCurrencyFilterChanged(AppCurrency.usdCode),
                  ),
                ],
              ),

              // Summary Pills
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSummaryPill(
                    label: '${'treasury.inflow'.tr()} (ل.س)',
                    value: '+${totalInSyp.toStringAsFixed(0)}',
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  _buildSummaryPill(
                    label: '${'treasury.outflow'.tr()} (ل.س)',
                    value: '-${totalOutSyp.toStringAsFixed(0)}',
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryPill(
                    label: '${'treasury.inflow'.tr()} (\$)',
                    value: '+\$${totalInUsd.toStringAsFixed(2)}',
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  _buildSummaryPill(
                    label: '${'treasury.outflow'.tr()} (\$)',
                    value: '-\$${totalOutUsd.toStringAsFixed(2)}',
                    color: AppColors.danger,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Ledger Table / List
          Expanded(
            child: ledger.isEmpty
                ? EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'treasury.no_transactions'.tr(),
                    description: 'treasury.no_transactions_desc'.tr(),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            color: AppColors.surface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                _headerCell('treasury.date'.tr(), flex: 3),
                                _headerCell('treasury.movement_type'.tr(), flex: 3),
                                _headerCell('treasury.person_name'.tr(), flex: 4),
                                _headerCell('treasury.serial'.tr(), flex: 2),
                                _headerCell('treasury.inflow'.tr(), flex: 3, align: TextAlign.end),
                                _headerCell('treasury.outflow'.tr(), flex: 3, align: TextAlign.end),
                                _headerCell('treasury.running_balance'.tr(), flex: 4, align: TextAlign.end),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // Table Rows
                          Expanded(
                            child: ListView.separated(
                              itemCount: ledger.length,
                              separatorBuilder: (_, i) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = ledger[index];
                                return _buildLedgerRow(item);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String title, {required int flex, TextAlign align = TextAlign.start}) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        textAlign: align,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildLedgerRow(TreasuryLedgerItem item) {
    final isUsd = item.currency == 'USD';
    final symbol = isUsd ? AppCurrency.usdSymbol : AppCurrency.sypSymbol;
    final runningBalance = isUsd ? item.runningBalanceUsd : item.runningBalanceSyp;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Date & Time
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('yyyy/MM/dd').format(item.date),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  DateFormat('hh:mm a').format(item.date),
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Movement Type Badge
          Expanded(
            flex: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypeBadge(item),
              ],
            ),
          ),

          // Party / Notes / Description
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.partyName ?? item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                if (item.notes != null && item.notes!.isNotEmpty)
                  Text(
                    item.notes!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),

          // Reference Number
          Expanded(
            flex: 2,
            child: Text(
              item.referenceNumber ?? '-',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),

          // Inflow Amount
          Expanded(
            flex: 3,
            child: Text(
              item.isCashIn
                  ? '+${item.amount.toStringAsFixed(isUsd ? 2 : 0)} $symbol'
                  : '-',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: item.isCashIn ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ),

          // Outflow Amount
          Expanded(
            flex: 3,
            child: Text(
              !item.isCashIn
                  ? '-${item.amount.toStringAsFixed(isUsd ? 2 : 0)} $symbol'
                  : '-',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: !item.isCashIn ? AppColors.danger : AppColors.textSecondary,
              ),
            ),
          ),

          // Running Balance
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${runningBalance.toStringAsFixed(isUsd ? 2 : 0)} $symbol',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: runningBalance >= 0 ? AppColors.textPrimary : AppColors.danger,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(TreasuryLedgerItem item) {
    Color color;
    IconData icon;
    String label = item.title;

    switch (item.type) {
      case 'cash_sale':
        color = AppColors.success;
        icon = Icons.shopping_bag_outlined;
        break;
      case 'return':
        color = AppColors.warning;
        icon = Icons.replay_outlined;
        break;
      case 'debt_payment':
        color = const Color(0xFF0284C7);
        icon = Icons.handshake_outlined;
        break;
      case 'expense':
        color = AppColors.danger;
        icon = Icons.receipt_long_outlined;
        break;
      case 'purchase':
        color = const Color(0xFF9333EA);
        icon = Icons.local_shipping_outlined;
        break;
      case 'exchange':
        color = const Color(0xFF0D9488);
        icon = Icons.currency_exchange;
        break;
      case 'treasury_in':
        color = AppColors.success;
        icon = Icons.arrow_downward;
        break;
      case 'treasury_out':
        color = AppColors.danger;
        icon = Icons.arrow_upward;
        break;
      default:
        color = AppColors.primary;
        icon = Icons.account_balance_wallet_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    IconData? icon,
    Color? selectedColor,
  }) {
    final activeColor = selectedColor ?? AppColors.primary;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor.withValues(alpha: 0.15) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? activeColor : AppColors.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
