import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_awaiting_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Anneau d'attente du mobile money : chrono `mm:ss` calé sur l'échéance du
/// serveur, rotation coupée quand la réduction du mouvement est active.
void main() {
  Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('affiche le temps restant puis le décompte chaque seconde', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 19, 10);
    await tester.pumpWidget(
      host(
        MobileMoneyAwaitingRing(
          expiresAt: DateTime.utc(2026, 10, 19, 10, 14, 58),
          now: () => now,
        ),
      ),
    );

    expect(find.text('14:58'), findsOneWidget);
    expect(find.text('pour valider'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('14:57'), findsOneWidget);

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    // Anneau qui tourne : sans valeur.
    expect(indicator.value, isNull);
    expect(indicator.strokeWidth, 7);
    expect(
      tester.getSize(find.byKey(const Key('mobile-money-awaiting-ring'))),
      const Size.square(118),
    );
  });

  testWidgets('ring_overOneHour_showsHours : h:mm:ss dès une heure restante', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 10, 19, 10);
    await tester.pumpWidget(
      host(
        MobileMoneyAwaitingRing(
          expiresAt: now.add(
            const Duration(hours: 1, minutes: 59, seconds: 58),
          ),
          now: () => now,
        ),
      ),
    );

    expect(find.text('1:59:58'), findsOneWidget);
  });

  testWidgets('ring_exactlyOneHour_showsHours', (tester) async {
    final now = DateTime.utc(2026, 10, 19, 10);
    await tester.pumpWidget(
      host(
        MobileMoneyAwaitingRing(
          expiresAt: now.add(const Duration(hours: 1)),
          now: () => now,
        ),
      ),
    );

    expect(find.text('1:00:00'), findsOneWidget);
  });

  testWidgets('ring_underOneHour_mmss : 59:59 reste en mm:ss', (tester) async {
    final now = DateTime.utc(2026, 10, 19, 10);
    await tester.pumpWidget(
      host(
        MobileMoneyAwaitingRing(
          expiresAt: now.add(const Duration(minutes: 59, seconds: 59)),
          now: () => now,
        ),
      ),
    );

    expect(find.text('59:59'), findsOneWidget);
  });

  testWidgets('échéance passée : 00:00, jamais négatif', (tester) async {
    await tester.pumpWidget(
      host(
        MobileMoneyAwaitingRing(
          expiresAt: DateTime.utc(2026, 10, 19, 10),
          now: () => DateTime.utc(2026, 10, 19, 10, 3),
        ),
      ),
    );

    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets('nouvelle échéance (demande renvoyée) : chrono recalculé', (
    tester,
  ) async {
    DateTime now() => DateTime.utc(2026, 10, 19, 10);
    await tester.pumpWidget(
      host(
        MobileMoneyAwaitingRing(
          expiresAt: DateTime.utc(2026, 10, 19, 10, 1),
          now: now,
        ),
      ),
    );
    expect(find.text('01:00'), findsOneWidget);

    await tester.pumpWidget(
      host(
        MobileMoneyAwaitingRing(
          expiresAt: DateTime.utc(2026, 10, 19, 10, 15),
          now: now,
        ),
      ),
    );
    expect(find.text('15:00'), findsOneWidget);
  });

  testWidgets('réduction du mouvement : anneau immobile', (tester) async {
    await tester.pumpWidget(
      host(
        MobileMoneyAwaitingRing(
          expiresAt: DateTime.utc(2026, 10, 19, 10, 5),
          now: () => DateTime.utc(2026, 10, 19, 10),
        ),
        disableAnimations: true,
      ),
    );

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, isNotNull);
    expect(find.text('05:00'), findsOneWidget);
    // Immobile : l'arbre se stabilise.
    await tester.pumpAndSettle();
  });
}
