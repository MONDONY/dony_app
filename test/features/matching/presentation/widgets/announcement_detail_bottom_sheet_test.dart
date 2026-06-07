// Widget tests pour la CTA « Ouvrir les kg restants » dans le détail du trajet
// (B5) + affichage « réservés / ouverts » quand le surplus est publié.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

AnnouncementModel _ann({
  double reservedKg = 0,
  bool surplusEligible = false,
  bool surplusPublished = false,
  double availableKg = 10,
  int bidsCount = 0,
}) =>
    AnnouncementModel(
      id: 'ann-1',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 8),
      availableKg: availableKg,
      totalKg: reservedKg + availableKg,
      pricePerKg: 7,
      status: 'ACTIVE',
      bidsCount: bidsCount,
      createdAt: DateTime(2026, 7),
      updatedAt: DateTime(2026, 7),
      reservedKg: reservedKg,
      surplusEligible: surplusEligible,
      surplusPublished: surplusPublished,
    );

void main() {
  late MockAnnouncementBloc annBloc;
  late MockCancellationBloc cancelBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  void seedDetail(AnnouncementModel a) {
    when(() => annBloc.state).thenReturn(AnnouncementDetailLoaded(a));
    whenListen(annBloc, const Stream<AnnouncementState>.empty(),
        initialState: AnnouncementDetailLoaded(a));
  }

  setUp(() {
    annBloc = MockAnnouncementBloc();
    cancelBloc = MockCancellationBloc();
    when(() => cancelBloc.state).thenReturn(CancellationInitial());
    whenListen(cancelBloc, const Stream<CancellationState>.empty(),
        initialState: CancellationInitial());

    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<CancellationBloc>()) {
      getIt.unregister<CancellationBloc>();
    }
    getIt.registerFactory<AnnouncementBloc>(() => annBloc);
    getIt.registerFactory<CancellationBloc>(() => cancelBloc);
  });

  tearDown(() {
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<CancellationBloc>()) {
      getIt.unregister<CancellationBloc>();
    }
  });

  Widget host() => MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              key: const Key('open-btn'),
              onPressed: () => AnnouncementDetailBottomSheet.show(
                ctx,
                announcementId: 'ann-1',
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('open-btn')));
    await tester.pumpAndSettle();
  }

  testWidgets('canOpenSurplus → bouton « Ouvrir les kg restants » présent',
      (tester) async {
    seedDetail(_ann(reservedKg: 12, surplusEligible: true));
    await open(tester);

    expect(
      find.widgetWithText(DonyButton, 'Ouvrir les kg restants'),
      findsOneWidget,
    );
  });

  testWidgets(
      'surplus déjà publié → bouton absent + affichage réservés / ouverts',
      (tester) async {
    seedDetail(_ann(
      reservedKg: 12,
      surplusEligible: true,
      surplusPublished: true,
      availableKg: 8,
    ));
    await open(tester);

    expect(
      find.widgetWithText(DonyButton, 'Ouvrir les kg restants'),
      findsNothing,
    );
    expect(find.textContaining('12 kg réservés'), findsOneWidget);
    expect(find.textContaining('8 kg ouverts'), findsOneWidget);
  });

  testWidgets(
      'tap sur « Ouvrir les kg restants » ouvre la feuille surplus',
      (tester) async {
    seedDetail(_ann(reservedKg: 12, surplusEligible: true));
    await open(tester);

    await tester.tap(
      find.widgetWithText(DonyButton, 'Ouvrir les kg restants'),
    );
    await tester.pumpAndSettle();

    // La feuille OpenSurplusBottomSheet est ouverte par-dessus le détail.
    expect(find.text('Ouvrir les kg restants'), findsWidgets);
    expect(find.text('12 kg verrouillés'), findsOneWidget);
  });

  testWidgets('non éligible → bouton absent', (tester) async {
    seedDetail(_ann(reservedKg: 12));
    await open(tester);

    expect(
      find.widgetWithText(DonyButton, 'Ouvrir les kg restants'),
      findsNothing,
    );
  });

  testWidgets('trajet public classique (non dédié) → bouton absent',
      (tester) async {
    seedDetail(_ann());
    await open(tester);

    expect(
      find.widgetWithText(DonyButton, 'Ouvrir les kg restants'),
      findsNothing,
    );
  });
}
