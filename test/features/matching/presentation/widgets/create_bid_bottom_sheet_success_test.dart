import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

/// Integration test of the LIVE bid-payment success flow.
///
/// `lib/app/router.dart` routes `/bids/new` to the `CreateBidScreen` class
/// exported by `widgets/create_bid_bottom_sheet.dart` (NOT the one in
/// `screens/create_bid_screen.dart`, which is unreferenced in lib/). This
/// test pumps that live widget class directly — bypassing
/// `CreateBidBottomSheet.show()` — and drives the real
/// `DonyPaymentSheet.show(...).onSuccess` callback end-to-end: real
/// `PaymentSheetBloc`, mocked Stripe gateway, PayPal path (the
/// `PlatformPayButton` wallet button crashes outside a real iOS/Android
/// target).

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

class _MockLocalAuthService extends Mock implements LocalAuthService {}

class _MockBox extends Mock implements Box {}

class _MockPaymentGateway extends Mock implements PaymentGateway {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

class _FakeRecipientEvent extends Fake implements RecipientEvent {}

/// [HiveService.userPrefs] normally opens a real Hive box — overridden here
/// so tests can inject a [Box] mock without touching the filesystem.
class _FakeHiveService extends HiveService {
  _FakeHiveService(this._box);
  final Box _box;

  @override
  Box get userPrefs => _box;
}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

// ── Fixtures ───────────────────────────────────────────────────────────────────

AnnouncementModel _announcement() => AnnouncementModel(
      id: 'ann-1',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 8, 15),
      availableKg: 10,
      totalKg: 10,
      pricePerKg: 8,
      status: 'ACTIVE',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

// ── Harness ────────────────────────────────────────────────────────────────────

/// `/create` hosts the live `CreateBidScreen` PUSHED onto the stack (not as
/// root) because its `onSuccess` starts with `context.pop()` — the
/// production behaviour when routed from `/bids/new`.
Widget _buildHarness(AnnouncementModel announcement) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => Scaffold(
          body: Builder(
            builder: (inner) => TextButton(
              onPressed: () => inner.push('/create'),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/create',
        builder: (_, state) => CreateBidScreen(announcement: announcement),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, state) => Scaffold(
          body: Center(child: Text('Bid détail ${state.uri.query}')),
        ),
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

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  late _MockBidBloc bidBloc;
  late _MockPaymentBloc paymentBloc;
  late _MockWalletBloc walletBloc;
  late _MockBidPhotosCubit photosCubit;
  late _MockRecipientBloc recipientBloc;
  late _MockLocalAuthService authService;
  late _MockBox userPrefsBox;
  late _MockPaymentGateway paymentGateway;
  late _MockPaymentRepository paymentRepository;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(BidInitial());
    registerFallbackValue(BidConfirmPaymentRequested(''));
    registerFallbackValue(const PaymentInitial());
    registerFallbackValue(_FakeRecipientEvent());
  });

  setUp(() {
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => bidBloc.close()).thenAnswer((_) async {});

    paymentBloc = _MockPaymentBloc();
    when(() => paymentBloc.state).thenReturn(const PaymentInitial());
    when(() => paymentBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => paymentBloc.close()).thenAnswer((_) async {});

    walletBloc = _MockWalletBloc();
    when(() => walletBloc.state).thenReturn(WalletInitial());
    when(() => walletBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => walletBloc.close()).thenAnswer((_) async {});

    photosCubit = _MockBidPhotosCubit();
    when(() => photosCubit.state).thenReturn(const <BidPhotoUpload>[]);
    when(() => photosCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => photosCubit.close()).thenAnswer((_) async {});
    when(() => photosCubit.readyKeys).thenReturn(const <String>[]);

    recipientBloc = _MockRecipientBloc();
    when(() => recipientBloc.state).thenReturn(const RecipientState());
    when(() => recipientBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => recipientBloc.close()).thenAnswer((_) async {});

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
    when(() => paymentGateway.confirmPayPal(any())).thenAnswer((_) async {});

    paymentRepository = _MockPaymentRepository();
    when(() => paymentRepository.listSavedPaymentMethods())
        .thenAnswer((_) async => []);

    void register<T extends Object>(T Function() factory) {
      if (getIt.isRegistered<T>()) {
        getIt.unregister<T>();
      }
      getIt.registerFactory<T>(factory);
    }

    register<BidBloc>(() => bidBloc);
    register<PaymentBloc>(() => paymentBloc);
    register<WalletBloc>(() => walletBloc);
    register<BidPhotosCubit>(() => photosCubit);
    register<RecipientBloc>(() => recipientBloc);
    register<IContentCategoryRepository>(_FakeContentCategoryRepository.new);
    register<LocalAuthService>(() => authService);
    register<HiveService>(() => _FakeHiveService(userPrefsBox));
    register<PaymentGateway>(() => paymentGateway);
    register<PaymentRepository>(() => paymentRepository);
  });

  tearDown(() {
    void unregister<T extends Object>() {
      if (getIt.isRegistered<T>()) {
        getIt.unregister<T>();
      }
    }

    unregister<BidBloc>();
    unregister<PaymentBloc>();
    unregister<WalletBloc>();
    unregister<BidPhotosCubit>();
    unregister<RecipientBloc>();
    unregister<IContentCategoryRepository>();
    unregister<LocalAuthService>();
    unregister<HiveService>();
    unregister<PaymentGateway>();
    unregister<PaymentRepository>();
  });

  testWidgets(
      'CheckoutPaymentSheetReady + paiement PayPal réussi → écran fermé, '
      'DonySuccessScreen, navigation seulement après le CTA', (tester) async {
    final paymentStates = StreamController<PaymentState>.broadcast();
    addTearDown(paymentStates.close);
    when(() => paymentBloc.stream).thenAnswer((_) => paymentStates.stream);

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildHarness(_announcement()));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    // Le vrai CreateBidScreen (widgets/) est affiché.
    expect(find.text('Envoyer un colis'), findsOneWidget);

    paymentStates.add(const CheckoutPaymentSheetReady(
      clientSecret: 'pi_test_secret',
      publishableKey: 'pk_test',
      bidId: 'bid-77',
      amountEur: 56.0,
      paymentMethodTypes: ['paypal'],
    ));
    await tester.pumpAndSettle();

    // La DonyPaymentSheet est ouverte (PayPal dispo, aucune carte
    // enregistrée) → on paie via le bouton PayPal.
    await tester.tap(find.byKey(const Key('paymentSheetPayPalButton')));
    await tester.pump(); // PaymentSheetProcessing
    await tester.pump(); // PaymentSheetSuccess (résolution async du gateway)
    await tester
        .pump(const Duration(milliseconds: 900)); // déclenchement onSuccess
    await tester.pumpAndSettle();

    // 1. Confirmation synchrone du paiement côté backend.
    verify(() => bidBloc.add(any(
            that: isA<BidConfirmPaymentRequested>()
                .having((e) => e.bidId, 'bidId', 'bid-77'))))
        .called(1);

    // 2. L'écran de création est fermé (pop) et DonySuccessScreen affiché —
    //    SANS navigation vers le détail du bid à ce stade.
    expect(find.text('Envoyer un colis'), findsNothing);
    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Offre payée !'), findsOneWidget);
    expect(find.textContaining('Bid détail'), findsNothing);

    // 3. La navigation vers /bids/{id}?from=payment n'arrive qu'au tap CTA.
    await tester.tap(find.text('Voir mon envoi'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bid détail'), findsOneWidget);
    expect(find.textContaining('from=payment'), findsOneWidget);
  });

  testWidgets(
      'paiement de bid (bottom sheet) confirmé utilise DonySuccessScreen '
      'avec la mascotte securise', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DonySuccessScreen(
        mascotteType: DonyMascotteType.securise,
        title: 'Offre payée !',
        subtitle: 'Le voyageur va être notifié de ta demande.',
        ctaLabel: 'Voir mon envoi',
        onCta: () {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Offre payée !'), findsOneWidget);
    expect(find.text('Voir mon envoi'), findsOneWidget);
  });
}
