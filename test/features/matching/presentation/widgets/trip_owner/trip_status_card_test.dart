// Carte de statut de l'écran du trajet (vue du voyageur propriétaire) : une
// carte d'information courte par état (brouillon, complet, en cours, arrivé,
// terminé, annulé, retiré par l'équipe), aucune pour un trajet actif ni pour
// un statut inconnu de l'app. Report annoncé seulement s'il est possible,
// lien vers le support sur un trajet complet ou retiré. FR et EN, 360 dp,
// texte × 1,3.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_status_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  status: status,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

void main() {
  group('tripStatusCardKindFor', () {
    // Redesign du 31/10 : plus de carte pour un trajet publié, en cours ni
    // terminé, le badge du billet suffit.
    test('une carte pour brouillon, complet, annulé, retiré ; aucune pour '
        'ACTIVE, IN_PROGRESS, COMPLETED ni un statut inconnu', () {
      expect(tripStatusCardKindFor('DRAFT'), TripStatusCardKind.draft);
      expect(tripStatusCardKindFor('ACTIVE'), isNull);
      expect(tripStatusCardKindFor('FULL'), TripStatusCardKind.full);
      expect(tripStatusCardKindFor('IN_PROGRESS'), isNull);
      expect(tripStatusCardKindFor('COMPLETED'), isNull);
      expect(tripStatusCardKindFor('CANCELLED'), TripStatusCardKind.cancelled);
      expect(
        tripStatusCardKindFor('REMOVED_BY_ADMIN'),
        TripStatusCardKind.removedByAdmin,
      );
      expect(tripStatusCardKindFor('EXPIRED'), isNull);
      expect(tripStatusCardKindFor(''), isNull);
      expect(tripStatusCardKindFor('full'), isNull);
    });

    // « Arrivé à destination » laisse le trajet IN_PROGRESS jusqu'au dernier
    // colis livré : la carte suit les colis.
    group('IN_PROGRESS selon les colis', () {
      TripStatusCardKind? kind(List<BidModel>? bids) =>
          tripStatusCardKindFor('IN_PROGRESS', bids: bids);

      test('colis pas encore chargés : aucune carte', () {
        expect(kind(null), isNull);
      });
      test('colis en transit ou remis : aucune carte', () {
        expect(kind([_bid('b1', 'IN_TRANSIT')]), isNull);
        expect(kind([_bid('b1', 'HANDED_OVER')]), isNull);
      });
      test('aucun colis : aucune carte', () {
        expect(kind(const []), isNull);
      });
      test('colis arrivés, plus rien en route : arrivé', () {
        expect(kind([_bid('b1', 'ARRIVED')]), TripStatusCardKind.arrived);
        expect(
          kind([
            _bid('b1', 'ARRIVED'),
            _bid('b2', 'COMPLETED'),
            _bid('b3', 'ACCEPTED'),
            _bid('b4', 'CANCELLED'),
          ]),
          TripStatusCardKind.arrived,
        );
      });
      test('un colis arrivé, un autre encore en route : aucune carte', () {
        expect(kind([_bid('b1', 'ARRIVED'), _bid('b2', 'IN_TRANSIT')]), isNull);
        expect(
          kind([_bid('b1', 'ARRIVED'), _bid('b2', 'HANDED_OVER')]),
          isNull,
        );
      });
      test('tous livrés : aucune carte (le back passe ensuite COMPLETED)', () {
        expect(kind([_bid('b1', 'COMPLETED')]), isNull);
      });
      test('colis arrivé sur un autre statut : la carte du statut', () {
        final arrived = [_bid('b1', 'ARRIVED')];
        expect(tripStatusCardKindFor('COMPLETED', bids: arrived), isNull);
        expect(
          tripStatusCardKindFor('CANCELLED', bids: arrived),
          TripStatusCardKind.cancelled,
        );
        expect(tripStatusCardKindFor('ACTIVE', bids: arrived), isNull);
      });
    });
  });

  Future<void> pump(
    WidgetTester tester,
    TripStatusCardKind kind, {
    bool canReschedule = false,
    Locale locale = const Locale('fr'),
    double textScale = 1,
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TripStatusCard(kind: kind, canReschedule: canReschedule),
            ),
          ),
        ),
        GoRoute(
          path: '/support',
          builder: (_, _) => const Scaffold(body: Text('support-home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routerConfig: router,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  final support = find.byKey(const Key('trip-status-card-support'));

  DonyStatusBanner banner(WidgetTester tester) =>
      tester.widget<DonyStatusBanner>(find.byType(DonyStatusBanner));

  group('textes', () {
    final fr = lookupAppLocalizations(const Locale('fr'));

    testWidgets('brouillon : le bandeau d\'avant, titre et message', (
      tester,
    ) async {
      await pump(tester, TripStatusCardKind.draft);
      expect(find.byKey(const Key('trip-status-card-draft')), findsOneWidget);
      expect(find.text(fr.tripOwnerDraftBannerTitle), findsOneWidget);
      expect(find.text(fr.tripOwnerDraftBannerMessage), findsOneWidget);
      expect(banner(tester).type, DonyStatusBannerType.warning);
    });

    testWidgets('complet, report possible : report et support', (tester) async {
      await pump(tester, TripStatusCardKind.full, canReschedule: true);
      expect(
        find.text(
          'Trajet complet : plus de demande possible. Vous pouvez reporter '
          'le départ. Pour annuler, contactez le support.',
        ),
        findsOneWidget,
      );
      expect(banner(tester).type, DonyStatusBannerType.warning);
      expect(banner(tester).title, isNull);
      expect(support, findsOneWidget);
    });

    // Déjà reporté deux fois, ou colis en route : l'entrée « Reporter » du
    // menu est verrouillée, la carte ne promet plus de report.
    testWidgets('complet, report impossible : sans « reporter »', (
      tester,
    ) async {
      await pump(tester, TripStatusCardKind.full);
      expect(
        find.text(
          'Trajet complet : plus de demande possible. Pour annuler, '
          'contactez le support.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('reporter'), findsNothing);
      expect(support, findsOneWidget);
    });

    testWidgets('arrivé : les colis attendent leurs destinataires', (
      tester,
    ) async {
      await pump(tester, TripStatusCardKind.arrived);
      expect(
        find.text('Trajet arrivé : vos colis attendent leurs destinataires.'),
        findsOneWidget,
      );
      expect(banner(tester).type, DonyStatusBannerType.info);
      expect(banner(tester).iconAsset, 'flag');
      expect(support, findsNothing);
    });

    testWidgets('annulé : procédure de retour des colis remis', (tester) async {
      await pump(tester, TripStatusCardKind.cancelled);
      expect(
        find.textContaining(
          'Les colis déjà remis suivent la procédure de retour',
        ),
        findsOneWidget,
      );
      expect(banner(tester).type, DonyStatusBannerType.warning);
    });

    testWidgets('retiré par l\'équipe : lien vers le support', (tester) async {
      await pump(tester, TripStatusCardKind.removedByAdmin);
      expect(
        find.text("Ce trajet a été retiré par l'équipe Yadony."),
        findsOneWidget,
      );
      expect(banner(tester).type, DonyStatusBannerType.warning);
      expect(
        find.descendant(
          of: support,
          matching: find.text('Contacter le support'),
        ),
        findsOneWidget,
      );
    });

    for (final kind in [
      TripStatusCardKind.removedByAdmin,
      TripStatusCardKind.full,
    ]) {
      testWidgets('${kind.name} : le lien ouvre l\'écran du support', (
        tester,
      ) async {
        await pump(tester, kind);
        await tester.tap(support);
        await tester.pumpAndSettle();
        expect(find.text('support-home'), findsOneWidget);
      });
    }

    for (final kind in [
      TripStatusCardKind.draft,
      TripStatusCardKind.arrived,
      TripStatusCardKind.cancelled,
    ]) {
      testWidgets('${kind.name} : pas de lien vers le support', (tester) async {
        await pump(tester, kind);
        expect(support, findsNothing);
      });
    }

    testWidgets('anglais : textes et lien', (tester) async {
      await pump(
        tester,
        TripStatusCardKind.arrived,
        locale: const Locale('en'),
      );
      expect(
        find.text(
          'Trip arrived: your parcels are waiting for their recipients.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('anglais : complet sans report, lien du support', (
      tester,
    ) async {
      await pump(tester, TripStatusCardKind.full, locale: const Locale('en'));
      expect(
        find.text(
          'Trip full: no more requests can come in. To cancel, contact support.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: support, matching: find.text('Contact support')),
        findsOneWidget,
      );
    });
  });

  test('textes sans tiret cadratin, en FR et en EN', () {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      final l = lookupAppLocalizations(locale);
      for (final text in [
        l.tripStatusFullMessage,
        l.tripStatusFullNoRescheduleMessage,
        l.tripStatusArrivedMessage,
        l.tripStatusCancelledMessage,
        l.tripStatusRemovedMessage,
      ]) {
        expect(text, isNot(contains('—')));
        expect(text, isNot(contains('Dony ')));
      }
    }
  });

  group('rendu', () {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      for (final kind in TripStatusCardKind.values) {
        testWidgets(
          '${locale.languageCode} ${kind.name} à 360 dp, texte × 1,3',
          (tester) async {
            await pump(
              tester,
              kind,
              canReschedule: true,
              locale: locale,
              textScale: 1.3,
              width: 360,
            );
            expect(tester.takeException(), isNull);
            expect(find.byType(DonyStatusBanner), findsOneWidget);
          },
        );
      }
    }
  });
}
