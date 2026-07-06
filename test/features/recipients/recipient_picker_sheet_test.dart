import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/contact_picker_service.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/presentation/widgets/recipient_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class FakeRecipientEvent extends Fake implements RecipientEvent {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockContactPickerService extends Mock implements ContactPickerService {}

const _r1 = Recipient(
  id: 'r-1',
  fullName: 'Mamadou Diallo',
  phoneE164: '+221771234567',
  city: 'Dakar',
  country: 'SN',
);

const _r2 = Recipient(
  id: 'r-2',
  fullName: 'Aminata Koné',
  phoneE164: '+22507891234',
  city: 'Abidjan',
  country: 'CI',
);

const _r3 = Recipient(
  id: 'r-3',
  fullName: 'Moussa Traoré',
  phoneE164: '+22370001122',
  city: 'Bamako',
  country: 'ML',
);

const _r4Default = Recipient(
  id: 'r-4',
  fullName: 'Ndèye Fall',
  phoneE164: '+221781112233',
  city: 'Dakar',
  country: 'SN',
  isDefault: true,
);

void main() {
  setUpAll(() => registerFallbackValue(FakeRecipientEvent()));

  late MockAnalyticsService analytics;
  late MockContactPickerService contactPicker;

  setUp(() {
    analytics = MockAnalyticsService();
    contactPicker = MockContactPickerService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(analytics);

    if (getIt.isRegistered<ContactPickerService>()) {
      getIt.unregister<ContactPickerService>();
    }
    getIt.registerSingleton<ContactPickerService>(contactPicker);
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    if (getIt.isRegistered<ContactPickerService>()) {
      getIt.unregister<ContactPickerService>();
    }
    if (getIt.isRegistered<RecipientBloc>()) {
      getIt.unregister<RecipientBloc>();
    }
  });

  /// Ouvre la sheet via `.show()` (mêmes routes que `recipients_screen_test`)
  /// et retourne le `Future<Recipient?>` produit par le pop, capturé dans
  /// [resultHolder] pour être inspecté après `pumpAndSettle`.
  Future<void> pumpSheet(
    WidgetTester tester,
    RecipientBloc bloc, {
    String? currentPhone,
    required List<Recipient?> resultHolder,
  }) async {
    if (getIt.isRegistered<RecipientBloc>()) {
      getIt.unregister<RecipientBloc>();
    }
    getIt.registerFactory<RecipientBloc>(() => bloc);

    // Surface agrandie : la sheet (0.7 de la hauteur) doit avoir assez de
    // place pour que le ListView construise toutes les lignes destinataire
    // dans la fenêtre visible + cache extent (sinon les lignes hors-écran
    // ne sont pas inflate et les finders `find.text` les manquent).
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      final r = await RecipientPickerSheet.show(
                        context,
                        currentPhone: currentPhone,
                      );
                      resultHolder.add(r);
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/profile/recipients/new',
              builder: (_, _) => const Scaffold(body: Text('New Recipient')),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('preselects default recipient and confirms it', (tester) async {
    final bloc = MockRecipientBloc();
    when(() => bloc.state).thenReturn(
      const RecipientState(
        status: RecipientStatus.success,
        recipients: [_r1, _r4Default],
      ),
    );
    final results = <Recipient?>[];

    await pumpSheet(tester, bloc, resultHolder: results);

    // Le badge « Par défaut » n'apparaît que sur r-4 → confirme la
    // présélection visuelle du destinataire par défaut.
    expect(find.text('Par défaut'), findsOneWidget);

    await tester.tap(find.text('Confirmer ce destinataire'));
    await tester.pumpAndSettle();

    expect(results, [_r4Default]);
    verify(() => bloc.add(const RecipientPicked('saved'))).called(1);
  });

  testWidgets(
    'currentPhone match takes precedence over default when nothing else selected',
    (tester) async {
      final bloc = MockRecipientBloc();
      when(() => bloc.state).thenReturn(
        const RecipientState(
          status: RecipientStatus.success,
          recipients: [_r1, _r4Default],
        ),
      );
      final results = <Recipient?>[];

      await pumpSheet(
        tester,
        bloc,
        currentPhone: _r1.phoneE164,
        resultHolder: results,
      );

      await tester.tap(find.text('Confirmer ce destinataire'));
      await tester.pumpAndSettle();

      expect(results, [_r1]);
    },
  );

  testWidgets('search filters list by name and city', (tester) async {
    final bloc = MockRecipientBloc();
    // > 3 destinataires pour afficher le champ de recherche.
    when(() => bloc.state).thenReturn(
      const RecipientState(
        status: RecipientStatus.success,
        recipients: [_r1, _r2, _r3, _r4Default],
      ),
    );
    final results = <Recipient?>[];

    await pumpSheet(tester, bloc, resultHolder: results);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Aminata Koné'), findsOneWidget);
    expect(find.text('Moussa Traoré'), findsOneWidget);

    // "ndeye" (sans accent) doit matcher "Ndèye Fall" — filtre
    // insensible à la casse et aux accents.
    await tester.enterText(find.byType(TextField), 'ndeye');
    await tester.pumpAndSettle();

    expect(find.text('Ndèye Fall'), findsOneWidget);
    expect(find.text('Aminata Koné'), findsNothing);
    expect(find.text('Moussa Traoré'), findsNothing);
    expect(find.text('Mamadou Diallo'), findsNothing);

    // Recherche par ville.
    await tester.enterText(find.byType(TextField), 'abidjan');
    await tester.pumpAndSettle();

    expect(find.text('Aminata Koné'), findsOneWidget);
    expect(find.text('Ndèye Fall'), findsNothing);
  });

  testWidgets('tapping a row changes selection', (tester) async {
    final bloc = MockRecipientBloc();
    when(() => bloc.state).thenReturn(
      const RecipientState(
        status: RecipientStatus.success,
        recipients: [_r1, _r4Default],
      ),
    );
    final results = <Recipient?>[];

    await pumpSheet(tester, bloc, resultHolder: results);

    // Par défaut r-4 est présélectionné ; on tape r-1 pour changer.
    await tester.tap(find.text('Mamadou Diallo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmer ce destinataire'));
    await tester.pumpAndSettle();

    expect(results, [_r1]);
  });

  testWidgets('confirm button disabled when list empty', (tester) async {
    final bloc = MockRecipientBloc();
    when(
      () => bloc.state,
    ).thenReturn(const RecipientState(status: RecipientStatus.success));
    final results = <Recipient?>[];

    await pumpSheet(tester, bloc, resultHolder: results);

    expect(find.text('Confirmer ce destinataire'), findsOneWidget);

    // Le bouton est désactivé : le tap ne déclenche ni pop ni event bloc.
    await tester.tap(find.text('Confirmer ce destinataire'));
    await tester.pumpAndSettle();

    expect(results, isEmpty);
    verifyNever(() => bloc.add(const RecipientPicked('saved')));
  });
}
