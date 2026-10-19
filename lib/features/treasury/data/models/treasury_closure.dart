import 'package:small_mall/features/treasury/data/models/cash_denominations.dart';

/// End-of-Day Treasury Closure & Cash Reconciliation Record (Z-Report)
class TreasuryClosure {
  TreasuryClosure({
    required this.id,
    this.serialNumber,
    required this.closedAt,
    this.openingBalanceSyp = 0.0,
    this.openingBalanceUsd = 0.0,
    this.totalInSyp = 0.0,
    this.totalInUsd = 0.0,
    this.totalOutSyp = 0.0,
    this.totalOutUsd = 0.0,
    required this.expectedBalanceSyp,
    required this.expectedBalanceUsd,
    required this.actualBalanceSyp,
    required this.actualBalanceUsd,
    required this.differenceSyp,
    required this.differenceUsd,
    required this.denominations,
    this.notes,
    required this.status,
  });

  factory TreasuryClosure.fromMap(Map<String, dynamic> map) {
    return TreasuryClosure(
      id: map['id'] as String,
      serialNumber: map['serial_number'] as int?,
      closedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['closed_at'] as num).toInt(),
      ),
      openingBalanceSyp: (map['opening_balance_syp'] as num?)?.toDouble() ?? 0.0,
      openingBalanceUsd: (map['opening_balance_usd'] as num?)?.toDouble() ?? 0.0,
      totalInSyp: (map['total_in_syp'] as num?)?.toDouble() ?? 0.0,
      totalInUsd: (map['total_in_usd'] as num?)?.toDouble() ?? 0.0,
      totalOutSyp: (map['total_out_syp'] as num?)?.toDouble() ?? 0.0,
      totalOutUsd: (map['total_out_usd'] as num?)?.toDouble() ?? 0.0,
      expectedBalanceSyp: (map['expected_balance_syp'] as num?)?.toDouble() ?? 0.0,
      expectedBalanceUsd: (map['expected_balance_usd'] as num?)?.toDouble() ?? 0.0,
      actualBalanceSyp: (map['actual_balance_syp'] as num?)?.toDouble() ?? 0.0,
      actualBalanceUsd: (map['actual_balance_usd'] as num?)?.toDouble() ?? 0.0,
      differenceSyp: (map['difference_syp'] as num?)?.toDouble() ?? 0.0,
      differenceUsd: (map['difference_usd'] as num?)?.toDouble() ?? 0.0,
      denominations: CashDenominations.fromJsonStrings(
        sypJson: map['denominations_syp_json'] as String?,
        usdJson: map['denominations_usd_json'] as String?,
      ),
      notes: map['notes'] as String?,
      status: map['status'] as String? ?? 'balanced',
    );
  }

  final String id;
  final int? serialNumber;
  final DateTime closedAt;
  final double openingBalanceSyp;
  final double openingBalanceUsd;
  final double totalInSyp;
  final double totalInUsd;
  final double totalOutSyp;
  final double totalOutUsd;
  final double expectedBalanceSyp;
  final double expectedBalanceUsd;
  final double actualBalanceSyp;
  final double actualBalanceUsd;
  final double differenceSyp; // positive = surplus, negative = shortage
  final double differenceUsd;
  final CashDenominations denominations;
  final String? notes;
  final String status; // 'balanced', 'shortage', 'surplus'

  bool get isBalanced => status == 'balanced';
  bool get isShortage => status == 'shortage';
  bool get isSurplus => status == 'surplus';

  Map<String, dynamic> toMap() => {
        'id': id,
        'serial_number': serialNumber,
        'closed_at': closedAt.millisecondsSinceEpoch,
        'opening_balance_syp': openingBalanceSyp,
        'opening_balance_usd': openingBalanceUsd,
        'total_in_syp': totalInSyp,
        'total_in_usd': totalInUsd,
        'total_out_syp': totalOutSyp,
        'total_out_usd': totalOutUsd,
        'expected_balance_syp': expectedBalanceSyp,
        'expected_balance_usd': expectedBalanceUsd,
        'actual_balance_syp': actualBalanceSyp,
        'actual_balance_usd': actualBalanceUsd,
        'difference_syp': differenceSyp,
        'difference_usd': differenceUsd,
        'denominations_syp_json': denominations.toJsonSyp(),
        'denominations_usd_json': denominations.toJsonUsd(),
        'notes': notes,
        'status': status,
      };
}
