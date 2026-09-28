import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Set<String> _extractKeyPaths(Map<String, dynamic> map, [String prefix = '']) {
  final keys = <String>{};
  for (final entry in map.entries) {
    final fullKey = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    if (entry.value is Map<String, dynamic>) {
      keys.addAll(_extractKeyPaths(entry.value as Map<String, dynamic>, fullKey));
    } else {
      keys.add(fullKey);
    }
  }
  return keys;
}

void main() {
  late Map<String, dynamic> arMap;
  late Map<String, dynamic> enMap;

  setUpAll(() {
    final arFile = File('assets/translations/ar.json');
    final enFile = File('assets/translations/en.json');

    expect(arFile.existsSync(), isTrue, reason: 'ar.json must exist');
    expect(enFile.existsSync(), isTrue, reason: 'en.json must exist');

    final arContent = arFile.readAsStringSync();
    final enContent = enFile.readAsStringSync();

    arMap = json.decode(arContent) as Map<String, dynamic>;
    enMap = json.decode(enContent) as Map<String, dynamic>;
  });

  test('ar.json and en.json exist and are valid JSON', () {
    expect(arMap.isNotEmpty, isTrue);
    expect(enMap.isNotEmpty, isTrue);

    // Verify top-level namespaces
    expect(arMap.containsKey('settings'), isTrue);
    expect(enMap.containsKey('settings'), isTrue);
    expect(arMap.containsKey('nav'), isTrue);
    expect(enMap.containsKey('nav'), isTrue);
    expect(arMap.containsKey('pos'), isTrue);
    expect(enMap.containsKey('pos'), isTrue);
    expect(arMap.containsKey('invoices'), isTrue);
    expect(enMap.containsKey('invoices'), isTrue);
    expect(arMap.containsKey('reports'), isTrue);
    expect(enMap.containsKey('reports'), isTrue);
  });

  test('All keys in ar.json match en.json symmetrically (zero missing translations)', () {
    final arKeys = _extractKeyPaths(arMap);
    final enKeys = _extractKeyPaths(enMap);

    final missingInEn = arKeys.difference(enKeys);
    final missingInAr = enKeys.difference(arKeys);

    expect(
      missingInEn,
      isEmpty,
      reason: 'Keys present in ar.json but missing in en.json: $missingInEn',
    );
    expect(
      missingInAr,
      isEmpty,
      reason: 'Keys present in en.json but missing in ar.json: $missingInAr',
    );
  });

  test('Verify newly added currency exchange and repricing keys are present and translated', () {
    final requiredKeys = [
      'settings.reprice_products_title',
      'settings.reprice_products_desc',
      'settings.reprice_products_btn',
      'settings.reprice_no_rate_warning',
      'settings.reprice_dialog_title',
      'settings.reprice_dialog_desc',
      'settings.reprice_current_rate',
      'settings.reprice_mode_usd_to_syp',
      'settings.reprice_mode_smart',
      'settings.reprice_mode_syp_to_usd',
      'settings.reprice_confirm_btn',
      'settings.reprice_success',
      'settings.reprice_no_products',
      'inventory.auto_conversion_active',
      'inventory.auto_conversion_paused',
      'inventory.auto_conversion_hint_on',
      'inventory.auto_conversion_hint_off',
      'inventory.syp_prices',
      'inventory.usd_prices',
      'inventory.cost_price_syp',
      'inventory.cost_price_usd',
      'inventory.retail_price_syp',
      'inventory.wholesale_price_syp',
      'inventory.retail_price_usd',
      'inventory.wholesale_price_usd',
      'inventory.syp_and_usd',
      'invoices.exchange',
      'invoices.currency_exchange',
      'invoices.exchange_invoice',
      'invoices.new_exchange',
      'invoices.new_exchange_action',
      'invoices.buy_usd',
      'invoices.sell_usd',
      'invoices.exchange_buy_usd',
      'invoices.exchange_sell_usd',
      'invoices.exchange_rate_label',
      'invoices.exchange_rate_applied',
      'invoices.exchange_rate_unit',
      'invoices.exchange_from_amount',
      'invoices.exchange_to_amount',
      'invoices.paid_amount',
      'invoices.received_amount',
      'invoices.exchange_notes',
      'invoices.exchange_notes_hint',
      'invoices.exchange_impact_preview',
      'invoices.cashbox_syp',
      'invoices.cashbox_usd',
      'invoices.confirm_exchange',
      'invoices.exchange_saved',
      'invoices.edit_exchange_title',
      'invoices.edit_exchange_desc',
      'invoices.save_exchange_changes',
      'invoices.exchange_updated_success',
      'invoices.delete_exchange_confirm_title',
      'invoices.delete_exchange_confirm_msg',
      'invoices.exchange_deleted_success',
      'reports.exchange_card_title',
      'reports.exchange_card_desc',
      'reports.balance_before_exchange',
      'reports.balance_before_exchange_desc',
      'reports.balance_after_exchange',
      'reports.balance_after_exchange_desc',
      'reports.exchange_net_impact',
      'reports.exchange_impact_desc',
      'reports.new_exchange_btn',
      'reports.exchange_operations_count',
      'reports.exchange_in',
      'reports.exchange_out',
      'reports.no_exchanges_in_period',
    ];

    final arKeys = _extractKeyPaths(arMap);
    final enKeys = _extractKeyPaths(enMap);

    for (final key in requiredKeys) {
      expect(arKeys.contains(key), isTrue, reason: 'Key $key missing in ar.json');
      expect(enKeys.contains(key), isTrue, reason: 'Key $key missing in en.json');
    }
  });
}
