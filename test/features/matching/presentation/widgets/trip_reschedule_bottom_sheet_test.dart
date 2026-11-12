import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_result.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/arrival_day_chips.dart';
import 'package:dony/features/matching/presentation/widgets/trip_reschedule_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/plane_icon_expectations.dart';

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

/// Jour à [n] jours de [d], en arithmétique de calendrier : un `Duration`
/// franchissant un changement d'heure décalerait minuit d'une heure.
DateTime _plusDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Départ dans quelques jours, un jour du mois où le lendemain existe encore
/// dans la même grille du sélecteur de date.
DateTime _departureDay() {
  var d = _plusDays(DateTime.now(), 3);
  while (d.day > 26) {
    d = _plusDays(d, 1);
  }
  return d;
}

void main() {
  _calendarArithmeticTests();

  late _MockAnnouncementBloc bloc;
  late StreamController<AnnouncementState> states;
  final departure = _departureDay();

  AnnouncementModel buildAnnouncement({
    TransportMode? mode,
    String? arrivalTime = '06:30',
    int arrivalOffset = 1,
  }) => AnnouncementModel(
    id: 'a1',
    travelerId: 't1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: departure,
    departureTime: '22:00',
    arrivalTime: arrivalTime,
    arrivalDate: _plusDays(departure, arrivalOffset),
    handoverDeadline: _plusDays(departure, -1),
    availableKg: 10,
    totalKg: 20,
    pricePerKg: 5,
    status: 'FULL',
    bidsCount: 2,
    remainingReschedules: 1,
    transportMode: mode,
    createdAt: DateTime(2026, 9),
    updatedAt: DateTime(2026, 9),
  );
  final announcement = buildAnnouncement();

  setUpAll(() {
    registerFallbackValue(AnnouncementDetailRequested('x'));
  });

  setUp(() {
    bloc = _MockAnnouncementBloc();
    states = StreamController<AnnouncementState>.broadcast();
    addTearDown(states.close);
    whenListen(bloc, states.stream, initialState: AnnouncementInitial());
  });

  Widget host({AnnouncementModel? trip, Locale locale = AppL10n.fr}) =>
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        // Téléphone en 24 h : le sélecteur d'heure en saisie clavier n'accepte
        // « 18 » qu'à cette condition.
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<AnnouncementBloc>.value(
          value: bloc,
          child: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => TripRescheduleBottomSheet.show(
                    ctx,
                    announcement: trip ?? announcement,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> open(
    WidgetTester tester, {
    AnnouncementModel? trip,
    Locale locale = AppL10n.fr,
    Size size = const Size(900, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(trip: trip, locale: locale));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  DonyButton submitButton(WidgetTester tester) => tester.widget<DonyButton>(
    find.byKey(const Key('trip-reschedule-submit')),
  );

  Future<void> pickNextDay(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('reschedule-date-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${departure.day + 1}'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  /// Remise des colis : [day] au calendrier, puis l'heure saisie au clavier
  /// au sélecteur enchaîné (FLUTTER-PK), ou annulée quand [hour] est nul.
  Future<void> pickHandover(
    WidgetTester tester,
    DateTime day, {
    String? hour,
  }) async {
    await tester.tap(find.byKey(const Key('reschedule-handover-field')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('${day.day}'),
      ),
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    if (hour == null) {
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      return;
    }
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), hour);
    await tester.enterText(fields.at(1), '00');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  AnnouncementRescheduleRequested submitAndCapture(WidgetTester tester) {
    return verify(() => bloc.add(captureAny())).captured.single
        as AnnouncementRescheduleRequested;
  }

  testWidgets(
    'bouton inactif sans motif ni nouvelle date, conséquences affichées',
    (tester) async {
      await open(tester);

      expect(submitButton(tester).onPressed, isNull);
      expect(
        find.textContaining('Un trajet se reporte 2 fois au plus'),
        findsOneWidget,
      );
      // Heures du trajet reprises : seul le jour change dans le cas courant.
      expect(find.text('22:00'), findsOneWidget);
      expect(find.text('06:30'), findsOneWidget);
    },
  );

  // Recette Redmi : le champ restait inerte tant qu'aucune nouvelle date
  // n'était choisie, sans rien qui l'explique.
  testWidgets('remise des colis : pré-remplie et cliquable dès l\'ouverture', (
    tester,
  ) async {
    await open(tester);

    final day = _plusDays(departure, -1);
    expect(
      find.descendant(
        of: find.byKey(const Key('reschedule-handover-field')),
        matching: find.textContaining('${day.day}'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('reschedule-handover-field')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('le résumé affiche le départ actuel puis le nouveau', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Actuellement'), findsOneWidget);

    await pickNextDay(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('reschedule-summary')),
        // Jour suivi d'une espace (« 22 oct. ») : un départ à 22:00 la
        // veille contient aussi « 22 », dans l'heure.
        matching: find.textContaining(RegExp('\\b${departure.day + 1} ')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('annonce le dernier report possible', (tester) async {
    await open(tester);

    expect(
      find.text('Dernier report possible pour ce trajet.'),
      findsOneWidget,
    );
  });

  testWidgets('même date et même heure : refusé avant l\'envoi', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(
      find.byKey(const Key('reschedule-reason-FLIGHT_CANCELLED')),
    );
    await tester.tap(find.byKey(const Key('reschedule-date-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text("Choisissez une date ou une heure différente de l'actuelle."),
      findsOneWidget,
    );
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets(
    'nouvelle date : envoie le report avec la remise décalée d\'autant',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('reschedule-reason-POSTPONED')));
      await pickNextDay(tester);
      await tester.enterText(find.byType(TextField), 'Nouveau vol confirmé');
      await tester.pump();

      await tester.tap(find.byKey(const Key('trip-reschedule-submit')));
      await tester.pump();

      final event =
          verify(() => bloc.add(captureAny())).captured.single
              as AnnouncementRescheduleRequested;
      final newDay = _plusDays(departure, 1);
      expect(event.announcementId, 'a1');
      expect(DateUtils.isSameDay(event.departureDate, newDay), isTrue);
      expect(event.departureTime, '22:00');
      expect(event.arrivalTime, '06:30');
      // Vol de nuit gardé : arrivée le lendemain du nouveau départ.
      expect(
        event.arrivalDate,
        DateUtils.dateOnly(
          _plusDays(newDay, 1),
        ).toIso8601String().substring(0, 10),
      );
      // Même écart qu'avant (remise la veille), en fin de journée.
      expect(
        event.handoverDeadline,
        DateTime(newDay.year, newDay.month, newDay.day - 1, 23, 59),
      );
      expect(event.reason, TripRescheduleReason.postponed);
      expect(event.note, 'Nouveau vol confirmé');
    },
  );

  testWidgets('remise : jour puis heure choisis, envoyés tels quels', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('reschedule-reason-POSTPONED')));
    await pickNextDay(tester);
    final newDay = _plusDays(departure, 1);

    await pickHandover(tester, newDay, hour: '18');

    expect(
      find.descendant(
        of: find.byKey(const Key('reschedule-handover-field')),
        matching: find.textContaining('18:00'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reschedule-handover-error')), findsNothing);
    await tester.tap(find.byKey(const Key('trip-reschedule-submit')));
    await tester.pump();

    expect(
      submitAndCapture(tester).handoverDeadline,
      DateTime(newDay.year, newDay.month, newDay.day, 18),
    );
  });

  testWidgets(
    'remise après l\'heure du nouveau départ : erreur et bouton inactif',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('reschedule-reason-POSTPONED')));
      await pickNextDay(tester);
      final newDay = _plusDays(departure, 1);

      await pickHandover(tester, newDay, hour: '23');

      expect(
        find.byKey(const Key('reschedule-handover-error')),
        findsOneWidget,
      );
      expect(submitButton(tester).onPressed, isNull);
    },
  );

  testWidgets('remise : heure annulée le jour du départ, heure de départ', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('reschedule-reason-POSTPONED')));
    await pickNextDay(tester);
    final newDay = _plusDays(departure, 1);

    await pickHandover(tester, newDay);
    await tester.tap(find.byKey(const Key('trip-reschedule-submit')));
    await tester.pump();

    expect(
      submitAndCapture(tester).handoverDeadline,
      DateTime(newDay.year, newDay.month, newDay.day, 22),
    );
  });

  group('motifs selon le mode', () {
    final reasonKeys = [
      'FLIGHT_CANCELLED',
      'TRANSPORT_CANCELLED',
      'POSTPONED',
      'OTHER',
    ];

    Iterable<String> shownReasons() => reasonKeys.where(
      (w) => find.byKey(Key('reschedule-reason-$w')).evaluate().isNotEmpty,
    );

    testWidgets('avion : « Vol annulé », envoyé FLIGHT_CANCELLED', (
      tester,
    ) async {
      await open(tester, trip: buildAnnouncement(mode: TransportMode.plane));

      expect(shownReasons(), ['FLIGHT_CANCELLED', 'POSTPONED', 'OTHER']);
      expect(find.text('Vol annulé'), findsOneWidget);
      expect(find.text('Panne ou contretemps'), findsNothing);
      await tester.tap(
        find.byKey(const Key('reschedule-reason-FLIGHT_CANCELLED')),
      );
      await pickNextDay(tester);
      await tester.tap(find.byKey(const Key('trip-reschedule-submit')));
      await tester.pump();

      expect(
        submitAndCapture(tester).reason,
        TripRescheduleReason.flightCancelled,
      );
    });

    testWidgets('mode absent : traité comme l\'avion', (tester) async {
      await open(tester);

      expect(shownReasons(), ['FLIGHT_CANCELLED', 'POSTPONED', 'OTHER']);
      expect(find.text('Vol annulé'), findsOneWidget);
    });

    testWidgets(
      'route : « Panne ou contretemps », envoyé TRANSPORT_CANCELLED',
      (tester) async {
        await open(tester, trip: buildAnnouncement(mode: TransportMode.car));

        expect(shownReasons(), ['TRANSPORT_CANCELLED', 'POSTPONED', 'OTHER']);
        expect(find.text('Panne ou contretemps'), findsOneWidget);
        expect(find.text('Vol annulé'), findsNothing);
        expect(find.text('Voyage repoussé'), findsOneWidget);
        expect(find.text('Autre raison'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('reschedule-reason-TRANSPORT_CANCELLED')),
        );
        await pickNextDay(tester);
        await tester.tap(find.byKey(const Key('trip-reschedule-submit')));
        await tester.pump();

        expect(
          submitAndCapture(tester).reason,
          TripRescheduleReason.transportCancelled,
        );
      },
    );

    testWidgets('bus : affiché comme la route', (tester) async {
      await open(tester, trip: buildAnnouncement(mode: TransportMode.bus));

      expect(find.text('Panne ou contretemps'), findsOneWidget);
    });

    testWidgets('bateau : « Transport annulé », envoyé TRANSPORT_CANCELLED', (
      tester,
    ) async {
      await open(tester, trip: buildAnnouncement(mode: TransportMode.boat));

      expect(shownReasons(), ['TRANSPORT_CANCELLED', 'POSTPONED', 'OTHER']);
      expect(find.text('Transport annulé'), findsOneWidget);
      expect(find.text('Panne ou contretemps'), findsNothing);
    });

    testWidgets('anglais : libellés par mode', (tester) async {
      enableEnglish();
      await open(
        tester,
        trip: buildAnnouncement(mode: TransportMode.car),
        locale: AppL10n.en,
      );
      expect(find.text('Breakdown or setback'), findsOneWidget);
      expect(
        find.text('Departure canceled or trip postponed: pick the new date.'),
        findsOneWidget,
      );
    });

    for (final mode in [
      null,
      TransportMode.plane,
      TransportMode.car,
      TransportMode.boat,
    ]) {
      testWidgets('aucune icône d\'avion dans la feuille (${mode?.name})', (
        tester,
      ) async {
        await open(tester, trip: buildAnnouncement(mode: mode));

        expectNoPlaneIcon(tester);
        expect(findDonyIcon('flag'), findsOneWidget);
        expect(findDonyIcon('calendar'), findsWidgets);
      });
    }

    for (final locale in [AppL10n.fr, AppL10n.en]) {
      testWidgets('bouton sur une ligne à 360 dp (${locale.languageCode})', (
        tester,
      ) async {
        enableEnglish();
        await open(
          tester,
          trip: buildAnnouncement(mode: TransportMode.car),
          locale: locale,
          size: const Size(360, 2400),
        );

        final label = find.descendant(
          of: find.byKey(const Key('trip-reschedule-submit')),
          matching: find.byType(Text),
        );
        expect(tester.takeException(), isNull);
        final style = tester.widget<Text>(label).style;
        final fontSize = (style?.fontSize ?? 14);
        expect(
          tester.getSize(label).height,
          lessThanOrEqualTo(fontSize * 1.7),
          reason: 'libellé sur une ligne',
        );
      });
    }
  });

  group('arrivée en route (T4)', () {
    AnnouncementModel roadTrip({
      String? arrivalTime,
      int arrivalOffset = 10,
      TransportMode mode = TransportMode.car,
    }) => buildAnnouncement(
      mode: mode,
      arrivalTime: arrivalTime,
      arrivalOffset: arrivalOffset,
    );

    AnnouncementRescheduleRequested submitRoad(WidgetTester tester) =>
        verify(() => bloc.add(captureAny())).captured.single
            as AnnouncementRescheduleRequested;

    testWidgets('trajet route : pas d\'heure d\'arrivée, puces avec Autre '
        'date', (tester) async {
      await open(tester, trip: roadTrip());

      expect(
        find.byKey(const Key('reschedule-arrival-time-field')),
        findsNothing,
      );
      expect(find.byKey(const Key('arrival-day-other')), findsOneWidget);
    });

    testWidgets('trajet route à J+10 : ouvert à J+10, envoyé avec le nouveau '
        'départ', (tester) async {
      await open(tester, trip: roadTrip());
      final chips = tester.widget<ArrivalDayChips>(
        find.byType(ArrivalDayChips),
      );
      expect(chips.notifier.value, 10);
      expect(chips.maxDays, 14);

      await tester.tap(find.byKey(const Key('reschedule-reason-POSTPONED')));
      await pickNextDay(tester);
      await tester.tap(find.byKey(const Key('trip-reschedule-submit')));
      await tester.pump();

      final event = submitRoad(tester);
      final newDay = _plusDays(departure, 1);
      expect(event.arrivalTime, isNull);
      expect(
        event.arrivalDate,
        DateUtils.dateOnly(
          _plusDays(newDay, 10),
        ).toIso8601String().substring(0, 10),
      );
    });

    testWidgets('Autre date jusqu\'à J+14 du nouveau départ', (tester) async {
      await open(tester, trip: roadTrip(arrivalOffset: 0));
      await tester.tap(find.byKey(const Key('reschedule-reason-POSTPONED')));
      await pickNextDay(tester);
      final newDay = _plusDays(departure, 1);

      await tester.tap(find.byKey(const Key('arrival-day-other')));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, _plusDays(newDay, 3));
      expect(picker.lastDate, _plusDays(newDay, 14));
      // La date proposée d'emblée est J+3 : « OK » la retient.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trip-reschedule-submit')));
      await tester.pump();
      expect(
        submitRoad(tester).arrivalDate,
        DateUtils.dateOnly(
          _plusDays(newDay, 3),
        ).toIso8601String().substring(0, 10),
      );
    });

    testWidgets('route sans jour d\'arrivée : aucun arrivalDate envoyé', (
      tester,
    ) async {
      await open(tester, trip: roadTrip(arrivalOffset: 0));
      await tester.tap(find.byKey(const Key('reschedule-reason-POSTPONED')));
      await pickNextDay(tester);
      await tester.tap(find.byKey(const Key('trip-reschedule-submit')));
      await tester.pump();

      expect(submitRoad(tester).arrivalDate, isNull);
    });

    testWidgets('ancien trajet route avec heure d\'arrivée : champ gardé', (
      tester,
    ) async {
      await open(
        tester,
        trip: roadTrip(arrivalTime: '18:00', arrivalOffset: 2),
      );

      expect(
        find.byKey(const Key('reschedule-arrival-time-field')),
        findsOneWidget,
      );
      expect(find.text('18:00'), findsOneWidget);
      expect(find.byKey(const Key('arrival-day-other')), findsOneWidget);
    });

    testWidgets('trajet avion : heure d\'arrivée, trois puces sans Autre '
        'date', (tester) async {
      await open(tester, trip: buildAnnouncement(mode: TransportMode.plane));

      expect(
        find.byKey(const Key('reschedule-arrival-time-field')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('arrival-day-2')), findsOneWidget);
      expect(find.byKey(const Key('arrival-day-other')), findsNothing);
    });

    testWidgets('422 arrival-too-far : message du serveur, feuille gardée '
        'ouverte', (tester) async {
      await open(tester, trip: roadTrip());
      await tester.tap(find.byKey(const Key('reschedule-reason-POSTPONED')));
      await pickNextDay(tester);

      states.add(
        AnnouncementError(
          const ServerException(
            'L\'arrivée ne peut pas dépasser 14 jours après le départ.',
            'arrival-too-far',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('14 jours après le départ'), findsOneWidget);
      expect(find.byType(TripRescheduleBottomSheet), findsOneWidget);
      expect(
        tester
            .widget<DonyButton>(find.byKey(const Key('trip-reschedule-submit')))
            .onPressed,
        isNotNull,
      );
    });

    for (final locale in [AppL10n.fr, AppL10n.en]) {
      testWidgets('360 dp ${locale.languageCode} : quatre puces et bouton '
          'sur une ligne', (tester) async {
        if (locale == AppL10n.en) enableEnglish();
        await open(
          tester,
          trip: roadTrip(arrivalOffset: 6),
          locale: locale,
          size: const Size(360, 2400),
        );
        expect(tester.takeException(), isNull);

        final heights = <double>{};
        for (final k in [
          'arrival-day-0',
          'arrival-day-1',
          'arrival-day-2',
          'arrival-day-other',
        ]) {
          final chip = find.byKey(Key(k));
          expect(chip, findsOneWidget);
          final label = find.descendant(of: chip, matching: find.byType(Text));
          expect(tester.getSize(label.first).height, lessThan(24));
          heights.add(tester.getSize(chip).height);
        }
        expect(heights.length, 1);

        final button = find.descendant(
          of: find.byKey(const Key('trip-reschedule-submit')),
          matching: find.byType(Text),
        );
        final fontSize = tester.widget<Text>(button).style?.fontSize ?? 14;
        expect(
          tester.getSize(button).height,
          lessThanOrEqualTo(fontSize * 1.7),
        );
      });
    }
  });

  testWidgets(
    'trajet reporté : la feuille se ferme et annonce les expéditeurs prévenus',
    (tester) async {
      await open(tester);

      states.add(
        AnnouncementRescheduled(
          announcement,
          const TripRescheduleResult(
            rescheduleId: 'r1',
            rescheduleCount: 1,
            remainingReschedules: 1,
            parcelsAwaitingDecision: 2,
            requestsInformed: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TripRescheduleBottomSheet), findsNothing);
      expect(
        find.text('Trajet reporté. 2 expéditeurs vont confirmer leur colis.'),
        findsOneWidget,
      );
    },
  );
}

// Arithmétique de calendrier du report : dates fixes, indépendantes du jour
// d'exécution et du fuseau de la machine (heure d'été 2026 : dimanche 29 mars
// de 23 h, heure d'hiver : dimanche 25 octobre de 25 h en Europe/Paris).
void _calendarArithmeticTests() {
  group('calendarDaysBetween', () {
    test('semaine ordinaire', () {
      expect(
        calendarDaysBetween(DateTime(2026, 6, 10), DateTime(2026, 6, 11)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 6, 10), DateTime(2026, 6, 10)),
        0,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 6, 12), DateTime(2026, 6, 10)),
        -2,
      );
    });

    test('ignore les heures', () {
      expect(
        calendarDaysBetween(
          DateTime(2026, 6, 10, 23, 59),
          DateTime(2026, 6, 11, 0, 1),
        ),
        1,
      );
    });

    test('jour de 23 h (29 mars) : 29 -> 30 mars vaut 1 jour', () {
      expect(
        calendarDaysBetween(DateTime(2026, 3, 29), DateTime(2026, 3, 30)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)),
        2,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 3, 30), DateTime(2026, 3, 28)),
        -2,
      );
    });

    test('jour de 25 h (25 octobre) : 25 -> 26 octobre vaut 1 jour', () {
      expect(
        calendarDaysBetween(DateTime(2026, 10, 25), DateTime(2026, 10, 26)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)),
        2,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 10, 26), DateTime(2026, 10, 24)),
        -2,
      );
    });
  });

  group('rescheduleArrivalDate', () {
    test('semaine ordinaire', () {
      expect(
        rescheduleArrivalDate(DateTime(2026, 6, 10), 0),
        DateTime(2026, 6, 10),
      );
      expect(
        rescheduleArrivalDate(DateTime(2026, 6, 10), 1),
        DateTime(2026, 6, 11),
      );
      expect(
        rescheduleArrivalDate(DateTime(2026, 6, 30), 2),
        DateTime(2026, 7, 2),
      );
    });

    test('heure d\'hiver : 25 octobre + 1 jour = 26 octobre minuit', () {
      expect(
        rescheduleArrivalDate(DateTime(2026, 10, 25), 1),
        DateTime(2026, 10, 26),
      );
      expect(
        rescheduleArrivalDate(DateTime(2026, 10, 24), 2),
        DateTime(2026, 10, 26),
      );
      expect(
        rescheduleArrivalDate(DateTime(2026, 10, 25), 2),
        DateTime(2026, 10, 27),
      );
    });

    test('heure d\'été : 28/29 mars + jours', () {
      expect(
        rescheduleArrivalDate(DateTime(2026, 3, 29), 1),
        DateTime(2026, 3, 30),
      );
      expect(
        rescheduleArrivalDate(DateTime(2026, 3, 28), 2),
        DateTime(2026, 3, 30),
      );
    });
  });

  group('rescheduleDefaultHandoverDay', () {
    final past = DateTime(2026);

    DateTime day(DateTime d, int lead) => rescheduleDefaultHandoverDay(
      newDeparture: d,
      leadDays: lead,
      today: past,
    );

    test('semaine ordinaire, écart 0, 1 et 2 jours', () {
      final d = DateTime(2026, 6, 10);
      expect(day(d, 0), DateTime(2026, 6, 10));
      expect(day(d, 1), DateTime(2026, 6, 9));
      expect(day(d, 2), DateTime(2026, 6, 8));
    });

    test('heure d\'hiver : départ lundi 26 octobre 00:00, veille à minuit', () {
      final d = DateTime(2026, 10, 26);
      expect(day(d, 0), DateTime(2026, 10, 26));
      expect(day(d, 1), DateTime(2026, 10, 25));
      expect(day(d, 2), DateTime(2026, 10, 24));
      // Jamais une heure décalée : le jour sans heure reste à minuit.
      expect(day(d, 1).hour, 0);
    });

    test('heure d\'hiver : départ le jour du changement', () {
      final d = DateTime(2026, 10, 25);
      expect(day(d, 1), DateTime(2026, 10, 24));
      expect(day(d, 2), DateTime(2026, 10, 23));
    });

    test('heure d\'été : départ lundi 30 mars, veille et avant-veille', () {
      final d = DateTime(2026, 3, 30);
      expect(day(d, 0), DateTime(2026, 3, 30));
      expect(day(d, 1), DateTime(2026, 3, 29));
      expect(day(d, 2), DateTime(2026, 3, 28));
      expect(day(d, 1).hour, 0);
    });

    test('heure d\'été : départ le jour du changement', () {
      final d = DateTime(2026, 3, 29);
      expect(day(d, 1), DateTime(2026, 3, 28));
      expect(day(d, 2), DateTime(2026, 3, 27));
    });

    test('écart plafonné à 7 jours et jamais négatif', () {
      final d = DateTime(2026, 6, 20);
      expect(day(d, 30), DateTime(2026, 6, 13));
      expect(day(d, -3), DateTime(2026, 6, 20));
    });

    test('jamais avant aujourd\'hui', () {
      final today = DateTime(2026, 10, 25);
      expect(
        rescheduleDefaultHandoverDay(
          newDeparture: DateTime(2026, 10, 26),
          leadDays: 2,
          today: today,
        ),
        today,
      );
    });
  });
}
