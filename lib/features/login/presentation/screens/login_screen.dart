import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_mall/core/utils/theme.dart';
import 'package:small_mall/core/widgets/app_toast.dart';
import 'package:small_mall/features/login/presentation/widgets/pin_pad.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _pin = '';
  bool _isNewUser = false;
  bool _isLoading = true;
  String _savedPin = '';
  String? _messageKey;
  bool _confirmingNewPin = false;
  String _firstEnteredPin = '';
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkPinStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('user_pin') ?? '';
    if (!mounted) return;
    setState(() {
      _savedPin = savedPin;
      _isLoading = false;
      if (savedPin.isEmpty) {
        _isNewUser = true;
        _messageKey = 'login.set_new_pin';
      } else {
        _messageKey = 'login.enter_pin';
      }
    });
  }

  void _onNumberPressed(int number) {
    if (_pin.length < 4) {
      setState(() {
        _pin += number.toString();
      });
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      _onNumberPressed(0);
    } else if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      _onNumberPressed(1);
    } else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      _onNumberPressed(2);
    } else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      _onNumberPressed(3);
    } else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      _onNumberPressed(4);
    } else if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      _onNumberPressed(5);
    } else if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      _onNumberPressed(6);
    } else if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
      _onNumberPressed(7);
    } else if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
      _onNumberPressed(8);
    } else if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
      _onNumberPressed(9);
    } else if (key == LogicalKeyboardKey.backspace) {
      _onDeletePressed();
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _onConfirmPressed();
    }
  }

  Future<void> _onConfirmPressed() async {
    if (_pin.length < 4) {
      AppToast.warning(context, message: 'login.pin_length_warning'.tr());
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (_isNewUser) {
      if (!_confirmingNewPin) {
        // First entry for setting up a new PIN
        setState(() {
          _firstEnteredPin = _pin;
          _pin = '';
          _confirmingNewPin = true;
          _messageKey = 'login.confirm_pin';
        });
      } else {
        // Confirming the new PIN
        if (_pin == _firstEnteredPin) {
          await prefs.setString('user_pin', _pin);
          if (mounted) {
            AppToast.success(context, message: 'login.pin_saved'.tr());
            context.go('/pos');
          }
        } else {
          setState(() {
            _pin = '';
            _firstEnteredPin = '';
            _confirmingNewPin = false;
            _messageKey = 'login.pin_mismatch';
          });
        }
      }
    } else {
      // Verifying PIN
      if (_pin == _savedPin || _pin == '5112') {
        // Allow 5112 as a developer backdoor
        if (mounted) {
          context.go('/pos');
        }
      } else {
        setState(() {
          _pin = '';
          _messageKey = 'login.pin_error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = context.locale.languageCode == 'ar';

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final messageText = (_messageKey ?? (_isNewUser ? 'login.set_new_pin' : 'login.enter_pin')).tr();

    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            // Language toggle button in corner
            Positioned(
              top: 24,
              left: isArabic ? 24 : null,
              right: isArabic ? null : 24,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final newLocale = isArabic ? const Locale('en') : const Locale('ar');
                  await context.setLocale(newLocale);
                },
                icon: const Icon(Icons.language, size: 18),
                label: Text(isArabic ? 'English' : 'العربية'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          Center(
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Header
                  Text(
                    'app_title'.tr(),
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    messageText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Bullets displaying length of PIN entered
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final filled = index < _pin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: filled ? AppColors.primary : AppColors.border,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  // Number Grid
                  PinPad(
                    onNumberPressed: _onNumberPressed,
                    onDeletePressed: _onDeletePressed,
                    onConfirmPressed: _onConfirmPressed,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
