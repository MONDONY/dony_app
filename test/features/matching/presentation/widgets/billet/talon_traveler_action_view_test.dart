import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_traveler_action_view.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

Future<GoRouter> _pump(
  WidgetTester tester,
  TalonTravelerAction action, {
  String? travelerName,
  DeliveryWindow? deliveryWindow,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TalonTravelerActionView(
            bidId: 'bid-1',
            action: action,
            travelerName: travelerName,
            deliveryWindow: deliveryWindow,
          ),
        ),
      ),
      GoRoute(
        path: '/tracking/scan',
        builder: (context, state) => const Scaffold(body: Text('SCANNER')),
      ),
      GoRoute(
        path: '/tracking/confirm',
        builder: (context, state) => const Scaffold(body: Text('RECEPTION')),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  return router;
}

void main() {
  testWidgets('mode scan → bouton "Scanner le colis"', (tester) async {
    await _pump(tester, TalonTravelerAction.scan);
    expect(find.text('Lire le QR du colis'), findsOneWidget);
  });

  testWidgets('mode confirmDelivery → bouton "Confirmer la livraison"', (
    tester,
  ) async {
    await _pump(
      tester,
      TalonTravelerAction.confirmDelivery,
      travelerName: 'Abou D.',
    );
    expect(find.text('Confirmer la livraison'), findsOneWidget);
  });

  testWidgets('tap scan → navigue vers /tracking/scan', (tester) async {
    await _pump(tester, TalonTravelerAction.scan);
    await tester.tap(find.text('Lire le QR du colis'));
    await tester.pumpAndSettle();
    expect(find.text('SCANNER'), findsOneWidget);
  });

  testWidgets('tap confirmDelivery → navigue vers /tracking/confirm', (
    tester,
  ) async {
    await _pump(
      tester,
      TalonTravelerAction.confirmDelivery,
      travelerName: 'Abou D.',
    );
    await tester.tap(find.text('Confirmer la livraison'));
    await tester.pumpAndSettle();
    expect(find.text('RECEPTION'), findsOneWidget);
  });

  group('traductions', () {
    testWidgets(
      'en anglais : mode scan → "Scan the parcel QR" et son indication',
      (tester) async {
        useEnglish();
        await _pump(tester, TalonTravelerAction.scan);
        expect(find.text('Scan the parcel QR'), findsOneWidget);
        expect(
          find.text('At drop-off, scan the sender\'s QR.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'en anglais : mode confirmDelivery → "Confirm the delivery" et son indication',
      (tester) async {
        useEnglish();
        await _pump(
          tester,
          TalonTravelerAction.confirmDelivery,
          travelerName: 'Abou D.',
        );
        expect(find.text('Confirm the delivery'), findsOneWidget);
        expect(
          find.text("On arrival, enter the sender's pickup code."),
          findsOneWidget,
        );
      },
    );
  });

  group('confirmDelivery avant le départ (FLUTTER-CB)', () {
    final future = DeliveryWindow(
      departure: DateTime.now().add(const Duration(days: 1)),
      hasTime: true,
    );

    testWidgets('départ à venir : bouton désactivé et explication', (
      tester,
    ) async {
      await _pump(
        tester,
        TalonTravelerAction.confirmDelivery,
        travelerName: 'Abou D.',
        deliveryWindow: future,
      );
      expect(
        tester.widget<DonyButton>(find.byType(DonyButton)).onPressed,
        isNull,
      );
      expect(find.byType(DeliveryLockedHint), findsOneWidget);
      await tester.tap(find.text('Confirmer la livraison'));
      await tester.pumpAndSettle();
      expect(find.text('RECEPTION'), findsNothing);
    });

    testWidgets('mode scan : jamais verrouillé par le départ', (tester) async {
      await _pump(tester, TalonTravelerAction.scan, deliveryWindow: future);
      expect(
        tester.widget<DonyButton>(find.byType(DonyButton)).onPressed,
        isNotNull,
      );
      expect(find.byType(DeliveryLockedHint), findsNothing);
    });
  });
}
