import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/treasury/data/models/cash_denominations.dart';
import 'package:small_mall/features/treasury/data/models/treasury_closure.dart';
import 'package:uuid/uuid.dart';

class TreasuryReconciliationDialog extends StatefulWidget {
  const TreasuryReconciliationDialog({
    super.key,
    required this.expectedBalanceSyp,
    required this.expectedBalanceUsd,
    required this.onSave,
  });

  final double expectedBalanceSyp;
  final double expectedBalanceUsd;
  final Future<void> Function(
    TreasuryClosure closure, {
    required bool createAdjustmentTransactions,
  }) onSave;

  @override
  State<TreasuryReconciliationDialog> createState() =>
      _TreasuryReconciliationDialogState();
}

class _TreasuryReconciliationDialogState
    extends State<TreasuryReconciliationDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _denominations = CashDenominations();
  final _notesController = TextEditingController();

  // Controllers for text inputs of bill counts
  final Map<int, TextEditingController> _sypControllers = {};
  final Map<int, TextEditingController> _usdControllers = {};

  bool _createAdjustment = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    for (final val in [5000, 2000, 1000, 500]) {
      _sypControllers[val] = TextEditingController(text: '0');
    }

    for (final val in [100, 50, 20, 10, 5, 1]) {
      _usdControllers[val] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    for (final c in _sypControllers.values) {
      c.dispose();
    }
    for (final c in _usdControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateSyp(int val, int count) {
    setState(() {
      final safeCount = count < 0 ? 0 : count;
      switch (val) {
        case 5000:
          _denominations.syp5000 = safeCount;
          break;
        case 2000:
          _denominations.syp2000 = safeCount;
          break;
        case 1000:
          _denominations.syp1000 = safeCount;
          break;
        case 500:
          _denominations.syp500 = safeCount;
          break;
      }
      _sypControllers[val]?.text = safeCount.toString();
    });
  }

  void _updateUsd(int val, int count) {
    setState(() {
      final safeCount = count < 0 ? 0 : count;
      switch (val) {
        case 100:
          _denominations.usd100 = safeCount;
          break;
        case 50:
          _denominations.usd50 = safeCount;
          break;
        case 20:
          _denominations.usd20 = safeCount;
          break;
        case 10:
          _denominations.usd10 = safeCount;
          break;
        case 5:
          _denominations.usd5 = safeCount;
          break;
        case 1:
          _denominations.usd1 = safeCount;
          break;
      }
      _usdControllers[val]?.text = safeCount.toString();
    });
  }

  int _getSypCount(int val) {
    switch (val) {
      case 5000:
        return _denominations.syp5000;
      case 2000:
        return _denominations.syp2000;
      case 1000:
        return _denominations.syp1000;
      case 500:
        return _denominations.syp500;
      default:
        return 0;
    }
  }

  int _getUsdCount(int val) {
    switch (val) {
      case 100:
        return _denominations.usd100;
      case 50:
        return _denominations.usd50;
      case 20:
        return _denominations.usd20;
      case 10:
        return _denominations.usd10;
      case 5:
        return _denominations.usd5;
      case 1:
        return _denominations.usd1;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actualSyp = _denominations.totalSyp;
    final diffSyp = actualSyp - widget.expectedBalanceSyp;

    final actualUsd = _denominations.totalUsd;
    final diffUsd = actualUsd - widget.expectedBalanceUsd;

    final hasDifference = diffSyp.abs() > 0.01 || diffUsd.abs() > 0.01;

    String overallStatus = 'balanced';
    if (diffSyp < -0.01 || diffUsd < -0.01) {
      overallStatus = 'shortage';
    } else if (diffSyp > 0.01 || diffUsd > 0.01) {
      overallStatus = 'surplus';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 820,
        height: 740,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header
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
                        Icons.fact_check_outlined,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'treasury.reconcile_dialog_title'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'treasury.reconcile_dialog_subtitle'.tr(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'common.close'.tr(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Dual Expected vs Actual Comparison Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  // SYP Summary Box
                  Expanded(
                    child: _buildCurrencySummaryBox(
                      title: 'treasury.vault_syp'.tr(),
                      symbol: AppCurrency.sypSymbol,
                      expected: widget.expectedBalanceSyp,
                      actual: actualSyp,
                      diff: diffSyp,
                      isUsd: false,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 70,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: AppColors.border,
                  ),
                  // USD Summary Box
                  Expanded(
                    child: _buildCurrencySummaryBox(
                      title: 'treasury.vault_usd'.tr(),
                      symbol: AppCurrency.usdSymbol,
                      expected: widget.expectedBalanceUsd,
                      actual: actualUsd,
                      diff: diffUsd,
                      isUsd: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tab Bar for Currency Denominations
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.money, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${'treasury.denominations_syp'.tr()} (${actualSyp.toStringAsFixed(0)} ${AppCurrency.sypSymbol})',
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.attach_money, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${'treasury.denominations_usd'.tr()} (${actualUsd.toStringAsFixed(2)} ${AppCurrency.usdSymbol})',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Denominations Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSypDenominationsTab(),
                  _buildUsdDenominationsTab(),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Optional auto-adjustment checkbox & Notes
            if (hasDifference)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (overallStatus == 'shortage'
                          ? AppColors.danger
                          : AppColors.warning)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (overallStatus == 'shortage'
                            ? AppColors.danger
                            : AppColors.warning)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _createAdjustment,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() => _createAdjustment = val ?? true);
                      },
                    ),
                    Expanded(
                      child: Text(
                        'treasury.auto_adjustment_checkbox'.tr(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'treasury.closure_notes'.tr(),
                    hint: 'treasury.closure_notes_hint'.tr(),
                    controller: _notesController,
                    prefixIcon: const Icon(Icons.edit_note, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: Text('common.cancel'.tr()),
                ),
                const SizedBox(width: 12),
                PrimaryButton(
                  label: _isSaving
                      ? 'common.loading'.tr()
                      : 'treasury.confirm_closure_btn'.tr(),
                  icon: Icons.check_circle_outline,
                  backgroundColor: AppColors.primary,
                  onPressed: _isSaving ? null : _saveReconciliation,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencySummaryBox({
    required String title,
    required String symbol,
    required double expected,
    required double actual,
    required double diff,
    required bool isUsd,
  }) {
    final isBalanced = diff.abs() <= 0.01;
    final isShortage = diff < -0.01;
    final statusColor = isBalanced
        ? AppColors.success
        : (isShortage ? AppColors.danger : const Color(0xFFD97706));

    final statusText = isBalanced
        ? 'treasury.status_balanced'.tr()
        : (isShortage
            ? '${'treasury.status_shortage'.tr()}: ${diff.abs().toStringAsFixed(isUsd ? 2 : 0)} $symbol'
            : '${'treasury.status_surplus'.tr()}: +${diff.toStringAsFixed(isUsd ? 2 : 0)} $symbol');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'treasury.expected_balance'.tr(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${expected.toStringAsFixed(isUsd ? 2 : 0)} $symbol',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'treasury.actual_counted'.tr(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${actual.toStringAsFixed(isUsd ? 2 : 0)} $symbol',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSypDenominationsTab() {
    final sypBills = [5000, 2000, 1000, 500];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: sypBills.length,
      separatorBuilder: (_, i) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final val = sypBills[index];
        final count = _getSypCount(val);
        final subtotal = count * val;

        return _buildDenominationRow(
          denominationLabel: '$val ${AppCurrency.sypSymbol}',
          subtotalText: '$subtotal ${AppCurrency.sypSymbol}',
          count: count,
          controller: _sypControllers[val]!,
          quickAddSteps: const [10, 50, 100],
          onCountChanged: (newCount) => _updateSyp(val, newCount),
        );
      },
    );
  }

  Widget _buildUsdDenominationsTab() {
    final usdBills = [100, 50, 20, 10, 5, 1];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: usdBills.length,
      separatorBuilder: (_, i) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final val = usdBills[index];
        final count = _getUsdCount(val);
        final subtotal = count * val;

        return _buildDenominationRow(
          denominationLabel: '$val ${AppCurrency.usdSymbol}',
          subtotalText: '$subtotal ${AppCurrency.usdSymbol}',
          count: count,
          controller: _usdControllers[val]!,
          quickAddSteps: const [1, 5, 10],
          onCountChanged: (newCount) => _updateUsd(val, newCount),
        );
      },
    );
  }

  Widget _buildDenominationRow({
    required String denominationLabel,
    required String subtotalText,
    required int count,
    required TextEditingController controller,
    required List<int> quickAddSteps,
    required ValueChanged<int> onCountChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: [
          // Bill badge
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Center(
              child: Text(
                denominationLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Decrement Button
          IconButton(
            onPressed: count > 0 ? () => onCountChanged(count - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            color: AppColors.danger,
          ),

          // Count Text Field
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (val) {
                final parsed = int.tryParse(val) ?? 0;
                onCountChanged(parsed);
              },
            ),
          ),

          // Increment Button
          IconButton(
            onPressed: () => onCountChanged(count + 1),
            icon: const Icon(Icons.add_circle_outline, size: 22),
            color: AppColors.success,
          ),
          const SizedBox(width: 8),

          // Quick Add Steps Buttons
          ...quickAddSteps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(left: 4),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(36, 30),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                onPressed: () => onCountChanged(count + step),
                child: Text('+$step'),
              ),
            ),
          ),

          const Spacer(),

          // Subtotal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '= $subtotalText',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveReconciliation() async {
    setState(() => _isSaving = true);
    try {
      final actualSyp = _denominations.totalSyp;
      final diffSyp = actualSyp - widget.expectedBalanceSyp;

      final actualUsd = _denominations.totalUsd;
      final diffUsd = actualUsd - widget.expectedBalanceUsd;

      String status = 'balanced';
      if (diffSyp < -0.01 || diffUsd < -0.01) {
        status = 'shortage';
      } else if (diffSyp > 0.01 || diffUsd > 0.01) {
        status = 'surplus';
      }

      final closure = TreasuryClosure(
        id: const Uuid().v4(),
        closedAt: DateTime.now(),
        expectedBalanceSyp: widget.expectedBalanceSyp,
        expectedBalanceUsd: widget.expectedBalanceUsd,
        actualBalanceSyp: actualSyp,
        actualBalanceUsd: actualUsd,
        differenceSyp: diffSyp,
        differenceUsd: diffUsd,
        denominations: _denominations,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        status: status,
      );

      await widget.onSave(
        closure,
        createAdjustmentTransactions: _createAdjustment,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
