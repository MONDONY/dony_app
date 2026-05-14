import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_keypad.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  static const _pinLength = 6;

  String _pin = '';
  String? _firstPin;
  bool _isConfirming = false;
  bool _hasError = false;

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
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _handleComplete() async {
    if (!_isConfirming) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _isConfirming = true;
      });
    } else {
      if (_pin == _firstPin) {
        await getIt<LocalAuthService>().savePin(_pin);
        if (mounted) {
          context.go('/home');
        }
      } else {
        setState(() {
          _hasError = true;
          _pin = '';
        });
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() {
            _hasError = false;
            _firstPin = null;
            _isConfirming = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: DonyLayout.constrained(
          context,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: h),
            child: Column(
              children: [
                const Spacer(flex: 2),
                _buildHeader(cs, tt),
                const Spacer(flex: 2),
                _buildStepIndicator(cs),
                const SizedBox(height: DonySpacing.xxl),
                _buildPinDots(cs),
                const Spacer(flex: 3),
                DonyKeypad(onDigit: _onDigit, onDelete: _onDelete),
                SizedBox(height: DonySpacing.xxl + bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, TextTheme tt) {
    return Column(
      children: [
        DonyMascotteAnimated(
          type: DonyMascotteType.securise,
          size: DonyMascotteSize.md,
          withGlow: _isConfirming,
        ),
        const SizedBox(height: DonySpacing.lg),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            _isConfirming ? 'Confirmez votre code PIN' : 'Créez votre code PIN',
            key: ValueKey(_isConfirming),
            style: tt.headlineLarge?.copyWith(color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          _isConfirming
              ? 'Saisissez le même code pour confirmer'
              : 'Ce code vous servira à déverrouiller l\'app',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04);
  }

  Widget _buildStepIndicator(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _StepDot(active: true, label: '1'),
        Container(
          width: 32,
          height: 2,
          color: _isConfirming ? cs.primary : cs.outline,
        ),
        _StepDot(active: _isConfirming, label: '2'),
      ],
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
