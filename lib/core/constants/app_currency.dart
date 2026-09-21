/// Centralized Currency Configuration System
///
/// Provides a single source of truth for all currency definitions, symbols,
/// names, formatting, and options across the entire application.
class CurrencyDefinition {
  const CurrencyDefinition({
    required this.code,
    required this.symbol,
    required this.nameAr,
    required this.nameEn,
    this.isPrimary = false,
  });

  /// The standard international or system code (e.g. 'SYP', 'USD')
  final String code;

  /// The short display symbol (e.g. 'ل.س', '$')
  final String symbol;

  /// Arabic localized display name
  final String nameAr;

  /// English localized display name
  final String nameEn;

  /// Whether this is the store's primary / base accounting currency
  final bool isPrimary;
}

class AppCurrency {
  AppCurrency._();

  /// 1. Primary Base Currency: Syrian Pound (ل.س)
  /// Can be modified in this single place if the store's base currency ever changes.
  static const CurrencyDefinition primary = CurrencyDefinition(
    code: 'SYP',
    symbol: 'ل.س',
    nameAr: 'ليرة سورية',
    nameEn: 'Syrian Pound',
    isPrimary: true,
  );

  /// 2. Secondary Currency: US Dollar ($)
  /// Available as a currency option for products in the same pattern.
  static const CurrencyDefinition secondary = CurrencyDefinition(
    code: 'USD',
    symbol: '\$',
    nameAr: 'دولار أمريكي',
    nameEn: 'US Dollar',
    isPrimary: false,
  );

  /// List of all supported currencies in the system
  static const List<CurrencyDefinition> allCurrencies = [
    primary,
    secondary,
  ];

  static const String defaultCode = 'SYP';
  static const String defaultSymbol = 'ل.س';

  static String get primaryCode => primary.code;
  static String get primarySymbol => primary.symbol;
  static String get baseCode => primary.code;
  static String get baseSymbol => primary.symbol;

  static String get secondaryCode => secondary.code;
  static String get secondarySymbol => secondary.symbol;

  static String get sypCode => primary.code;
  static String get sypSymbol => primary.symbol;
  static String get usdCode => secondary.code;
  static String get usdSymbol => secondary.symbol;

  /// Resolve a currency definition by code, defaulting to primary if null or unrecognized
  static CurrencyDefinition fromCode(String? code) {
    if (code == null || code.trim().isEmpty) return primary;
    final upper = code.trim().toUpperCase();
    if (upper == secondary.code || upper == 'USD' || upper == '\$' || upper == 'دولار') {
      return secondary;
    }
    if (upper == primary.code || upper == 'SYP' || upper == 'ل.س' || upper == 'ليرة') {
      return primary;
    }
    return primary;
  }

  /// Get currency symbol by code
  static String getSymbol(String? code) => fromCode(code).symbol;

  /// Format an amount with its currency symbol
  static String format(double amount, {String? currencyCode, int decimals = 2}) {
    final def = fromCode(currencyCode);
    return '${amount.toStringAsFixed(decimals)} ${def.symbol}';
  }
}
