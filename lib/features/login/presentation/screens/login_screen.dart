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

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _isNewUser = false;
  bool _isLoading = true;
  bool _isVerifying = false;
  bool _isError = false;
  String _savedPin = '';
  String? _messageKey;
  String? _errorMessage;
  bool _confirmingNewPin = false;
  String _firstEnteredPin = '';
  final FocusNode _focusNode = FocusNode();

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _checkPinStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
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
    if (_pin.length < 4 && !_isVerifying) {
      final newPin = _pin + number.toString();
      setState(() {
        _pin = newPin;
        _errorMessage = null;
      });

      // Auto-submit when 4th digit is entered
      if (newPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted && _pin.length == 4) {
            _onConfirmPressed();
          }
        });
      }
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty && !_isVerifying) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onClearPressed() {
    if (_pin.isNotEmpty && !_isVerifying) {
      setState(() {
        _pin = '';
        _errorMessage = null;
      });
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || _isVerifying) return;
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
    } else if (key == LogicalKeyboardKey.escape) {
      _onClearPressed();
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _onConfirmPressed();
    }
  }

  Future<void> _onConfirmPressed() async {
    if (_pin.length < 4 || _isVerifying) {
      if (_pin.length < 4) {
        AppToast.warning(context, message: 'login.pin_length_warning'.tr());
      }
      return;
    }

    setState(() => _isVerifying = true);

    final prefs = await SharedPreferences.getInstance();

    if (_isNewUser) {
      if (!_confirmingNewPin) {
        // First entry for setting up a new PIN
        setState(() {
          _firstEnteredPin = _pin;
          _pin = '';
          _confirmingNewPin = true;
          _messageKey = 'login.confirm_pin';
          _isVerifying = false;
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
          _shakeController.forward(from: 0.0);
          setState(() {
            _errorMessage = 'login.pin_mismatch'.tr();
            _pin = '';
            _firstEnteredPin = '';
            _confirmingNewPin = false;
            _messageKey = 'login.set_new_pin';
            _isVerifying = false;
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
        _shakeController.forward(from: 0.0);
        setState(() {
          _errorMessage = 'login.pin_error'.tr();
          _isError = true;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() {
            _pin = '';
            _isError = false;
            _isVerifying = false;
          });
        }
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

    final messageText =
        (_messageKey ?? (_isNewUser ? 'login.set_new_pin' : 'login.enter_pin')).tr();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            // Ambient Background Accent Rings
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.04),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.04),
                ),
              ),
            ),

            // Language switcher in top corner
            Positioned(
              top: 24,
              left: isArabic ? 24 : null,
              right: isArabic ? null : 24,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final newLocale = isArabic ? const Locale('en') : const Locale('ar');
                  await context.setLocale(newLocale);
                },
                icon: const Icon(Icons.language_rounded, size: 18),
                label: Text(
                  isArabic ? 'English' : 'العربية',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceElevated,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),

            // Main Login Card
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  width: 410,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Store / App Icon Header
                      Center(
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // App Title
                      Text(
                        'app_title'.tr(),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),

                      // System Subtitle
                      Text(
                        'login.system_subtitle'.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Instructional Prompt
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          messageText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      // Error message banner
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: AppColors.danger,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // PIN Indicators with Shake Animation
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_shakeAnimation.value, 0),
                            child: child,
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final filled = index < _pin.length;
                            final dotColor = _isError
                                ? AppColors.danger
                                : (filled ? AppColors.primary : Colors.transparent);

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutBack,
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isError
                                      ? AppColors.danger
                                      : (filled ? AppColors.primary : AppColors.border),
                                  width: 2,
                                ),
                                boxShadow: (filled && !_isError)
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Number Keypad
                      PinPad(
                        onNumberPressed: _onNumberPressed,
                        onDeletePressed: _onDeletePressed,
                        onClearPressed: _onClearPressed,
                        onConfirmPressed: _onConfirmPressed,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
