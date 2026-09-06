import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ar.json and en.json exist and are valid JSON', () {
    final arFile = File('assets/translations/ar.json');
    final enFile = File('assets/translations/en.json');

    expect(arFile.existsSync(), isTrue, reason: 'ar.json must exist');
    expect(enFile.existsSync(), isTrue, reason: 'en.json must exist');

    final arContent = arFile.readAsStringSync();
    final enContent = enFile.readAsStringSync();

    final arMap = json.decode(arContent) as Map<String, dynamic>;
    final enMap = json.decode(enContent) as Map<String, dynamic>;

    expect(arMap.isNotEmpty, isTrue);
    expect(enMap.isNotEmpty, isTrue);

    // Verify top-level namespaces
    expect(arMap.containsKey('settings'), isTrue);
    expect(enMap.containsKey('settings'), isTrue);
    expect(arMap.containsKey('nav'), isTrue);
    expect(enMap.containsKey('nav'), isTrue);
    expect(arMap.containsKey('pos'), isTrue);
    expect(enMap.containsKey('pos'), isTrue);

    // Verify language switcher keys
    final arSettings = arMap['settings'] as Map<String, dynamic>;
    final enSettings = enMap['settings'] as Map<String, dynamic>;

    expect(arSettings.containsKey('language'), isTrue);
    expect(enSettings.containsKey('language'), isTrue);
    expect(arSettings.containsKey('arabic'), isTrue);
    expect(enSettings.containsKey('arabic'), isTrue);
    expect(arSettings.containsKey('english'), isTrue);
    expect(enSettings.containsKey('english'), isTrue);
  });
}
