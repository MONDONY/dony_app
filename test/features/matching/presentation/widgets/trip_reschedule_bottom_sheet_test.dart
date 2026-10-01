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

/// Départ dans quelques jours, un jour du mois où le lendemain existe encore
/// dans la même grille du sélecteur de date.
DateTime _departureDay() {
  var d = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 3));
  while (d.day > 26) {
    d = d.add(const Duration(days: 1));
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
    arrivalDate: departure.add(const Duration(days: 1)),
    handoverDeadline: departure.subtract(const Duration(days: 1)),
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

    final day = departure.subtract(const Duration(days: 1));
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
        matching: find.textContaining('${departure.day + 1}'),
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
      final newDay = departure.add(const Duration(days: 1));
      expect(event.announcementId, 'a1');
      expect(DateUtils.isSameDay(event.departureDate, newDay), isTrue);
      expect(event.departureTime, '22:00');
      expect(event.arrivalTime, '06:30');
      // Vol de nuit gardé : arrivée le lendemain du nouveau départ.
      expect(
        event.arrivalDate,
        DateUtils.dateOnly(
          newDay.add(const Duration(days: 1)),
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
