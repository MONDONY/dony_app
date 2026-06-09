import 'dart:async';

import 'package:dony/core/widgets/dony_keypad.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/local_auth_bloc.dart';
import 'package:dony/features/auth/bloc/local_auth_event.dart';
import 'package:dony/features/auth/bloc/local_auth_state.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';


class LocalAuthScreen extends StatefulWidget {
  /// Mode vérification : l'écran est `push`é pour confirmer l'identité avant
  /// une action sensible (paiement) et doit renvoyer un résultat booléen via
  /// `context.pop(true/false)` — au lieu de naviguer vers `/home` comme lors
  /// du déverrouillage au démarrage.
  final bool verifyMode;

  const LocalAuthScreen({super.key, this.verifyMode = false});

  @override
  State<LocalAuthScreen> createState() => _LocalAuthScreenState();
}

class _LocalAuthScreenState extends State<LocalAuthScreen> {
  static const _pinLength = 6;

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

  /// Déconnecte le compte courant pour permettre la connexion à un autre compte.
  /// Efface le PIN (via [AuthSwitchAccountRequested]) puis renvoie vers le choix
  /// du mode de connexion.
  Future<void> _switchAccount() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer de compte ?'),
        content: const Text(
          'Vous allez être déconnecté de ce compte. Vous devrez vous '
          'reconnecter et reconfigurer votre code PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: cs.primary),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }
    context.read<AuthBloc>().add(const AuthSwitchAccountRequested());
    if (mounted) {
      context.go('/auth/method');
    }
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocConsumer<LocalAuthBloc, LocalAuthState>(
        listener: (context, state) {
          if (state is LocalAuthSuccess) {
            if (widget.verifyMode) {
              context.pop(true);
            } else {
              context.go('/home');
            }
          } else if (state is LocalAuthNoPinSet) {
            if (widget.verifyMode) {
              // Aucun PIN configuré : on ne peut pas vérifier ici. On renvoie
              // un échec ; l'appelant invite l'utilisateur à créer un PIN.
              context.pop(false);
            } else {
              context.go('/auth/pin-setup');
            }
          } else if (state is LocalAuthLocked) {
            _startLockCountdown(state.secondsLeft);
          } else if (state is LocalAuthPinRequired) {
            _lockTimer?.cancel();
            setState(() => _pin = '');
          }
        },
        builder: (context, state) {
          final h = DonyLayout.hPadding(context);
          final bottom = MediaQuery.paddingOf(context).bottom;

          return SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // LayoutBuilder donne la hauteur RÉELLE après SafeArea — fiable.
                final availH = constraints.maxHeight;
                final isCompact = availH < 750;

                final double lockSize = isCompact ? 60 : 80;
                final double logoSize = isCompact ? 48 : 69;
                final double vGapSm  = isCompact ? DonySpacing.xs : DonySpacing.xl;
                final double vGapLg  = isCompact ? DonySpacing.sm : DonySpacing.xxl;
                final double bottomH = isCompact ? DonySpacing.sm : DonySpacing.xxl;

                return DonyLayout.constrained(
                  context,
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: h),
                    child: Column(
                      children: [
                        if (!widget.verifyMode)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _switchAccount,
                              icon: const Icon(Icons.swap_horiz_rounded,
                                  size: 18),
                              label: const Text('Autre compte'),
                              style: TextButton.styleFrom(
                                foregroundColor: cs.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: DonySpacing.md,
                                    vertical: DonySpacing.sm),
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (!isCompact) ...[
                          const DonyMascotteAnimated(
                            type: DonyMascotteType.securise,
                            size: DonyMascotteSize.sm,
                          ),
                          const SizedBox(height: DonySpacing.md),
                        ],
                        _buildLockIcon(state, cs, size: lockSize),
                        SizedBox(height: vGapSm),
                        _buildTitle(cs, logoSize: logoSize),
                        SizedBox(height: vGapLg),
                        _buildPinDots(state, cs),
                        if (state is LocalAuthPinRequired &&
                            state.attemptsLeft < 3)
                          _buildAttemptsWarning(state.attemptsLeft, cs),
                        if (state is LocalAuthLocked) _buildLockMessage(cs),
                        const Spacer(flex: 3),
                        if (state is LocalAuthPinRequired)
                          DonyKeypad(
                            onDigit: _onDigit,
                            onDelete: _onDelete,
                            onBiometric: state.biometricAvailable
                                ? () => context
                                    .read<LocalAuthBloc>()
                                    .add(const LocalAuthBiometricRequested())
                                : null,
                          ),
                        if (state is LocalAuthLocked)
                          DonyKeypad(
                              onDigit: _onDigit,
                              onDelete: _onDelete,
                              enabled: false),
                        if (state is LocalAuthChecking)
                          CircularProgressIndicator(color: cs.primary),
                        SizedBox(height: bottomH + bottom),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLockIcon(LocalAuthState state, ColorScheme cs, {double size = 80}) {
    final isLocked = state is LocalAuthLocked;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isLocked ? cs.errorContainer : cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isLocked ? Icons.lock : Icons.lock_open_outlined,
        color: isLocked ? cs.error : cs.primary,
        size: size * 0.45,
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildTitle(ColorScheme cs, {double logoSize = 69}) {
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        DonyLogo(fontSize: logoSize),
        const SizedBox(height: 10),
        Text(
          'Saisissez votre code PIN',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04);
  }

  Widget _buildPinDots(LocalAuthState state, ColorScheme cs) {
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
                ? cs.error
                : filled
                    ? cs.primary
                    : cs.outline,
            border: Border.all(
              color: filled ? cs.primary : cs.outline,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAttemptsWarning(int attemptsLeft, ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.md),
      child: Text(
        attemptsLeft == 1
            ? 'Dernière tentative avant blocage'
            : '$attemptsLeft tentatives restantes',
        style: tt.bodySmall?.copyWith(
          color: cs.error,
          fontWeight: FontWeight.w500,
        ),
      ).animate().fadeIn(duration: 200.ms).shake(),
    );
  }

  Widget _buildLockMessage(ColorScheme cs) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.base),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.lg,
          vertical: DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: cs.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, color: cs.error, size: 18),
            const SizedBox(width: DonySpacing.sm),
            Text(
              'Réessayez dans $_lockSecondsLeft secondes',
              style: tt.bodySmall?.copyWith(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 200.ms),
    );
  }
}
