import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_flow.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_request_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockRepository extends Mock implements BidSupplementRepository {}

class _MockMediaService extends Mock implements DonyMediaService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

BidModel _bid() => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'ACCEPTED',
  paymentMethod: BidPaymentMethod.cash,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

const _options = SupplementOptions(
  currency: 'EUR',
  minNet: 1,
  maxNet: 300,
  suggestions: [
    SupplementSuggestion(kind: SupplementSuggestion.kindKg, unitNet: 8),
  ],
  rail: 'CASH',
);

const _proposed = BidSupplement(
  id: 'sup-1',
  status: BidSupplementStatus.proposed,
  rail: 'CASH',
  grossAmount: 10,
  commissionStatus: SupplementCommissionStatus.charged,
);

const _unfunded = ValidationException(
  'd',
  code: 'supplement-commission-unfunded',
  extensions: {
    'availableBalance': 0.5,
    'requiredCommission': 2,
    'shortfall': 1.5,
    'hasCard': false,
    'currency': 'EUR',
    'bidCurrency': 'EUR',
    'alternatives': [
      {'currency': 'XOF', 'balance': 5000, 'required': 1312},
    ],
  },
);

/// Texte affiché, espaces insécables du format monétaire lues comme des
/// espaces simples.
Finder _txt(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText())?.replaceAll(RegExp('[  ]'), ' ') ==
          text,
);

Finder _btn(String label) =>
    find.ancestor(of: _txt(label), matching: find.byType(DonyButton)).first;

void main() {
  late _MockRepository repository;
  late _MockMediaService media;
  late _MockAnalyticsService analytics;
  late _MockBidBloc bidBloc;
  late List<String> secrets;
  late bool failAuth;
  late int authorizations;
  late bool authorizeResult;

  setUpAll(() {
    registerFallbackValue(_FakeBidEvent());
    registerFallbackValue(ImageSource.camera);
    registerFallbackValue(BidSupplementReason.other);
    registerFallbackValue(SupplementCommissionSource.wallet);
  });

  setUp(() {
    DonySnackbar.clearDedup();
    repository = _MockRepository();
    media = _MockMediaService();
    analytics = _MockAnalyticsService();
    bidBloc = _MockBidBloc();
    secrets = [];
    failAuth = false;
    authorizations = 0;
    authorizeResult = true;
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => repository.options(any())).thenAnswer((_) async => _options);
    when(() => repository.quote(any(), any())).thenAnswer(
      (inv) async => SupplementQuote(
        netAmount: inv.positionalArguments[1] as double,
        commissionAmount: 2,
        grossAmount: (inv.positionalArguments[1] as double) + 2,
        currency: 'EUR',
      ),
    );
    when(
      () => media.pick(source: any(named: 'source')),
    ).thenAnswer((_) async => XFile('/tmp/supplement-introuvable.jpg'));
    when(
      () => repository.uploadPhoto(any(), any()),
    ).thenAnswer((_) async => 'tracking/bid-1/supplement.jpg');
    getIt.registerFactory<SupplementRequestCubit>(
      () => SupplementRequestCubit(
        repository,
        media,
        analytics,
        quoteDebounce: Duration.zero,
        commissionFlow: SupplementCommissionFlow(
          repository,
          analytics,
          nextAction: (secret) async {
            secrets.add(secret);
            if (failAuth) throw StateError('canceled');
          },
        ),
      ),
    );
  });

  tearDown(() async => getIt.reset());

  void stubCreate(Future<BidSupplement> Function() answer) => when(
    () => repository.create(
      any(),
      netAmount: any(named: 'netAmount'),
      reason: any(named: 'reason'),
      reasonText: any(named: 'reasonText'),
      gridItemLabel: any(named: 'gridItemLabel'),
      photoKey: any(named: 'photoKey'),
      commissionSource: any(named: 'commissionSource'),
      fundingCurrency: any(named: 'fundingCurrency'),
    ),
  ).thenAnswer((_) => answer());

  List<Object?> capturedSources() => verify(
    () => repository.create(
      any(),
      netAmount: any(named: 'netAmount'),
      reason: any(named: 'reason'),
      reasonText: any(named: 'reasonText'),
      gridItemLabel: any(named: 'gridItemLabel'),
      photoKey: any(named: 'photoKey'),
      commissionSource: captureAny(named: 'commissionSource'),
      fundingCurrency: captureAny(named: 'fundingCurrency'),
    ),
  ).captured;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<BidBloc>.value(
            value: bidBloc,
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => openSupplementRequestSheet(
                    context,
                    _bid(),
                    authorize: (_) async {
                      authorizations++;
                      return authorizeResult;
                    },
                  ),
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/payments/wallet/topup/method',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(true),
              child: const Text('recharge faite'),
            ),
          ),
        ),
        GoRoute(
          path: '/payments/commission-method',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(),
              child: const Text('carte ajoutée'),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  /// Suggestion « +1 kg », photo prise : prêt à envoyer « Demander 10 € ».
  Future<void> fill(WidgetTester tester) async {
    await tester.tap(_txt('+1 kg : 8 €'));
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();
  }

  Finder inScroll(Finder f) =>
      find.ancestor(of: f, matching: find.byType(SingleChildScrollView));

  testWidgets('espèces : choix de la source, récap en espèces, aucun '
      'DonyButton dans le contenu', (tester) async {
    await open(tester);
    await fill(tester);

    expect(find.text('Commission du supplément'), findsOneWidget);
    expect(find.text('Mon solde Yadony'), findsOneWidget);
    expect(find.text('Ma carte commission'), findsOneWidget);
    expect(find.text('Remis en espèces par l\'expéditeur'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(DonyButton),
      ),
      findsNothing,
    );
    expect(inScroll(_btn('Demander 10 €')), findsNothing);
  });

  testWidgets('envoi : vérification locale puis solde par défaut', (
    tester,
  ) async {
    stubCreate(() async => _proposed);
    await open(tester);
    await fill(tester);

    await tester.tap(_btn('Demander 10 €'));
    await tester.pumpAndSettle();

    expect(authorizations, 1);
    expect(capturedSources(), [SupplementCommissionSource.wallet, null]);
    expect(find.text('Demande envoyée à l\'expéditeur'), findsOneWidget);
    verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
  });

  testWidgets('vérification refusée : rien n\'est envoyé', (tester) async {
    authorizeResult = false;
    await open(tester);
    await fill(tester);

    await tester.tap(_btn('Demander 10 €'));
    await tester.pumpAndSettle();

    expect(find.text('Paiement non confirmé, réessayez'), findsOneWidget);
    verifyNever(
      () => repository.create(
        any(),
        netAmount: any(named: 'netAmount'),
        reason: any(named: 'reason'),
        photoKey: any(named: 'photoKey'),
      ),
    );
    expect(
      tester.widget<DonyButton>(_btn('Demander 10 €')).onPressed,
      isNotNull,
    );
  });

  testWidgets('carte choisie : envoyée avec la source CARD', (tester) async {
    stubCreate(() async => _proposed);
    await open(tester);
    await fill(tester);

    await tester.tap(find.text('Ma carte commission'));
    await tester.pumpAndSettle();
    await tester.tap(_btn('Demander 10 €'));
    await tester.pumpAndSettle();

    expect(capturedSources(), [SupplementCommissionSource.card, null]);
  });

  testWidgets('solde insuffisant : ce qui manque, autre portefeuille, '
      'recharge et carte dans le stickyBottom', (tester) async {
    var calls = 0;
    stubCreate(() async {
      if (calls++ == 0) throw _unfunded;
      return _proposed;
    });
    await open(tester);
    await fill(tester);
    await tester.tap(_btn('Demander 10 €'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Choisissez votre carte ou un autre solde'),
      findsOneWidget,
    );
    expect(find.text('Mon solde XOF'), findsOneWidget);
    final topup = _btn('Recharger en EUR');
    final addCard = _btn('Ajouter une carte');
    expect(inScroll(topup), findsNothing);
    expect(inScroll(addCard), findsNothing);

    await tester.tap(find.text('Mon solde XOF'));
    await tester.pumpAndSettle();
    await tester.tap(_btn('Demander 10 €'));
    await tester.pumpAndSettle();

    expect(capturedSources(), [
      SupplementCommissionSource.wallet,
      null,
      SupplementCommissionSource.wallet,
      'XOF',
    ]);
    expect(find.text('Demande envoyée à l\'expéditeur'), findsOneWidget);
  });

  testWidgets('« Recharger » : feuille fermée, recharge, feuille rouverte', (
    tester,
  ) async {
    stubCreate(() async => throw _unfunded);
    await open(tester);
    await fill(tester);
    await tester.tap(_btn('Demander 10 €'));
    await tester.pumpAndSettle();

    await tester.tap(_btn('Recharger en EUR'));
    await tester.pumpAndSettle();
    expect(find.text('recharge faite'), findsOneWidget);

    await tester.tap(find.text('recharge faite'));
    await tester.pumpAndSettle();

    expect(find.text('Demander un supplément'), findsOneWidget);
    verify(() => repository.options('bid-1')).called(2);
  });

  testWidgets('carte manquante : « Ajouter une carte » puis feuille rouverte', (
    tester,
  ) async {
    stubCreate(
      () async => throw const ValidationException(
        'd',
        code: 'commission-method-missing',
      ),
    );
    await open(tester);
    await fill(tester);
    await tester.tap(find.text('Ma carte commission'));
    await tester.pumpAndSettle();
    await tester.tap(_btn('Demander 10 €'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Aucune carte commission enregistrée. Ajoutez-en une, ou payez avec '
        'votre solde.',
      ),
      findsOneWidget,
    );
    await tester.tap(_btn('Ajouter une carte'));
    await tester.pumpAndSettle();
    expect(find.text('carte ajoutée'), findsOneWidget);

    await tester.tap(find.text('carte ajoutée'));
    await tester.pumpAndSettle();
    expect(find.text('Demander un supplément'), findsOneWidget);
  });

  testWidgets(
    '3DS abandonnée : « Réessayer le paiement » confirme la demande',
    (tester) async {
      failAuth = true;
      stubCreate(
        () async => const BidSupplement(
          id: 'sup-1',
          status: BidSupplementStatus.commissionPending,
          rail: 'CASH',
          grossAmount: 10,
          commissionClientSecret: 'pi_secret',
        ),
      );
      await open(tester);
      await fill(tester);
      await tester.tap(find.text('Ma carte commission'));
      await tester.pumpAndSettle();
      await tester.tap(_btn('Demander 10 €'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Validation bancaire interrompue : rien n\'a été prélevé. Réessayez.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Votre demande est enregistrée'),
        findsOneWidget,
      );
      final retry = find.byKey(const Key('supplement-commission-retry-btn'));
      expect(retry, findsOneWidget);
      expect(inScroll(retry), findsNothing);
      expect(find.text('Ma carte commission'), findsNothing);

      failAuth = false;
      when(
        () => repository.confirmCommission('bid-1', 'sup-1'),
      ).thenAnswer((_) async => _proposed);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(authorizations, 2);
      expect(secrets, ['pi_secret']);
      expect(find.text('Demande envoyée à l\'expéditeur'), findsOneWidget);
    },
  );

  testWidgets('débit sans réponse (502) : message du catalogue et réessai', (
    tester,
  ) async {
    stubCreate(
      () async => throw const ServiceUnavailableException(
        'd',
        'supplement-commission-charge-failed',
      ),
    );
    await open(tester);
    await fill(tester);
    await tester.tap(find.text('Ma carte commission'));
    await tester.pumpAndSettle();
    await tester.tap(_btn('Demander 10 €'));
    await tester.pumpAndSettle();

    expect(find.text('Commission non prélevée'), findsWidgets);
    expect(
      find.byKey(const Key('supplement-commission-retry-btn')),
      findsOneWidget,
    );
  });

  testWidgets('commission encore en traitement : message neutre', (
    tester,
  ) async {
    stubCreate(
      () async => const BidSupplement(
        id: 'sup-1',
        status: BidSupplementStatus.commissionPending,
        rail: 'CASH',
        grossAmount: 10,
      ),
    );
    await open(tester);
    await fill(tester);
    await tester.tap(_btn('Demander 10 €'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Demande enregistrée : paiement de la commission en cours de '
        'validation',
      ),
      findsOneWidget,
    );
    verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
  });

  testWidgets('carte refusée : la feuille se ferme et recharge', (
    tester,
  ) async {
    stubCreate(
      () async => throw const ValidationException(
        'd',
        code: 'supplement-commission-card-declined',
      ),
    );
    await open(tester);
    await fill(tester);
    await tester.tap(_btn('Demander 10 €'));
    await tester.pumpAndSettle();

    expect(find.text('Demander un supplément'), findsNothing);
    verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
  });

  testWidgets('anglais : choix de la source traduit', (tester) async {
    useEnglish();
    await open(tester);

    expect(find.text('Supplement commission'), findsOneWidget);
    expect(find.text('My Yadony balance'), findsOneWidget);
    expect(find.text('My commission card'), findsOneWidget);
  });
}
