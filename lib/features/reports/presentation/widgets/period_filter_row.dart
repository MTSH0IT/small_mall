import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/utils/theme.dart';

class PeriodFilterRow extends StatelessWidget {
  const PeriodFilterRow({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.activePeriod,
    required this.onSelectPeriod,
    required this.onSelectCustomRange,
    required this.onNavigatePeriod,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String activePeriod;
  final ValueChanged<String> onSelectPeriod;
  final VoidCallback onSelectCustomRange;
  final ValueChanged<int> onNavigatePeriod;

  @override
  Widget build(BuildContext context) {
    final startStr = DateFormat('yyyy/MM/dd').format(startDate);
    final endStr = DateFormat('yyyy/MM/dd').format(endDate);
    final isSameDay = startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day;
    final dateDisplay = isSameDay ? startStr : '$startStr - $endStr';

    final periodOptions = [
      {'key': 'today', 'label': 'reports.period_today'.tr()},
      {'key': 'yesterday', 'label': 'reports.period_yesterday'.tr()},
      {'key': 'this_week', 'label': 'reports.period_this_week'.tr()},
      {'key': 'this_month', 'label': 'reports.period_this_month'.tr()},
      {'key': 'last_month', 'label': 'reports.period_last_month'.tr()},
      {'key': 'custom', 'label': 'reports.period_custom'.tr()},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Chips Row + Date Range Display
          Row(
            children: [
              // Period Options Chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: periodOptions.map((opt) {
                      final isSelected = activePeriod == opt['key'];
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: ChoiceChip(
                          label: Text(opt['label']!),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (opt['key'] == 'custom') {
                              onSelectCustomRange();
                            } else {
                              onSelectPeriod(opt['key']!);
                            }
                          },
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Quick Date Range Navigator (< date >)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'reports.prev_period'.tr(),
                      onPressed: () => onNavigatePeriod(-1),
                    ),
                    InkWell(
                      onTap: onSelectCustomRange,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              dateDisplay,
                              style: AppTheme.numericStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'reports.next_period'.tr(),
                      onPressed: () => onNavigatePeriod(1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
