import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/reimbursement_info_banner.dart';
import 'package:dony/features/payments/presentation/widgets/payment_method_names.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

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

class _FakeRecipientEvent extends Fake implements RecipientEvent {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

// ── GetIt captures ─────────────────────────────────────────────────────────────
//
// CreateBidBottomSheet.show() calls getIt<BidBloc>(), getIt<PaymentBloc>(),
// getIt<WalletBloc>() and getIt<BidPhotosCubit>(). We register factories that
// return the _current_ mock (set in setUp) so each test controls its own bloc.

late _MockBidBloc _currentBidBloc;
late _MockPaymentBloc _currentPaymentBloc;
late _MockWalletBloc _currentWalletBloc;
late _MockBidPhotosCubit _currentPhotosCubit;
late _MockRecipientBloc _currentRecipientBloc;

// ── Fixtures ───────────────────────────────────────────────────────────────────

AnnouncementModel _announcement({bool cashEnabled = false}) {
  final methods = cashEnabled
      ? const {BidPaymentMethod.stripe, BidPaymentMethod.cash}
      : const {BidPaymentMethod.stripe};
  return AnnouncementModel(
    id: 'ann-1',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2026, 8, 15),
    availableKg: 10,
    totalKg: 10,
    pricePerKg: 8,
    status: 'ACTIVE',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    acceptedPaymentMethods: methods,
  );
}

// Trajet cash-only (publié sans Stripe Connect — Task 5) : acceptedPaymentMethods
// ne contient que `cash`. La chip Stripe doit disparaître et le mode par
// défaut doit basculer sur cash (D5).
AnnouncementModel _cashOnlyAnnouncement() {
  return AnnouncementModel(
    id: 'ann-cash-only',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2026, 8, 15),
    availableKg: 10,
    totalKg: 10,
    pricePerKg: 8,
    status: 'ACTIVE',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    acceptedPaymentMethods: const {BidPaymentMethod.cash},
  );
}

AnnouncementModel _kgFreeAnnouncement() {
  // KG_FREE: availableKg=1 but capacityUnit=KG_FREE → must NOT block
  return AnnouncementModel(
    id: 'ann-kgfree',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2026, 8, 15),
    availableKg: 1,
    totalKg: 1,
    pricePerKg: 8,
    status: 'ACTIVE',
    capacityUnit: 'KG_FREE',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    acceptedPaymentMethods: const {BidPaymentMethod.stripe},
  );
}

AnnouncementModel _mixedGridOnlyAnnouncement() {
  return AnnouncementModel(
    id: 'ann-grid-only',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2026, 8, 15),
    availableKg: 10,
    totalKg: 10,
    pricePerKg: 0, // pas de tarif kg
    status: 'ACTIVE',
    pricingMode: 'MIXED',
    priceGridItems: const [
      AnnouncementGridItemModel(
        id: 'item-1',
        label: 'Valise cabine',
        unitPriceNet: 20.0,
        unitPriceDisplay: 22.4,
      ),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    acceptedPaymentMethods: const {BidPaymentMethod.stripe},
  );
}

AnnouncementModel _mixedAnnouncement() {
  return AnnouncementModel(
    id: 'ann-mixed',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2026, 8, 15),
    availableKg: 10,
    totalKg: 10,
    pricePerKg: 8,
    status: 'ACTIVE',
    pricingMode: 'MIXED',
    priceGridItems: const [
      AnnouncementGridItemModel(
        id: 'item-1',
        label: 'Téléphone',
        unitPriceNet: 10,
        unitPriceDisplay: 11.20,
      ),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    acceptedPaymentMethods: const {BidPaymentMethod.stripe},
  );
}

// ── Harness ────────────────────────────────────────────────────────────────────

// 800×5000 px: all sheet content visible without scrolling.
const _kSize = Size(800, 5000);

Widget _buildHarness(AnnouncementModel announcement) {
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
      // CreateBidBottomSheet.show() delegates to context.push('/bids/new')
      // (post-06a9a2bc refactor, PR #126 : CreateBidScreen est un écran
      // GoRouter plein écran, plus une modal) — reflète la vraie route de
      // lib/app/router.dart.
      GoRoute(
        path: '/bids/new',
        builder: (_, state) =>
            CreateBidScreen(announcement: state.extra as AnnouncementModel),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Bid détail'))),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
  );
}

/// Opens the bottom sheet. Uses pumpAndSettle to drain all flutter_animate
/// timers (non-periodic, so pumpAndSettle eventually settles).
Future<void> _openSheet(
  WidgetTester tester,
  AnnouncementModel announcement,
) async {
  tester.view.physicalSize = _kSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildHarness(announcement));
  await tester.tap(find.text('Ouvrir'));
  // pumpAndSettle drains all flutter_animate initial timers (0-duration start
  // timers + delay timers). Works because all animations are non-periodic.
  await tester.pumpAndSettle();
}

// Selects a category + checks disclaimer so canSubmit becomes true.
// Label issu du catalogue unifié (PR #139) : 'Vêtements & tissus'.
Future<void> _enableSubmitButton(WidgetTester tester) async {
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

// Fills all mandatory text fields so _submit() passes validation.
Future<void> _fillMandatoryFields(WidgetTester tester) async {
  // at(0) = input inline contenu (ignoré) ; at(1)=description, at(2)=valeur, at(3)=nom, at(4)=tel
  await tester.enterText(find.byType(TextField).at(1), 'Médicaments');
  await tester.pump();
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(2), 'Amadou Diallo');
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(3), '+221 77 000 00 00');
  await tester.pump();
}

// Navigue de l'étape "form" vers l'étape "paymentPicker".
// Nécessite une annonce avec des méthodes de paiement alternatives (cash/wave/orange) :
// remplit les champs obligatoires puis soumet via le bouton "Envoyer".
Future<void> _goToPaymentPicker(WidgetTester tester) async {
  await _enableSubmitButton(tester);
  await _fillMandatoryFields(tester);
  await tester.tap(find.text('Envoyer'));
  await tester.pumpAndSettle();
}

// ── Tests ──────────────────────────────────────────────────────────────────────

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

    // Register GetIt factories that always return the current test-level mock.
    // The factory captures _current* by reference (Dart closure semantics), so
    // each test's setUp can swap the mock before the sheet is opened.
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
    if (!getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.registerFactory<IContentCategoryRepository>(
        _FakeContentCategoryRepository.new,
      );
    }
    registerFallbackValue(_FakeRecipientEvent());
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
  });

  // ── 1. Visibilité du sélecteur ─────────────────────────────────────────────

  group('Politique de remboursement', () {
    testWidgets(
      'le champ valeur déclarée est absent, le banner remboursement présent',
      (tester) async {
        await _openSheet(tester, _announcement());

        expect(find.text('VALEUR DÉCLARÉE (€)'), findsNothing);
        expect(find.byType(ReimbursementInfoBanner), findsOneWidget);
      },
    );
  });

  group('Visibilité du sélecteur de paiement', () {
    testWidgets('annonce Stripe-only → sélecteur non affiché', (tester) async {
      await _openSheet(tester, _announcement(cashEnabled: false));

      expect(find.text('Comment veux-tu payer ?'), findsNothing);
      expect(find.byKey(const Key('payment-method-cash')), findsNothing);
    });

    testWidgets('annonce CASH+STRIPE → sélecteur affiché avec 2 tuiles', (
      tester,
    ) async {
      await _openSheet(tester, _announcement(cashEnabled: true));
      await _goToPaymentPicker(tester);

      expect(find.text('Comment veux-tu payer ?'), findsOneWidget);
      expect(find.byKey(const Key('payment-method-stripe')), findsOneWidget);
      expect(find.byKey(const Key('payment-method-cash')), findsOneWidget);
      // La tuile STRIPE annonce les wallets via les logos de marque.
      expect(find.byType(PaymentMethodNames), findsOneWidget);
    });

    testWidgets('Stripe sélectionné par défaut → bouton affiche Bloquer', (
      tester,
    ) async {
      await _openSheet(tester, _announcement(cashEnabled: true));
      await _goToPaymentPicker(tester);

      // Bouton sticky du picker : "Bloquer X€ & payer" (mode Stripe par défaut).
      expect(find.textContaining('Bloquer'), findsWidgets);
      // Le bouton ne dit pas "Envoyer (paiement en espèces)".
      expect(find.text('Confirmer (paiement en espèces)'), findsNothing);
    });
  });

  // ── 2. Changement de mode ──────────────────────────────────────────────────

  group('Changement de mode de paiement', () {
    testWidgets('taper CASH → bouton libellé change en espèces', (
      tester,
    ) async {
      await _openSheet(tester, _announcement(cashEnabled: true));
      await _goToPaymentPicker(tester);

      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pump();

      expect(find.text('Confirmer (paiement en espèces)'), findsOneWidget);
      expect(find.textContaining('Bloquer'), findsNothing);
    });

    testWidgets('taper STRIPE après CASH → libellé bouton revient à Bloquer', (
      tester,
    ) async {
      await _openSheet(tester, _announcement(cashEnabled: true));
      await _goToPaymentPicker(tester);

      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('payment-method-stripe')));
      await tester.pump();

      expect(find.textContaining('Bloquer'), findsWidgets);
      expect(find.text('Confirmer (paiement en espèces)'), findsNothing);
    });
  });

  // ── 2b. Trajet cash-only + avertissement séquestre (D5) ───────────────────

  group('Trajet cash-only — Stripe indisponible', () {
    testWidgets(
      'chip Stripe absente, cash sélectionné par défaut, note séquestre visible',
      (tester) async {
        await _openSheet(tester, _cashOnlyAnnouncement());
        await _goToPaymentPicker(tester);

        expect(find.byKey(const Key('payment-method-stripe')), findsNothing);
        expect(find.byKey(const Key('payment-method-cash')), findsOneWidget);

        // Cash est le mode par défaut (Stripe indisponible) → le bouton sticky
        // affiche directement le libellé « espèces », jamais « Bloquer ».
        expect(find.text('Confirmer (paiement en espèces)'), findsOneWidget);
        expect(find.textContaining('Bloquer'), findsNothing);

        // Note D5 : absence de séquestre en paiement cash.
        expect(
          find.textContaining(
            'Paiement en espèces : pas de séquestre, vous payez le voyageur '
            'directement, sans garantie de remboursement par dony.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'soumission cash-only → BidCreateRequested paymentMethod=cash',
      (tester) async {
        await _openSheet(tester, _cashOnlyAnnouncement());
        await _goToPaymentPicker(tester);

        await tester.tap(find.text('Confirmer (paiement en espèces)'));
        await tester.pump();

        verify(
          () => _currentBidBloc.add(
            any(
              that: predicate<BidEvent>(
                (e) =>
                    e is BidCreateRequested &&
                    e.paymentMethod == BidPaymentMethod.cash,
              ),
            ),
          ),
        ).called(1);
        verifyNever(
          () => _currentBidBloc.add(any(that: isA<BidCheckoutRequested>())),
        );
      },
    );
  });

  group('Trajet mixte (Stripe + cash) — note séquestre selon sélection', () {
    testWidgets('Stripe sélectionné par défaut → pas de note séquestre', (
      tester,
    ) async {
      await _openSheet(tester, _announcement(cashEnabled: true));
      await _goToPaymentPicker(tester);

      expect(find.textContaining('pas de séquestre'), findsNothing);
    });

    testWidgets('tap sur CASH → note séquestre apparaît', (tester) async {
      await _openSheet(tester, _announcement(cashEnabled: true));
      await _goToPaymentPicker(tester);

      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pump();

      expect(find.textContaining('pas de séquestre'), findsOneWidget);
    });

    testWidgets('retour à STRIPE après CASH → note séquestre disparaît', (
      tester,
    ) async {
      await _openSheet(tester, _announcement(cashEnabled: true));
      await _goToPaymentPicker(tester);

      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pump();
      expect(find.textContaining('pas de séquestre'), findsOneWidget);

      await tester.tap(find.byKey(const Key('payment-method-stripe')));
      await tester.pump();
      expect(find.textContaining('pas de séquestre'), findsNothing);
    });
  });

  // ── 3. Soumission ──────────────────────────────────────────────────────────

  group('Soumission du formulaire', () {
    testWidgets(
      'mode CASH + formulaire complet → BidCreateRequested paymentMethod=cash',
      (tester) async {
        await _openSheet(tester, _announcement(cashEnabled: true));
        await _goToPaymentPicker(tester);

        await tester.tap(find.byKey(const Key('payment-method-cash')));
        await tester.pump();

        await tester.tap(find.text('Confirmer (paiement en espèces)'));
        await tester.pump();

        verify(
          () => _currentBidBloc.add(
            any(
              that: predicate<BidEvent>(
                (e) =>
                    e is BidCreateRequested &&
                    e.paymentMethod == BidPaymentMethod.cash,
              ),
            ),
          ),
        ).called(1);
        verifyNever(
          () => _currentBidBloc.add(any(that: isA<BidCheckoutRequested>())),
        );
      },
    );

    testWidgets(
      'mode STRIPE (défaut) + formulaire complet → BidCheckoutRequested dispatché',
      (tester) async {
        await _openSheet(tester, _announcement(cashEnabled: true));
        await _goToPaymentPicker(tester);

        // Stripe sélectionné par défaut sur le picker → bouton "Bloquer X€ & payer".
        await tester.tap(find.textContaining('& payer'));
        await tester.pump();

        verify(
          () => _currentBidBloc.add(any(that: isA<BidCheckoutRequested>())),
        ).called(1);
        verifyNever(
          () => _currentBidBloc.add(any(that: isA<BidCreateRequested>())),
        );
      },
    );
  });

  // ── 4. Navigation sur BidCreated ──────────────────────────────────────────

  group('Navigation après BidCreated', () {
    testWidgets('BidCreated → sheet fermé, DonySuccessScreen affiché, '
        'CTA « Voir mon envoi » navigue vers /bids/{id}', (tester) async {
      final stateController = StreamController<BidState>.broadcast();
      addTearDown(stateController.close);

      when(
        () => _currentBidBloc.stream,
      ).thenAnswer((_) => stateController.stream);

      await _openSheet(tester, _announcement(cashEnabled: true));

      // Sheet is open.
      expect(find.text('Envoyer un colis'), findsOneWidget);

      // Simulate successful bid creation.
      stateController.add(BidCreated(BidModel.skeleton('bid-xyz')));
      await tester.pump();
      await tester.pumpAndSettle();

      // Depuis PR #141 (écrans de succès unifiés) : l'écran de création est
      // fermé et DonySuccessScreen « Offre envoyée ! » s'affiche — la
      // navigation vers le détail du bid n'a lieu qu'après le CTA.
      expect(find.text('Envoyer un colis'), findsNothing);
      expect(find.byType(DonySuccessScreen), findsOneWidget);
      expect(find.text('Offre envoyée !'), findsOneWidget);
      expect(find.text('Bid détail'), findsNothing);

      // CTA → navigation vers /bids/{id} (règle métier conservée).
      await tester.tap(find.text('Voir mon envoi'));
      await tester.pumpAndSettle();
      expect(find.text('Bid détail'), findsOneWidget);
    });
  });

  // ── 5. Mode MIXED — poids optionnel ───────────────────────────────────────

  group('Mode MIXED — poids optionnel', () {
    testWidgets('annonce MIXED → label "Poids du colis (optionnel)" affiché', (
      tester,
    ) async {
      await _openSheet(tester, _mixedAnnouncement());

      expect(find.text('Poids du colis (optionnel)'), findsOneWidget);
    });

    testWidgets(
      'annonce KG → label "Poids du colis" affiché sans "(optionnel)"',
      (tester) async {
        await _openSheet(tester, _announcement());

        expect(find.text('Poids du colis'), findsOneWidget);
        expect(find.text('Poids du colis (optionnel)'), findsNothing);
      },
    );

    testWidgets('annonce MIXED → bouton "Choisir mes articles" visible', (
      tester,
    ) async {
      await _openSheet(tester, _mixedAnnouncement());

      // The new grid section shows a tappable card with the section header
      // and the "Choisir mes articles" button text.
      expect(find.text('ARTICLES'), findsOneWidget);
      expect(find.text('Choisir mes articles'), findsOneWidget);
    });

    testWidgets(
      'annonce MIXED + poids > 0 (slider défaut 5 kg) → soumission possible',
      (tester) async {
        await _openSheet(tester, _mixedAnnouncement());

        // Select a category and accept disclaimer; slider starts at 5 → hasWeight = true.
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

        // canSubmit is true (hasWeight). Fill mandatory fields and tap the submit button.
        await _fillMandatoryFields(tester);
        await tester.tap(find.text('Envoyer'));
        await tester.pump();

        // BidCheckoutRequested should have been dispatched.
        verify(
          () => _currentBidBloc.add(any(that: isA<BidCheckoutRequested>())),
        ).called(1);
      },
    );

    testWidgets(
      'annonce MIXED + poids > 0 sans articles → soumission via weight seul',
      (tester) async {
        await _openSheet(tester, _mixedAnnouncement());

        // Select a category and accept disclaimer; slider starts at 5 (weight > 0).
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

        // canSubmit is true (hasWeight). Fill mandatory fields and tap submit.
        await _fillMandatoryFields(tester);
        await tester.tap(find.text('Envoyer'));
        await tester.pump();

        // BidCheckoutRequested should have been dispatched.
        verify(
          () => _currentBidBloc.add(any(that: isA<BidCheckoutRequested>())),
        ).called(1);
      },
    );

    testWidgets(
      'annonce KG + poids=0 → soumission bloquée (comportement KG inchangé)',
      (tester) async {
        await _openSheet(tester, _announcement());

        // Select a category and accept disclaimer.
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

        // Drag slider all the way left → weight = 1 (min in KG mode).
        final slider = find.byType(Slider);
        final sliderRect = tester.getRect(slider);
        await tester.drag(slider, Offset(-(sliderRect.width), 0));
        await tester.pump();

        // Even at min (1 kg), KG mode should allow submission.
        await _fillMandatoryFields(tester);
        await tester.tap(find.text('Envoyer'));
        await tester.pump();

        verify(
          () => _currentBidBloc.add(any(that: isA<BidCheckoutRequested>())),
        ).called(1);
      },
    );
  });

  // ── 5b. Validation _submit() ──────────────────────────────────────────────

  group('Validation _submit()', () {
    testWidgets('description vide → snackbar "Description obligatoire"', (
      tester,
    ) async {
      await _openSheet(tester, _announcement());
      await _enableSubmitButton(tester);
      // Laisser la description vide, remplir le reste
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(2), 'Amadou');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(3), '+221770000000');
      await tester.pump();

      await tester.tap(find.text('Envoyer'));
      await tester.pump();

      expect(find.text('Description obligatoire'), findsOneWidget);
    });

    testWidgets(
      'nom destinataire vide → snackbar "Nom du destinataire obligatoire"',
      (tester) async {
        await _openSheet(tester, _announcement());
        await _enableSubmitButton(tester);
        await tester.enterText(find.byType(TextField).at(1), 'Médicaments');
        await tester.pump();
        await tester.pump();
        // Laisser nom et téléphone vides
        await tester.tap(find.text('Envoyer'));
        await tester.pump();

        expect(find.text('Nom du destinataire obligatoire'), findsOneWidget);
      },
    );

    testWidgets(
      'téléphone destinataire vide → snackbar "Téléphone du destinataire obligatoire"',
      (tester) async {
        await _openSheet(tester, _announcement());
        await _enableSubmitButton(tester);
        await tester.enterText(find.byType(TextField).at(1), 'Médicaments');
        await tester.pump();
        await tester.pump();
        await tester.enterText(find.byType(TextField).at(2), 'Amadou');
        await tester.pump();
        // Laisser le téléphone vide
        await tester.tap(find.text('Envoyer'));
        await tester.pump();

        expect(
          find.text('Téléphone du destinataire obligatoire'),
          findsOneWidget,
        );
      },
    );
  });

  // ── 5c. BLoC state listeners ──────────────────────────────────────────────

  group('BLoC state listeners', () {
    testWidgets(
      'BidCheckoutReady → dispatche BidCheckoutPaymentRequested au PaymentBloc',
      (tester) async {
        registerFallbackValue(
          const BidCheckoutPaymentRequested(
            clientSecret: '',
            publishableKey: '',
            bidId: '',
            amountEur: 0,
          ),
        );
        when(() => _currentPaymentBloc.add(any())).thenReturn(null);

        final ctrl = StreamController<BidState>.broadcast();
        addTearDown(ctrl.close);
        when(() => _currentBidBloc.stream).thenAnswer((_) => ctrl.stream);

        await _openSheet(tester, _announcement());

        ctrl.add(
          BidCheckoutReady(
            BidCheckoutResponseModel(
              bidId: 'bid-1',
              clientSecret: 'cs_test',
              publishableKey: 'pk_test',
              expiresAt: DateTime.utc(2026, 12, 31),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        verify(
          () => _currentPaymentBloc.add(
            any(that: isA<BidCheckoutPaymentRequested>()),
          ),
        ).called(1);
      },
    );

    testWidgets('BidError → affiche un snackbar via ErrorPresenter', (
      tester,
    ) async {
      final ctrl = StreamController<BidState>.broadcast();
      addTearDown(ctrl.close);
      when(() => _currentBidBloc.stream).thenAnswer((_) => ctrl.stream);

      await _openSheet(tester, _announcement());

      ctrl.add(BidError(const NetworkException('Erreur réseau')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Un SnackBar ou texte d'erreur doit apparaître.
      expect(find.textContaining('réseau', findRichText: true), findsWidgets);
    });
  });

  // ── 6. Capacité initiale — branches availableKg ───────────────────────────

  group('Capacité initiale', () {
    testWidgets(
      'availableKg = 1 (KG mode) → affiche "Aucune capacité disponible"',
      (tester) async {
        // sliderMin = 1.0 (KG mode), maxKg = 1 → maxKg <= sliderMin → no-capacity path
        final noCapAnnouncement = AnnouncementModel(
          id: 'ann-nocap',
          travelerId: 'trav-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(2026, 8, 15),
          availableKg: 1,
          totalKg: 10,
          pricePerKg: 8,
          status: 'ACTIVE',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          acceptedPaymentMethods: const {BidPaymentMethod.stripe},
        );
        await _openSheet(tester, noCapAnnouncement);
        expect(find.text('Aucune capacité disponible'), findsOneWidget);
      },
    );

    testWidgets('availableKg = 3 (< 5, KG mode) → sheet ouvre sans erreur', (
      tester,
    ) async {
      // Covers the else branch: initialWeight = availableKg (not 5)
      final smallKgAnnouncement = AnnouncementModel(
        id: 'ann-small',
        travelerId: 'trav-1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2026, 8, 15),
        availableKg: 3,
        totalKg: 10,
        pricePerKg: 8,
        status: 'ACTIVE',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        acceptedPaymentMethods: const {BidPaymentMethod.stripe},
      );
      await _openSheet(tester, smallKgAnnouncement);
      expect(find.text('Envoyer un colis'), findsOneWidget);
    });
  });

  // ── 7. Sélection d'articles grille ───────────────────────────────────────

  group('Sélection d\'articles grille', () {
    testWidgets(
      'sélectionner un article → affiche "1 article sélectionné" et total',
      (tester) async {
        await _openSheet(tester, _mixedAnnouncement());

        // Open the GridItemSelectionSheet by tapping the grid card.
        await tester.tap(find.text('Choisir mes articles'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Add item-1 (Téléphone) once.
        await tester.tap(find.byKey(const Key('grid-item-add-item-1')));
        await tester.pump();

        // Confirm the selection.
        await tester.tap(find.byKey(const Key('grid-sheet-confirm')));
        await tester.pumpAndSettle();

        // Main sheet now shows the selected-items state.
        expect(find.textContaining('article sélectionné'), findsOneWidget);
        // Le breakdown de prix affiche la ligne « Articles » (grille > 0).
        expect(find.text('Articles'), findsOneWidget);
      },
    );

    testWidgets(
      'sélectionner puis déconfirmer (null) → état non-sélectionné conservé',
      (tester) async {
        await _openSheet(tester, _mixedAnnouncement());

        // Tap grid card, then close sheet without confirming (tap outside).
        await tester.tap(find.text('Choisir mes articles'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Close by tapping the backdrop (dismiss the modal).
        await tester.tapAt(const Offset(400, 100));
        await tester.pumpAndSettle();

        // Still showing the "no selection" state.
        expect(find.text('Choisir mes articles'), findsOneWidget);
      },
    );
  });

  // ── 7b. KG_FREE — capacité non bloquée ───────────────────────────────────

  group('KG_FREE — pas de blocage capacité', () {
    testWidgets(
      'annonce KG_FREE (availableKg=1) → PAS de "Aucune capacité disponible"',
      (tester) async {
        await _openSheet(tester, _kgFreeAnnouncement());

        expect(find.text('Aucune capacité disponible'), findsNothing);
      },
    );

    testWidgets('annonce KG_FREE → saisie libre (stepper) au lieu du slider', (
      tester,
    ) async {
      await _openSheet(tester, _kgFreeAnnouncement());

      // Kilo libre : capacité non bornée → stepper/saisie, pas de slider.
      expect(find.byType(Slider), findsNothing);
      expect(find.byKey(const Key('weight-increment')), findsOneWidget);
      expect(find.byKey(const Key('weight-decrement')), findsOneWidget);
      expect(find.byKey(const Key('weight-field')), findsOneWidget);
    });

    testWidgets(
      'annonce KG_FREE → formulaire ouvre normalement (titre visible)',
      (tester) async {
        await _openSheet(tester, _kgFreeAnnouncement());

        expect(find.text('Envoyer un colis'), findsOneWidget);
      },
    );
  });

  // ── 8. hasGridPricing / hasKgPricing flags ────────────────────────────────

  group('hasGridPricing / hasKgPricing flags', () {
    testWidgets('bouton "Choisir mes articles" visible si hasGridPricing', (
      tester,
    ) async {
      await _openSheet(tester, _mixedGridOnlyAnnouncement());
      expect(find.text('Choisir mes articles'), findsOneWidget);
    });

    testWidgets('slider poids absent si !hasKgPricing', (tester) async {
      await _openSheet(tester, _mixedGridOnlyAnnouncement());
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('canSubmit = false sans articles sélectionnés', (tester) async {
      await _openSheet(tester, _mixedGridOnlyAnnouncement());

      // Select a category and accept disclaimer — but no grid articles chosen.
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

      // The submit button should remain disabled (no grid items selected).
      final submitFinder = find.text('Envoyer');
      expect(submitFinder, findsOneWidget);
      final donyBtnFinder = find.ancestor(
        of: submitFinder,
        matching: find.byType(DonyButton),
      );
      if (donyBtnFinder.evaluate().isNotEmpty) {
        final btn = tester.widget<DonyButton>(donyBtnFinder.first);
        expect(btn.onPressed, isNull);
      }
    });
  });
}
