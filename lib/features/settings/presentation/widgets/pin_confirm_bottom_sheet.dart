import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_keypad.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PinConfirmBottomSheet extends StatefulWidget {
  const PinConfirmBottomSheet({super.key, required this.authService});

  final LocalAuthService authService;

  static Future<bool?> show(
    BuildContext context, {
    required LocalAuthService authService,
  }) {
    return DonyBottomSheet.show<bool>(
      context,
      child: PinConfirmBottomSheet(authService: authService),
    );
  }

  @override
  State<PinConfirmBottomSheet> createState() => _PinConfirmBottomSheetState();
}

class _PinConfirmBottomSheetState extends State<PinConfirmBottomSheet> {
  static const _pinLength = 6;
  static const _maxAttempts = 3;

  String _pin = '';
  bool _hasError = false;
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
      Future.delayed(const Duration(milliseconds: 150), _validate);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) {
      return;
    }
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _validate() async {
    final valid = await widget.authService.validatePin(_pin);
    if (!mounted) {
      return;
    }
    if (valid) {
      Navigator.of(context, rootNavigator: true).pop(true);
      return;
    }
    _attemptsLeft--;
    if (_attemptsLeft <= 0) {
      Navigator.of(context, rootNavigator: true).pop(false);
      return;
    }
    setState(() {
      _hasError = true;
      _pin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DonySpacing.lg),
        Text(
          'Confirmez votre code PIN',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          'Saisissez votre code pour confirmer',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pinLength, (i) {
            final filled = i < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 14,
              height: 14,
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
        ).animate(target: _hasError ? 1 : 0).shake(duration: 400.ms),
        if (_hasError)
          Padding(
            padding: const EdgeInsets.only(top: DonySpacing.sm),
            child: Text(
              '$_attemptsLeft tentative(s) restante(s)',
              style: tt.bodySmall?.copyWith(color: cs.error),
            ).animate().fadeIn(),
          ),
        const SizedBox(height: DonySpacing.xl),
        DonyKeypad(onDigit: _onDigit, onDelete: _onDelete),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + DonySpacing.lg),
      ],
    );
  }
}
