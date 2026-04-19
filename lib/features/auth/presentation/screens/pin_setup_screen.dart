import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_keypad.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
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
  static const _kGreen = Color(0xFF1A6B3C);
  static const _kGreenLight = Color(0xFFEAF5EF);
  static const _kBg = Color(0xFFF8F9FA);

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
          context.go('/kyc');
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
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              _buildHeader(),
              const SizedBox(height: 48),
              _buildStepIndicator(),
              const SizedBox(height: 40),
              _buildPinDots(),
              const Spacer(),
              DonyKeypad(onDigit: _onDigit, onDelete: _onDelete),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: _kGreenLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline, color: _kGreen, size: 32),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            _isConfirming ? 'Confirmez votre code PIN' : 'Créez votre code PIN',
            key: ValueKey(_isConfirming),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isConfirming
              ? 'Saisissez le même code pour confirmer'
              : 'Ce code vous servira à déverrouiller l\'app',
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          textAlign: TextAlign.center,
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04);
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _StepDot(active: true, label: '1'),
        Container(width: 32, height: 2, color: _isConfirming ? _kGreen : Colors.grey.shade300),
        _StepDot(active: _isConfirming, label: '2'),
      ],
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (i) {
        final filled = i < _pin.length;
        final isError = _hasError;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isError
                ? Colors.red.shade400
                : filled
                    ? _kGreen
                    : Colors.grey.shade300,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFF1A6B3C) : Colors.grey.shade200,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey.shade500,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
