import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/presentation/widgets/recipient_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class FakeRecipientEvent extends Fake implements RecipientEvent {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

const _r1 = Recipient(
  id: 'r-1',
  fullName: 'Mamadou Diallo',
  phoneE164: '+221771234567',
  city: 'Dakar',
  country: 'SN',
);

void main() {
  setUpAll(() => registerFallbackValue(FakeRecipientEvent()));

  late MockRecipientBloc sectionBloc;
  late MockAnalyticsService analytics;
  late RecipientSectionController controller;
  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController cityCtrl;

  setUp(() {
    sectionBloc = MockRecipientBloc();
    when(() => sectionBloc.state).thenReturn(const RecipientState());
    controller = RecipientSectionController();
    nameCtrl = TextEditingController();
    phoneCtrl = TextEditingController();
    cityCtrl = TextEditingController();

    // RecipientPickerSheet (Task 8) logge un event via getIt<AnalyticsService>
    // dans son initState — nécessaire dès qu'un test ouvre le picker.
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(analytics);
  });

  tearDown(() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    cityCtrl.dispose();
    if (getIt.isRegistered<RecipientBloc>()) {
      getIt.unregister<RecipientBloc>();
    }
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  Widget buildSut({String? fallbackCity, String? fallbackCountry}) =>
      MaterialApp(
        home: Scaffold(
          body: RecipientSection(
            controller: controller,
            nameCtrl: nameCtrl,
            phoneCtrl: phoneCtrl,
            cityCtrl: cityCtrl,
            fallbackCity: fallbackCity,
            fallbackCountry: fallbackCountry,
            createBloc: () => sectionBloc,
            children: const [SizedBox.shrink()],
          ),
        ),
      );

  testWidgets('initial state shows picker button', (tester) async {
    await tester.pumpWidget(buildSut());
    await tester.pump();

    expect(find.text('Choisir un destinataire'), findsOneWidget);
    expect(find.text('Changer'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('manual edit of a selected recipient reverts to manual state', (
    tester,
  ) async {
    // Bloc utilisé en interne par RecipientPickerSheet.show() — distinct du
    // bloc de la section, injecté via `getIt` (comportement réel du picker).
    final pickerBloc = MockRecipientBloc();
    when(() => pickerBloc.state).thenReturn(
      const RecipientState(status: RecipientStatus.success, recipients: [_r1]),
    );
    getIt.registerFactory<RecipientBloc>(() => pickerBloc);

    await tester.pumpWidget(buildSut());
    await tester.pump();

    await tester.tap(find.text('Choisir un destinataire'));
    await tester.pumpAndSettle();

    // Seul destinataire de la liste → présélectionné automatiquement.
    await tester.tap(find.text('Confirmer ce destinataire'));
    await tester.pumpAndSettle();

    // État 2 : carte sélectionnée, champs prérempli.
    expect(find.text('Changer'), findsOneWidget);
    expect(nameCtrl.text, _r1.fullName);
    expect(phoneCtrl.text, _r1.phoneE164);

    // L'utilisateur modifie manuellement le nom → invalide la sélection.
    nameCtrl.text = 'Un Autre Nom';
    await tester.pump();

    expect(find.text('Changer'), findsNothing);
    expect(find.text('Choisir un destinataire'), findsOneWidget);
  });

  testWidgets(
    'editing city only does not clear a selected recipient (regression)',
    (tester) async {
      final pickerBloc = MockRecipientBloc();
      when(() => pickerBloc.state).thenReturn(
        const RecipientState(
          status: RecipientStatus.success,
          recipients: [_r1],
        ),
      );
      getIt.registerFactory<RecipientBloc>(() => pickerBloc);

      await tester.pumpWidget(buildSut());
      await tester.pump();
      await tester.tap(find.text('Choisir un destinataire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer ce destinataire'));
      await tester.pumpAndSettle();

      expect(find.text('Changer'), findsOneWidget);

      cityCtrl.text = 'Rufisque';
      await tester.pump();

      // Toujours sélectionné : seule la ville a changé.
      expect(find.text('Changer'), findsOneWidget);
    },
  );

  testWidgets(
    'reloads the recipient list even when the picker is dismissed without '
    'picking anything (fix 3: avoids a stale toggle after in-sheet create)',
    (tester) async {
      final pickerBloc = MockRecipientBloc();
      when(() => pickerBloc.state).thenReturn(
        const RecipientState(status: RecipientStatus.success, recipients: [_r1]),
      );
      getIt.registerFactory<RecipientBloc>(() => pickerBloc);

      await tester.pumpWidget(buildSut());
      await tester.pump();

      // sectionBloc.add() is called once with RecipientLoaded in initState.
      verify(() => sectionBloc.add(const RecipientLoaded())).called(1);

      await tester.tap(find.text('Choisir un destinataire'));
      await tester.pumpAndSettle();

      // Dismiss the sheet without confirming (close button -> pops null).
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      // Still on the initial state (no recipient selected)...
      expect(find.text('Choisir un destinataire'), findsOneWidget);
      // ...but the section's own bloc was reloaded a second time, so a
      // recipient created-then-abandoned inside the sheet is reflected in
      // `_phoneIsKnown`/`_toggleVisible` right away.
      verify(() => sectionBloc.add(const RecipientLoaded())).called(1);
    },
  );

  testWidgets('toggle hidden when phone matches a saved recipient', (
    tester,
  ) async {
    when(() => sectionBloc.state).thenReturn(
      const RecipientState(status: RecipientStatus.success, recipients: [_r1]),
    );

    await tester.pumpWidget(buildSut());
    await tester.pump();

    nameCtrl.text = 'Mamadou Diallo';
    phoneCtrl.text = _r1.phoneE164; // déjà connu
    await tester.pump();

    expect(find.byType(SwitchListTile), findsNothing);

    // Un numéro valide mais inconnu fait apparaître le toggle : preuve que
    // le gate dépend bien de la connaissance du numéro, pas d'un blocage
    // permanent.
    phoneCtrl.text = '+221781112233';
    await tester.pump();

    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets(
    'maybeSaveManualEntry dispatches RecipientCreated with phone-derived country',
    (tester) async {
      await tester.pumpWidget(buildSut(fallbackCity: 'Dakar'));
      await tester.pump();

      nameCtrl.text = 'Fatou Ndiaye';
      phoneCtrl.text = '+221771112233'; // -> SN via countryFromPhone
      await tester.pump();

      expect(find.byType(SwitchListTile), findsOneWidget);

      controller.maybeSaveManualEntry();

      // captureAny récupère tout ce qui a transité par add() (y compris le
      // RecipientLoaded de initState) → on isole le seul RecipientCreated.
      final captured = verify(() => sectionBloc.add(captureAny())).captured;
      final created = captured.whereType<RecipientCreated>();
      expect(created, hasLength(1));
      final event = created.single;
      expect(event.fullName, 'Fatou Ndiaye');
      expect(event.phoneE164, '+221771112233');
      expect(event.country, 'SN');
      expect(event.city, 'Dakar'); // cityCtrl vide → fallbackCity
    },
  );

  testWidgets(
    'maybeSaveManualEntry uses fallbackCountry over phone-derived country',
    (tester) async {
      await tester.pumpWidget(buildSut(fallbackCity: 'Dakar', fallbackCountry: 'CI'));
      await tester.pump();

      nameCtrl.text = 'Ama Koffi';
      phoneCtrl.text = '+221771234567'; // -> SN via countryFromPhone (different from CI)
      await tester.pump();

      expect(find.byType(SwitchListTile), findsOneWidget);

      controller.maybeSaveManualEntry();

      // fallbackCountry='CI' should win over phone-derived 'SN'
      final captured = verify(() => sectionBloc.add(captureAny())).captured;
      final created = captured.whereType<RecipientCreated>();
      expect(created, hasLength(1));
      final event = created.single;
      expect(event.fullName, 'Ama Koffi');
      expect(event.phoneE164, '+221771234567');
      expect(event.country, 'CI'); // fallbackCountry wins, not 'SN' from phone
      expect(event.city, 'Dakar');
    },
  );

  testWidgets('maybeSaveManualEntry does nothing when toggle off', (
    tester,
  ) async {
    await tester.pumpWidget(buildSut(fallbackCity: 'Dakar'));
    await tester.pump();

    nameCtrl.text = 'Fatou Ndiaye';
    phoneCtrl.text = '+221771112233';
    await tester.pump();

    expect(find.byType(SwitchListTile), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    controller.maybeSaveManualEntry();

    verifyNever(() => sectionBloc.add(any(that: isA<RecipientCreated>())));
  });

  group('countryFromPhone', () {
    test('+221 -> SN', () {
      expect(countryFromPhone('+221771234567'), 'SN');
    });

    test('+225 -> CI', () {
      expect(countryFromPhone('+22507891234'), 'CI');
    });

    test('+223 -> ML', () {
      expect(countryFromPhone('+22370001122'), 'ML');
    });

    test('+237 -> CM', () {
      expect(countryFromPhone('+237691234567'), 'CM');
    });

    test('unknown prefix defaults to SN', () {
      expect(countryFromPhone('+33612345678'), 'SN');
    });
  });
}
