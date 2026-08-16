// Widget tests pour ArrivalInstructionsBottomSheet (F5).
//
// Vérifie : dispatch de AnnouncementTripMarkArrivedRequested au tap
// « Confirmer l'arrivée » (avec/sans instructions), fermeture + snackbar
// succès sur AnnouncementTripArrived, ErrorPresenter sur AnnouncementError.
//
// Le sheet lit le AnnouncementBloc partagé via `context.read` (comme
// CancellationBottomSheet) : le test le fournit via BlocProvider.value au
// niveau du host, pas via getIt.
//
// Piège : `BlocProvider.value` réabonne son propre listener interne
// (Provider) au stream dès que l'ancêtre est reconstruit — ce qui arrive
// forcément à l'ouverture d'un bottom sheet modal. Avec un stream
// `Stream.fromIterable` à émission unique, ce réabonnement drain
// silencieusement l'unique événement avant que le `BlocListener` du widget
// ne s'y abonne à son tour (stream déjà terminé, broadcast sans rejeu). On
// utilise donc un `StreamController` broadcast et on émet l'état APRÈS
// l'ouverture du sheet, une fois tous les abonnements en place.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

AnnouncementModel _announcement() => AnnouncementModel(
  id: 'a1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 8),
  availableKg: 10,
  totalKg: 20,
  pricePerKg: 5,
  status: 'ARRIVED',
  createdAt: DateTime(2026, 7),
  updatedAt: DateTime(2026, 7),
);

void main() {
  late MockAnnouncementBloc bloc;

  setUpAll(() {
    registerFallbackValue(
      AnnouncementTripMarkArrivedRequested(announcementId: 'x'),
    );
  });

  setUp(() {
    bloc = MockAnnouncementBloc();
    when(() => bloc.state).thenReturn(AnnouncementInitial());
    whenListen(
      bloc,
      const Stream<AnnouncementState>.empty(),
      initialState: AnnouncementInitial(),
    );
  });

  Widget host() => MaterialApp(
    theme: AppTheme.light(),
    home: BlocProvider<AnnouncementBloc>.value(
      value: bloc,
      child: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open-btn'),
              onPressed: () => ArrivalInstructionsBottomSheet.show(
                ctx,
                announcementId: 'a1',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('open-btn')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'submitting dispatches AnnouncementTripMarkArrivedRequested avec les instructions saisies',
    (tester) async {
      await open(tester);

      await tester.enterText(
        find.byType(TextField),
        'Métro Châtelet, sortie 3',
      );
      await tester.tap(find.text("Confirmer l'arrivée"));
      await tester.pump();

      final captured = verify(() => bloc.add(captureAny())).captured;
      final event = captured
          .whereType<AnnouncementTripMarkArrivedRequested>()
          .single;
      expect(event.announcementId, 'a1');
      expect(event.arrivalInstructions, 'Métro Châtelet, sortie 3');
    },
  );

  testWidgets('submitting sans instructions envoie arrivalInstructions null', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text("Confirmer l'arrivée"));
    await tester.pump();

    final captured = verify(() => bloc.add(captureAny())).captured;
    final event = captured
        .whereType<AnnouncementTripMarkArrivedRequested>()
        .single;
    expect(event.announcementId, 'a1');
    expect(event.arrivalInstructions, isNull);
  });

  testWidgets(
    'le sheet se ferme et affiche un snackbar succès sur AnnouncementTripArrived',
    (tester) async {
      final controller = StreamController<AnnouncementState>.broadcast();
      addTearDown(controller.close);
      whenListen(bloc, controller.stream, initialState: AnnouncementInitial());

      await open(tester);

      controller.add(AnnouncementTripArrived(_announcement()));
      await tester.pumpAndSettle();

      expect(find.text('Trajet marqué comme arrivé'), findsOneWidget);
      expect(find.text('Arrivé à destination'), findsNothing);
    },
  );

  testWidgets('affiche un état de chargement pendant Loading', (tester) async {
    when(() => bloc.state).thenReturn(AnnouncementLoading());
    whenListen(
      bloc,
      const Stream<AnnouncementState>.empty(),
      initialState: AnnouncementLoading(),
    );

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('open-btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final button = tester.widget<DonyButton>(find.byType(DonyButton));
    expect(button.isLoading, isTrue);
    expect(button.onPressed, isNull);
  });

  testWidgets(
    "affiche un message d'erreur via ErrorPresenter sur AnnouncementError",
    (tester) async {
      final controller = StreamController<AnnouncementState>.broadcast();
      addTearDown(controller.close);
      whenListen(bloc, controller.stream, initialState: AnnouncementInitial());

      await open(tester);

      controller.add(
        AnnouncementError(const NetworkException('Erreur réseau brute')),
      );
      await tester.pumpAndSettle();

      // ErrorPresenter passe par ErrorCatalog : le message brut n'est jamais
      // affiché tel quel, on vérifie le titre mappé (_networkGeneric).
      expect(find.text('Erreur réseau'), findsOneWidget);
    },
  );
}
