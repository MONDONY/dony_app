import 'dart:async';

import 'package:dony/app/router.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/analytics_consent_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Branche le tracking sur le cycle de vie d'authentification.
///
/// Utilise directement [FirebaseAuth.instance.authStateChanges()] pour éviter
/// toute dépendance au context/BlocProvider (AuthBloc est un factory GetIt,
/// non accessible depuis MaterialApp.builder de façon fiable).
class AnalyticsConsentGate extends StatefulWidget {
  const AnalyticsConsentGate({required this.child, super.key});

  final Widget child;

  @override
  State<AnalyticsConsentGate> createState() => _AnalyticsConsentGateState();
}

class _AnalyticsConsentGateState extends State<AnalyticsConsentGate> {
  StreamSubscription<User?>? _authSub;
  bool _prompted = false;
  bool _prompting = false;

  AnalyticsService get _analytics => getIt<AnalyticsService>();

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);

    // authStateChanges() est un broadcast stream : si l'utilisateur est déjà
    // connecté au moment du mount, le stream ne rejoue pas l'état courant.
    // On vérifie currentUser directement après le premier frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      // ignore: avoid_print
      print('[Analytics] postFrame currentUser=${user?.uid ?? 'null'}');
      if (user != null) _onAuthChanged(user);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _onAuthChanged(User? user) {
    // ignore: avoid_print
    print('[Analytics] authStateChanged: user=${user?.uid ?? 'null'}');
    if (user != null) {
      unawaited(_analytics.identify(user.uid));
      unawaited(_maybePrompt(user.uid));
    } else {
      unawaited(_analytics.reset());
    }
  }

  Future<void> _maybePrompt(String userId) async {
    // ignore: avoid_print
    print('[Analytics] _maybePrompt: prompted=$_prompted prompting=$_prompting '
        'configured=${_analytics.isConfigured} hasAnswered=${_analytics.hasAnswered}');
    if (_prompted || _prompting || !_analytics.isConfigured || _analytics.hasAnswered) {
      return;
    }
    _prompting = true;

    // GoRouter n'a pas encore créé son Navigator au premier frame.
    // On attend jusqu'à 2 s que le navigatorKey soit prêt.
    BuildContext? navContext;
    for (var i = 0; i < 40; i++) {
      navContext = appRouter.routerDelegate.navigatorKey.currentContext;
      // ignore: avoid_print
      if (i == 0) print('[Analytics] navContext check #$i: ${navContext != null ? 'ready' : 'null'}');
      if (navContext != null) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _prompting = false;
    if (navContext == null) {
      // ignore: avoid_print
      print('[Analytics] navContext still null after 2s → aborting');
      return;
    }

    // ignore: avoid_print
    print('[Analytics] showing consent sheet…');
    _prompted = true;
    final granted = await AnalyticsConsentSheet.show(navContext);
    // ignore: avoid_print
    print('[Analytics] consent sheet closed: granted=$granted');
    if (granted) {
      await _analytics.identify(userId);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
