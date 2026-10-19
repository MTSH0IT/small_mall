import 'dart:convert';

/// Calculator and container for cash bill counts in SYP and USD
class CashDenominations {
  CashDenominations({
    this.syp5000 = 0,
    this.syp2000 = 0,
    this.syp1000 = 0,
    this.syp500 = 0,
    this.usd100 = 0,
    this.usd50 = 0,
    this.usd20 = 0,
    this.usd10 = 0,
    this.usd5 = 0,
    this.usd1 = 0,
  });

  factory CashDenominations.fromJsonStrings({
    String? sypJson,
    String? usdJson,
  }) {
    final result = CashDenominations();
    if (sypJson != null && sypJson.isNotEmpty) {
      try {
        final map = jsonDecode(sypJson) as Map<String, dynamic>;
        result.syp5000 = (map['5000'] as num?)?.toInt() ?? 0;
        result.syp2000 = (map['2000'] as num?)?.toInt() ?? 0;
        result.syp1000 = (map['1000'] as num?)?.toInt() ?? 0;
        result.syp500 = (map['500'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }

    if (usdJson != null && usdJson.isNotEmpty) {
      try {
        final map = jsonDecode(usdJson) as Map<String, dynamic>;
        result.usd100 = (map['100'] as num?)?.toInt() ?? 0;
        result.usd50 = (map['50'] as num?)?.toInt() ?? 0;
        result.usd20 = (map['20'] as num?)?.toInt() ?? 0;
        result.usd10 = (map['10'] as num?)?.toInt() ?? 0;
        result.usd5 = (map['5'] as num?)?.toInt() ?? 0;
        result.usd1 = (map['1'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }

    return result;
  }

  // Syrian Pounds count of bills
  int syp5000;
  int syp2000;
  int syp1000;
  int syp500;

  // US Dollar count of bills
  int usd100;
  int usd50;
  int usd20;
  int usd10;
  int usd5;
  int usd1;

  double get totalSyp =>
      (syp5000 * 5000.0) +
      (syp2000 * 2000.0) +
      (syp1000 * 1000.0) +
      (syp500 * 500.0);

  double get totalUsd =>
      (usd100 * 100.0) +
      (usd50 * 50.0) +
      (usd20 * 20.0) +
      (usd10 * 10.0) +
      (usd5 * 5.0) +
      (usd1 * 1.0);

  Map<String, dynamic> toMapSyp() => {
        '5000': syp5000,
        '2000': syp2000,
        '1000': syp1000,
        '500': syp500,
        'total': totalSyp,
      };

  Map<String, dynamic> toMapUsd() => {
        '100': usd100,
        '50': usd50,
        '20': usd20,
        '10': usd10,
        '5': usd5,
        '1': usd1,
        'total': totalUsd,
      };

  String toJsonSyp() => jsonEncode(toMapSyp());
  String toJsonUsd() => jsonEncode(toMapUsd());
}
