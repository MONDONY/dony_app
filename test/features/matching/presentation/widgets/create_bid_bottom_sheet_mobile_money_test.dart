import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
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

// Tests dédiés à la task 10 : choix du mode « Mobile money » (pawaPay) et
// numéro payeur facultatif dans l'offre de l'expéditeur. Harnais copié de
// create_bid_bottom_sheet_cash_test.dart (helpers privés, non partageables
// entre fichiers de test) et étendu avec un AuthBloc pour le pré-remplissage,
// et un BidNegotiationBloc pour couvrir le second site d'appel du sélecteur
// (mode négociation).

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

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

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
  // AuthBloc optionnel : la plupart des tests vérifient justement que la
  // sheet survit à son absence (ProviderNotFoundException rattrapée, champ
  // vide). Seul le groupe « pré-remplissage » le fournit.
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

// ── Harness (site négociation — dans l'étape formulaire) ───────────────────────
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

Future<List<BidNegotiationProposeRequested>> _submitProposal(
  WidgetTester tester,
) async {
  await tester.ensureVisible(find.byKey(const Key('bid-submit-btn')));
  await tester.tap(find.byKey(const Key('bid-submit-btn')));
  await tester.pump(_kSettle);

  return verify(
    () => _currentNegotiationBloc.add(captureAny()),
  ).captured.whereType<BidNegotiationProposeRequested>().toList();
}

// ── Tests ──────────────────────────────────────────────────────────────────────

final RegExp mobileMoneyCtaLabel = RegExp(r'^Confirmer .* par mobile money$');

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
    when(() => _currentPhotosCubit.readyKeys).thenReturn(const <String>[]);

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

  // ── 1. Visibilité de la tuile ────────────────────────────────────────────

  group('Visibilité de la tuile mobile money (site direct)', () {
    testWidgets(
      'annonce EUR STRIPE+CASH (sans mobile money) → tuile mobile money absente',
      (tester) async {
        await _openSheet(
          tester,
          _announcement(
            methods: const {BidPaymentMethod.stripe, BidPaymentMethod.cash},
            currency: 'EUR',
          ),
        );
        await _goToPaymentPicker(tester);

        expect(find.byKey(const Key('payment-method-stripe')), findsOneWidget);
        expect(find.byKey(const Key('payment-method-cash')), findsOneWidget);
        expect(
          find.byKey(const Key('payment-method-mobile-money')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'annonce XOF STRIPE+MOBILE_MONEY → carte retirée (zone CFA), tuile mobile '
      'money présente, pas de tuile cash',
      (tester) async {
        await _openSheet(
          tester,
          _announcement(
            methods: const {
              BidPaymentMethod.stripe,
              BidPaymentMethod.mobileMoney,
            },
          ),
        );
        await _goToPaymentPicker(tester);

        // Recette du 2026-09-09 : la carte n'existe pas en XOF, même déclarée.
        expect(find.byKey(const Key('payment-method-stripe')), findsNothing);
        expect(
          find.byKey(const Key('payment-method-mobile-money')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('payment-method-cash')), findsNothing);
        expect(find.text('Mobile money'), findsOneWidget);
        expect(find.text('Orange Money, Wave, MTN'), findsOneWidget);
      },
    );

    testWidgets(
      'annonce mobile-money-only → picker affiché, mobile money sélectionné '
      'par défaut, champ numéro visible sans tap',
      (tester) async {
        await _openSheet(
          tester,
          _announcement(methods: const {BidPaymentMethod.mobileMoney}),
        );
        await _goToPaymentPicker(tester);

        expect(find.byKey(const Key('payment-method-stripe')), findsNothing);
        expect(find.byKey(const Key('payment-method-cash')), findsNothing);
        expect(
          find.byKey(const Key('payment-method-mobile-money')),
          findsOneWidget,
        );
        // Sélectionné par défaut (seule alternative) → champ déjà visible.
        expect(find.byKey(const Key('payer-phone-field')), findsOneWidget);
        expect(find.textContaining(mobileMoneyCtaLabel), findsOneWidget);
      },
    );
  });

  // ── 1 bis. Rails par devise ───────────────────────────────────────────────
  //
  // Recette du 2026-09-09 : une annonce XOF déclarait la carte, la feuille la
  // proposait, et le séquestre Stripe partait en euros pour un montant en
  // francs CFA. Le backend filtre désormais à l'écriture ; la feuille ne
  // propose jamais un moyen que la devise du trajet n'autorise pas.

  group('Rails par devise', () {
    testWidgets(
      'annonce XOF déclarant la carte → carte retirée, espèces et mobile money '
      'proposés, espèces par défaut',
      (tester) async {
        await _openSheet(
          tester,
          _announcement(
            methods: const {
              BidPaymentMethod.stripe,
              BidPaymentMethod.cash,
              BidPaymentMethod.mobileMoney,
            },
          ),
        );
        await _goToPaymentPicker(tester);

        expect(find.byKey(const Key('payment-method-stripe')), findsNothing);
        expect(find.byKey(const Key('payment-method-cash')), findsOneWidget);
        expect(
          find.byKey(const Key('payment-method-mobile-money')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('payer-phone-field')), findsNothing);
      },
    );

    testWidgets(
      'annonce EUR déclarant le mobile money → mobile money retiré, carte et '
      'espèces proposées',
      (tester) async {
        await _openSheet(
          tester,
          _announcement(
            methods: const {
              BidPaymentMethod.stripe,
              BidPaymentMethod.cash,
              BidPaymentMethod.mobileMoney,
            },
            currency: 'EUR',
          ),
        );
        await _goToPaymentPicker(tester);

        expect(find.byKey(const Key('payment-method-stripe')), findsOneWidget);
        expect(find.byKey(const Key('payment-method-cash')), findsOneWidget);
        expect(
          find.byKey(const Key('payment-method-mobile-money')),
          findsNothing,
        );
      },
    );
  });

  // ── 2. Affichage du champ numéro ─────────────────────────────────────────

  group('Champ numéro payeur — affichage', () {
    testWidgets('tuile espèces sélectionnée par défaut → champ numéro absent', (
      tester,
    ) async {
      await _openSheet(
        tester,
        _announcement(
          methods: const {BidPaymentMethod.cash, BidPaymentMethod.mobileMoney},
        ),
      );
      await _goToPaymentPicker(tester);

      expect(find.byKey(const Key('payer-phone-field')), findsNothing);
    });

    testWidgets(
      // Ce harnais ne fournit pas d'AuthBloc : _initialPayerPhone() est donc
      // vide (ProviderNotFoundException rattrapée), exactement comme un
      // compte Yadony sans numéro de téléphone (vérification SMS pas encore
      // configurée) — l'aide doit refléter l'absence de pré-remplissage.
      'tap sur la tuile mobile money, sans numéro disponible → champ '
      'numéro apparaît avec l\'aide "aucun numéro"',
      (tester) async {
        await _openSheet(
          tester,
          _announcement(
            methods: const {
              BidPaymentMethod.cash,
              BidPaymentMethod.mobileMoney,
            },
          ),
        );
        await _goToPaymentPicker(tester);

        await tester.tap(find.byKey(const Key('payment-method-mobile-money')));
        await tester.pump();

        expect(find.byKey(const Key('payer-phone-field')), findsOneWidget);
        expect(find.text('Numéro qui paiera (facultatif)'), findsOneWidget);
        expect(
          find.textContaining(
            "Ton compte n'a pas de numéro : indique celui qui paiera. Tu "
            'recevras la demande de paiement dessus.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Par défaut, ton numéro Yadony'),
          findsNothing,
        );
      },
    );

    testWidgets('tap sur la tuile mobile money, AuthBloc avec un numéro → aide '
        '"Par défaut, ton numéro Yadony"', (tester) async {
      final authBloc = _MockAuthBloc();
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(
          UserModel(
            id: 'u1',
            roles: [],
            kycStatus: 'VERIFIED',
            status: 'ACTIVE',
            phoneNumber: '+221771234567',
          ),
        ),
      );

      await _openSheet(
        tester,
        _announcement(
          methods: const {BidPaymentMethod.cash, BidPaymentMethod.mobileMoney},
        ),
        authBloc: authBloc,
      );
      await _goToPaymentPicker(tester);

      await tester.tap(find.byKey(const Key('payment-method-mobile-money')));
      await tester.pump();

      expect(find.byKey(const Key('payer-phone-field')), findsOneWidget);
      expect(
        find.textContaining(
          'Par défaut, ton numéro Yadony. Tu recevras la demande de '
          'paiement sur ce numéro.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining("Ton compte n'a pas de numéro"), findsNothing);
    });

    testWidgets(
      'retour aux espèces après mobile money → champ numéro disparaît',
      (tester) async {
        await _openSheet(
          tester,
          _announcement(
            methods: const {
              BidPaymentMethod.cash,
              BidPaymentMethod.mobileMoney,
            },
          ),
        );
        await _goToPaymentPicker(tester);

        await tester.tap(find.byKey(const Key('payment-method-mobile-money')));
        await tester.pump();
        expect(find.byKey(const Key('payer-phone-field')), findsOneWidget);

        await tester.tap(find.byKey(const Key('payment-method-cash')));
        await tester.pump();
        expect(find.byKey(const Key('payer-phone-field')), findsNothing);
      },
    );
  });

  // ── 3. Pré-remplissage depuis l'utilisateur connecté ────────────────────

  group('Champ numéro payeur — pré-remplissage', () {
    testWidgets(
      'AuthBloc absent du contexte → champ démarre vide (pas de plantage)',
      (tester) async {
        await _openSheet(
          tester,
          _announcement(methods: const {BidPaymentMethod.mobileMoney}),
        );
        await _goToPaymentPicker(tester);

        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('payer-phone-field')),
            matching: find.byType(TextField),
          ),
        );
        expect(field.controller!.text, isEmpty);
      },
    );

    testWidgets(
      'AuthBloc avec utilisateur ayant un numéro → champ pré-rempli',
      (tester) async {
        final authBloc = _MockAuthBloc();
        whenListen(
          authBloc,
          const Stream<AuthState>.empty(),
          initialState: const AuthAuthenticated(
            UserModel(
              id: 'u1',
              roles: [],
              kycStatus: 'VERIFIED',
              status: 'ACTIVE',
              phoneNumber: '+221771234567',
            ),
          ),
        );

        await _openSheet(
          tester,
          _announcement(methods: const {BidPaymentMethod.mobileMoney}),
          authBloc: authBloc,
        );
        await _goToPaymentPicker(tester);

        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('payer-phone-field')),
            matching: find.byType(TextField),
          ),
        );
        expect(field.controller!.text, '+221771234567');
      },
    );

    testWidgets('AuthBloc avec utilisateur sans numéro → champ démarre vide', (
      tester,
    ) async {
      final authBloc = _MockAuthBloc();
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthAuthenticated(
          UserModel(
            id: 'u1',
            roles: [],
            kycStatus: 'VERIFIED',
            status: 'ACTIVE',
          ),
        ),
      );

      await _openSheet(
        tester,
        _announcement(methods: const {BidPaymentMethod.mobileMoney}),
        authBloc: authBloc,
      );
      await _goToPaymentPicker(tester);

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('payer-phone-field')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, isEmpty);
    });
  });

  // ── 4. Libellé du bouton sticky ──────────────────────────────────────────

  group('Bouton de confirmation — libellé selon le mode', () {
    testWidgets('mode mobile money → « Confirmer … par mobile money »', (
      tester,
    ) async {
      await _openSheet(
        tester,
        _announcement(
          methods: const {
            BidPaymentMethod.stripe,
            BidPaymentMethod.mobileMoney,
          },
        ),
      );
      await _goToPaymentPicker(tester);

      await tester.tap(find.byKey(const Key('payment-method-mobile-money')));
      await tester.pump();

      expect(find.textContaining(mobileMoneyCtaLabel), findsOneWidget);
      expect(find.textContaining('Bloquer'), findsNothing);
    });

    testWidgets('mode STRIPE → toujours « Bloquer … & payer »', (tester) async {
      await _openSheet(
        tester,
        _announcement(
          methods: const {BidPaymentMethod.stripe, BidPaymentMethod.cash},
          currency: 'EUR',
        ),
      );
      await _goToPaymentPicker(tester);

      expect(find.textContaining('Bloquer'), findsWidgets);
      expect(find.textContaining(mobileMoneyCtaLabel), findsNothing);
    });
  });

  // ── 5. Soumission ─────────────────────────────────────────────────────────

  group('Soumission — BidCreateRequested (site direct)', () {
    testWidgets('mode mobile money + numéro saisi → paymentMethod=mobileMoney, '
        'phoneNumber normalisé', (tester) async {
      await _openSheet(
        tester,
        _announcement(methods: const {BidPaymentMethod.mobileMoney}),
      );
      await _goToPaymentPicker(tester);

      await tester.enterText(
        find.byKey(const Key('payer-phone-field')),
        '+221 77 345 67 89',
      );
      await tester.pump();

      await tester.tap(find.textContaining(mobileMoneyCtaLabel));
      await tester.pump();

      final captured = verify(
        () => _currentBidBloc.add(captureAny(that: isA<BidCreateRequested>())),
      ).captured;
      expect(captured, hasLength(1));
      final event = captured.single as BidCreateRequested;
      expect(event.paymentMethod, BidPaymentMethod.mobileMoney);
      expect(event.phoneNumber, '+221773456789');
      verifyNever(
        () => _currentBidBloc.add(any(that: isA<BidCheckoutRequested>())),
      );
    });

    testWidgets('mode mobile money + champ laissé vide → phoneNumber null', (
      tester,
    ) async {
      await _openSheet(
        tester,
        _announcement(methods: const {BidPaymentMethod.mobileMoney}),
      );
      await _goToPaymentPicker(tester);

      await tester.tap(find.textContaining(mobileMoneyCtaLabel));
      await tester.pump();

      final captured = verify(
        () => _currentBidBloc.add(captureAny(that: isA<BidCreateRequested>())),
      ).captured;
      final event = captured.single as BidCreateRequested;
      expect(event.paymentMethod, BidPaymentMethod.mobileMoney);
      expect(event.phoneNumber, isNull);
    });

    testWidgets(
      'numéro pré-rempli puis effacé par l\'expéditeur → phoneNumber null',
      (tester) async {
        final authBloc = _MockAuthBloc();
        whenListen(
          authBloc,
          const Stream<AuthState>.empty(),
          initialState: const AuthAuthenticated(
            UserModel(
              id: 'u1',
              roles: [],
              kycStatus: 'VERIFIED',
              status: 'ACTIVE',
              phoneNumber: '+221771234567',
            ),
          ),
        );

        await _openSheet(
          tester,
          _announcement(methods: const {BidPaymentMethod.mobileMoney}),
          authBloc: authBloc,
        );
        await _goToPaymentPicker(tester);

        await tester.enterText(find.byKey(const Key('payer-phone-field')), '');
        await tester.pump();

        await tester.tap(find.textContaining(mobileMoneyCtaLabel));
        await tester.pump();

        final captured = verify(
          () =>
              _currentBidBloc.add(captureAny(that: isA<BidCreateRequested>())),
        ).captured;
        final event = captured.single as BidCreateRequested;
        expect(event.phoneNumber, isNull);
      },
    );

    testWidgets(
      'sélection mobile money puis retour cash → phoneNumber jamais envoyé '
      'en cash',
      (tester) async {
        await _openSheet(
          tester,
          _announcement(
            methods: const {
              BidPaymentMethod.cash,
              BidPaymentMethod.mobileMoney,
            },
          ),
        );
        await _goToPaymentPicker(tester);

        await tester.tap(find.byKey(const Key('payment-method-mobile-money')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('payer-phone-field')),
          '+221773456789',
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('payment-method-cash')));
        await tester.pump();

        await tester.tap(
          find.textContaining(RegExp(r'^Confirmer .* en espèces$')),
        );
        await tester.pump();

        final captured = verify(
          () =>
              _currentBidBloc.add(captureAny(that: isA<BidCreateRequested>())),
        ).captured;
        final event = captured.single as BidCreateRequested;
        expect(event.paymentMethod, BidPaymentMethod.cash);
        expect(event.phoneNumber, isNull);
      },
    );
  });

  // ── 6. Sous-titre de succès ───────────────────────────────────────────────
  //
  // Le libellé exact du sous-titre « Offre envoyée ! » est couvert dans
  // create_bid_bottom_sheet_success_test.dart (harnais dédié à BidCreated).

  // ── 7. Second site d'appel — mode négociation ────────────────────────────

  group(
    'Mode négociation — second site du sélecteur (mobile money exclu, R13)',
    () {
      // R13 : le backend rejette toute négociation en mobile money (422
      // mobile-money-negotiation-unsupported, BidNegotiationService) —
      // décision produit « offres classiques seulement ». Ces tests
      // remplacent ceux du round précédent (qui vérifiaient l'inverse) :
      // on ne supprime jamais un test, on le fait affirmer le comportement
      // correct.
      testWidgets(
        // Sans cash, mobile money ne compte plus comme alternative en
        // négociation (_hasAlternativePaymentMethods = false ici) : toute la
        // section « MODE DE PAIEMENT » disparaît, exactement comme avant la
        // task 10 pour une annonce stripe-only — aucune tuile, pas même
        // stripe (le mode reste figé sur stripe en silence).
        'annonce STRIPE+MOBILE_MONEY (sans cash) en négociation → aucune '
        'section de paiement, aucune tuile, aucun champ numéro',
        (tester) async {
          await _openNegotiation(
            tester,
            _announcement(
              methods: const {
                BidPaymentMethod.stripe,
                BidPaymentMethod.mobileMoney,
              },
              negotiable: true,
            ),
          );

          expect(find.byKey(const Key('payment-method-stripe')), findsNothing);
          expect(
            find.byKey(const Key('payment-method-mobile-money')),
            findsNothing,
          );
          expect(find.byKey(const Key('payer-phone-field')), findsNothing);
        },
      );

      testWidgets(
        'annonce MOBILE_MONEY seul en négociation → aucune tuile de paiement, '
        'aucun champ numéro (ni stripe ni cash disponibles, mobile money exclu)',
        (tester) async {
          await _openNegotiation(
            tester,
            _announcement(
              methods: const {BidPaymentMethod.mobileMoney},
              negotiable: true,
            ),
          );

          expect(find.byKey(const Key('payment-method-stripe')), findsNothing);
          expect(find.byKey(const Key('payment-method-cash')), findsNothing);
          expect(
            find.byKey(const Key('payment-method-mobile-money')),
            findsNothing,
          );
          expect(find.byKey(const Key('payer-phone-field')), findsNothing);
        },
      );

      testWidgets(
        // Avec cash, l'alternative redevient réelle : la section s'affiche
        // (stripe + cash), mais la tuile mobile money reste exclue même si
        // l'annonce l'accepte — c'est le cœur du fix R13.
        'annonce EUR STRIPE+CASH+MOBILE_MONEY en négociation → tuiles stripe et '
        'cash présentes, tuile mobile money toujours absente',
        (tester) async {
          await _openNegotiation(
            tester,
            _announcement(
              methods: const {
                BidPaymentMethod.stripe,
                BidPaymentMethod.cash,
                BidPaymentMethod.mobileMoney,
              },
              negotiable: true,
              currency: 'EUR',
            ),
          );

          expect(
            find.byKey(const Key('payment-method-stripe')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('payment-method-cash')), findsOneWidget);
          expect(
            find.byKey(const Key('payment-method-mobile-money')),
            findsNothing,
          );
          expect(find.byKey(const Key('payer-phone-field')), findsNothing);
        },
      );

      testWidgets(
        // Zone CFA : la carte n'existe pas, l'espèce ouvre la section, et le
        // mobile money reste exclu en négociation même si la devise l'autorise.
        'annonce XOF CASH+MOBILE_MONEY en négociation → tuile espèces seule, '
        'tuile mobile money absente',
        (tester) async {
          await _openNegotiation(
            tester,
            _announcement(
              methods: const {
                BidPaymentMethod.cash,
                BidPaymentMethod.mobileMoney,
              },
              negotiable: true,
            ),
          );

          expect(find.byKey(const Key('payment-method-stripe')), findsNothing);
          expect(find.byKey(const Key('payment-method-cash')), findsOneWidget);
          expect(
            find.byKey(const Key('payment-method-mobile-money')),
            findsNothing,
          );
          expect(find.byKey(const Key('payer-phone-field')), findsNothing);
        },
      );

      testWidgets(
        // Reprend et complète le test préexistant « mode carte (défaut) » :
        // preuve que BidNegotiationProposeRequested ne porte jamais
        // phoneNumber quel que soit le nombre de tuiles rendues (ici stripe
        // seule, mobile money exclu).
        'mode carte (défaut) en négociation → phoneNumber toujours null',
        (tester) async {
          await _openNegotiation(
            tester,
            _announcement(
              methods: const {
                BidPaymentMethod.stripe,
                BidPaymentMethod.mobileMoney,
              },
              negotiable: true,
              currency: 'EUR',
            ),
          );
          await _fillNegotiationForm(tester);

          final captured = await _submitProposal(tester);
          expect(captured, hasLength(1));
          expect(captured.single.paymentMethod, BidPaymentMethod.stripe);
          expect(captured.single.phoneNumber, isNull);
        },
      );
    },
  );
}
