import 'dart:async';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_keypad.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

/// Détermine la route à suivre après la création du PIN, selon l'état du
/// consentement analytics.
///
/// Réconcilie d'abord avec le backend (source de vérité) si l'utilisateur n'a
/// pas de réponse locale : sans ce sync, un utilisateur réinstallé (Hive vide,
/// donc `hasAnswered` faux à tort) qui a déjà consenti côté backend serait
/// redemandé — exactement la régression que la persistance backend élimine.
///
/// - Déjà répondu (local ou après sync) → `/auth/referral-code`.
/// - Jamais répondu → `/auth/analytics-consent`, affiché à TOUT nouvel
///   utilisateur au 1er lancement, quel que soit le pays. Le choix reste
///   modifiable ensuite dans Réglages › Confidentialité.
///
/// [prefs] : conservé pour compat de signature (appelants/tests) ; le pays
/// n'est plus discriminant depuis qu'on affiche l'écran partout.
@visibleForTesting
Future<String> resolvePostPinSetupRoute(
  AnalyticsService analytics,
  Box<dynamic> prefs,
) async {
  if (analytics.isConfigured && !analytics.hasAnswered) {
    await analytics.syncFromBackend();
  }
  if (analytics.isConfigured && !analytics.hasAnswered) {
    return '/auth/analytics-consent';
  }
  return '/auth/referral-code';
}

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
        unawaited(
          getIt<AnalyticsService>().logEvent(AnalyticsEvents.signupCompleted),
        );
        final route = await resolvePostPinSetupRoute(
          getIt<AnalyticsService>(),
          getIt<HiveService>().userPrefs,
        );
        if (mounted) context.go(route);
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
                const SizedBox(height: DonySpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: DonyStepPill(current: 3, total: 3, label: 'Code PIN'),
                ),
                // Zone haute scrollable : mascotte + titre uniquement
                // (sacrifiables si l'écran est court). Le step indicator et
                // surtout les points du PIN restent ÉPINGLÉS au-dessus du
                // keypad — ils sont le retour visuel de la saisie et ne doivent
                // jamais passer sous le pli (sinon le champ semble absent).
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildHeader(cs, tt),
                            const SizedBox(height: DonySpacing.xl),
                            _buildStepIndicator(cs),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: DonySpacing.xl),
                _buildPinDots(cs),
                const SizedBox(height: DonySpacing.xl),
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
