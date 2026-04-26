import 'dart:async';

import 'package:dony/core/widgets/dony_keypad.dart';
import 'package:dony/features/auth/bloc/local_auth_bloc.dart';
import 'package:dony/features/auth/bloc/local_auth_event.dart';
import 'package:dony/features/auth/bloc/local_auth_state.dart';
import 'package:dony/core/constants/app_assets.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';


class LocalAuthScreen extends StatefulWidget {
  const LocalAuthScreen({super.key});

  @override
  State<LocalAuthScreen> createState() => _LocalAuthScreenState();
}

class _LocalAuthScreenState extends State<LocalAuthScreen> {
  static const _pinLength = 6;
  static const _kGreen = DonyColors.blue400;
  static const _kGreenLight = DonyColors.blue100;
  static const _kBg = DonyColors.grey50;

  String _pin = '';
  int _lockSecondsLeft = 30;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalAuthBloc>().add(const LocalAuthStarted());
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_pin.length >= _pinLength) {
      return;
    }
    setState(() => _pin += d);
    if (_pin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 100), _submitPin);
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

  void _submitPin() {
    context.read<LocalAuthBloc>().add(LocalAuthPinSubmitted(_pin));
    setState(() => _pin = '');
  }

  void _startLockCountdown(int seconds) {
    _lockTimer?.cancel();
    setState(() => _lockSecondsLeft = seconds);
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _lockSecondsLeft--);
      if (_lockSecondsLeft <= 0) {
        timer.cancel();
        context.read<LocalAuthBloc>().add(const LocalAuthLockExpired());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: BlocConsumer<LocalAuthBloc, LocalAuthState>(
        listener: (context, state) {
          if (state is LocalAuthSuccess) {
            // PIN correct → accès accordé
            context.go('/home');
          } else if (state is LocalAuthNoPinSet) {
            // Aucun PIN configuré (ex: effacé par ancien logout) → écran de création
            context.go('/auth/pin-setup');
          } else if (state is LocalAuthLocked) {
            _startLockCountdown(state.secondsLeft);
          } else if (state is LocalAuthPinRequired) {
            _lockTimer?.cancel();
            setState(() => _pin = '');
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 56),
                  _buildLockIcon(state),
                  const SizedBox(height: 24),
                  _buildTitle(),
                  const SizedBox(height: 48),
                  _buildPinDots(state),
                  if (state is LocalAuthPinRequired && state.attemptsLeft < 3)
                    _buildAttemptsWarning(state.attemptsLeft),
                  if (state is LocalAuthLocked)
                    _buildLockMessage(),
                  const Spacer(),
                  if (state is LocalAuthPinRequired)
                    DonyKeypad(
                      onDigit: _onDigit,
                      onDelete: _onDelete,
                      onBiometric: state.biometricAvailable
                          ? () => context.read<LocalAuthBloc>().add(const LocalAuthBiometricRequested())
                          : null,
                    ),
                  if (state is LocalAuthLocked)
                    DonyKeypad(onDigit: _onDigit, onDelete: _onDelete, enabled: false),
                  if (state is LocalAuthChecking)
                    const CircularProgressIndicator(color: _kGreen),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLockIcon(LocalAuthState state) {
    final isLocked = state is LocalAuthLocked;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: isLocked ? Colors.red.shade50 : _kGreenLight,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isLocked ? Icons.lock : Icons.lock_open_outlined,
        color: isLocked ? Colors.red.shade400 : _kGreen,
        size: 36,
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Image.asset(AppAssets.logo, height: 70),
        const SizedBox(height: 14),
        const Text(
          'Saisissez votre code PIN',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04);
  }

  Widget _buildPinDots(LocalAuthState state) {
    final isError = state is LocalAuthPinRequired && state.attemptsLeft < 3 && _pin.isEmpty;
    return Row(
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
            color: isError
                ? Colors.red.shade300
                : filled
                    ? _kGreen
                    : Colors.grey.shade300,
            border: Border.all(
              color: filled ? _kGreen : Colors.grey.shade400,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAttemptsWarning(int attemptsLeft) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        attemptsLeft == 1
            ? 'Dernière tentative avant blocage'
            : '$attemptsLeft tentatives restantes',
        style: TextStyle(
          color: Colors.red.shade500,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ).animate().fadeIn(duration: 200.ms).shake(),
    );
  }

  Widget _buildLockMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, color: Colors.red.shade500, size: 18),
            const SizedBox(width: 8),
            Text(
              'Réessayez dans $_lockSecondsLeft secondes',
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 200.ms),
    );
  }
}
