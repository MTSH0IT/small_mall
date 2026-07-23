import 'package:logger/logger.dart';

import 'log_context.dart';
import 'log_level_config.dart';

class AppLogger {
  AppLogger()
      : _logger = Logger(
          printer: PrettyPrinter(methodCount: 0),
          level: LogLevelConfig.currentLevel,
        );

  final Logger _logger;

  void debug(String message, {LogContext? context}) =>
      _logger.d(_format(message, context));

  void info(String message, {LogContext? context}) =>
      _logger.i(_format(message, context));

  void warning(String message, {LogContext? context}) =>
      _logger.w(_format(message, context));

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    LogContext? context,
  }) =>
      _logger.e(
        _format(message, context),
        error: error,
        stackTrace: stackTrace,
      );

  String _format(String message, LogContext? context) =>
      context != null ? '[${context.name}] $message' : message;
}