import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class LogLevelConfig {
  static Level get currentLevel {
    if (kDebugMode) return Level.debug;
    return Level.warning;
  }
}