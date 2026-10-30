// Carte de statut de l'écran du trajet (vue du voyageur propriétaire) : une
// carte d'information courte par état (brouillon, complet, en cours,
// terminé, annulé, retiré par l'équipe), aucune pour un trajet actif ni pour
// un statut inconnu de l'app. FR et EN, 360 dp, texte × 1,3.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_status_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tripStatusCardKindFor', () {
    test('une carte par état, aucune pour ACTIVE ni un statut inconnu', () {
      expect(tripStatusCardKindFor('DRAFT'), TripStatusCardKind.draft);
      expect(tripStatusCardKindFor('ACTIVE'), isNull);
      expect(tripStatusCardKindFor('FULL'), TripStatusCardKind.full);
      expect(
        tripStatusCardKindFor('IN_PROGRESS'),
        TripStatusCardKind.inProgress,
      );
      expect(tripStatusCardKindFor('COMPLETED'), TripStatusCardKind.completed);
      expect(tripStatusCardKindFor('CANCELLED'), TripStatusCardKind.cancelled);
      expect(
        tripStatusCardKindFor('REMOVED_BY_ADMIN'),
        TripStatusCardKind.removedByAdmin,
      );
      expect(tripStatusCardKindFor('EXPIRED'), isNull);
      expect(tripStatusCardKindFor(''), isNull);
      expect(tripStatusCardKindFor('full'), isNull);
    });
  });

  Future<void> pump(
    WidgetTester tester,
    TripStatusCardKind kind, {
    Locale locale = const Locale('fr'),
    double textScale = 1,
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
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
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TripStatusCard(kind: kind),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

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

    testWidgets('complet : report possible, annulation par le support', (
      tester,
    ) async {
      await pump(tester, TripStatusCardKind.full);
      expect(
        find.text(
          'Trajet complet : plus de demande possible. Vous pouvez reporter '
          'le départ. Pour annuler, contactez le support.',
        ),
        findsOneWidget,
      );
      expect(banner(tester).type, DonyStatusBannerType.warning);
      expect(banner(tester).title, isNull);
    });

    testWidgets('en cours', (tester) async {
      await pump(tester, TripStatusCardKind.inProgress);
      expect(find.text(fr.tripStatusInProgressMessage), findsOneWidget);
      expect(banner(tester).type, DonyStatusBannerType.info);
    });

    testWidgets('terminé', (tester) async {
      await pump(tester, TripStatusCardKind.completed);
      expect(find.text(fr.tripStatusCompletedMessage), findsOneWidget);
      expect(banner(tester).type, DonyStatusBannerType.info);
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

    testWidgets('retiré par l\'équipe : contacter le support', (tester) async {
      await pump(tester, TripStatusCardKind.removedByAdmin);
      expect(
        find.text(
          "Ce trajet a été retiré par l'équipe Yadony. Contactez le support.",
        ),
        findsOneWidget,
      );
      expect(banner(tester).type, DonyStatusBannerType.warning);
    });
  });

  test('textes sans tiret cadratin, en FR et en EN', () {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      final l = lookupAppLocalizations(locale);
      for (final text in [
        l.tripStatusFullMessage,
        l.tripStatusInProgressMessage,
        l.tripStatusCompletedMessage,
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
