import 'package:small_mall/core/utils/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

class PeriodFilterRow extends StatelessWidget {

  const PeriodFilterRow({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onSelectDateRange,
  });
  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onSelectDateRange;

  @override
  Widget build(BuildContext context) {
    final startStr = DateFormat('yyyy/MM/dd').format(startDate);
    final endStr = DateFormat('yyyy/MM/dd').format(endDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            'الفترة المحددة: من $startStr إلى $endStr',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onSelectDateRange,
            icon: const Icon(Icons.edit_calendar, color: AppColors.primary),
            label: const Text('تعديل الفترة', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
