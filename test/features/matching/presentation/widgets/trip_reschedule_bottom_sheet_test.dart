import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_result.dart';
import 'package:dony/features/matching/presentation/widgets/trip_reschedule_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
  late _MockAnnouncementBloc bloc;
  late StreamController<AnnouncementState> states;
  final departure = _departureDay();

  final announcement = AnnouncementModel(
    id: 'a1',
    travelerId: 't1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: departure,
    departureTime: '22:00',
    arrivalTime: '06:30',
    arrivalDate: _plusDays(departure, 1),
    handoverDeadline: _plusDays(departure, -1),
    availableKg: 10,
    totalKg: 20,
    pricePerKg: 5,
    status: 'FULL',
    bidsCount: 2,
    remainingReschedules: 1,
    createdAt: DateTime(2026, 9),
    updatedAt: DateTime(2026, 9),
  );

  setUpAll(() {
    registerFallbackValue(AnnouncementDetailRequested('x'));
  });

  setUp(() {
    bloc = _MockAnnouncementBloc();
    states = StreamController<AnnouncementState>.broadcast();
    addTearDown(states.close);
    whenListen(bloc, states.stream, initialState: AnnouncementInitial());
  });

  Widget host() => MaterialApp(
    theme: AppTheme.light(),
    locale: AppL10n.fr,
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
                announcement: announcement,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
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
