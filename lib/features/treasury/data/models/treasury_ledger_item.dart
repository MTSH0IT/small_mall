import 'package:small_mall/core/constants/app_currency.dart';

/// Item in the unified real-time Treasury Ledger with running balance
class TreasuryLedgerItem {
  TreasuryLedgerItem({
    required this.id,
    required this.title,
    required this.type,
    required this.isCashIn,
    required this.amount,
    required this.date,
    this.currency = AppCurrency.defaultCode,
    this.partyName,
    this.referenceNumber,
    this.notes,
    this.runningBalanceSyp = 0.0,
    this.runningBalanceUsd = 0.0,
  });

  final String id;
  final String title;
  final String type;
  final bool isCashIn;
  final double amount;
  final DateTime date;
  final String currency;
  final String? partyName;
  final String? referenceNumber;
  final String? notes;
  final double runningBalanceSyp;
  final double runningBalanceUsd;

  String get currencySymbol => AppCurrency.getSymbol(currency);
  bool get isUsd => currency == 'USD';
}
