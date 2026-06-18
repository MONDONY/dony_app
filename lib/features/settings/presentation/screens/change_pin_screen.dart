import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_keypad.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

enum _PinStep { verifyOld, enterNew, confirmNew }

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key, required this.authService});
  final LocalAuthService authService;

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  static const _pinLength = 6;
  static const _maxAttempts = 3;

  _PinStep _step = _PinStep.verifyOld;
  String _pin = '';
  String? _newPin;
  bool _hasError = false;
  String _errorMessage = '';
  int _attemptsLeft = _maxAttempts;

  void _onDigit(String d) {
    if (_pin.length >= _pinLength) {
      return;
    }
    setState(() {
      _pin += d;
      _hasError = false;
    });
    if (_pin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 150), _handleComplete);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) {
      return;
    }
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _handleComplete() async {
    switch (_step) {
      case _PinStep.verifyOld:
        final valid = await widget.authService.validatePin(_pin);
        if (!mounted) {
          return;
        }
        if (valid) {
          setState(() {
            _step = _PinStep.enterNew;
            _pin = '';
            _attemptsLeft = _maxAttempts;
          });
        } else {
          _attemptsLeft--;
          if (_attemptsLeft <= 0) {
            if (mounted) {
              context.pop();
            }
            return;
          }
          setState(() {
            _hasError = true;
            _errorMessage = 'Code incorrect';
            _pin = '';
          });
        }
      case _PinStep.enterNew:
        setState(() {
          _newPin = _pin;
          _step = _PinStep.confirmNew;
          _pin = '';
        });
      case _PinStep.confirmNew:
        if (_pin == _newPin) {
          await widget.authService.savePin(_pin);
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code PIN modifié'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop(true);
        } else {
          setState(() {
            _hasError = true;
            _errorMessage = 'Les codes ne correspondent pas';
            _step = _PinStep.enterNew;
            _newPin = null;
            _pin = '';
          });
        }
    }
  }

  String get _subtitle => switch (_step) {
    _PinStep.verifyOld => 'Saisissez votre code actuel',
    _PinStep.enterNew => 'Créez votre nouveau code',
    _PinStep.confirmNew => 'Confirmez le nouveau code',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Modifier le code PIN'),
      body: SafeArea(
        child: DonyLayout.constrained(
          context,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
            child: Column(
              children: [
                // Zone haute scrollable : évite que le keypad (~356px) +
                // titre + dots dépassent l'écran sur petit device / gros
                // text scale (mode overflow corrigé identique au pin_setup).
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: DonySpacing.xl),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                _subtitle,
                                key: ValueKey(_step),
                                style: tt.headlineLarge?.copyWith(
                                  color: cs.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.lg),
                            _buildStepIndicator(cs),
                            const SizedBox(height: DonySpacing.xxl),
                            _buildPinDots(cs),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              child: _hasError
                                  ? Padding(
                                      padding: const EdgeInsets.only(
                                        top: DonySpacing.md,
                                      ),
                                      child: Text(
                                        _errorMessage,
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.error,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ).animate().fadeIn(duration: 200.ms),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                DonyKeypad(onDigit: _onDigit, onDelete: _onDelete),
                SizedBox(height: DonySpacing.xxl + bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme cs) {
    final steps = [_PinStep.verifyOld, _PinStep.enterNew, _PinStep.confirmNew];
    final current = steps.indexOf(_step);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Ligne de connexion
          return Container(
            width: 32,
            height: 2,
            color: i ~/ 2 < current ? cs.primary : cs.outline,
          );
        }
        final idx = i ~/ 2;
        final active = idx <= current;
        return _StepDot(active: active, label: '${idx + 1}');
      }),
    );
  }

  Widget _buildPinDots(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (i) {
        final filled = i < _pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hasError
                ? cs.error
                : filled
                ? cs.primary
                : cs.outline,
          ),
        );
      }),
    ).animate(target: _hasError ? 1 : 0).shake(duration: 400.ms);
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.active, required this.label});
  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? cs.primary : cs.outline,
      ),
      child: Center(
        child: Text(
          label,
          style: tt.labelMedium?.copyWith(
            color: active ? cs.onPrimary : cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
