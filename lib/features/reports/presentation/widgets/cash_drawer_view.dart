import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/card_container.dart';
import 'package:small_mall/core/widgets/empty_state_view.dart';
import 'package:small_mall/features/reports/data/reports_repository.dart';

class CashDrawerView extends StatefulWidget {
  const CashDrawerView({
    super.key,
    required this.cashDrawerData,
  });

  final CashDrawerReportData cashDrawerData;

  @override
  State<CashDrawerView> createState() => _CashDrawerViewState();
}

class _CashDrawerViewState extends State<CashDrawerView> {
  String _movementFilter = 'all'; // 'all', 'in', 'out'

  @override
  Widget build(BuildContext context) {
    final currency = 'common.currency'.tr();
    final data = widget.cashDrawerData;

    final filteredMovements = data.movements.where((m) {
      if (_movementFilter == 'in') return m.isCashIn;
      if (_movementFilter == 'out') return !m.isCashIn;
      return true;
    }).toList();

    final totalFlow = data.totalCashIn + data.totalCashOut;
    final inPct = totalFlow > 0 ? (data.totalCashIn / totalFlow).clamp(0.0, 1.0) : 0.5;

    final isSurplus = data.netCashFlow >= 0;
    final statusColor = isSurplus ? AppColors.success : AppColors.danger;
    final statusText = data.netCashFlow == 0
        ? 'reports.cash_balanced'.tr()
        : (isSurplus ? 'reports.cash_surplus'.tr() : 'reports.cash_deficit'.tr());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Cash Drawer Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Title & Net Cash Status Badge
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
                          child: const Icon(Icons.point_of_sale, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'reports.cash_drawer_title'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSurplus ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 3 Big Highlight Columns: Cash In vs Cash Out vs Net Cash Flow
                Row(
                  children: [
                    // A. المقبوضات النقدية (Cash In)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.download, color: AppColors.success, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'reports.cash_in'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '+${data.totalCashIn.toStringAsFixed(2)} $currency',
                              style: AppTheme.numericStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                            const Divider(height: 16, color: AppColors.border),
                            _buildMiniSummaryRow('reports.cash_sales'.tr(), data.cashSales, currency),
                            const SizedBox(height: 4),
                            _buildMiniSummaryRow('reports.debt_collections'.tr(), data.debtPaymentsCollected, currency),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // B. المدفوعات النقدية (Cash Out)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.upload, color: AppColors.danger, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'reports.cash_out'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '-${data.totalCashOut.toStringAsFixed(2)} $currency',
                              style: AppTheme.numericStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.danger,
                              ),
                            ),
                            const Divider(height: 16, color: AppColors.border),
                            _buildMiniSummaryRow('reports.cash_returns'.tr(), data.cashReturns, currency),
                            const SizedBox(height: 4),
                            _buildMiniSummaryRow('reports.expenses_paid'.tr(), data.expensesPaid, currency),
                            const SizedBox(height: 4),
                            _buildMiniSummaryRow('reports.cash_purchases'.tr(), data.cashPurchases, currency),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // C. صافي حركة الصندوق (Net Cash Movement)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_balance_wallet, color: statusColor, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'reports.net_cash_flow'.tr(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${data.netCashFlow >= 0 ? '+' : ''}${data.netCashFlow.toStringAsFixed(2)} $currency',
                              style: AppTheme.numericStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            const Divider(height: 16, color: AppColors.border),
                            Text(
                              '${data.movements.length} ${'invoices.title'.tr()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Proportional Visual Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'reports.cash_flow_indicator'.tr(),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          '${(inPct * 100).toStringAsFixed(0)}% وارد / ${((1 - inPct) * 100).toStringAsFixed(0)}% صادر',
                          style: AppTheme.numericStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 10,
                        child: Row(
                          children: [
                            Expanded(
                              flex: (inPct * 100).toInt().clamp(1, 99),
                              child: Container(color: AppColors.success),
                            ),
                            Expanded(
                              flex: ((1 - inPct) * 100).toInt().clamp(1, 99),
                              child: Container(color: AppColors.danger),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Cash Movements Ledger (كشف الحركات النقدية للصندوق)
          CardContainer(
            title: 'reports.cash_movements_ledger'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filter Buttons Row (All, Inflows, Outflows)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'common.all'.tr()),
                      const SizedBox(width: 8),
                      _buildFilterChip('in', 'reports.cash_in'.tr()),
                      const SizedBox(width: 8),
                      _buildFilterChip('out', 'reports.cash_out'.tr()),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),

                if (filteredMovements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
                    child: EmptyStateView(
                      icon: Icons.receipt_long_outlined,
                      title: 'reports.cash_movements_ledger'.tr(),
                      description: 'reports.no_cash_movements'.tr(),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredMovements.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final item = filteredMovements[index];
                      final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(item.date);
                      final sign = item.isCashIn ? '+' : '-';
                      final itemColor = item.isCashIn ? AppColors.success : AppColors.danger;

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: itemColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            item.isCashIn ? Icons.south_west : Icons.north_east,
                            color: itemColor,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (item.referenceNumber != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  item.referenceNumber!,
                                  style: AppTheme.numericStyle(fontSize: 11, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            if (item.partyName != null) ...[
                              const SizedBox(width: 12),
                              const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                item.partyName!,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                            if (item.notes != null && item.notes!.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.notes!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Text(
                          '$sign${item.amount.toStringAsFixed(2)} $currency',
                          style: AppTheme.numericStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: itemColor,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _movementFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _movementFilter = key),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildMiniSummaryRow(String title, double amount, String currency) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(
          '${amount.toStringAsFixed(1)} $currency',
          style: AppTheme.numericStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
