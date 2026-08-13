// Widget tests pour OpenSurplusBottomSheet (B4).
//
// Vérifie : rendu des chips de prix, bouton désactivé tant que le formulaire
// est invalide, dispatch de AnnouncementSurplusOpenRequested au tap « Publier »,
// fermeture sur AnnouncementSurplusOpened.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/open_surplus_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

AnnouncementModel _dedicated() => AnnouncementModel(
  id: 'ann-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 8),
  availableKg: 0,
  totalKg: 12,
  pricePerKg: 0,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 7),
  updatedAt: DateTime(2026, 7),
  reservedKg: 12,
  surplusEligible: true,
);

void main() {
  late MockAnnouncementBloc bloc;

  setUpAll(() {
    registerFallbackValue(
      AnnouncementSurplusOpenRequested(
        announcementId: 'x',
        surplusKg: 1,
        pricePerKg: 1,
      ),
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
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    getIt.registerFactory<AnnouncementBloc>(() => bloc);
  });

  tearDown(() {
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
  });

  Widget host() => MaterialApp(
    theme: AppTheme.light(),
    home: Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const Key('open-btn'),
            onPressed: () =>
                OpenSurplusBottomSheet.show(ctx, announcement: _dedicated()),
            child: const Text('Ouvrir'),
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

  testWidgets('affiche le titre, la capacité réservée et les chips de prix', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Ouvrir les kg restants'), findsOneWidget);
    expect(find.text('12 kg verrouillés'), findsOneWidget);
    // 4 chips preset (5/6/7/8 €) + chip « Autre ».
    expect(find.byKey(const Key('surplus-price-chip-0')), findsOneWidget);
    expect(find.byKey(const Key('surplus-price-chip-3')), findsOneWidget);
    expect(find.byKey(const Key('surplus-price-chip-custom')), findsOneWidget);
    expect(find.text('Publier'), findsOneWidget);
  });

  testWidgets('le bouton Publier est désactivé tant que les kg sont absents', (
    tester,
  ) async {
    await open(tester);

    // Un prix preset est sélectionné par défaut, mais kg vide → invalide.
    final button = tester.widget<DonyButton>(
      find.widgetWithText(DonyButton, 'Publier'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'le bouton Publier s\'active quand kg ≥ 1 et un prix est choisi',
    (tester) async {
      await open(tester);

      await tester.enterText(find.byKey(const Key('surplus-kg-field')), '8');
      await tester.pumpAndSettle();

      final button = tester.widget<DonyButton>(
        find.widgetWithText(DonyButton, 'Publier'),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'tap Publier dispatche AnnouncementSurplusOpenRequested avec les bons args',
    (tester) async {
      await open(tester);

      await tester.enterText(find.byKey(const Key('surplus-kg-field')), '8');
      await tester.pumpAndSettle();
      // Sélectionne explicitement le chip 7€ (index 2).
      await tester.tap(find.byKey(const Key('surplus-price-chip-2')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DonyButton, 'Publier'));
      await tester.pump();

      final captured = verify(() => bloc.add(captureAny())).captured;
      final event = captured
          .whereType<AnnouncementSurplusOpenRequested>()
          .single;
      expect(event.announcementId, 'ann-1');
      expect(event.surplusKg, 8.0);
      expect(event.pricePerKg, 7.0);
    },
  );

  testWidgets('saisie d\'un prix custom envoie ce prix', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('surplus-kg-field')), '5');
    await tester.tap(find.byKey(const Key('surplus-price-chip-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('surplus-custom-price-field')),
      '9',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DonyButton, 'Publier'));
    await tester.pump();

    final event = verify(
      () => bloc.add(captureAny()),
    ).captured.whereType<AnnouncementSurplusOpenRequested>().single;
    expect(event.surplusKg, 5.0);
    expect(event.pricePerKg, 9.0);
  });

  testWidgets('le sheet se ferme sur AnnouncementSurplusOpened', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<AnnouncementState>.fromIterable([
        AnnouncementSurplusOpened(_dedicated()),
      ]),
      initialState: AnnouncementInitial(),
    );

    await open(tester);
    // Le titre était visible à l'ouverture.
    await tester.pumpAndSettle();

    expect(find.text('Ouvrir les kg restants'), findsNothing);
  });

  testWidgets('affiche un état de chargement (Publication…) pendant Loading', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(AnnouncementLoading());
    whenListen(
      bloc,
      const Stream<AnnouncementState>.empty(),
      initialState: AnnouncementLoading(),
    );

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('open-btn')));
    // pump() explicite : le spinner du DonyButton (animation infinie) empêche
    // pumpAndSettle de se terminer.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // En loading, le DonyButton n'affiche que le spinner : on vérifie l'état
    // via ses propriétés (isLoading + label) plutôt que via le texte rendu.
    final button = tester.widget<DonyButton>(find.byType(DonyButton));
    expect(button.isLoading, isTrue);
    expect(button.label, 'Publication…');
    expect(button.onPressed, isNull);
  });
}
