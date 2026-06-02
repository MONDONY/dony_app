import 'dart:async';

import 'package:dony/app/router.dart';
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
/// Placé dans `MaterialApp.builder` (au-dessus du Navigator), il utilise le
/// `navigatorKey` de GoRouter pour présenter le sheet avec un contexte valide.
class AnalyticsConsentGate extends StatefulWidget {
  const AnalyticsConsentGate({required this.child, super.key});

  final Widget child;

  @override
  State<AnalyticsConsentGate> createState() => _AnalyticsConsentGateState();
}

class _AnalyticsConsentGateState extends State<AnalyticsConsentGate> {
  bool _prompted = false;
  bool _prompting = false;

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
    if (_prompted || _prompting || !_analytics.isConfigured || _analytics.hasAnswered) {
      return;
    }
    _prompting = true;

    // Au premier frame GoRouter n'a pas encore créé le Navigator.
    // On attend jusqu'à 1 s que le navigatorKey soit prêt.
    BuildContext? navContext;
    for (var i = 0; i < 20; i++) {
      navContext = appRouter.routerDelegate.navigatorKey.currentContext;
      if (navContext != null) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _prompting = false;
    if (navContext == null) return;

    _prompted = true;
    final granted = await AnalyticsConsentSheet.show(navContext);
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
