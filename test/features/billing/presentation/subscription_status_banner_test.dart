import 'package:dony/core/design/widgets/dony_status_banner.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:dony/features/billing/presentation/widgets/subscription_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Durée suffisante pour laisser flutter_animate terminer ses délais internes
/// (voir `upgrade_to_pro_screen_test.dart` : un `pumpAndSettle` boucle
/// indéfiniment sur une animation répétée).
const _kSettle = Duration(milliseconds: 600);

ProSubscriptionModel _sub({
  required bool active,
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

  // `subscriptionHasVisibleAlert` est un miroir du `switch` de
  // `SubscriptionStatusBanner`, et deux écrans s'en servent pour décider s'ils
  // doivent réserver de la place au bandeau. Jusqu'ici, cette synchronisation
  // ne reposait que sur un commentaire de chaque côté. Ces tests la
  // verrouillent : ils ne comparent PAS le prédicat à une table de valeurs
  // attendues écrite à la main (elle dériverait avec lui), ils le comparent à
  // ce que le widget rend réellement.
  group('subscriptionHasVisibleAlert', () {
    final cases = <String, ProSubscriptionModel>{
      'pastDue': _sub(active: true, status: ProSubscriptionStatus.pastDue),
      'legacyGrace': _sub(
        active: true,
        status: ProSubscriptionStatus.legacyGrace,
      ),
      'active sans résiliation programmée': _sub(
        active: true,
        status: ProSubscriptionStatus.active,
      ),
      'active avec résiliation programmée': _sub(
        active: true,
        status: ProSubscriptionStatus.active,
        cancelAtPeriodEnd: true,
        currentPeriodEnd: DateTime.utc(2026, 9, 30),
      ),
      'active, résiliation programmée mais sans date': _sub(
        active: true,
        status: ProSubscriptionStatus.active,
        cancelAtPeriodEnd: true,
      ),
      'canceled': _sub(active: false, status: ProSubscriptionStatus.canceled),
      'expired': _sub(active: false, status: ProSubscriptionStatus.expired),
      'none': _sub(active: false, status: ProSubscriptionStatus.none),
      'unknown': _sub(active: false, status: ProSubscriptionStatus.unknown),
    };

    cases.forEach((label, subscription) {
      testWidgets('$label : le prédicat dit exactement ce que le widget rend', (
        tester,
      ) async {
        await _pump(
          tester,
          SubscriptionStatusBanner(subscription: subscription),
        );

        final rendersSomething = find
            .byType(DonyStatusBanner)
            .evaluate()
            .isNotEmpty;
        expect(
          subscriptionHasVisibleAlert(subscription),
          rendersSomething,
          reason:
              'Le prédicat et le rendu du bandeau ont divergé pour « $label ». '
              'Les deux vivent dans le même fichier, ils doivent bouger '
              'ensemble.',
        );
      });
    });

    test('les neuf cas couvrent les sept statuts de l\'énumération', () {
      // Sans ce garde-fou, l'ajout d'un statut à l'énumération laisserait la
      // table ci-dessus incomplète sans que rien ne l'annonce.
      final covered = cases.values.map((s) => s.status).toSet();
      expect(covered, ProSubscriptionStatus.values.toSet());
    });
  });

  group('daysUntil', () {
    test('échéance dans 7 jours pleins rend 7', () {
      final now = DateTime(2026, 1, 1, 10);
      final instant = now.add(const Duration(days: 7));
      expect(daysUntil(instant, now: now), 7);
    });

    test('échéance dans 6 jours et 12 heures arrondit vers le haut à 7', () {
      final now = DateTime(2026, 1, 1, 10);
      final instant = now.add(const Duration(days: 6, hours: 12));
      expect(daysUntil(instant, now: now), 7);
    });

    test('échéance dans 2 heures rend 1', () {
      final now = DateTime(2026, 1, 1, 10);
      final instant = now.add(const Duration(hours: 2));
      expect(daysUntil(instant, now: now), 1);
    });

    test('échéance déjà passée rend 0, jamais un nombre négatif', () {
      final now = DateTime(2026, 1, 1, 10);
      final instant = now.subtract(const Duration(days: 3));
      expect(daysUntil(instant, now: now), 0);
    });

    test('échéance nulle rend null', () {
      final now = DateTime(2026, 1, 1, 10);
      expect(daysUntil(null, now: now), isNull);
    });

    test('échéance UTC vs now local : le résultat repose sur la durée réelle '
        'écoulée, pas sur une soustraction de jours calendaires, et vaut '
        'donc la même chose sous tous les fuseaux', () {
      // Les deux instants sont ancrés en absolu (`DateTime.utc`) : leur
      // écart réel est fixé à 26h, quel que soit le fuseau de la machine
      // qui exécute ce test. `.toLocal()` ne change pas l'instant que
      // désigne `now`, seulement l'étiquette/les champs affichés : c'est
      // exactement ce que fait `DateTime.now()` en production (une
      // horloge locale qui désigne un instant réel).
      final instant = DateTime.utc(2026, 8, 29, 22);
      final now = DateTime.utc(2026, 8, 28, 20).toLocal();

      // Preuve que le piège est réel, écrite pour rester vraie sous tout
      // fuseau raisonnable (UTC-12 à UTC+14) : une implémentation naïve
      // qui reconstruit une date "jour calendaire" à partir des champs
      // bruts de `instant` (29 août, alors que ceux-ci sont UTC) via un
      // constructeur *local*, puis soustrait des jours calendaires
      // plutôt que la durée réelle écoulée, ne compte jamais les 2 jours
      // pleins corrects : selon le fuseau, elle rend 0 ou 1, jamais 2.
      final naiveInstantDay = DateTime(
        instant.year,
        instant.month,
        instant.day,
      );
      final naiveNowDay = DateTime(now.year, now.month, now.day);
      final naiveDays = naiveInstantDay.difference(naiveNowDay).inDays;
      expect(
        naiveDays,
        isNot(2),
        reason:
            'ce calcul naïf par jours calendaires sous-compte '
            'systématiquement (0 ou 1 selon le fuseau) face aux 26h '
            'réelles séparant les deux instants ; il ne rend jamais le '
            'bon résultat, quel que soit le fuseau de la machine',
      );

      expect(daysUntil(instant, now: now), 2);
    });

    test('daysUntil est invariant à la représentation de now : now et '
        'now.toUtc() désignent le même instant et doivent rendre le même '
        'résultat', () {
      // Complément volontairement modeste au test principal ci-dessus,
      // pas un remplacement : sur une machine réglée sur UTC (décalage
      // nul), `now` et `now.toUtc()` ont des champs calendaires
      // identiques, donc même une implémentation naïve par champs
      // calendaires passerait ce test sans être correcte. Il n'apporte
      // une garantie réelle que sur une machine à décalage non nul (ex.
      // un poste de développement à l'heure de Paris, UTC+1/+2) : c'est
      // le test principal, construit pour rester discriminant sous tout
      // fuseau, qui protège contre le piège UTC/local lui-même.
      final now = DateTime.now();
      final instant = now.add(const Duration(days: 5, hours: 8));

      expect(
        daysUntil(instant, now: now.toUtc()),
        daysUntil(instant, now: now),
      );
    });
  });

  group('SubscriptionStatusBanner', () {
    testWidgets('pastDue : bandeau visible, action "Régler" appelle '
        'onAction', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        SubscriptionStatusBanner(
          subscription: _sub(
            active: true,
            status: ProSubscriptionStatus.pastDue,
          ),
          onAction: () => tapped = true,
        ),
      );

      expect(find.byType(DonyStatusBanner), findsOneWidget);
      expect(
        find.textContaining("n'a pas abouti"),
        findsOneWidget,
        reason: 'le texte doit parler explicitement du paiement échoué',
      );
      expect(find.text('Régler'), findsOneWidget);

      await tester.tap(find.text('Régler'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets(
      'legacyGrace avec graceExpiresAt dans 12 jours : le texte contient 12',
      (tester) async {
        final graceExpiresAt = DateTime.now().toUtc().add(
          const Duration(days: 12) - const Duration(minutes: 1),
        );
        await _pump(
          tester,
          SubscriptionStatusBanner(
            subscription: _sub(
              active: true,
              status: ProSubscriptionStatus.legacyGrace,
              graceExpiresAt: graceExpiresAt,
            ),
          ),
        );

        expect(find.byType(DonyStatusBanner), findsOneWidget);
        expect(find.textContaining('12'), findsOneWidget);
      },
    );

    testWidgets(
      'legacyGrace sans graceExpiresAt : bandeau visible sans nombre de '
      'jours',
      (tester) async {
        await _pump(
          tester,
          SubscriptionStatusBanner(
            subscription: _sub(
              active: true,
              status: ProSubscriptionStatus.legacyGrace,
            ),
          ),
        );

        expect(find.byType(DonyStatusBanner), findsOneWidget);
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        for (final t in textWidgets) {
          final data = t.data ?? '';
          expect(
            RegExp(r'\d').hasMatch(data),
            isFalse,
            reason:
                'aucun chiffre ne doit apparaître : "dans null jours" '
                'serait pire que ne rien dire',
          );
          expect(
            data.toLowerCase(),
            isNot(contains('null')),
            reason:
                'un garde manquant sur `days == null` interpolerait '
                'littéralement "dans null jours" ; aucun chiffre dans ce '
                'texte ne suffit pas à l\'exclure',
          );
        }
      },
    );

    testWidgets(
      'active + cancelAtPeriodEnd + currentPeriodEnd : bandeau info avec '
      'la date en heure locale',
      (tester) async {
        final currentPeriodEnd = DateTime.utc(2026, 12, 24, 10);
        await _pump(
          tester,
          SubscriptionStatusBanner(
            subscription: _sub(
              active: true,
              status: ProSubscriptionStatus.active,
              cancelAtPeriodEnd: true,
              currentPeriodEnd: currentPeriodEnd,
            ),
          ),
        );

        expect(find.byType(DonyStatusBanner), findsOneWidget);
        final expectedDate = DateFormat(
          'd MMMM yyyy',
          'fr',
        ).format(currentPeriodEnd.toLocal());
        expect(find.textContaining(expectedDate), findsOneWidget);
      },
    );

    testWidgets('active + cancelAtPeriodEnd faux : rien ne s\'affiche', (
      tester,
    ) async {
      await _pump(
        tester,
        SubscriptionStatusBanner(
          subscription: _sub(
            active: true,
            status: ProSubscriptionStatus.active,
            currentPeriodEnd: DateTime.utc(2026, 12, 24),
          ),
        ),
      );

      expect(find.byType(DonyStatusBanner), findsNothing);
    });

    for (final status in [
      ProSubscriptionStatus.none,
      ProSubscriptionStatus.canceled,
      ProSubscriptionStatus.expired,
    ]) {
      testWidgets('statut $status : rien ne s\'affiche', (tester) async {
        await _pump(
          tester,
          SubscriptionStatusBanner(
            subscription: _sub(active: false, status: status),
          ),
        );

        expect(find.byType(DonyStatusBanner), findsNothing);
      });
    }

    testWidgets(
      'statut unknown : rien ne s\'affiche (pas d\'alerte inventée)',
      (tester) async {
        await _pump(
          tester,
          SubscriptionStatusBanner(
            subscription: _sub(
              active: false,
              status: ProSubscriptionStatus.unknown,
            ),
          ),
        );

        expect(find.byType(DonyStatusBanner), findsNothing);
      },
    );

    testWidgets('aucun texte du bandeau ne contient de tiret cadratin', (
      tester,
    ) async {
      for (final sub in [
        _sub(active: true, status: ProSubscriptionStatus.pastDue),
        _sub(
          active: true,
          status: ProSubscriptionStatus.legacyGrace,
          graceExpiresAt: DateTime.now().toUtc().add(const Duration(days: 5)),
        ),
        _sub(active: true, status: ProSubscriptionStatus.legacyGrace),
        _sub(
          active: true,
          status: ProSubscriptionStatus.active,
          cancelAtPeriodEnd: true,
          currentPeriodEnd: DateTime.utc(2026, 12, 24),
        ),
      ]) {
        await _pump(tester, SubscriptionStatusBanner(subscription: sub));

        final texts = tester.widgetList<Text>(find.byType(Text));
        for (final t in texts) {
          expect(t.data ?? '', isNot(contains('—')));
        }
        final richTexts = tester.widgetList<RichText>(find.byType(RichText));
        for (final rt in richTexts) {
          expect(rt.text.toPlainText(), isNot(contains('—')));
        }
      }
    });
  });
}
