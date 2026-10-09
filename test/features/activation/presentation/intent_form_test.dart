import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/data/activation_repository.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/widgets/intent_form.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockIntentCubit extends MockCubit<IntentFormState>
    implements IntentCubit {}

class _MockRepo extends Mock implements ActivationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

/// Les 14 pays UEMOA + CEMAC acceptés par `CountryCatalog` côté serveur.
const _uemoaCemac = [
  'BJ', 'BF', 'CI', 'GW', 'ML', 'NE', 'SN', 'TG', // UEMOA
  'CM', 'CF', 'TD', 'CG', 'GQ', 'GA', // CEMAC
];

void main() {
  late _MockIntentCubit cubit;

  setUp(() {
    cubit = _MockIntentCubit();
    when(() => cubit.state).thenReturn(const IntentFormState());
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<IntentCubit>.value(
          value: cubit,
          child: const SingleChildScrollView(child: IntentForm()),
        ),
      ),
    ),
  );

  testWidgets('affiche les trois intentions et les destinations', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Envoyer des colis'), findsOneWidget);
    expect(find.text("Je voyage et j'ai de la place"), findsOneWidget);
    expect(find.text('Les deux'), findsOneWidget);
    for (final code in kIntentDestinations) {
      expect(find.byKey(Key('intent-destination-$code')), findsOneWidget);
    }
    expect(find.byKey(const Key('intent-destination-OTHER')), findsOneWidget);
  });

  testWidgets('destination principale : titre et aide sans ambiguïté', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Votre destination principale'), findsOneWidget);
    expect(
      find.text(
        'Pour personnaliser votre accueil. Vous pouvez envoyer et voyager '
        'vers tous les pays desservis.',
      ),
      findsOneWidget,
    );
    expect(find.text('Vers quel pays ?'), findsNothing);
  });

  testWidgets('destination principale : textes anglais', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<IntentCubit>.value(
            value: cubit,
            child: const SingleChildScrollView(child: IntentForm()),
          ),
        ),
      ),
    );
    expect(find.text('Your main destination'), findsOneWidget);
    expect(
      find.text(
        'Used to personalise your home screen. You can still send and travel '
        'to every country we serve.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('FLUTTER-H5 : les 14 pays UEMOA + CEMAC et « Autre »', (
    tester,
  ) async {
    await pump(tester);
    expect(kIntentDestinations.toSet(), _uemoaCemac.toSet());
    expect(kIntentDestinations, hasLength(14));
    for (final code in _uemoaCemac) {
      expect(find.byKey(Key('intent-destination-$code')), findsOneWidget);
    }
    expect(find.text('🇬🇶 Guinée équatoriale'), findsOneWidget);
    expect(find.text('🇧🇯 Bénin'), findsOneWidget);
    expect(find.text('Autre'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FLUTTER-H5 : corridors en tête puis ordre alphabétique', (
    tester,
  ) async {
    await pump(tester);
    final l = lookupAppLocalizations(const Locale('fr'));
    final ordered = orderedIntentDestinations(l);
    expect(ordered.take(4), ['SN', 'CI', 'ML', 'CM']);
    // « Bénin » avant « Burkina Faso » : les accents sont ignorés.
    expect(ordered.skip(4), [
      'BJ', 'BF', 'CF', 'CG', 'GA', 'GQ', 'GW', 'NE', 'TD', 'TG', //
    ]);
    final positions = [
      for (final code in ordered)
        tester.getTopLeft(find.byKey(Key('intent-destination-$code'))),
    ];
    for (var i = 1; i < positions.length; i++) {
      final prev = positions[i - 1];
      final cur = positions[i];
      expect(
        cur.dy > prev.dy || (cur.dy == prev.dy && cur.dx > prev.dx),
        isTrue,
        reason: '${ordered[i]} doit suivre ${ordered[i - 1]}',
      );
    }
  });

  testWidgets('FLUTTER-H5 : ordre anglais suivant les noms anglais', (
    tester,
  ) async {
    final l = lookupAppLocalizations(const Locale('en'));
    final ordered = orderedIntentDestinations(l);
    expect(ordered.take(4), ['SN', 'CI', 'ML', 'CM']);
    expect(ordered.skip(4), [
      'BJ', 'BF', 'CF', 'TD', 'CG', 'GQ', 'GA', 'GW', 'NE', 'TG', //
    ]);
  });

  testWidgets('FLUTTER-H5 : un nouveau pays choisi part tel quel au serveur', (
    tester,
  ) async {
    registerFallbackValue(UserIntent.sender);
    registerFallbackValue(IntentSource.signup);
    final repo = _MockRepo();
    final analytics = _MockAnalytics();
    when(
      () => repo.declareIntent(
        intent: any(named: 'intent'),
        destinationCountry: any(named: 'destinationCountry'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    final real = IntentCubit(repo, analytics);
    addTearDown(real.close);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<IntentCubit>.value(
            value: real,
            child: const SingleChildScrollView(child: IntentForm()),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('intent-option-sender')));
    final gabon = find.byKey(const Key('intent-destination-GA'));
    await tester.ensureVisible(gabon);
    await tester.tap(gabon);
    await tester.pump();
    expect(real.state.destination, 'GA');
    expect(
      tester.getSemantics(gabon),
      isSemantics(isSelected: true, isButton: true),
    );
    await real.submit(IntentSource.settings);
    verify(
      () => repo.declareIntent(
        intent: UserIntent.sender,
        destinationCountry: 'GA',
        source: IntentSource.settings,
      ),
    ).called(1);
  });

  testWidgets('les taps sélectionnent', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('intent-option-traveler')));
    await tester.tap(find.byKey(const Key('intent-destination-CI')));
    await tester.tap(find.byKey(const Key('intent-destination-OTHER')));
    verify(() => cubit.selectIntent(UserIntent.traveler)).called(1);
    verify(() => cubit.selectDestination('CI')).called(1);
    verify(() => cubit.selectDestination(kIntentOtherDestination)).called(1);
  });

  testWidgets('l\'option choisie est annoncée comme sélectionnée', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const IntentFormState(intent: UserIntent.both));
    await pump(tester);
    expect(
      tester.getSemantics(find.byKey(const Key('intent-option-both'))),
      isSemantics(isSelected: true, isButton: true),
    );
  });
}
