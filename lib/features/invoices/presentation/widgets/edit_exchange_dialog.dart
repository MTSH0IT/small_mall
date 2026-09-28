import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:small_mall/core/constants/app_currency.dart';
import 'package:small_mall/core/services/app_settings_service.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_text_field.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/core/widgets/primary_button.dart';
import 'package:small_mall/features/invoices/data/invoices_repository.dart';
import 'package:small_mall/features/invoices/presentation/cubit/invoices_cubit.dart';

class EditExchangeDialog extends StatefulWidget {
  const EditExchangeDialog({
    super.key,
    required this.transaction,
    required this.cubit,
  });

  final UnifiedTransactionRecord transaction;
  final InvoicesCubit cubit;

  static Future<void> show(
    BuildContext context,
    UnifiedTransactionRecord transaction,
    InvoicesCubit cubit,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditExchangeDialog(
        transaction: transaction,
        cubit: cubit,
      ),
    );
  }

  @override
  State<EditExchangeDialog> createState() => _EditExchangeDialogState();
}

class _EditExchangeDialogState extends State<EditExchangeDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _actionType; // 'buy_usd' or 'sell_usd'
  late final TextEditingController _fromAmountController;
  late final TextEditingController _toAmountController;
  late final TextEditingController _rateController;
  late final TextEditingController _notesController;
  late DateTime _selectedDate;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final raw = widget.transaction.rawExchangeInvoice;
    _actionType = raw?.actionType ?? 'buy_usd';

    final rate = raw?.exchangeRate ?? AppSettingsService.usdExchangeRate;
    _rateController = TextEditingController(
      text: rate > 0
          ? (rate % 1 == 0 ? rate.toInt().toString() : rate.toString())
          : '',
    );

    final fromAmt = raw?.fromAmount ?? widget.transaction.totalAmount;
    final toAmt = raw?.toAmount ?? 0.0;

    _fromAmountController = TextEditingController(
      text: fromAmt > 0
          ? (_actionType == 'buy_usd'
              ? AppSettingsService.formatSyp(fromAmt)
              : AppSettingsService.formatUsd(fromAmt))
          : '',
    );

    _toAmountController = TextEditingController(
      text: toAmt > 0
          ? (_actionType == 'buy_usd'
              ? AppSettingsService.formatUsd(toAmt)
              : AppSettingsService.formatSyp(toAmt))
          : '',
    );

    _notesController = TextEditingController(text: raw?.notes ?? widget.transaction.notes ?? '');
    _selectedDate = raw?.createdAt ?? widget.transaction.createdAt;
  }

  @override
  void dispose() {
    _fromAmountController.dispose();
    _toAmountController.dispose();
    _rateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _currentRate =>
      AppSettingsService.parseNumber(_rateController.text) ?? 0.0;

  void _onFromChanged(String val) {
    final rate = _currentRate;
    if (rate <= 0) return;
    final amount = AppSettingsService.parseNumber(val);
    if (amount == null || amount <= 0) {
      if (_toAmountController.text.isNotEmpty) _toAmountController.text = '';
      setState(() {});
      return;
    }

    if (_actionType == 'buy_usd') {
      // SYP -> USD: USD = SYP / rate
      final usd = amount / rate;
      final formatted = AppSettingsService.formatUsd(usd);
      if (_toAmountController.text != formatted) {
        _toAmountController.text = formatted;
      }
    } else {
      // USD -> SYP: SYP = USD * rate
      final syp = amount * rate;
      final formatted = AppSettingsService.formatSyp(syp);
      if (_toAmountController.text != formatted) {
        _toAmountController.text = formatted;
      }
    }
    setState(() {});
  }

  void _onToChanged(String val) {
    final rate = _currentRate;
    if (rate <= 0) return;
    final amount = AppSettingsService.parseNumber(val);
    if (amount == null || amount <= 0) {
      if (_fromAmountController.text.isNotEmpty) _fromAmountController.text = '';
      setState(() {});
      return;
    }

    if (_actionType == 'buy_usd') {
      // To is USD -> From is SYP: SYP = USD * rate
      final syp = amount * rate;
      final formatted = AppSettingsService.formatSyp(syp);
      if (_fromAmountController.text != formatted) {
        _fromAmountController.text = formatted;
      }
    } else {
      // To is SYP -> From is USD: USD = SYP / rate
      final usd = amount / rate;
      final formatted = AppSettingsService.formatUsd(usd);
      if (_fromAmountController.text != formatted) {
        _fromAmountController.text = formatted;
      }
    }
    setState(() {});
  }

  void _onRateChanged(String _) {
    _onFromChanged(_fromAmountController.text);
  }

  void _setActionType(String newType) {
    if (_actionType == newType) return;
    setState(() {
      _actionType = newType;
      _fromAmountController.clear();
      _toAmountController.clear();
    });
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      setState(() {
        _selectedDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime?.hour ?? _selectedDate.hour,
          pickedTime?.minute ?? _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final fromAmt = AppSettingsService.parseNumber(_fromAmountController.text);
    final toAmt = AppSettingsService.parseNumber(_toAmountController.text);
    final rate = _currentRate;

    if (fromAmt == null || fromAmt <= 0 || toAmt == null || toAmt <= 0) {
      AppToast.warning(context, message: 'common.required_field'.tr());
      return;
    }
    if (rate <= 0) {
      AppToast.warning(context, message: 'settings.reprice_no_rate_warning'.tr());
      return;
    }

    setState(() => _isSaving = true);
    try {
      final fromCurr = _actionType == 'buy_usd' ? AppCurrency.sypCode : AppCurrency.usdCode;
      final toCurr = _actionType == 'buy_usd' ? AppCurrency.usdCode : AppCurrency.sypCode;

      await widget.cubit.updateExchangeInvoice(
        exchangeId: widget.transaction.id,
        actionType: _actionType,
        fromCurrency: fromCurr,
        fromAmount: fromAmt,
        toCurrency: toCurr,
        toAmount: toAmt,
        exchangeRate: rate,
        notes: _notesController.text.trim(),
        createdAt: _selectedDate,
      );

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, message: 'invoices.exchange_updated_success'.tr());
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, message: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.transaction;
    final isBuyUsd = _actionType == 'buy_usd';
    final fromSymbol = isBuyUsd ? AppCurrency.primarySymbol : r'$';
    final toSymbol = isBuyUsd ? r'$' : AppCurrency.primarySymbol;

    final fromVal = AppSettingsService.parseNumber(_fromAmountController.text) ?? 0.0;
    final toVal = AppSettingsService.parseNumber(_toAmountController.text) ?? 0.0;

    final displayId = tr.globalSerialNumber != null
        ? '#${tr.globalSerialNumber}'
        : (tr.serialNumber != null ? '#${tr.serialNumber}' : '#${tr.id.substring(0, 8)}');

    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.currency_exchange_rounded,
              color: Color(0xFF0284C7),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'invoices.edit_exchange_title'.tr(namedArgs: {'id': displayId}),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'invoices.edit_exchange_desc'.tr(),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Direction Switch Buttons
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDirectionTab(
                          isSelected: isBuyUsd,
                          title: 'invoices.buy_usd'.tr(),
                          icon: Icons.south_west_rounded,
                          color: const Color(0xFF059669),
                          onTap: () => _setActionType('buy_usd'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildDirectionTab(
                          isSelected: !isBuyUsd,
                          title: 'invoices.sell_usd'.tr(),
                          icon: Icons.north_east_rounded,
                          color: const Color(0xFF2563EB),
                          onTap: () => _setActionType('sell_usd'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Exchange Rate Row
                AppTextField(
                  label: 'invoices.exchange_rate_applied'.tr(),
                  controller: _rateController,
                  hint: '15000',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: const Icon(Icons.sync_alt_rounded, size: 18, color: AppColors.primary),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Text(
                      'invoices.exchange_rate_unit'.tr(),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  onChanged: _onRateChanged,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'common.required_field'.tr();
                    final parsed = AppSettingsService.parseNumber(v);
                    if (parsed == null || parsed <= 0) return 'common.numeric_only'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 3. From and To Amount Fields
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // From Amount (المبلغ المصروف)
                    Expanded(
                      child: AppTextField(
                        label: 'invoices.paid_amount'.tr(),
                        controller: _fromAmountController,
                        hint: '0.0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        prefixIcon: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          child: Text(
                            fromSymbol,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isBuyUsd ? AppColors.primary : const Color(0xFF059669),
                            ),
                          ),
                        ),
                        onChanged: _onFromChanged,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'common.required_field'.tr();
                          final parsed = AppSettingsService.parseNumber(v);
                          if (parsed == null || parsed <= 0) return 'common.numeric_only'.tr();
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // To Amount (المبلغ المقبوض)
                    Expanded(
                      child: AppTextField(
                        label: 'invoices.received_amount'.tr(),
                        controller: _toAmountController,
                        hint: '0.0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        prefixIcon: const Icon(
                          Icons.arrow_upward_rounded,
                          size: 18,
                          color: AppColors.success,
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          child: Text(
                            toSymbol,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isBuyUsd ? const Color(0xFF059669) : AppColors.primary,
                            ),
                          ),
                        ),
                        onChanged: _onToChanged,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'common.required_field'.tr();
                          final parsed = AppSettingsService.parseNumber(v);
                          if (parsed == null || parsed <= 0) return 'common.numeric_only'.tr();
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Date Picker Row
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(
                          '${'invoices.invoice_date'.tr()}: ${DateFormat('yyyy/MM/dd HH:mm').format(_selectedDate)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Notes
                AppTextField(
                  label: 'invoices.exchange_notes'.tr(),
                  controller: _notesController,
                  hint: 'invoices.exchange_notes_hint'.tr(),
                  prefixIcon: const Icon(Icons.note_alt_outlined, size: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),

                // 6. Impact Preview Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF0284C7)),
                          const SizedBox(width: 6),
                          Text(
                            'invoices.exchange_impact_preview'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'invoices.cashbox_syp'.tr(),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isBuyUsd
                                        ? '- ${AppSettingsService.formatSyp(fromVal)} ${AppCurrency.primarySymbol}'
                                        : '+ ${AppSettingsService.formatSyp(toVal)} ${AppCurrency.primarySymbol}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isBuyUsd ? AppColors.danger : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'invoices.cashbox_usd'.tr(),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isBuyUsd
                                        ? '+ ${AppSettingsService.formatUsd(toVal)} \$'
                                        : '- ${AppSettingsService.formatUsd(fromVal)} \$',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isBuyUsd ? AppColors.success : AppColors.danger,
                                    ),
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
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        PrimaryButton(
          label: 'invoices.save_exchange_changes'.tr(),
          icon: Icons.check_circle_outline_rounded,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _submit,
        ),
      ],
    );
  }

  Widget _buildDirectionTab({
    required bool isSelected,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : AppColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
