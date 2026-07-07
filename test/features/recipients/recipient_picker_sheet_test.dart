import 'dart:async';

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

const _r5Rel = Recipient(
  id: 'r-5',
  fullName: 'Fatou Sow',
  relationship: 'Maman',
  phoneE164: '+221760004455',
  city: 'Thiès',
  country: 'SN',
);

const _rNew = Recipient(
  id: 'r-new',
  fullName: 'Nouveau Ami',
  phoneE164: '+33711223344',
  city: 'Paris',
  country: 'FR',
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
    bool settle = true,
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
              builder: (context, _) => Scaffold(
                body: Column(
                  children: [
                    const Text('New Recipient'),
                    TextButton(
                      onPressed: () => context.pop(true),
                      child: const Text('save-new'),
                    ),
                    TextButton(
                      onPressed: () => context.pop(false),
                      child: const Text('cancel-new'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Spinner perpétuel à l'écran → pumpAndSettle ne convergerait jamais ;
      // on pompe juste l'animation d'ouverture de la sheet.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
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
    verify(
      () => bloc.add(
        any(that: isA<RecipientPicked>().having((e) => e.source, 'source', 'saved')),
      ),
    ).called(1);
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

  testWidgets(
    '« Nouveau destinataire » pushes edit screen, reloads and selects newest',
    (tester) async {
      final bloc = MockRecipientBloc();
      final states = StreamController<RecipientState>();
      addTearDown(states.close);
      whenListen(
        bloc,
        states.stream,
        initialState: const RecipientState(
          status: RecipientStatus.success,
          recipients: [_r1],
        ),
      );
      final results = <Recipient?>[];

      await pumpSheet(tester, bloc, resultHolder: results);

      await tester.tap(find.text('Nouveau destinataire'));
      await tester.pumpAndSettle();
      expect(find.text('New Recipient'), findsOneWidget);

      // L'écran d'édition pop(true) → la sheet recharge, MAIS ne dispatch
      // PAS encore RecipientPicked : la source reste en attente jusqu'à la
      // confirmation, pour éviter un double comptage analytics (fix 2).
      await tester.tap(find.text('save-new'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const RecipientLoaded())).called(greaterThan(0));
      verifyNever(() => bloc.add(any(that: isA<RecipientPicked>())));

      // Le bloc émet la liste rechargée (nouveau en tête) → le listener
      // sélectionne le plus récent, que « Confirmer » retourne.
      states.add(
        const RecipientState(
          status: RecipientStatus.success,
          recipients: [_rNew, _r1],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmer ce destinataire'));
      await tester.pumpAndSettle();
      expect(results, [_rNew]);
      // La confirmation tire l'unique event RecipientPicked, tagué avec la
      // source posée par le flux de création ('new').
      verify(
        () => bloc.add(
          any(
            that: isA<RecipientPicked>()
                .having((e) => e.source, 'source', 'new'),
          ),
        ),
      ).called(1);
    },
  );

  testWidgets(
    '« Nouveau destinataire » then manually picking a different existing '
    'row reverts the confirm source to saved',
    (tester) async {
      final bloc = MockRecipientBloc();
      final states = StreamController<RecipientState>();
      addTearDown(states.close);
      whenListen(
        bloc,
        states.stream,
        initialState: const RecipientState(
          status: RecipientStatus.success,
          recipients: [_r1],
        ),
      );
      final results = <Recipient?>[];

      await pumpSheet(tester, bloc, resultHolder: results);

      await tester.tap(find.text('Nouveau destinataire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('save-new'));
      await tester.pumpAndSettle();

      states.add(
        const RecipientState(
          status: RecipientStatus.success,
          recipients: [_rNew, _r1],
        ),
      );
      await tester.pumpAndSettle();

      // L'utilisateur change ensuite manuellement de sélection vers un
      // destinataire pré-existant : la source doit retomber à 'saved',
      // pas rester 'new'.
      await tester.tap(find.text('Mamadou Diallo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmer ce destinataire'));
      await tester.pumpAndSettle();

      expect(results, [_r1]);
      verify(
        () => bloc.add(
          any(
            that: isA<RecipientPicked>()
                .having((e) => e.source, 'source', 'saved'),
          ),
        ),
      ).called(1);
    },
  );

  testWidgets(
    're-tapping the auto-selected newly-created recipient keeps source as new',
    (tester) async {
      final bloc = MockRecipientBloc();
      final states = StreamController<RecipientState>();
      addTearDown(states.close);
      whenListen(
        bloc,
        states.stream,
        initialState: const RecipientState(
          status: RecipientStatus.success,
          recipients: [_r1],
        ),
      );
      final results = <Recipient?>[];

      await pumpSheet(tester, bloc, resultHolder: results);

      await tester.tap(find.text('Nouveau destinataire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('save-new'));
      await tester.pumpAndSettle();

      // Bloc reloads with new recipient in the list.
      states.add(
        const RecipientState(
          status: RecipientStatus.success,
          recipients: [_rNew, _r1],
        ),
      );
      await tester.pumpAndSettle();

      // User re-taps the newly-created (already selected) row.
      await tester.tap(find.text('Nouveau Ami'));
      await tester.pumpAndSettle();

      // Confirming should preserve source as 'new' (not reset to 'saved').
      await tester.tap(find.text('Confirmer ce destinataire'));
      await tester.pumpAndSettle();

      expect(results, [_rNew]);
      verify(
        () => bloc.add(
          any(
            that: isA<RecipientPicked>()
                .having((e) => e.source, 'source', 'new'),
          ),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'contact import pushes prefilled edit screen and tags source phone_contact '
    'at confirm time',
    (tester) async {
      final bloc = MockRecipientBloc();
      final states = StreamController<RecipientState>();
      addTearDown(states.close);
      whenListen(
        bloc,
        states.stream,
        initialState: const RecipientState(
          status: RecipientStatus.success,
          recipients: [_r1],
        ),
      );
      when(() => contactPicker.pick()).thenAnswer(
        (_) async =>
            const PickedContact(fullName: 'Awa Contact', phone: '+221770009988'),
      );
      final results = <Recipient?>[];

      await pumpSheet(tester, bloc, resultHolder: results);

      await tester.tap(find.text('Choisir dans mes contacts'));
      await tester.pumpAndSettle();
      expect(find.text('New Recipient'), findsOneWidget);

      await tester.tap(find.text('save-new'));
      await tester.pumpAndSettle();

      verify(() => contactPicker.pick()).called(1);
      // Pas encore d'event RecipientPicked : en attente de la confirmation.
      verifyNever(() => bloc.add(any(that: isA<RecipientPicked>())));

      states.add(
        const RecipientState(
          status: RecipientStatus.success,
          recipients: [_rNew, _r1],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmer ce destinataire'));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          any(
            that: isA<RecipientPicked>()
                .having((e) => e.source, 'source', 'phone_contact'),
          ),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'contact import shows spinner while picking and does nothing on cancel',
    (tester) async {
      final bloc = MockRecipientBloc();
      when(() => bloc.state).thenReturn(
        const RecipientState(
          status: RecipientStatus.success,
          recipients: [_r1],
        ),
      );
      final completer = Completer<PickedContact?>();
      when(() => contactPicker.pick()).thenAnswer((_) => completer.future);
      final results = <Recipient?>[];

      await pumpSheet(tester, bloc, resultHolder: results);

      await tester.tap(find.text('Choisir dans mes contacts'));
      await tester.pump();
      // Spinner dans la tuile d'action pendant l'attente du picker natif.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(null); // annulation utilisateur
      await tester.pumpAndSettle();

      expect(find.text('New Recipient'), findsNothing);
      verifyNever(() => bloc.add(any(that: isA<RecipientPicked>())));
    },
  );

  testWidgets('shows loading indicator while first load is in flight', (
    tester,
  ) async {
    final bloc = MockRecipientBloc();
    when(() => bloc.state)
        .thenReturn(const RecipientState(status: RecipientStatus.loading));
    final results = <Recipient?>[];

    await pumpSheet(tester, bloc, resultHolder: results, settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('close button pops the sheet with null', (tester) async {
    final bloc = MockRecipientBloc();
    when(() => bloc.state).thenReturn(
      const RecipientState(
        status: RecipientStatus.success,
        recipients: [_r1],
      ),
    );
    final results = <Recipient?>[];

    await pumpSheet(tester, bloc, resultHolder: results);

    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    expect(results, [null]);
    expect(find.text('Confirmer ce destinataire'), findsNothing);
  });

  testWidgets(
    'empty search shows « Aucun résultat » and clear button restores list',
    (tester) async {
      final bloc = MockRecipientBloc();
      when(() => bloc.state).thenReturn(
        const RecipientState(
          status: RecipientStatus.success,
          recipients: [_r1, _r2, _r5Rel, _r4Default],
        ),
      );
      final results = <Recipient?>[];

      await pumpSheet(tester, bloc, resultHolder: results);

      // Le lien de parenté prime sur le nom en titre de ligne.
      expect(find.text('Maman'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz-introuvable');
      await tester.pumpAndSettle();
      expect(find.text('Aucun résultat'), findsOneWidget);

      // Le bouton clear du champ de recherche restaure la liste.
      await tester.tap(
        find.descendant(
          of: find.byType(TextField),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Aucun résultat'), findsNothing);
      expect(find.text('Maman'), findsOneWidget);
    },
  );

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
