import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:dony/features/billing/presentation/widgets/subscription_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

const _kSettle = Duration(milliseconds: 600);

ProSubscriptionModel _sub({
  bool active = true,
  required ProSubscriptionStatus status,
  ProSubscriptionSource? source,
  String? billingCycle,
  DateTime? currentPeriodEnd,
  bool cancelAtPeriodEnd = false,
  DateTime? graceExpiresAt,
}) => ProSubscriptionModel(
  active: active,
  status: status,
  source: source,
  billingCycle: billingCycle,
  currentPeriodEnd: currentPeriodEnd,
  cancelAtPeriodEnd: cancelAtPeriodEnd,
  graceExpiresAt: graceExpiresAt,
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump(_kSettle);
}

void main() {
  setUpAll(() async => initializeDateFormatting('fr'));

  group('SubscriptionStatusCard', () {
    testWidgets(
      'abonnement mensuel actif : statut, rythme mensuel, date de '
      'renouvellement locale',
      (tester) async {
        final currentPeriodEnd = DateTime.utc(2026, 9, 15, 8);
        await _pump(
          tester,
          SubscriptionStatusCard(
            subscription: _sub(
              status: ProSubscriptionStatus.active,
              source: ProSubscriptionSource.stripe,
              billingCycle: 'MONTHLY',
              currentPeriodEnd: currentPeriodEnd,
            ),
          ),
        );

        expect(find.textContaining('Actif'), findsOneWidget);
        expect(find.textContaining('mensuel'), findsOneWidget);
        final expectedDate = DateFormat(
          'd MMMM yyyy',
          'fr',
        ).format(currentPeriodEnd.toLocal());
        expect(find.textContaining(expectedDate), findsOneWidget);
      },
    );

    testWidgets('abonnement annuel actif : le rythme annuel est affiché', (
      tester,
    ) async {
      await _pump(
        tester,
        SubscriptionStatusCard(
          subscription: _sub(
            status: ProSubscriptionStatus.active,
            source: ProSubscriptionSource.stripe,
            billingCycle: 'YEARLY',
            currentPeriodEnd: DateTime.utc(2027, 8, 15),
          ),
        ),
      );

      expect(find.textContaining('annuel'), findsOneWidget);
      expect(
        find.textContaining('mensuel'),
        findsNothing,
        reason:
            'le mensuel et l\'annuel ne doivent jamais cohabiter dans le '
            'même rendu',
      );
    });

    testWidgets(
      'octroi administrateur (billingCycle nul) : aucun rythme de '
      'facturation, aucun prix',
      (tester) async {
        await _pump(
          tester,
          SubscriptionStatusCard(
            subscription: _sub(
              status: ProSubscriptionStatus.active,
              source: ProSubscriptionSource.adminGrant,
            ),
          ),
        );

        expect(find.textContaining('mensuel'), findsNothing);
        expect(find.textContaining('annuel'), findsNothing);
        final texts = tester.widgetList<Text>(find.byType(Text));
        for (final t in texts) {
          expect(
            t.data ?? '',
            isNot(contains('€')),
            reason: 'un accès offert par un admin ne doit jamais afficher '
                'de prix',
          );
        }
      },
    );

    testWidgets('grâce historique : accès gratuit et temporaire', (
      tester,
    ) async {
      await _pump(
        tester,
        SubscriptionStatusCard(
          subscription: _sub(
            status: ProSubscriptionStatus.legacyGrace,
            source: ProSubscriptionSource.legacyFree,
          ),
        ),
      );

      final texts = tester.widgetList<Text>(find.byType(Text));
      final joined = texts.map((t) => t.data ?? '').join(' ');
      expect(joined, contains('gratuit'));
      expect(joined, contains('temporaire'));
    });

    testWidgets('résiliation programmée : dit explicitement, en plus de la '
        'date', (tester) async {
      final currentPeriodEnd = DateTime.utc(2026, 10, 5, 12);
      await _pump(
        tester,
        SubscriptionStatusCard(
          subscription: _sub(
            status: ProSubscriptionStatus.active,
            source: ProSubscriptionSource.stripe,
            billingCycle: 'MONTHLY',
            cancelAtPeriodEnd: true,
            currentPeriodEnd: currentPeriodEnd,
          ),
        ),
      );

      final texts = tester.widgetList<Text>(find.byType(Text));
      final joined = texts.map((t) => t.data ?? '').join(' ');
      expect(joined, contains('ésiliation'));
      final expectedDate = DateFormat(
        'd MMMM yyyy',
        'fr',
      ).format(currentPeriodEnd.toLocal());
      expect(joined, contains(expectedDate));
    });

    testWidgets('onManage nul : aucun bouton de gestion', (tester) async {
      await _pump(
        tester,
        SubscriptionStatusCard(
          subscription: _sub(status: ProSubscriptionStatus.active),
        ),
      );

      expect(find.byType(DonyButton), findsNothing);
    });

    testWidgets('onManage fourni : bouton rendu, rappel appelé au tap', (
      tester,
    ) async {
      var tapped = false;
      await _pump(
        tester,
        SubscriptionStatusCard(
          subscription: _sub(status: ProSubscriptionStatus.active),
          onManage: () => tapped = true,
        ),
      );

      expect(find.byType(DonyButton), findsOneWidget);
      await tester.tap(find.byType(DonyButton));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('aucun tiret cadratin dans les textes rendus', (
      tester,
    ) async {
      for (final sub in [
        _sub(
          status: ProSubscriptionStatus.active,
          billingCycle: 'MONTHLY',
          currentPeriodEnd: DateTime.utc(2026, 9, 15),
        ),
        _sub(
          status: ProSubscriptionStatus.active,
          billingCycle: 'YEARLY',
          currentPeriodEnd: DateTime.utc(2027, 8, 15),
        ),
        _sub(status: ProSubscriptionStatus.legacyGrace),
        _sub(
          status: ProSubscriptionStatus.active,
          cancelAtPeriodEnd: true,
          currentPeriodEnd: DateTime.utc(2026, 10, 5),
        ),
        _sub(status: ProSubscriptionStatus.pastDue),
      ]) {
        await _pump(
          tester,
          SubscriptionStatusCard(subscription: sub, onManage: () {}),
        );

        final texts = tester.widgetList<Text>(find.byType(Text));
        for (final t in texts) {
          expect(t.data ?? '', isNot(contains('—')));
        }
      }
    });
  });
}
