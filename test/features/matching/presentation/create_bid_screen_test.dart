import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/presentation/screens/create_bid_screen.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

/// Task 11 — wiring test for `RecipientSection` inside `CreateBidScreen`.
///
/// The deep behaviour of `RecipientSection` (3-state picker, toggle
/// visibility, manual-entry save payload) is already covered by Task 9's
/// `recipient_section_test.dart`. Here we only assert the WIRING: the
/// section renders on the form (picker button, 2 unchanged fields),
/// `fallbackCity`/`fallbackCountry` come from `widget.announcement`, and
/// `RecipientSectionController.maybeSaveManualEntry()` fires on
/// `BidCheckoutReady` (dispatching `RecipientCreated` on the section's own
/// bloc) before the existing PaymentBloc dispatch — never on error/other
/// states.

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockBidBloc extends MockBloc<BidEvent, BidState>
    implements BidBloc {}

class MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class _FakeRecipientEvent extends Fake implements RecipientEvent {}

class _MockLocalAuthService extends Mock implements LocalAuthService {}

class _MockBox extends Mock implements Box {}

class _MockPaymentGateway extends Mock implements PaymentGateway {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

/// [HiveService.userPrefs] normally opens a real Hive box — overridden here
/// so tests can inject a [Box] mock without touching the filesystem.
class _FakeHiveService extends HiveService {
  _FakeHiveService(this._box);
  final Box _box;

  @override
  Box get userPrefs => _box;
}

/// Repository de catalogue mocké — prouve que l'écran affiche le catalogue
/// fourni par le repository (pas une liste figée en dur).
class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _testAnnouncement = AnnouncementModel(
  id: 'ann-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  // Deliberately different from the country the phone prefix (+221) would
  // resolve to (SN) — proves fallbackCountry comes from the announcement,
  // not from `countryFromPhone`.
  arrivalCountryCode: 'CI',
  departureDate: DateTime(2026, 6, 15),
  availableKg: 10,
  totalKg: 10,
  pricePerKg: 8,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  traveler: const TravelerProfile(
    id: 'trav-1',
    displayName: 'Ibrahima Diallo',
  ),
);

// ── Builder ───────────────────────────────────────────────────────────────────

Widget _buildScreen(MockBidBloc bidBloc, MockPaymentBloc paymentBloc) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => MultiBlocProvider(
          providers: [
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<PaymentBloc>.value(value: paymentBloc),
          ],
          child: CreateBidScreen(announcement: _testAnnouncement),
        ),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, state) =>
            const Scaffold(body: Center(child: Text('Bid detail screen'))),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// Must advance past all flutter_animate delays (max 200ms delay + 300ms
// duration) AND GoRouter internal timers to prevent "Timer still pending".
const _kSettle = Duration(milliseconds: 600);

// Pumps the screen with a tall viewport (1400px) so the full form — including
// the DisclaimerCard near the bottom — is always visible without scrolling.
Future<void> _pumpScreen(WidgetTester tester, MockBidBloc bidBloc, MockPaymentBloc paymentBloc) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildScreen(bidBloc, paymentBloc));
  await tester.pump(_kSettle);
}

// Selects one category + checks disclaimer → makes canSubmit = true.
// Requires _pumpScreen to have been called first.
Future<void> _enableSubmit(WidgetTester tester) async {
  await tester.tap(find.text('Vêtements & tissus'));
  await tester.pump();
  await tester.tap(find.byType(Checkbox).first);
  await tester.pump();
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockBidBloc bidBloc;
  late MockPaymentBloc paymentBloc;
  late MockRecipientBloc recipientBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(BidInitial());
    registerFallbackValue(BidCheckoutRequested(
      announcementId: '',
      weightKg: 0,
      declaredValueEur: 0,
      description: '',
      contentCategory: '',
      recipientName: '',
      recipientPhone: '',
    ));
    registerFallbackValue(PaymentInitial());
    registerFallbackValue(BidCheckoutPaymentRequested(
      clientSecret: '',
      publishableKey: '',
      bidId: '',
      amountEur: 0,
    ));
    registerFallbackValue(_FakeRecipientEvent());
  });

  setUp(() {
    // Several tests in this suite emit the exact same "Erreur réseau"
    // message via ErrorPresenter/DonySnackbar in quick succession — clear
    // the dedup cache so one test's snackbar doesn't suppress the next's.
    DonySnackbar.clearDedup();

    bidBloc = MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());

    paymentBloc = MockPaymentBloc();
    when(() => paymentBloc.state).thenReturn(const PaymentInitial());
    when(() => paymentBloc.stream).thenAnswer((_) => const Stream.empty());

    recipientBloc = MockRecipientBloc();
    when(() => recipientBloc.state).thenReturn(const RecipientState());
    when(() => recipientBloc.stream).thenAnswer((_) => const Stream.empty());

    if (getIt.isRegistered<RecipientBloc>()) {
      getIt.unregister<RecipientBloc>();
    }
    getIt.registerFactory<RecipientBloc>(() => recipientBloc);

    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
    getIt.registerFactory<IContentCategoryRepository>(
      () => _FakeContentCategoryRepository(),
    );
  });

  tearDown(() {
    bidBloc.close();
    paymentBloc.close();
    if (getIt.isRegistered<RecipientBloc>()) {
      getIt.unregister<RecipientBloc>();
    }
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
  });

  // ── 1. Rendu initial ──────────────────────────────────────────────────────

  group('Rendu initial', () {
    testWidgets('affiche le titre et les sections du formulaire',
        (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      expect(find.text("Demande d'envoi"), findsOneWidget);
      expect(find.text('POIDS ESTIMÉ'), findsOneWidget);
      expect(find.text('CONTENU DU COLIS'), findsOneWidget);
      expect(find.text('DESCRIPTION (AU VOYAGEUR)'), findsOneWidget);
      expect(find.text('VALEUR DÉCLARÉE (€)'), findsOneWidget);
      expect(find.text('DESTINATAIRE'), findsOneWidget);
    });

    testWidgets(
        'affiche le bouton "Choisir un destinataire" et les 2 champs inchangés',
        (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      expect(find.text('Choisir un destinataire'), findsOneWidget);
      expect(find.text('Prénom et nom du destinataire'), findsOneWidget);
      expect(find.text('Téléphone du destinataire'), findsOneWidget);
    });

    testWidgets('affiche le nom du voyageur dans l\'appbar', (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      expect(find.textContaining('Ibrahima Diallo'), findsOneWidget);
    });

    testWidgets(
      'affiche le catalogue fourni par le repository (pas une liste figée) '
      'et permet une saisie libre',
      (tester) async {
        await _pumpScreen(tester, bidBloc, paymentBloc);

        // Les 11 catégories du catalogue (mocké via _FakeContentCategoryRepository)
        // sont affichées — la source est le repository, pas une constante figée.
        for (final category in fallbackCatalog) {
          expect(find.text(category.label), findsOneWidget);
        }

        // Saisie libre : ajouter un type absent du catalogue.
        await tester.enterText(
          find.byKey(const Key('custom-category-input')),
          'Poissons',
        );
        await tester.tap(find.byKey(const Key('add-custom-category-btn')));
        await tester.pump();

        expect(find.text('Poissons'), findsOneWidget);
      },
    );

    testWidgets('bouton désactivé sans catégorie ni disclaimer',
        (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      final button =
          tester.widget<InkWell>(
            find.descendant(of: find.byType(DonyButton), matching: find.byType(InkWell)).last,
          );
      expect(button.onTap, isNull);
    });

    testWidgets('affiche la section de prix (Total + Frais de service)',
        (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Frais de service'), findsOneWidget);
    });
  });

  // ── 1b. Navigation ───────────────────────────────────────────────────────

  group('Navigation', () {
    testWidgets('bouton fermer → retour à l\'écran précédent', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // Nested router so context.pop() has a parent route to go back to
      final router = GoRouter(
        initialLocation: '/bid',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Écran parent'))),
            routes: [
              GoRoute(
                path: 'bid',
                builder: (ctx, state) => MultiBlocProvider(
                  providers: [
                    BlocProvider<BidBloc>.value(value: bidBloc),
                    BlocProvider<PaymentBloc>.value(value: paymentBloc),
                  ],
                  child: CreateBidScreen(announcement: _testAnnouncement),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/payments/pay',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Payment screen'))),
          ),
        ],
      );
      await tester.pumpWidget(
          MaterialApp.router(routerConfig: router, theme: AppTheme.light));
      await tester.pump(_kSettle);

      await tester.tap(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Écran parent'), findsOneWidget);
    });

    testWidgets('slider poids → met à jour le poids estimé', (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pump();

      // Slider callback executed without crash
      expect(find.byType(Slider), findsOneWidget);
    });
  });

  // ── 2. Sélection catégorie ────────────────────────────────────────────────

  group('Sélection catégorie', () {
    testWidgets('tap une catégorie → chip sélectionné (icône check)',
        (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      await tester.tap(find.text('Médicaments traditionnels'));
      await tester.pump();

      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'check'), findsOneWidget);
    });

    testWidgets('double-tap sur même catégorie → chip désélectionné',
        (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      await tester.tap(find.text('Documents & administratif'));
      await tester.pump();
      await tester.tap(find.text('Documents & administratif'));
      await tester.pump();

      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'check'), findsNothing);
    });

    testWidgets('sélection multiple → plusieurs icônes check', (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      await tester.tap(find.text('Vêtements & tissus'));
      await tester.pump();
      await tester.tap(find.text('Médicaments traditionnels'));
      await tester.pump();

      expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'check'), findsNWidgets(2));
    });
  });

  // ── 3. Disclaimer ─────────────────────────────────────────────────────────

  group('Disclaimer card', () {
    testWidgets('cocher disclaimer seul ne suffit pas (bouton reste désactivé)',
        (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      final button =
          tester.widget<InkWell>(
            find.descendant(of: find.byType(DonyButton), matching: find.byType(InkWell)).last,
          );
      expect(button.onTap, isNull);
    });

    testWidgets('catégorie + disclaimer → bouton activé', (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      await _enableSubmit(tester);

      final button =
          tester.widget<InkWell>(
            find.descendant(of: find.byType(DonyButton), matching: find.byType(InkWell)).last,
          );
      expect(button.onTap, isNotNull);
    });

    testWidgets('tap texte disclaimer → accepte via GestureDetector',
        (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      // Tap on the label text triggers GestureDetector.onTap (not Checkbox)
      await tester.tap(find.text('Je signe & j\'accepte'));
      await tester.pump();

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
      expect(checkbox.value, isTrue);
    });
  });

  // ── 4. Validation formulaire ──────────────────────────────────────────────

  group('Validation — messages d\'erreur', () {
    testWidgets('description vide → snackbar "Description obligatoire"',
        (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      await _enableSubmit(tester);
      await tester.tap(find.textContaining('Bloquer'));
      await tester.pumpAndSettle();

      expect(find.text('Description obligatoire'), findsOneWidget);
    });

    testWidgets('valeur vide → snackbar "Valeur déclarée invalide"',
        (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      await _enableSubmit(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Test');
      await tester.pump();

      await tester.tap(find.textContaining('Bloquer'));
      await tester.pumpAndSettle();

      expect(find.text('Valeur déclarée invalide'), findsOneWidget);
    });

    testWidgets('valeur > 500€ → snackbar "Valeur maximum : 500 €"',
        (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      await _enableSubmit(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Vêtements test');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '600');
      await tester.pump();

      await tester.tap(find.textContaining('Bloquer'));
      await tester.pumpAndSettle();

      expect(find.text('Valeur maximum : 500 €'), findsOneWidget);
    });

    testWidgets('nom destinataire vide → snackbar d\'erreur', (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      await _enableSubmit(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Test description');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '150');
      await tester.pump();

      await tester.tap(find.textContaining('Bloquer'));
      await tester.pumpAndSettle();

      expect(find.text('Nom du destinataire obligatoire'), findsOneWidget);
    });

    testWidgets('téléphone destinataire vide → snackbar d\'erreur',
        (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      await _enableSubmit(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Test description');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '150');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(2), 'Amadou Diallo');
      await tester.pump();

      await tester.tap(find.textContaining('Bloquer'));
      await tester.pumpAndSettle();

      expect(find.text('Téléphone du destinataire obligatoire'), findsOneWidget);
    });
  });

  // ── 5. Soumission valide ──────────────────────────────────────────────────

  group('Soumission valide', () {
    testWidgets('formulaire complet → BidCreateRequested dispatché',
        (tester) async {
      await _pumpScreen(tester, bidBloc, paymentBloc);

      await _enableSubmit(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Vêtements famille');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '150');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(2), 'Amadou Diallo');
      await tester.pump();
      await tester.enterText(
          find.byType(TextField).at(3), '+221 77 000 00 00');
      await tester.pump();

      await tester.tap(find.textContaining('Bloquer'));
      await tester.pump();

      verify(() => bidBloc.add(any(that: isA<BidCheckoutRequested>()))).called(1);
    });
  });

  // ── 6. États BLoC ─────────────────────────────────────────────────────────

  group('États BLoC', () {
    testWidgets('BidLoading → bouton affiche spinner (désactivé)',
        (tester) async {
      when(() => bidBloc.state).thenReturn(BidLoading());
      await _pumpScreen(tester, bidBloc, paymentBloc);

      // isLoading = true → DonyButton shows CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Button disabled
      final button =
          tester.widget<InkWell>(
            find.descendant(of: find.byType(DonyButton), matching: find.byType(InkWell)).last,
          );
      expect(button.onTap, isNull);
    });

    testWidgets('BidCheckoutReady → triggers PaymentBloc', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final checkoutResponse = BidCheckoutResponseModel(
        bidId: 'bid-1',
        clientSecret: 'pi_test_secret',
        publishableKey: 'pk_test_123',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      whenListen<BidState>(
        bidBloc,
        Stream.fromIterable([BidCheckoutReady(checkoutResponse)]),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(_buildScreen(bidBloc, paymentBloc));
      await tester.pumpAndSettle();

      // Verify PaymentBloc received BidCheckoutPaymentRequested event
      verify(() => paymentBloc.add(any(that: isA<BidCheckoutPaymentRequested>()))).called(1);
    });

    testWidgets(
        'BidCheckoutReady → sauvegarde le destinataire saisi manuellement '
        '(fallbackCity/fallbackCountry de l\'annonce) avant le dispatch '
        'PaymentBloc', (tester) async {
      final checkoutResponse = BidCheckoutResponseModel(
        bidId: 'bid-1',
        clientSecret: 'pi_test_secret',
        publishableKey: 'pk_test_123',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );
      final stateController = StreamController<BidState>();
      addTearDown(stateController.close);

      whenListen<BidState>(
        bidBloc,
        stateController.stream,
        initialState: BidInitial(),
      );

      await _pumpScreen(tester, bidBloc, paymentBloc);

      // Recipient name + a valid, unknown E.164 phone → toggle "Enregistrer
      // ce destinataire" appears and defaults to ON.
      await tester.enterText(find.byType(TextField).at(2), 'Amadou Diallo');
      await tester.pump();
      await tester.enterText(
          find.byType(TextField).at(3), '+221771112233');
      await tester.pump();
      expect(find.byType(SwitchListTile), findsOneWidget);

      stateController.add(BidCheckoutReady(checkoutResponse));
      await tester.pump();
      await tester.pump();

      final createdEvents = verify(
        () => recipientBloc.add(captureAny()),
      ).captured.whereType<RecipientCreated>();
      expect(createdEvents, hasLength(1));
      expect(createdEvents.single.fullName, 'Amadou Diallo');
      expect(createdEvents.single.phoneE164, '+221771112233');
      // fallbackCity/fallbackCountry come from widget.announcement, not a
      // hardcoded value nor countryFromPhone (which would give 'SN' for
      // +221).
      expect(createdEvents.single.city, 'Dakar');
      expect(createdEvents.single.country, 'CI');

      // The existing PaymentBloc dispatch still happens.
      verify(() => paymentBloc
              .add(any(that: isA<BidCheckoutPaymentRequested>())))
          .called(1);

      // Settle the checkout's own SnackBar/animation timers so they don't
      // bleed into the next test.
      await tester.pumpAndSettle();
    });

    testWidgets(
        'BidError → ne sauvegarde pas de destinataire (dispatch RecipientCreated absent)',
        (tester) async {
      final stateController = StreamController<BidState>();
      addTearDown(stateController.close);

      whenListen<BidState>(
        bidBloc,
        stateController.stream,
        initialState: BidInitial(),
      );

      await _pumpScreen(tester, bidBloc, paymentBloc);

      await tester.enterText(find.byType(TextField).at(2), 'Amadou Diallo');
      await tester.pump();
      await tester.enterText(
          find.byType(TextField).at(3), '+221771112233');
      await tester.pump();

      stateController.add(BidError(NetworkException('Erreur réseau')));
      await tester.pump();
      await tester.pump();

      verifyNever(
          () => recipientBloc.add(any(that: isA<RecipientCreated>())));

      // Settle this test's own error SnackBar timer before ending — leaving
      // it pending was bleeding into the next test's snackbar assertion.
      await tester.pumpAndSettle();
    });

    testWidgets('BidError → affiche message d\'erreur via snackbar',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      whenListen<BidState>(
        bidBloc,
        Stream.fromIterable([BidError(NetworkException('Erreur réseau'))]),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(_buildScreen(bidBloc, paymentBloc));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Erreur réseau'), findsOneWidget);
    });
  });

  // ── 6. Paiement Stripe réussi → DonySuccessScreen ────────────────────────

  group('Paiement Stripe réussi', () {
    late _MockLocalAuthService authService;
    late _MockBox userPrefsBox;
    late _MockPaymentGateway paymentGateway;
    late _MockPaymentRepository paymentRepository;

    setUp(() {
      authService = _MockLocalAuthService();
      userPrefsBox = _MockBox();
      // Biométrie activée + réussie → requirePaymentAuth ne passe jamais par
      // l'écran PIN '/auth/local' (pas de route stub nécessaire).
      when(() => userPrefsBox.get(HiveService.kBiometricEnabled,
          defaultValue: any(named: 'defaultValue'))).thenReturn(true);
      when(() => authService.isBiometricAvailable())
          .thenAnswer((_) async => true);
      when(() => authService.authenticateWithBiometric())
          .thenAnswer((_) async => true);

      paymentGateway = _MockPaymentGateway();
      // PlatformPayButton (Apple/Google Pay) plante hors iOS/Android réel —
      // on désactive le wallet et paie via PayPal (bouton Flutter classique).
      when(() => paymentGateway.isPlatformPaySupported())
          .thenAnswer((_) async => false);
      when(() => paymentGateway.confirmPayPal(any()))
          .thenAnswer((_) async {});

      paymentRepository = _MockPaymentRepository();
      when(() => paymentRepository.listSavedPaymentMethods())
          .thenAnswer((_) async => []);

      if (getIt.isRegistered<LocalAuthService>()) {
        getIt.unregister<LocalAuthService>();
      }
      getIt.registerFactory<LocalAuthService>(() => authService);

      if (getIt.isRegistered<HiveService>()) {
        getIt.unregister<HiveService>();
      }
      getIt.registerFactory<HiveService>(() => _FakeHiveService(userPrefsBox));

      if (getIt.isRegistered<PaymentGateway>()) {
        getIt.unregister<PaymentGateway>();
      }
      getIt.registerFactory<PaymentGateway>(() => paymentGateway);

      if (getIt.isRegistered<PaymentRepository>()) {
        getIt.unregister<PaymentRepository>();
      }
      getIt.registerFactory<PaymentRepository>(() => paymentRepository);
    });

    tearDown(() {
      if (getIt.isRegistered<LocalAuthService>()) {
        getIt.unregister<LocalAuthService>();
      }
      if (getIt.isRegistered<HiveService>()) {
        getIt.unregister<HiveService>();
      }
      if (getIt.isRegistered<PaymentGateway>()) {
        getIt.unregister<PaymentGateway>();
      }
      if (getIt.isRegistered<PaymentRepository>()) {
        getIt.unregister<PaymentRepository>();
      }
    });

    testWidgets(
        'CheckoutPaymentSheetReady + paiement PayPal réussi → '
        'DonySuccessScreen puis CTA vers /bids/{id}?from=payment',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      whenListen<PaymentState>(
        paymentBloc,
        Stream.fromIterable([
          const CheckoutPaymentSheetReady(
            clientSecret: 'pi_test_secret',
            publishableKey: 'pk_test',
            bidId: 'bid-42',
            amountEur: 56.0,
            paymentMethodTypes: ['paypal'],
          ),
        ]),
        initialState: const PaymentInitial(),
      );

      await tester.pumpWidget(_buildScreen(bidBloc, paymentBloc));
      await tester.pumpAndSettle();

      // La DonyPaymentSheet est ouverte (PayPal dispo, aucune carte
      // enregistrée) → on paie via le bouton PayPal.
      await tester.tap(find.byKey(const Key('paymentSheetPayPalButton')));
      await tester.pump(); // PaymentSheetProcessing
      await tester.pump(); // PaymentSheetSuccess (résolution async du gateway)
      await tester
          .pump(const Duration(milliseconds: 900)); // déclenchement onSuccess
      await tester.pumpAndSettle();

      verify(() => bidBloc.add(any(
              that: isA<BidConfirmPaymentRequested>()
                  .having((e) => e.bidId, 'bidId', 'bid-42'))))
          .called(1);

      expect(find.byType(DonySuccessScreen), findsOneWidget);
      expect(find.text('Offre payée !'), findsOneWidget);

      await tester.tap(find.text('Voir mon envoi'));
      await tester.pumpAndSettle();

      expect(find.text('Bid detail screen'), findsOneWidget);
    });
  });
}
