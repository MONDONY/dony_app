import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/custom_items_section.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _MockBidPhotosCubit extends MockCubit<List<BidPhotoUpload>>
    implements BidPhotosCubit {}

class _MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockNegotiationBloc
    extends MockBloc<BidNegotiationEvent, BidNegotiationState>
    implements BidNegotiationBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

const _kSettle = Duration(milliseconds: 600);

AnnouncementModel _announcement({
  bool negotiable = false,
  Set<BidPaymentMethod> acceptedPaymentMethods = const {
    BidPaymentMethod.stripe,
  },
  String currency = 'EUR',
  bool gridOnly = false,
}) => AnnouncementModel(
  id: 'ann-nego',
  currency: currency,
  travelerId: 'traveler-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 9, 12),
  availableKg: 10.0,
  totalKg: 10.0,
  pricePerKg: gridOnly ? null : 10.0,
  priceGridItems: gridOnly
      ? const [
          AnnouncementGridItemModel(
            id: 'grid-valise',
            label: 'Valise 23 kg',
            unitPriceNet: 40,
            unitPriceDisplay: 45,
          ),
        ]
      : const [],
  status: 'OPEN',
  createdAt: DateTime(2026, 8),
  updatedAt: DateTime(2026, 8),
  negotiable: negotiable,
  acceptedPaymentMethods: acceptedPaymentMethods,
  traveler: const TravelerProfile(
    id: 'traveler-1',
    displayName: 'Mamadou Diallo',
    acceptsUnverified: true,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBidBloc bidBloc;
  late _MockPaymentBloc paymentBloc;
  late _MockWalletBloc walletBloc;
  late _MockBidPhotosCubit photosCubit;
  late _MockRecipientBloc recipientBloc;
  late _MockAuthBloc authBloc;
  late _MockNegotiationBloc negotiationBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(_FakeBidEvent());
    registerFallbackValue(const BidNegotiationFetchRequested('fallback'));
  });

  setUp(() {
    bidBloc = _MockBidBloc();
    paymentBloc = _MockPaymentBloc();
    walletBloc = _MockWalletBloc();
    photosCubit = _MockBidPhotosCubit();
    recipientBloc = _MockRecipientBloc();
    authBloc = _MockAuthBloc();
    negotiationBloc = _MockNegotiationBloc();

    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidInitial(),
    );
    whenListen(
      paymentBloc,
      const Stream<PaymentState>.empty(),
      initialState: const PaymentInitial(),
    );
    whenListen(
      walletBloc,
      const Stream<WalletState>.empty(),
      initialState: WalletInitial(),
    );
    whenListen(
      photosCubit,
      const Stream<List<BidPhotoUpload>>.empty(),
      initialState: const <BidPhotoUpload>[],
    );
    when(() => photosCubit.readyKeys).thenReturn(const <String>[]);
    whenListen(
      recipientBloc,
      const Stream<RecipientState>.empty(),
      initialState: const RecipientState(),
    );
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthAuthenticated(
        UserModel(id: 'u1', roles: [], kycStatus: 'VERIFIED', status: 'ACTIVE'),
      ),
    );
    whenListen(
      negotiationBloc,
      const Stream<BidNegotiationState>.empty(),
      initialState: const BidNegotiationInitial(),
    );

    void register<T extends Object>(T mock) {
      if (getIt.isRegistered<T>()) getIt.unregister<T>();
      getIt.registerSingleton<T>(mock);
    }

    register<BidBloc>(bidBloc);
    register<PaymentBloc>(paymentBloc);
    register<WalletBloc>(walletBloc);
    register<BidPhotosCubit>(photosCubit);
    register<RecipientBloc>(recipientBloc);
    register<BidNegotiationBloc>(negotiationBloc);
    register<IContentCategoryRepository>(_FakeContentCategoryRepository());
  });

  tearDown(() {
    for (final unregister in [
      () => getIt.unregister<BidBloc>(),
      () => getIt.unregister<PaymentBloc>(),
      () => getIt.unregister<WalletBloc>(),
      () => getIt.unregister<BidPhotosCubit>(),
      () => getIt.unregister<RecipientBloc>(),
      () => getIt.unregister<BidNegotiationBloc>(),
      () => getIt.unregister<IContentCategoryRepository>(),
    ]) {
      unregister();
    }
  });

  // ── Détail du trajet : le second CTA ──────────────────────────────────────

  Widget detailApp(AnnouncementModel announcement) => MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<BidBloc>.value(value: bidBloc),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (ctx, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-detail'),
                  onPressed: () => showTravelerAnnouncementSheet(
                    ctx,
                    announcement: announcement,
                  ),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          ),
          GoRoute(path: '/bids/new', builder: (_, _) => const SizedBox()),
        ],
      ),
    ),
  );

  Future<void> openDetail(WidgetTester tester, AnnouncementModel a) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(detailApp(a));
    await tester.pump(_kSettle);
    await tester.tap(find.byKey(const Key('open-detail')));
    await tester.pump(_kSettle);
    await tester.pump(_kSettle);
  }

  testWidgets('un trajet a prix ferme n offre que la demande directe', (
    tester,
  ) async {
    await openDetail(tester, _announcement());

    expect(find.text('Faire une demande'), findsOneWidget);
    expect(find.byKey(const Key('negotiate-price-btn')), findsNothing);
  });

  testWidgets('un trajet negociable offre les deux CTA', (tester) async {
    await openDetail(tester, _announcement(negotiable: true));

    expect(find.text('Faire une demande'), findsOneWidget);
    expect(find.byKey(const Key('negotiate-price-btn')), findsOneWidget);
    expect(find.text('Proposer un prix'), findsOneWidget);
  });

  // ── Écran de proposition ──────────────────────────────────────────────────

  Widget bidApp({
    required bool negotiation,
    Set<BidPaymentMethod> acceptedPaymentMethods = const {
      BidPaymentMethod.stripe,
    },
    String currency = 'EUR',
    bool gridOnly = false,
  }) => MaterialApp.router(
    theme: AppTheme.light(),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => CreateBidScreen(
            announcement: _announcement(
              negotiable: negotiation,
              acceptedPaymentMethods: acceptedPaymentMethods,
              currency: currency,
              gridOnly: gridOnly,
            ),
            negotiation: negotiation,
          ),
        ),
      ],
    ),
  );

  Future<void> openBid(
    WidgetTester tester, {
    required bool negotiation,
    Set<BidPaymentMethod> acceptedPaymentMethods = const {
      BidPaymentMethod.stripe,
    },
    String currency = 'EUR',
    bool gridOnly = false,
  }) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      bidApp(
        negotiation: negotiation,
        acceptedPaymentMethods: acceptedPaymentMethods,
        currency: currency,
        gridOnly: gridOnly,
      ),
    );
    await tester.pump(_kSettle);
  }

  /// Remplit le formulaire de proposition jusqu'au disclaimer, sans soumettre.
  Future<void> fillNegotiationForm(WidgetTester tester) async {
    // Trajet kilo pur (pas de grille) : le poids est obligatoire pour
    // pouvoir soumettre (cf. `_syncFormButtonState`).
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump(_kSettle);

    // Contenu du colis
    await tester.ensureVisible(find.byKey(const Key('bid-content-field')));
    await tester.tap(find.byKey(const Key('bid-content-field')));
    await tester.pump(_kSettle);
    await tester.pump(_kSettle);
    await tester.enterText(
      find.byKey(const Key('bid-content-field')),
      'Chaussures',
    );
    await tester.pump(_kSettle);
    await tester.pump(_kSettle);
    await tester.tap(find.byKey(const Key('bid-content-item-Chaussures')));
    await tester.pump(_kSettle);

    // Description et destinataire
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Médicaments pour diabète + 2 tee-shirts enfants',
      ),
      'Deux paires de chaussures',
    );
    await tester.pump(_kSettle);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prénom et nom du destinataire'),
      'Awa Diop',
    );
    await tester.pump(_kSettle);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Téléphone du destinataire'),
      '+221700000000',
    );
    await tester.pump(_kSettle);

    // Disclaimer
    await tester.ensureVisible(find.text('Je signe & j\'accepte'));
    await tester.tap(find.text('Je signe & j\'accepte'));
    await tester.pump(_kSettle);
    await tester.pump(_kSettle);
  }

  Future<List<BidNegotiationProposeRequested>> submitProposal(
    WidgetTester tester,
  ) async {
    await tester.ensureVisible(find.byKey(const Key('bid-submit-btn')));
    await tester.tap(find.byKey(const Key('bid-submit-btn')));
    await tester.pump(_kSettle);

    return verify(
      () => negotiationBloc.add(captureAny()),
    ).captured.whereType<BidNegotiationProposeRequested>().toList();
  }

  String proposalText(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('negotiation-proposal-field')),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  testWidgets(
    'le mode direct n affiche ni articles hors grille ni proposition',
    (tester) async {
      await openBid(tester, negotiation: false);

      expect(find.byType(CustomItemsSection), findsNothing);
      expect(find.byKey(const Key('negotiation-proposal-field')), findsNothing);
    },
  );

  testWidgets(
    'le mode negociation affiche la section hors grille et le champ',
    (tester) async {
      await openBid(tester, negotiation: true);

      expect(find.byType(CustomItemsSection), findsOneWidget);
      expect(
        find.byKey(const Key('negotiation-proposal-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('negotiation-suggested-hint')),
        findsOneWidget,
      );
    },
  );

  testWidgets('le champ de proposition est pre-rempli avec le total suggere', (
    tester,
  ) async {
    await openBid(tester, negotiation: true);

    // Trajet kilo pur (pas de grille) : le poids part à 0 et doit être
    // choisi explicitement avant qu'un total suggéré positif existe.
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump(_kSettle);

    final initial = double.parse(proposalText(tester).replaceAll(',', '.'));
    expect(initial, greaterThan(0));
  });

  testWidgets('ajouter un article hors grille augmente le total suggere', (
    tester,
  ) async {
    await openBid(tester, negotiation: true);
    final initial = double.parse(proposalText(tester).replaceAll(',', '.'));

    await tester.ensureVisible(find.byKey(const Key('custom-item-add')));
    await tester.tap(find.byKey(const Key('custom-item-add')));
    await tester.pump(_kSettle);
    await tester.enterText(
      find.byKey(const Key('custom-item-label')),
      'Sac de riz',
    );
    await tester.pump(_kSettle);
    await tester.enterText(find.byKey(const Key('custom-item-amount')), '10');
    await tester.pump(_kSettle);
    await tester.pump(_kSettle);
    await tester.tap(find.byKey(const Key('custom-item-submit')));
    await tester.pump(_kSettle);
    await tester.pump(_kSettle);

    final updated = double.parse(proposalText(tester).replaceAll(',', '.'));
    expect(updated, closeTo(initial + 10, 0.01));
  });

  testWidgets('soumettre declenche BidNegotiationProposeRequested', (
    tester,
  ) async {
    await openBid(tester, negotiation: true);
    await fillNegotiationForm(tester);

    final captured = await submitProposal(tester);
    expect(captured, hasLength(1));
    expect(captured.single.announcementId, 'ann-nego');
    expect(captured.single.proposedTotalEur, greaterThan(0));
    expect(captured.single.recipientName, 'Awa Diop');
    // Trajet carte seule : le mode est figé sur la carte sans rien demander.
    expect(captured.single.paymentMethod, BidPaymentMethod.stripe);
  });

  // FLUTTER-4A : sur un trajet en grille pure, l'expéditeur dont le contenu
  // n'est pas dans la grille du voyageur l'ajoute en article hors grille ;
  // cela suffit pour proposer, et le contenu envoyé est son libellé.
  testWidgets('grille pure : un article hors grille seul permet de proposer', (
    tester,
  ) async {
    await openBid(tester, negotiation: true, gridOnly: true);

    await tester.ensureVisible(find.byKey(const Key('custom-item-add')));
    await tester.tap(find.byKey(const Key('custom-item-add')));
    await tester.pump(_kSettle);
    await tester.enterText(
      find.byKey(const Key('custom-item-label')),
      'Sac de riz',
    );
    await tester.pump(_kSettle);
    await tester.enterText(find.byKey(const Key('custom-item-amount')), '10');
    await tester.pump(_kSettle);
    await tester.pump(_kSettle);
    await tester.tap(find.byKey(const Key('custom-item-submit')));
    await tester.pump(_kSettle);
    await tester.pump(_kSettle);

    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Médicaments pour diabète + 2 tee-shirts enfants',
      ),
      'Un sac de riz de 10 kg',
    );
    await tester.pump(_kSettle);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prénom et nom du destinataire'),
      'Awa Diop',
    );
    await tester.pump(_kSettle);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Téléphone du destinataire'),
      '+221700000000',
    );
    await tester.pump(_kSettle);
    await tester.ensureVisible(find.text('Je signe & j\'accepte'));
    await tester.tap(find.text('Je signe & j\'accepte'));
    await tester.pump(_kSettle);
    await tester.pump(_kSettle);

    final captured = await submitProposal(tester);
    expect(captured, hasLength(1));
    expect(captured.single.contentCategory, 'Sac de riz');
    expect(captured.single.customItems, hasLength(1));
  });

  testWidgets('sans alternative, la proposition part sans etape paiement', (
    tester,
  ) async {
    await openBid(tester, negotiation: true);
    await fillNegotiationForm(tester);

    final captured = await submitProposal(tester);
    expect(captured, hasLength(1));
    expect(find.byKey(const Key('payment-method-stripe')), findsNothing);
    expect(find.byKey(const Key('payment-method-cash')), findsNothing);
  });

  testWidgets('le formulaire de proposition n affiche plus le choix du mode', (
    tester,
  ) async {
    await openBid(
      tester,
      negotiation: true,
      acceptedPaymentMethods: {BidPaymentMethod.stripe, BidPaymentMethod.cash},
    );

    // Comme l'offre directe : le mode se choisit à l'étape suivante.
    expect(find.byKey(const Key('payment-method-stripe')), findsNothing);
    expect(find.byKey(const Key('payment-method-cash')), findsNothing);
    expect(find.text('Continuer'), findsOneWidget);
  });

  testWidgets(
    'sur un trajet carte + especes, Continuer ouvre l etape paiement et la '
    'proposition porte le mode choisi',
    (tester) async {
      await openBid(
        tester,
        negotiation: true,
        acceptedPaymentMethods: {
          BidPaymentMethod.stripe,
          BidPaymentMethod.cash,
        },
      );
      await fillNegotiationForm(tester);

      // « Continuer » n'envoie rien : il mène à « Comment veux-tu payer ? ».
      await tester.ensureVisible(find.byKey(const Key('bid-submit-btn')));
      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pump(_kSettle);
      expect(find.text('Comment veux-tu payer ?'), findsOneWidget);
      expect(
        find.text(
          'Si le voyageur accepte votre prix, vous réglerez de cette façon.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pump(_kSettle);

      final captured = await submitProposal(tester);
      expect(captured, hasLength(1));
      expect(captured.single.paymentMethod, BidPaymentMethod.cash);
      expect(captured.single.phoneNumber, isNull);
    },
  );

  testWidgets(
    'sur un trajet carte + especes, la carte reste le choix par defaut',
    (tester) async {
      await openBid(
        tester,
        negotiation: true,
        acceptedPaymentMethods: {
          BidPaymentMethod.stripe,
          BidPaymentMethod.cash,
        },
      );
      await fillNegotiationForm(tester);

      await tester.ensureVisible(find.byKey(const Key('bid-submit-btn')));
      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pump(_kSettle);
      // Rien n'est débité à cette étape : la carte le dit.
      expect(
        find.text(
          'Payé par carte une fois ton prix accepté, puis bloqué par Yadony '
          "jusqu'à la confirmation de la livraison.",
        ),
        findsOneWidget,
      );

      final captured = await submitProposal(tester);
      expect(captured, hasLength(1));
      expect(captured.single.paymentMethod, BidPaymentMethod.stripe);
    },
  );

  testWidgets(
    'sur un trajet XOF especes + mobile money, la proposition peut partir en '
    'mobile money',
    (tester) async {
      await openBid(
        tester,
        negotiation: true,
        currency: 'XOF',
        acceptedPaymentMethods: {
          BidPaymentMethod.cash,
          BidPaymentMethod.mobileMoney,
        },
      );
      await fillNegotiationForm(tester);

      await tester.ensureVisible(find.byKey(const Key('bid-submit-btn')));
      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pump(_kSettle);
      // Pas de carte en zone CFA ; le mobile money n'est plus exclu.
      expect(find.byKey(const Key('payment-method-stripe')), findsNothing);
      await tester.tap(find.byKey(const Key('payment-method-mobile-money')));
      await tester.pump(_kSettle);

      final captured = await submitProposal(tester);
      expect(captured, hasLength(1));
      expect(captured.single.paymentMethod, BidPaymentMethod.mobileMoney);
    },
  );

  testWidgets('ouvrir le mode negociation tire l event d ouverture', (
    tester,
  ) async {
    await openBid(tester, negotiation: true);

    final opened = verify(
      () => negotiationBloc.add(captureAny()),
    ).captured.whereType<BidNegotiationOpenRequested>().toList();
    expect(opened, hasLength(1));
    expect(opened.single.announcementId, 'ann-nego');
  });
}
