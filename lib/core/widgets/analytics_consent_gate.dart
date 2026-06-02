import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/analytics_consent_sheet.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Branche le tracking sur le cycle de vie d'authentification :
///
/// - **login** (`AuthAuthenticated`) → `identify(userId)` + demande de
///   consentement la première fois ;
/// - **logout** (`AuthAuthenticated` → `AuthInitial`) → `reset()` pour
///   dissocier la session de l'utilisateur.
///
/// Doit être monté **sous** le `Navigator` de `MaterialApp` (via son `builder`)
/// pour pouvoir présenter le bottom sheet de consentement.
class AnalyticsConsentGate extends StatefulWidget {
  const AnalyticsConsentGate({required this.child, super.key});

  final Widget child;

  @override
  State<AnalyticsConsentGate> createState() => _AnalyticsConsentGateState();
}

class _AnalyticsConsentGateState extends State<AnalyticsConsentGate> {
  bool _prompted = false;

  AnalyticsService get _analytics => getIt<AnalyticsService>();

  @override
  void initState() {
    super.initState();
    // Cas « déjà connecté au démarrage » (session restaurée) : la transition
    // n'est pas captée par le listener, on traite l'état courant après le 1er frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AuthBloc>().state;
      if (state is AuthAuthenticated) {
        _onAuthenticated(state.user.id);
      }
    });
  }

  void _onAuthenticated(String userId) {
    unawaited(_analytics.identify(userId));
    unawaited(_maybePrompt(userId));
  }

  Future<void> _maybePrompt(String userId) async {
    if (_prompted || !_analytics.isConfigured || _analytics.hasAnswered) {
      return;
    }
    _prompted = true;
    if (!mounted) return;
    final granted = await AnalyticsConsentSheet.show(context);
    // Consentement accordé après le login → (re)lier l'identité.
    if (granted) {
      await _analytics.identify(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          curr is AuthAuthenticated ||
          (prev is AuthAuthenticated && curr is AuthInitial),
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          _onAuthenticated(state.user.id);
        } else {
          unawaited(_analytics.reset());
        }
      },
      child: widget.child,
    );
  }
}
