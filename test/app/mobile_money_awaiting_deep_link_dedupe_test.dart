import 'dart:async';

import 'package:dony/app/deep_link_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Retour Wave pendant que l'écran d'attente est ouvert : le lien profond
/// visait la route déjà affichée. Poussé une seconde fois, il empilait un
/// second écran et un second bloc (deux `payment_succeeded`, deux
/// snackbars, deux `pop`). L'écran ouvert doit rester seul et continuer de
/// sonder.
void main() {
  const bidId = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';
  const supplementId = '9b2c4d6e-1f3a-4b5c-8d7e-0a1b2c3d4e5f';

  for (final (label, route) in [
    ('colis', '/bids/$bidId/mobile-money/awaiting'),
    (
      'supplément',
      '/bids/$bidId/supplements/$supplementId/mobile-money/awaiting',
    ),
  ]) {
    testWidgets('$label : un seul écran d\'attente, le sondage continue', (
      tester,
    ) async {
      // Écrans d'attente montés (initState - dispose).
      var alive = 0;
      var polls = 0;
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/bids/:bidId/mobile-money/awaiting',
            builder: (_, _) => _PollingProbe(
              onOpen: () => alive++,
              onClose: () => alive--,
              onPoll: () => polls++,
            ),
          ),
          GoRoute(
            path:
                '/bids/:bidId/supplements/:supplementId/mobile-money/awaiting',
            builder: (_, _) => _PollingProbe(
              onOpen: () => alive++,
              onClose: () => alive--,
              onPoll: () => polls++,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      // Câblage identique à `app.dart`.
      final gate = DeepLinkGate(
        currentLocation: () =>
            router.routerDelegate.currentConfiguration.uri.path,
        topLocation: () => topRouteLocation(router),
        navigate: (r) => unawaited(router.push(r)),
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      unawaited(router.push(route));
      await tester.pumpAndSettle();
      expect(alive, 1);

      // Retour de Wave : même route, l'écran est déjà au premier plan.
      gate.dispatch(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(alive, 1);
      expect(find.byType(_PollingProbe), findsOneWidget);
      final before = polls;
      await tester.pump(const Duration(seconds: 10));
      expect(polls, greaterThan(before));

      // Sortie unique : on revient bien à l'accueil.
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  }
}

/// Écran d'attente simplifié : compte ses ouvertures et sonde toutes les
/// 5 s, comme `MobileMoneyAwaitingScreen`.
class _PollingProbe extends StatefulWidget {
  const _PollingProbe({
    required this.onOpen,
    required this.onClose,
    required this.onPoll,
  });

  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onPoll;

  @override
  State<_PollingProbe> createState() => _PollingProbeState();
}

class _PollingProbeState extends State<_PollingProbe> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.onOpen();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => widget.onPoll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('awaiting'));
}
