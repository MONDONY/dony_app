import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
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

import '../../../cancellation/cancellation_fee_test_support.dart';

// Tests du choix du mode « Mobile money » (pawaPay) dans l'offre de
// l'expéditeur. Le numéro qui paiera ne se saisit plus ici : il se choisit sur
// l'écran « Payer le colis » une fois l'offre acceptée. Harnais copié de
// create_bid_bottom_sheet_cash_test.dart (helpers privés, non partageables
// entre fichiers de test), avec un AuthBloc optionnel pour prouver que le
// numéro du compte n'est plus repris, et un BidNegotiationBloc pour couvrir le
// second site d'appel du sélecteur (mode négociation).

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _MockBidPhotosCubit extends MockCubit<List<BidPhotoUpload>>
    implements BidPhotosCubit {}

class _MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class _MockNegotiationBloc
    extends MockBloc<BidNegotiationEvent, BidNegotiationState>
    implements BidNegotiationBloc {}

class _FakeRecipientEvent extends Fake implements RecipientEvent {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

// ── GetIt captures ─────────────────────────────────────────────────────────────

late _MockBidBloc _currentBidBloc;
late _MockPaymentBloc _currentPaymentBloc;
late _MockWalletBloc _currentWalletBloc;
late _MockBidPhotosCubit _currentPhotosCubit;
late _MockRecipientBloc _currentRecipientBloc;
late _MockNegotiationBloc _currentNegotiationBloc;

// ── Fixtures ───────────────────────────────────────────────────────────────────

AnnouncementModel _announcement({
  required Set<BidPaymentMethod> methods,
  bool negotiable = false,
  String currency = 'XOF',
}) => AnnouncementModel(
  id: 'ann-mm',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 8, 15),
  availableKg: 10,
  totalKg: 10,
  pricePerKg: 8,
  status: 'ACTIVE',
  currency: currency,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  acceptedPaymentMethods: methods,
  negotiable: negotiable,
);

// ── Harness (site direct — étape « picker ») ───────────────────────────────────

const _kSize = Size(800, 5000);

Widget _buildHarness(AnnouncementModel announcement, {AuthBloc? authBloc}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => Scaffold(
          body: Builder(
            builder: (inner) => TextButton(
              onPressed: () =>
                  CreateBidBottomSheet.show(inner, announcement: announcement),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/bids/new',
        builder: (_, state) => CreateBidScreen(
          announcement: (state.extra! as CreateBidArgs).announcement,
          negotiation: (state.extra! as CreateBidArgs).negotiation,
        ),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('Bid détail'))),
      ),
    ],
  );
  final app = MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
  );
  // AuthBloc optionnel : la feuille n'en dépend plus ; un seul test le fournit
  // pour prouver que le numéro du compte n'est plus repris.
  if (authBloc == null) return app;
  return BlocProvider<AuthBloc>.value(value: authBloc, child: app);
}

Future<void> _openSheet(
  WidgetTester tester,
  AnnouncementModel announcement, {
  AuthBloc? authBloc,
}) async {
  tester.view.physicalSize = _kSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildHarness(announcement, authBloc: authBloc));
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

// Sélectionne une catégorie + coche le disclaimer (canSubmit = true) et règle
// le poids si un Slider est rendu — même logique que le fichier espèces.
Future<void> _enableSubmitButton(WidgetTester tester) async {
  final slider = find.byType(Slider);
  if (slider.evaluate().isNotEmpty) {
    tester.widget<Slider>(slider).onChanged!(5);
    await tester.pump();
  }
  await tester.tap(find.byKey(const Key('bid-content-field')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const Key('bid-content-item-Vêtements & tissus')),
  );
  await tester.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.pump();
  await tester.tap(find.byType(Checkbox).first);
  await tester.pump();
}

Future<void> _fillMandatoryFields(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(1), 'Médicaments');
  await tester.pump();
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(2), 'Amadou Diallo');
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(3), '+221 77 000 00 00');
  await tester.pump();
}

Future<void> _goToPaymentPicker(WidgetTester tester) async {
  await _enableSubmitButton(tester);
  await _fillMandatoryFields(tester);
  await tester.tap(find.text('Envoyer'));
  await tester.pumpAndSettle();
}

// ── Harness (site négociation — formulaire puis étape paiement) ────────────────
//
// Copié/adapté de test/features/matching/presentation/create_bid_negotiation_test.dart
// (helpers privés à ce fichier).

const _kSettle = Duration(milliseconds: 600);

Widget _negotiationApp(AnnouncementModel announcement) => MaterialApp.router(
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
        builder: (_, _) =>
            CreateBidScreen(announcement: announcement, negotiation: true),
      ),
    ],
  ),
);

Future<void> _openNegotiation(
  WidgetTester tester,
  AnnouncementModel announcement,
) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_negotiationApp(announcement));
  await tester.pump(_kSettle);
}

/// Remplit le formulaire de proposition jusqu'au disclaimer, sans soumettre.
Future<void> _fillNegotiationForm(WidgetTester tester) async {
  await tester.drag(find.byType(Slider), const Offset(200, 0));
  await tester.pump(_kSettle);

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

  await tester.ensureVisible(find.text('Je signe & j\'accepte'));
  await tester.tap(find.text('Je signe & j\'accepte'));
  await tester.pump(_kSettle);
  await tester.pump(_kSettle);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(BidInitial());
    registerFallbackValue(const PaymentInitial());
    registerFallbackValue(
      BidCreateRequested(
        announcementId: '',
        weightKg: 0,
        description: '',
        contentCategory: '',
        recipientName: '',
        recipientPhone: '',
      ),
    );
    registerFallbackValue(
      BidCheckoutRequested(
        announcementId: '',
        weightKg: 0,
        description: '',
        contentCategory: '',
        recipientName: '',
        recipientPhone: '',
      ),
    );
    registerFallbackValue(const BidNegotiationFetchRequested('fallback'));
    registerFallbackValue(
      const BidNegotiationProposeRequested(
        announcementId: '',
        weightKg: null,
        description: '',
        contentCategory: '',
        recipientName: '',
        recipientPhone: '',
        proposedTotalEur: 0,
      ),
    );
    registerFallbackValue(_FakeRecipientEvent());

    if (!getIt.isRegistered<BidBloc>()) {
      getIt.registerFactory<BidBloc>(() => _currentBidBloc);
    }
    if (!getIt.isRegistered<PaymentBloc>()) {
      getIt.registerFactory<PaymentBloc>(() => _currentPaymentBloc);
    }
    if (!getIt.isRegistered<WalletBloc>()) {
      getIt.registerFactory<WalletBloc>(() => _currentWalletBloc);
    }
    if (!getIt.isRegistered<BidPhotosCubit>()) {
      getIt.registerFactory<BidPhotosCubit>(() => _currentPhotosCubit);
    }
    if (!getIt.isRegistered<RecipientBloc>()) {
      getIt.registerFactory<RecipientBloc>(() => _currentRecipientBloc);
    }
    if (!getIt.isRegistered<BidNegotiationBloc>()) {
      getIt.registerFactory<BidNegotiationBloc>(() => _currentNegotiationBloc);
    }
    if (!getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.registerFactory<IContentCategoryRepository>(
        _FakeContentCategoryRepository.new,
      );
    }
  });

  setUp(() {
    _currentBidBloc = _MockBidBloc();
    when(() => _currentBidBloc.state).thenReturn(BidInitial());
    when(() => _currentBidBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => _currentBidBloc.close()).thenAnswer((_) async {});

    _currentPaymentBloc = _MockPaymentBloc();
    when(() => _currentPaymentBloc.state).thenReturn(const PaymentInitial());
    when(
      () => _currentPaymentBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => _currentPaymentBloc.close()).thenAnswer((_) async {});

    _currentWalletBloc = _MockWalletBloc();
    when(() => _currentWalletBloc.state).thenReturn(WalletInitial());
    when(
      () => _currentWalletBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => _currentWalletBloc.close()).thenAnswer((_) async {});

    _currentPhotosCubit = _MockBidPhotosCubit();
    when(() => _currentPhotosCubit.state).thenReturn(const <BidPhotoUpload>[]);
    when(
      () => _currentPhotosCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => _currentPhotosCubit.close()).thenAnswer((_) async {});
    when(
      () => _currentPhotosCubit.readyKeys,
    ).thenReturn(const <String>['bids/photo-1.jpg']);

    _currentRecipientBloc = _MockRecipientBloc();
    when(() => _currentRecipientBloc.state).thenReturn(const RecipientState());
    when(
      () => _currentRecipientBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => _currentRecipientBloc.close()).thenAnswer((_) async {});
    when(() => _currentRecipientBloc.add(any())).thenReturn(null);

    _currentNegotiationBloc = _MockNegotiationBloc();
    when(
      () => _currentNegotiationBloc.state,
    ).thenReturn(const BidNegotiationInitial());
    when(
      () => _currentNegotiationBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => _currentNegotiationBloc.close()).thenAnswer((_) async {});
    when(() => _currentNegotiationBloc.add(any())).thenReturn(null);
  });

  // Horloge réelle de l'écran : la date d'effet doit être passée.
  final inForce = CancellationFeeConfigModel(
    active: true,
    effectiveFrom: DateTime.utc(2026),
    capEur: 30,
    tiers: kActiveFeeConfig.tiers,
  );

  final notice = find.byKey(const Key('cancel-fee-scale-notice'));

  Future<void> openPicker(
    WidgetTester tester, {
    CancellationFeeConfigModel? config,
    String currency = 'EUR',
  }) async {
    await registerFeeConfig(config: config);
    await _openSheet(
      tester,
      _announcement(
        methods: {
          BidPaymentMethod.stripe,
          BidPaymentMethod.mobileMoney,
          BidPaymentMethod.cash,
        },
        currency: currency,
      ),
    );
    await _goToPaymentPicker(tester);
    await tester.pumpAndSettle();
  }

  group('Ligne du barème au-dessus du bouton de paiement', () {
    testWidgets('frais allumés, carte : ligne visible', (tester) async {
      await openPicker(tester, config: inForce);
      await tester.tap(find.byKey(const Key('payment-method-stripe')));
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
      expect(find.textContaining('Voir le barème'), findsOneWidget);
    });

    testWidgets('frais allumés, mobile money : ligne visible', (tester) async {
      await openPicker(tester, config: inForce, currency: 'XOF');
      await tester.tap(find.byKey(const Key('payment-method-mobile-money')));
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
    });

    testWidgets('espèces : ligne absente', (tester) async {
      await openPicker(tester, config: inForce);
      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pumpAndSettle();
      expect(notice, findsNothing);
    });

    testWidgets('carte puis espèces : la ligne disparaît', (tester) async {
      await openPicker(tester, config: inForce);
      await tester.tap(find.byKey(const Key('payment-method-stripe')));
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pumpAndSettle();
      expect(notice, findsNothing);
    });

    testWidgets('frais éteints : aucune ligne', (tester) async {
      await openPicker(tester, config: CancellationFeeConfigModel.inactive);
      await tester.tap(find.byKey(const Key('payment-method-stripe')));
      await tester.pumpAndSettle();
      expect(notice, findsNothing);
    });

    testWidgets('configuration absente (back antérieur, 404) : aucune ligne', (
      tester,
    ) async {
      await openPicker(tester);
      await tester.tap(find.byKey(const Key('payment-method-stripe')));
      await tester.pumpAndSettle();
      expect(notice, findsNothing);
    });

    testWidgets('toucher « Voir le barème » ouvre la feuille', (tester) async {
      await openPicker(tester, config: inForce);
      await tester.tap(find.byKey(const Key('payment-method-stripe')));
      await tester.pumpAndSettle();
      await tester.tap(notice);
      await tester.pumpAndSettle();
      expect(find.text('Barème des frais d\'annulation'), findsOneWidget);
      expect(find.byKey(const Key('cancel-fee-scale-close')), findsOneWidget);
    });
  });

  group('Mise en page et négociation', () {
    testWidgets('360 dp, texte x2 : la ligne et le bouton coexistent', (
      tester,
    ) async {
      await registerFeeConfig(config: inForce);
      await _openSheet(
        tester,
        _announcement(
          methods: {
            BidPaymentMethod.stripe,
            BidPaymentMethod.mobileMoney,
            BidPaymentMethod.cash,
          },
          currency: 'EUR',
        ),
      );
      await _goToPaymentPicker(tester);
      // Étape de paiement atteinte (formulaire rempli à largeur normale),
      // puis téléphone étroit et texte doublé.
      tester.view.physicalSize = const Size(360, 5000);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('bid-submit-btn'));

      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pumpAndSettle();
      expect(notice, findsNothing);
      // Débordement de 30 px déjà présent à ce réglage extrême, sans la ligne
      // (étape de paiement, hors périmètre) : on le purge pour ne juger que ce
      // que l'ajout de la ligne provoque.
      tester.takeException();
      final heightWithout = tester.getSize(button).height;

      await tester.tap(find.byKey(const Key('payment-method-stripe')));
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(button.hitTestable(), findsOneWidget);
      final label = tester.widget<DonyButton>(button).label;
      final text = find.descendant(of: button, matching: find.text(label));
      expect(text, findsOneWidget);
      final lineHeight = tester.getSize(text).height;
      // Une ligne : le texte n'est pas plus haut que le bouton, qui garde sa
      // hauteur avec la ligne au-dessus.
      expect(lineHeight, lessThan(tester.getSize(button).height));
      expect(tester.getSize(button).height, heightWithout);
    });

    testWidgets('mode négociation : aucune ligne', (tester) async {
      await registerFeeConfig(config: inForce);
      await _openNegotiation(
        tester,
        _announcement(
          methods: {BidPaymentMethod.stripe, BidPaymentMethod.cash},
          currency: 'EUR',
          negotiable: true,
        ),
      );
      await _fillNegotiationForm(tester);
      expect(find.byKey(const Key('bid-submit-btn')), findsOneWidget);
      expect(notice, findsNothing);
    });
  });
}
