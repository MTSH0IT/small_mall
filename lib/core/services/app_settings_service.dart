import 'package:shared_preferences/shared_preferences.dart';

/// Centralized service to manage app-wide settings such as
/// exchange rates and default product configurations.
class AppSettingsService {
  AppSettingsService._();

  static const String keyExchangeRate = 'settings_usd_exchange_rate';
  static const String keyDefaultMinStock = 'settings_default_min_stock';

  static double _usdExchangeRate = 0.0;
  static double _defaultMinStockAlert = 5.0;

  /// Current cached USD to SYP exchange rate (e.g. 15000.0).
  /// A value <= 0 indicates no active exchange rate.
  static double get usdExchangeRate => _usdExchangeRate;

  /// Whether an active exchange rate is configured.
  static bool get hasExchangeRate => _usdExchangeRate > 0;

  /// Current cached default minimum stock alert quantity (default: 5.0).
  static double get defaultMinStockAlert => _defaultMinStockAlert;

  /// Initialize and load settings into memory from [SharedPreferences].
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _usdExchangeRate = prefs.getDouble(keyExchangeRate) ?? 0.0;
    _defaultMinStockAlert = prefs.getDouble(keyDefaultMinStock) ?? 5.0;
  }

  /// Save updated exchange rate and default min stock alert.
  static Future<void> saveSettings({
    required double exchangeRate,
    required double defaultMinStock,
  }) async {
    _usdExchangeRate = exchangeRate;
    _defaultMinStockAlert = defaultMinStock;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyExchangeRate, exchangeRate);
    await prefs.setDouble(keyDefaultMinStock, defaultMinStock);
  }

  /// Convert USD amount to SYP based on current exchange rate.
  /// Returns 0.0 if exchange rate is not set or amount <= 0.
  static double convertUsdToSyp(double usd) {
    if (_usdExchangeRate <= 0 || usd <= 0) return 0.0;
    return usd * _usdExchangeRate;
  }

  /// Convert SYP amount to USD based on current exchange rate.
  /// Returns 0.0 if exchange rate is not set or amount <= 0.
  static double convertSypToUsd(double syp) {
    if (_usdExchangeRate <= 0 || syp <= 0) return 0.0;
    return syp / _usdExchangeRate;
  }

  /// Format SYP number for display in text fields.
  static String formatSyp(double syp) {
    if (syp <= 0) return '';
    return (syp % 1 == 0) ? syp.toInt().toString() : syp.toStringAsFixed(1);
  }

  /// Format USD number for display in text fields.
  static String formatUsd(double usd) {
    if (usd <= 0) return '';
    return (usd % 1 == 0) ? usd.toInt().toString() : usd.toStringAsFixed(2);
  }

  /// Helper to safely parse localized numeric input (handles Arabic digits and commas)
  static double? parseNumber(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final cleaned = text.trim()
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll(',', '.');
    return double.tryParse(cleaned);
  }
}
