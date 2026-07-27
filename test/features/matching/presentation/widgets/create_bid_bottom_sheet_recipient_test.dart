import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

/// Task 13 — wiring test for `RecipientSection` inside `CreateBidBottomSheet`
/// (`CreateBidScreen` defined in `create_bid_bottom_sheet.dart`).
///
/// The deep behaviour of `RecipientSection` itself (3-state picker, toggle
/// visibility, manual-entry save payload) is already covered by
/// `recipient_section_test.dart`. Here we only assert the WIRING.
///
/// Unlike the single-step hosts (`CreateBidScreen` in `screens/`,
/// `CompleteDetailsScreen`), this host is a *multi-step* form: when the
/// announcement offers alternative payment methods (cash/wave/orange money),
/// tapping "Envoyer" swaps the form step out for a payment-picker step via
/// `AnimatedSwitcher`, which disposes `RecipientSection` (and clears its
/// save hook) before `BidCreated`/`BidCheckoutReady` ever arrive. So the
/// save call is wired into `_goToPicker()` — right after validation passes,
/// while `RecipientSection` is still guaranteed mounted — instead of the
/// `BidCheckoutReady` BLoC listener branch used by the single-step hosts.
/// These tests specifically cover both the direct-Stripe path (no step
/// switch) and the alternative-payment-methods path (step switch) to prove
/// the save fires correctly in both.

// ── Mocks ────────────────────────────────────────────────────────────────────

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
// getIt<WalletBloc>(), getIt<BidPhotosCubit>() and RecipientSection calls
// getIt<RecipientBloc>(). We register factories that return the _current_
// mock (set in setUp) so each test controls its own bloc.

late _MockBidBloc _currentBidBloc;
late _MockPaymentBloc _currentPaymentBloc;
late _MockWalletBloc _currentWalletBloc;
late _MockBidPhotosCubit _currentPhotosCubit;
late _MockRecipientBloc _currentRecipientBloc;

// ── Fixtures ───────────────────────────────────────────────────────────────────

// Deliberately different from the country the phone prefix (+221) would
// resolve to (SN) — proves fallbackCountry comes from the announcement, not
// from `countryFromPhone`.
AnnouncementModel _announcement({bool cashEnabled = false}) {
  final methods = cashEnabled
      ? const {BidPaymentMethod.stripe, BidPaymentMethod.cash}
      : const {BidPaymentMethod.stripe};
  return AnnouncementModel(
    id: 'ann-1',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    arrivalCountryCode: 'CI',
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

// ── Harness ────────────────────────────────────────────────────────────────────

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
      // CreateBidBottomSheet.show() now delegates to context.push('/bids/new')
      // (post-06a9a2bc refactor: CreateBidScreen is a full GoRouter screen, no
      // longer a modal bottom sheet) — mirrors the real registration in
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

Future<void> _openSheet(
  WidgetTester tester,
  AnnouncementModel announcement,
) async {
  tester.view.physicalSize = _kSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildHarness(announcement));
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

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

// at(0) = input inline contenu (ignoré) ; at(1)=description, at(2)=valeur,
// at(3)=nom, at(4)=tel.
Future<void> _fillMandatoryFields(
  WidgetTester tester, {
  String phone = '+221771112233',
}) async {
  await tester.enterText(find.byType(TextField).at(1), 'Médicaments');
  await tester.pump();
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(2), 'Amadou Diallo');
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(3), phone);
  await tester.pump();
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(BidInitial());
    registerFallbackValue(const PaymentInitial());
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
    if (!getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.registerFactory<IContentCategoryRepository>(
        () => _FakeContentCategoryRepository(),
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
  });

  group('Rendu — RecipientSection', () {
    testWidgets(
      'affiche le bouton "Choisir un destinataire" et les 2 champs inchangés',
      (tester) async {
        await _openSheet(tester, _announcement());

        expect(find.text('Choisir un destinataire'), findsOneWidget);
        expect(find.text('Prénom et nom du destinataire'), findsOneWidget);
        expect(find.text('Téléphone du destinataire'), findsOneWidget);
      },
    );
  });

  group('Sauvegarde destinataire — mode direct (Stripe seul)', () {
    testWidgets('soumission valide → RecipientCreated dispatché avec '
        'fallbackCity/fallbackCountry de l\'annonce', (tester) async {
      await _openSheet(tester, _announcement(cashEnabled: false));

      await _enableSubmitButton(tester);
      await _fillMandatoryFields(tester);

      // Stripe-only announcement → no alternative payment methods → tapping
      // "Envoyer" goes straight through _goToPicker() → _confirmPayment()
      // without a step switch (sticky button still reads "Envoyer" here,
      // "Bloquer …" only appears once on the payment-picker step).
      await tester.tap(find.text('Envoyer'));
      await tester.pump();

      final createdEvents = verify(
        () => _currentRecipientBloc.add(captureAny()),
      ).captured.whereType<RecipientCreated>();
      expect(createdEvents, hasLength(1));
      expect(createdEvents.single.fullName, 'Amadou Diallo');
      expect(createdEvents.single.phoneE164, '+221771112233');
      // fallbackCity/fallbackCountry come from widget.announcement, not a
      // hardcoded value nor countryFromPhone (which would give 'SN' for
      // +221).
      expect(createdEvents.single.city, 'Dakar');
      expect(createdEvents.single.country, 'CI');

      // The existing submit flow still happens, unaffected.
      verify(
        () => _currentBidBloc.add(any(that: isA<BidCheckoutRequested>())),
      ).called(1);
    });
  });

  group('Sauvegarde destinataire — étape paiement (cash disponible)', () {
    testWidgets('annonce avec cash → soumission valide bascule vers le picker '
        'ET sauvegarde quand même le destinataire (widget déjà démonté)', (
      tester,
    ) async {
      await _openSheet(tester, _announcement(cashEnabled: true));

      await _enableSubmitButton(tester);
      await _fillMandatoryFields(tester);

      // Tapping "Envoyer" here switches the step to the payment picker
      // (AnimatedSwitcher unmounts RecipientSection) instead of dispatching
      // the bid directly.
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      // We are now on the payment-picker step.
      expect(find.text('Comment veux-tu payer ?'), findsOneWidget);

      // Despite RecipientSection being unmounted by now, the recipient was
      // already saved synchronously during _goToPicker(), before the step
      // switch.
      final createdEvents = verify(
        () => _currentRecipientBloc.add(captureAny()),
      ).captured.whereType<RecipientCreated>();
      expect(createdEvents, hasLength(1));
      expect(createdEvents.single.city, 'Dakar');
      expect(createdEvents.single.country, 'CI');

      // The BidBloc submission itself hasn't fired yet at this point (user
      // still needs to confirm a payment method on the picker step).
      verifyNever(
        () => _currentBidBloc.add(any(that: isA<BidCheckoutRequested>())),
      );
    });
  });

  group('Pas de sauvegarde sur échec de validation', () {
    testWidgets('nom destinataire vide → aucun dispatch RecipientCreated', (
      tester,
    ) async {
      await _openSheet(tester, _announcement());

      await _enableSubmitButton(tester);
      await tester.enterText(find.byType(TextField).at(1), 'Médicaments');
      await tester.pump();
      await tester.pump();
      // Nom et téléphone laissés vides.

      await tester.tap(find.text('Envoyer'));
      await tester.pump();

      expect(find.text('Nom du destinataire obligatoire'), findsOneWidget);
      verifyNever(
        () => _currentRecipientBloc.add(any(that: isA<RecipientCreated>())),
      );
    });

    testWidgets('BidError après soumission → pas de nouveau dispatch', (
      tester,
    ) async {
      final ctrl = StreamController<BidState>.broadcast();
      addTearDown(ctrl.close);
      when(() => _currentBidBloc.stream).thenAnswer((_) => ctrl.stream);

      await _openSheet(tester, _announcement());

      await _enableSubmitButton(tester);
      await _fillMandatoryFields(tester);
      await tester.tap(find.text('Envoyer'));
      await tester.pump();

      // Clear the interaction from the valid submission above so we can
      // assert no *additional* dispatch happens on error.
      clearInteractions(_currentRecipientBloc);

      ctrl.add(BidError(const NetworkException('Erreur réseau')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verifyNever(
        () => _currentRecipientBloc.add(any(that: isA<RecipientCreated>())),
      );
    });
  });
}
