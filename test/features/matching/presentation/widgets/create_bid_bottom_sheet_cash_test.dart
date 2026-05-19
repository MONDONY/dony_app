import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
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

// ── GetIt captures ─────────────────────────────────────────────────────────────
//
// CreateBidBottomSheet.show() calls getIt<BidBloc>() and getIt<PaymentBloc>().
// We register factories that return the _current_ mock (set in setUp) so each
// test controls its own bloc behavior.

late _MockBidBloc _currentBidBloc;
late _MockPaymentBloc _currentPaymentBloc;

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
      GoRoute(
        path: '/bids/:id',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Bid détail'))),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light,
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
Future<void> _enableSubmitButton(WidgetTester tester) async {
  await tester.tap(find.text('Vêtements'));
  await tester.pump();
  await tester.tap(find.byType(Checkbox).first);
  await tester.pump();
}

// Fills all mandatory text fields so _submit() passes validation.
Future<void> _fillMandatoryFields(WidgetTester tester) async {
  // TextField.at(0) = description, at(1) = valeur, at(2) = nom, at(3) = tel
  await tester.enterText(find.byType(TextField).at(0), 'Médicaments');
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(1), '100');
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(2), 'Amadou Diallo');
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(3), '+221 77 000 00 00');
  await tester.pump();
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(BidInitial());
    registerFallbackValue(const PaymentInitial());
    registerFallbackValue(BidCreateRequested(
      announcementId: '',
      weightKg: 0,
      declaredValueEur: 0,
      description: '',
      contentCategory: '',
      recipientName: '',
      recipientPhone: '',
    ));
    registerFallbackValue(BidCheckoutRequested(
      announcementId: '',
      weightKg: 0,
      declaredValueEur: 0,
      description: '',
      contentCategory: '',
      recipientName: '',
      recipientPhone: '',
    ));

    // Register GetIt factories that always return the current test-level mock.
    // The factory captures _current* by reference (Dart closure semantics), so
    // each test's setUp can swap the mock before the sheet is opened.
    if (!getIt.isRegistered<BidBloc>()) {
      getIt.registerFactory<BidBloc>(() => _currentBidBloc);
    }
    if (!getIt.isRegistered<PaymentBloc>()) {
      getIt.registerFactory<PaymentBloc>(() => _currentPaymentBloc);
    }
  });

  setUp(() {
    _currentBidBloc = _MockBidBloc();
    when(() => _currentBidBloc.state).thenReturn(BidInitial());
    when(() => _currentBidBloc.stream)
        .thenAnswer((_) => const Stream.empty());
    when(() => _currentBidBloc.close()).thenAnswer((_) async {});

    _currentPaymentBloc = _MockPaymentBloc();
    when(() => _currentPaymentBloc.state).thenReturn(const PaymentInitial());
    when(() => _currentPaymentBloc.stream)
        .thenAnswer((_) => const Stream.empty());
    when(() => _currentPaymentBloc.close()).thenAnswer((_) async {});
  });

  // ── 1. Visibilité du sélecteur ─────────────────────────────────────────────

  group('Visibilité du sélecteur de paiement', () {
    testWidgets('annonce Stripe-only → sélecteur non affiché', (tester) async {
      await _openSheet(tester, _announcement(cashEnabled: false));

      expect(find.text('MODE DE PAIEMENT'), findsNothing);
      expect(find.byKey(const Key('payment-method-cash')), findsNothing);
    });

    testWidgets('annonce CASH+STRIPE → sélecteur affiché avec 2 tuiles',
        (tester) async {
      await _openSheet(tester, _announcement(cashEnabled: true));

      expect(find.text('MODE DE PAIEMENT'), findsOneWidget);
      expect(find.byKey(const Key('payment-method-stripe')), findsOneWidget);
      expect(find.byKey(const Key('payment-method-cash')), findsOneWidget);
    });

    testWidgets('Stripe sélectionné par défaut → bouton affiche Bloquer',
        (tester) async {
      await _openSheet(tester, _announcement(cashEnabled: true));

      // Bouton sticky: "Bloquer X€ & envoyer" (mode Stripe par défaut).
      expect(find.textContaining('Bloquer'), findsWidgets);
      // Le bouton ne dit pas "Envoyer (paiement en espèces)".
      expect(
          find.text('Envoyer (paiement en espèces)'), findsNothing);
    });
  });

  // ── 2. Changement de mode ──────────────────────────────────────────────────

  group('Changement de mode de paiement', () {
    testWidgets('taper CASH → bouton libellé change en espèces',
        (tester) async {
      await _openSheet(tester, _announcement(cashEnabled: true));

      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pump();

      expect(find.text('Envoyer (paiement en espèces)'), findsOneWidget);
      expect(find.textContaining('Bloquer'), findsNothing);
    });

    testWidgets('taper STRIPE après CASH → libellé bouton revient à Bloquer',
        (tester) async {
      await _openSheet(tester, _announcement(cashEnabled: true));

      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('payment-method-stripe')));
      await tester.pump();

      expect(find.textContaining('Bloquer'), findsWidgets);
      expect(find.text('Envoyer (paiement en espèces)'), findsNothing);
    });
  });

  // ── 3. Soumission ──────────────────────────────────────────────────────────

  group('Soumission du formulaire', () {
    testWidgets(
        'mode CASH + formulaire complet → BidCreateRequested paymentMethod=cash',
        (tester) async {
      await _openSheet(tester, _announcement(cashEnabled: true));

      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pump();

      await _enableSubmitButton(tester);
      await _fillMandatoryFields(tester);

      await tester.tap(find.text('Envoyer (paiement en espèces)'));
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
          () => _currentBidBloc.add(any(that: isA<BidCheckoutRequested>())));
    });

    testWidgets(
        'mode STRIPE (défaut) + formulaire complet → BidCheckoutRequested dispatché',
        (tester) async {
      await _openSheet(tester, _announcement(cashEnabled: true));

      await _enableSubmitButton(tester);
      await _fillMandatoryFields(tester);

      // Tap the "Bloquer X€ & envoyer" button (first occurrence in the tree).
      await tester.tap(find.textContaining('Bloquer').first);
      await tester.pump();

      verify(
        () => _currentBidBloc.add(any(that: isA<BidCheckoutRequested>())),
      ).called(1);
      verifyNever(
          () => _currentBidBloc.add(any(that: isA<BidCreateRequested>())));
    });
  });

  // ── 4. Navigation sur BidCreated ──────────────────────────────────────────

  group('Navigation après BidCreated', () {
    testWidgets('BidCreated → sheet fermé et navigation vers /bids/{id}',
        (tester) async {
      final stateController = StreamController<BidState>.broadcast();
      addTearDown(stateController.close);

      when(() => _currentBidBloc.stream)
          .thenAnswer((_) => stateController.stream);

      await _openSheet(tester, _announcement(cashEnabled: true));

      // Sheet is open.
      expect(find.text('Envoyer un colis'), findsOneWidget);

      // Simulate successful bid creation.
      stateController.add(BidCreated(BidModel.skeleton('bid-xyz')));
      await tester.pump();
      await tester.pumpAndSettle();

      // Sheet dismissed, navigated to bid detail.
      expect(find.text('Bid détail'), findsOneWidget);
    });
  });
}
