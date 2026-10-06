import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/widgets/intent_form.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockIntentCubit extends MockCubit<IntentFormState>
    implements IntentCubit {}

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
