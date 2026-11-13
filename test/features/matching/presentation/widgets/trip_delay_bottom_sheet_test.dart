// Feuille « Annoncer un retard » (VoyMerRetard) : bouton dans le
// stickyBottom, motifs et aide selon le mode (aucun vol, port ni escale hors
// de leur mode), dates bornées (fin après le début, ni passée ni au-delà de
// la durée du mode), envoi, erreur du serveur, feuille gardée pendant
// l'envoi, 360 dp FR et EN, aucun avion hors avion.
import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/trip_delay/trip_delay_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_delay_info.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/trip_delay_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/label_fit_expectations.dart';
import '../../../../helpers/mock_analytics_backend.dart';
import '../../../../helpers/plane_icon_expectations.dart';
import 'trip_owner/trip_card_harness.dart' show loadAppFonts;

class _MockRepository extends Mock implements AnnouncementRepository {}

/// « Aujourd'hui » des tests : le bateau est parti le 2 décembre.
final _today = DateTime(2026, 12, 20, 10);

AnnouncementModel _trip({
  TransportMode? mode = TransportMode.boat,
  DateTime? departure,
}) => AnnouncementModel(
  id: 'trip-1',
  travelerId: 'trav-1',
  departureCity: 'Le Havre',
  arrivalCity: 'Abidjan',
  departureDate: departure ?? DateTime(2026, 12, 2),
  arrivalDate: DateTime(2027, 1, 4),
  arrivalDateMax: mode == TransportMode.boat ? DateTime(2027, 1, 11) : null,
  availableKg: 0,
  totalKg: 0,
  status: 'IN_PROGRESS',
  transportMode: mode,
  createdAt: DateTime(2026, 11),
  updatedAt: DateTime(2026, 11),
);

TripDelayInfo _delay() => TripDelayInfo(
  id: 'd-1',
  reason: 'PORT_CONGESTION',
  arrivalDate: DateTime(2027, 1, 15),
  arrivalDateMax: DateTime(2027, 1, 22),
  announcedAt: DateTime.utc(2026, 12, 20),
);

final _submit = find.byKey(const Key('trip-delay-submit'));

void main() {
  late _MockRepository repository;

  setUpAll(() async {
    registerFallbackValue(TripDelayReason.other);
    registerFallbackValue(DateTime(2026));
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await loadAppFonts();
  });

  setUp(() async {
    repository = _MockRepository();
    final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
    await getIt.reset();
    getIt.registerFactoryParam<TripDelayCubit, AnnouncementModel, void>(
      (trip, _) => TripDelayCubit(trip, repository, analytics),
    );
  });

  tearDown(() async => getIt.reset());

  void stubAnnounce(Future<TripDelayInfo> Function() answer) => when(
    () => repository.announceDelay(
      announcementId: any(named: 'announcementId'),
      reason: any(named: 'reason'),
      arrivalDate: any(named: 'arrivalDate'),
      arrivalDateMax: any(named: 'arrivalDateMax'),
      message: any(named: 'message'),
    ),
  ).thenAnswer((_) => answer());

  /// Ouvre la feuille ; [result] reçoit ce qu'elle rend à sa fermeture.
  Future<void> open(
    WidgetTester tester, {
    AnnouncementModel? trip,
    int senderCount = 12,
    Locale locale = const Locale('fr'),
    Size size = const Size(390, 900),
    void Function(TripDelayInfo?)? result,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final r = await TripDelayBottomSheet.show(
                  context,
                  trip: trip ?? _trip(),
                  senderCount: senderCount,
                  clock: () => _today,
                );
                result?.call(r);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester) =>
      tester.widget<DonyButton>(_submit).onPressed != null;

  /// Choisit le jour [day] du mois affiché par le calendrier ouvert.
  Future<void> pickDay(WidgetTester tester, Finder tile, String day) async {
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text(day));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  final from = find.byKey(const Key('trip-delay-from'));
  final to = find.byKey(const Key('trip-delay-to'));

  testWidgets('delaySheet_buttonInStickyBottom : bouton hors du contenu', (
    tester,
  ) async {
    await open(tester);
    expect(_submit, findsOneWidget);
    expect(
      find.ancestor(of: _submit, matching: find.byType(TripDelayBottomSheet)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(TripDelayBottomSheet),
        matching: find.byType(DonyButton),
      ),
      findsNothing,
    );
    expect(
      ModalRoute.of(tester.element(_submit))?.settings.name,
      '/sheet/trip-owner/delay',
    );
  });

  // Recette 13/11 : une date au-delà du plafond ne disait que « Hors de
  // portée. ».
  for (final english in [false, true]) {
    testWidgets('${english ? 'EN' : 'FR'} : date hors fenêtre, le sélecteur '
        'dit la règle des 120 jours du bateau', (tester) async {
      await open(
        tester,
        locale: english ? const Locale('en') : const Locale('fr'),
      );
      await tester.ensureVisible(from);
      await tester.tap(from);
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(
        picker.errorInvalidText,
        english
            ? contains('arrival is at most 120 days after departure')
            : contains("l'arrivée est au plus 120 jours après le départ"),
      );
    });
  }

  testWidgets('bateau : textes de la maquette, cinq motifs, aucun avion', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Annoncer un retard'), findsOneWidget);
    expect(
      find.text('Les 12 expéditeurs de ce trajet sont prévenus en une fois.'),
      findsOneWidget,
    );
    for (final label in [
      'Congestion au port',
      'Météo',
      'Escale prolongée',
      'Perturbation du transport',
      'Autre raison',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('NOUVELLE ARRIVÉE ESTIMÉE'), findsOneWidget);
    expect(find.text('Du'), findsOneWidget);
    expect(find.text('Au'), findsOneWidget);
    expect(find.text('MESSAGE AUX EXPÉDITEURS'), findsOneWidget);
    expect(
      find.text('Ex. : attente à Tanger Med, départ prévu jeudi'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Le report du trajet reste bloqué une fois les colis à bord ; '
        "l'annonce de retard, elle, reste possible jusqu'à l'arrivée.",
      ),
      findsOneWidget,
    );
    expect(find.text('Prévenir les expéditeurs'), findsOneWidget);
    // Départ 2 déc. 2026 + 120 jours.
    expect(
      find.text('Au plus tard le 1 avr. 2027 pour ce trajet'),
      findsOneWidget,
    );
    expect(find.textContaining('—'), findsNothing);
    expectNoPlaneIcon(tester);
  });

  testWidgets('route : ni port, ni escale, ni vol ; aide neutre', (
    tester,
  ) async {
    await open(
      tester,
      trip: _trip(mode: TransportMode.car, departure: DateTime(2026, 12, 15)),
    );
    expect(
      find.byKey(const Key('trip-delay-reason-PORT_CONGESTION')),
      findsNothing,
    );
    expect(find.text('Arrêt prolongé'), findsOneWidget);
    expect(find.text('Perturbation du transport'), findsOneWidget);
    expect(
      find.text('Ex. : contretemps, reprise prévue jeudi'),
      findsOneWidget,
    );
    // Mots propres à l'avion ou au bateau (« report » n'est pas « port »).
    final planeOrBoat = RegExp(
      r'\b(vols?|escales?|aéroports?|port|Tanger)\b',
      caseSensitive: false,
    );
    expect(find.textContaining(planeOrBoat), findsNothing);
    // Départ 15 déc. + 14 jours.
    expect(find.text('Au plus tard le 29 déc. pour ce trajet'), findsOneWidget);
    expectNoPlaneIcon(tester);
  });

  for (final mode in [TransportMode.other, null]) {
    testWidgets('mode inconnu ou absent ($mode) : motifs et aide neutres', (
      tester,
    ) async {
      await open(
        tester,
        trip: _trip(mode: mode, departure: DateTime(2026, 12, 19)),
      );
      expect(
        find.byKey(const Key('trip-delay-reason-PORT_CONGESTION')),
        findsNothing,
      );
      expect(find.text('Arrêt prolongé'), findsOneWidget);
      expect(
        find.text('Ex. : contretemps, reprise prévue jeudi'),
        findsOneWidget,
      );
      expectNoPlaneIcon(tester);
    });
  }

  testWidgets('avion : escale et vol permis, pas de port', (tester) async {
    await open(
      tester,
      trip: _trip(mode: TransportMode.plane, departure: DateTime(2026, 12, 19)),
    );
    expect(
      find.byKey(const Key('trip-delay-reason-PORT_CONGESTION')),
      findsNothing,
    );
    expect(find.text('Escale prolongée'), findsOneWidget);
    expect(
      find.text('Ex. : vol retardé, nouvel horaire annoncé demain'),
      findsOneWidget,
    );
  });

  testWidgets('expéditeurs inconnus ou seul : phrase sans nombre', (
    tester,
  ) async {
    await open(tester, senderCount: 0);
    expect(
      find.text(
        'Les expéditeurs dont le colis est à bord sont prévenus en une fois.',
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await open(tester, senderCount: 1);
    expect(
      find.text("L'expéditeur dont le colis est à bord est prévenu."),
      findsOneWidget,
    );
  });

  testWidgets('bouton éteint tant que motif et dates manquent, puis envoi', (
    tester,
  ) async {
    stubAnnounce(() async => _delay());
    TripDelayInfo? sent;
    var closed = false;
    await open(
      tester,
      result: (r) {
        sent = r;
        closed = true;
      },
    );
    expect(enabled(tester), isFalse);
    await tester.tap(find.text('Congestion au port'));
    await tester.pump();
    expect(enabled(tester), isFalse);
    // Le calendrier s'ouvre sur l'arrivée actuelle (janvier 2027).
    await pickDay(tester, from, '15');
    expect(enabled(tester), isFalse);
    await pickDay(tester, to, '22');
    expect(find.text('15 janv. 2027'), findsOneWidget);
    expect(find.text('22 janv. 2027'), findsOneWidget);
    expect(enabled(tester), isTrue);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('trip-delay-message')),
        matching: find.byType(EditableText),
      ),
      'Attente à Tanger Med',
    );
    await tester.tap(_submit);
    await tester.pumpAndSettle();
    verify(
      () => repository.announceDelay(
        announcementId: 'trip-1',
        reason: TripDelayReason.portCongestion,
        arrivalDate: DateTime(2027, 1, 15),
        arrivalDateMax: DateTime(2027, 1, 22),
        message: 'Attente à Tanger Med',
      ),
    ).called(1);
    expect(closed, isTrue);
    expect(sent, _delay());
    expect(find.byType(TripDelayBottomSheet), findsNothing);
  });

  testWidgets('début choisi après la fin : la fin le suit', (tester) async {
    await open(tester);
    await pickDay(tester, to, '18');
    await pickDay(tester, from, '25');
    expect(find.text('25 janv. 2027'), findsNWidgets(2));
  });

  testWidgets('fin bornée : jamais avant aujourd’hui ni le début', (
    tester,
  ) async {
    await open(tester);
    await pickDay(tester, from, '15');
    await tester.tap(to);
    await tester.pumpAndSettle();
    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(picker.firstDate, DateTime(2027, 1, 15));
    expect(picker.lastDate, DateTime(2027, 4));
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    await tester.tap(from);
    await tester.pumpAndSettle();
    final first = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    // Parti le 2 décembre : pas avant aujourd'hui, le 20.
    expect(first.firstDate, DateTime(2026, 12, 20));
  });

  testWidgets('limite du mode dépassée : dates fermées, limite en rouge', (
    tester,
  ) async {
    // Avion parti le 1er décembre : arrivée au plus tard le 4.
    await open(
      tester,
      trip: _trip(mode: TransportMode.plane, departure: DateTime(2026, 12)),
    );
    final limit = find.text('Au plus tard le 4 déc. pour ce trajet');
    expect(limit, findsOneWidget);
    expect(
      tester.widget<Text>(limit).style?.color,
      AppTheme.light().colorScheme.error,
    );
    await tester.tap(from);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(enabled(tester), isFalse);
  });

  testWidgets('refus du serveur : message traduit, feuille ouverte', (
    tester,
  ) async {
    stubAnnounce(
      () async =>
          throw const ConflictException('raw', code: 'trip-delay-not-allowed'),
    );
    await open(tester);
    await tester.tap(find.text('Météo'));
    await pickDay(tester, from, '15');
    await pickDay(tester, to, '15');
    await tester.tap(_submit);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-delay-error')), findsOneWidget);
    expect(
      find.text(
        'Un retard ne peut être annoncé que sur un trajet en cours : il doit '
        'être parti et ne pas être terminé.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TripDelayBottomSheet), findsOneWidget);
    expect(enabled(tester), isTrue);
  });

  testWidgets('pendant l’envoi : la feuille ne se ferme pas', (tester) async {
    final reply = Completer<TripDelayInfo>();
    stubAnnounce(() => reply.future);
    TripDelayInfo? sent;
    await open(tester, result: (r) => sent = r);
    await tester.tap(find.text('Météo'));
    await pickDay(tester, from, '15');
    await pickDay(tester, to, '20');
    await tester.tap(_submit);
    await tester.pump();
    expect(tester.widget<DonyButton>(_submit).isLoading, isTrue);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TripDelayBottomSheet), findsOneWidget);
    reply.complete(_delay());
    await tester.pumpAndSettle();
    expect(sent, isNotNull);
    expect(find.byType(TripDelayBottomSheet), findsNothing);
  });

  for (final locale in const [Locale('fr'), Locale('en')]) {
    testWidgets('delaySheet_360dp_${locale.languageCode} : bouton nominal', (
      tester,
    ) async {
      await open(tester, locale: locale, size: const Size(360, 800));
      expect(tester.takeException(), isNull);
      expectButtonLabelNominal(tester, _submit, reason: 'Prévenir');
      if (locale.languageCode == 'en') {
        expect(find.text('Announce a delay'), findsOneWidget);
        expect(find.text('Notify senders'), findsOneWidget);
        expect(find.text('Port congestion'), findsOneWidget);
        expect(find.text('Transport disruption'), findsOneWidget);
        expect(
          find.text('E.g. waiting at Tanger Med, departure expected Thursday'),
          findsOneWidget,
        );
      }
      expectNoPlaneIcon(tester);
    });
  }
}
