import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_quote_response.dart';
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

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _MockBidPhotosCubit extends MockCubit<List<BidPhotoUpload>>
    implements BidPhotosCubit {}

class _MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

// ── Données de test ──────────────────────────────────────────────────────────

final _announcement = AnnouncementModel(
  id: 'ann-promo-test',
  travelerId: 'traveler-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 8, 1),
  departureTime: '10:00',
  arrivalTime: '22:00',
  pickupAddress:
      const AddressData(label: 'CDG', lat: 49.0097, lng: 2.5479),
  deliveryAddress:
      const AddressData(label: 'DSS', lat: 14.7397, lng: -17.4902),
  availableKg: 10.0,
  totalKg: 10.0,
  pricePerKg: 12.0,
  status: 'OPEN',
  bidsCount: 0,
  createdAt: DateTime(2026, 7, 1),
  updatedAt: DateTime(2026, 7, 1),
  acceptedPaymentMethods: {BidPaymentMethod.stripe},
);

const _promoQuote = BidQuoteResponse(
  netEur: 60.0,
  rate: 0.06,
  commissionEur: 3.60,
  totalEur: 63.60,
  promoApplied: true,
  promoLabel: 'Code WELCOME10 : 6 % de commission',
);

// ── Helpers ───────────────────────────────────────────────────────────────────

void main() {
  // Épingle le taux de commission : ces tests assertent des montants
  // calculés à 12 % (indépendants du défaut kDonyCommissionRateDefault).
  setUpAll(() => setDonyCommissionRate(0.12));
  tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBidBloc bidBloc;
  late _MockPaymentBloc paymentBloc;
  late _MockWalletBloc walletBloc;
  late _MockBidPhotosCubit photosCubit;
  late _MockRecipientBloc recipientBloc;
  late StreamController<BidState> bidStream;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(_FakeBidEvent());
  });

  setUp(() {
    bidStream = StreamController<BidState>.broadcast();
    bidBloc = _MockBidBloc();
    paymentBloc = _MockPaymentBloc();
    walletBloc = _MockWalletBloc();
    photosCubit = _MockBidPhotosCubit();
    recipientBloc = _MockRecipientBloc();

    whenListen(bidBloc, bidStream.stream, initialState: BidInitial());
    whenListen(paymentBloc, const Stream<PaymentState>.empty(),
        initialState: PaymentInitial());
    whenListen(walletBloc, const Stream<WalletState>.empty(),
        initialState: WalletInitial());
    whenListen(photosCubit, const Stream<List<BidPhotoUpload>>.empty(),
        initialState: const <BidPhotoUpload>[]);
    when(() => photosCubit.readyKeys).thenReturn(const <String>[]);
    whenListen(recipientBloc, const Stream<RecipientState>.empty(),
        initialState: const RecipientState());

    // Enregistrement dans getIt
    void _register<T extends Object>(T mock) {
      if (getIt.isRegistered<T>()) getIt.unregister<T>();
      getIt.registerSingleton<T>(mock);
    }

    _register<BidBloc>(bidBloc);
    _register<PaymentBloc>(paymentBloc);
    _register<WalletBloc>(walletBloc);
    _register<BidPhotosCubit>(photosCubit);
    _register<RecipientBloc>(recipientBloc);
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
    getIt.registerSingleton<IContentCategoryRepository>(
      _FakeContentCategoryRepository(),
    );
  });

  tearDown(() async {
    await bidStream.close();
    if (getIt.isRegistered<BidBloc>()) getIt.unregister<BidBloc>();
    if (getIt.isRegistered<PaymentBloc>()) getIt.unregister<PaymentBloc>();
    if (getIt.isRegistered<WalletBloc>()) getIt.unregister<WalletBloc>();
    if (getIt.isRegistered<BidPhotosCubit>()) getIt.unregister<BidPhotosCubit>();
    if (getIt.isRegistered<RecipientBloc>()) getIt.unregister<RecipientBloc>();
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
  });

  /// App de test avec GoRouter. Depuis le refactor 06a9a2bc (#126),
  /// CreateBidBottomSheet.show() délègue à context.push('/bids/new') vers
  /// l'écran plein CreateBidScreen — la route miroir de lib/app/router.dart
  /// est donc requise ici.
  Widget _testApp() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open'),
                onPressed: () =>
                    CreateBidBottomSheet.show(ctx, announcement: _announcement),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/bids/new',
          builder: (_, state) => CreateBidScreen(
            announcement: state.extra as AnnouncementModel,
          ),
        ),
        GoRoute(path: '/bids/:id', builder: (_, __) => const SizedBox()),
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

  Future<void> _openSheet(WidgetTester tester) async {
    // Grand viewport : tout le formulaire est visible sans scroll, ce qui
    // fiabilise les finders (le scroll reste possible via _scrollTo).
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_testApp());
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  /// Scroll jusqu'à ce que [finder] soit visible dans l'écran.
  Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 80,
        scrollable: find.byType(Scrollable).first);
  }

  // ── 1. Affichage initial du champ ─────────────────────────────────────────

  testWidgets('la section CODE PROMO est présente dans le sheet', (tester) async {
    await _openSheet(tester);
    await _scrollTo(tester, find.text('CODE PROMO (OPTIONNEL)'));
    expect(find.text('CODE PROMO (OPTIONNEL)'), findsOneWidget);
  });

  testWidgets('le champ promo a le placeholder attendu', (tester) async {
    await _openSheet(tester);
    await _scrollTo(tester, find.text('CODE PROMO (OPTIONNEL)'));
    expect(find.text('Ex: WELCOME10'), findsOneWidget);
  });

  testWidgets('le bouton Appliquer est présent', (tester) async {
    await _openSheet(tester);
    await _scrollTo(tester, find.text('CODE PROMO (OPTIONNEL)'));
    expect(find.widgetWithText(FilledButton, 'Appliquer'), findsOneWidget);
  });

  // ── 2. Dispatch de l'événement ───────────────────────────────────────────

  testWidgets('Appliquer dispatche BidQuoteRequested avec le code saisi',
      (tester) async {
    await _openSheet(tester);
    await _scrollTo(tester, find.text('CODE PROMO (OPTIONNEL)'));

    // Saisir un code promo
    final promoField = find.ancestor(
      of: find.text('Ex: WELCOME10'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(promoField, 'WELCOME10');
    await tester.pump();

    // Tapper Appliquer
    await tester.tap(find.widgetWithText(FilledButton, 'Appliquer'));
    await tester.pump();

    // Vérifier que l'événement a été envoyé au BLoC
    verify(() => bidBloc.add(any(
          that: predicate<BidEvent>(
            (e) =>
                e is BidQuoteRequested &&
                e.promoCode == 'WELCOME10' &&
                e.announcementId == 'ann-promo-test',
          ),
        ))).called(1);
  });

  // ── 3. Succès — code promo valide ────────────────────────────────────────

  testWidgets('code valide → label vert affiché', (tester) async {
    await _openSheet(tester);
    await _scrollTo(tester, find.text('CODE PROMO (OPTIONNEL)'));

    final promoField = find.ancestor(
      of: find.text('Ex: WELCOME10'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(promoField, 'WELCOME10');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Appliquer'));
    await tester.pump();

    // Le BLoC émet les états de succès
    bidStream.add(BidQuoteLoading());
    await tester.pump();
    bidStream.add(BidQuoteLoaded(_promoQuote));
    await tester.pumpAndSettle();

    // Le label de promo doit apparaître
    expect(
      find.text('Code WELCOME10 : 6 % de commission'),
      findsOneWidget,
    );
  });

  testWidgets('code valide → icône check verte visible', (tester) async {
    await _openSheet(tester);
    await _scrollTo(tester, find.text('CODE PROMO (OPTIONNEL)'));

    final promoField = find.ancestor(
      of: find.text('Ex: WELCOME10'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(promoField, 'PROMO5');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Appliquer'));
    await tester.pump();

    bidStream.add(BidQuoteLoaded(_promoQuote));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is DonyIcon && w.name == 'circle-check',
      ),
      findsOneWidget,
    );
  });

  // ── 4. Erreur — code promo invalide ──────────────────────────────────────

  testWidgets('code invalide → message d\'erreur rouge affiché', (tester) async {
    await _openSheet(tester);
    await _scrollTo(tester, find.text('CODE PROMO (OPTIONNEL)'));

    final promoField = find.ancestor(
      of: find.text('Ex: WELCOME10'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(promoField, 'BADCODE');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Appliquer'));
    await tester.pump();

    // Le BLoC émet une erreur promo
    bidStream.add(
      BidPromoError(const ServerException('Code promo invalide ou expiré')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Code promo invalide ou expiré'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is DonyIcon && w.name == 'circle-alert',
      ),
      findsOneWidget,
    );
  });

  // ── 5. Chargement ──────────────────────────────────────────────────────────

  testWidgets('indicateur de chargement affiché pendant BidQuoteLoading',
      (tester) async {
    await _openSheet(tester);
    await _scrollTo(tester, find.text('CODE PROMO (OPTIONNEL)'));

    final promoField = find.ancestor(
      of: find.text('Ex: WELCOME10'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(promoField, 'WELCOME10');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Appliquer'));
    await tester.pump();

    bidStream.add(BidQuoteLoading());
    await tester.pump();

    // CircularProgressIndicator dans le suffixIcon du champ
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ── 6. Changement de code ─────────────────────────────────────────────────

  testWidgets('un nouveau code remplace le label promo précédent',
      (tester) async {
    await _openSheet(tester);
    await _scrollTo(tester, find.text('CODE PROMO (OPTIONNEL)'));

    final promoField = find.ancestor(
      of: find.text('Ex: WELCOME10'),
      matching: find.byType(TextFormField),
    );

    // Premier code → succès
    await tester.enterText(promoField, 'FIRST10');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Appliquer'));
    await tester.pump();
    bidStream.add(BidQuoteLoaded(_promoQuote));
    await tester.pumpAndSettle();
    expect(find.text('Code WELCOME10 : 6 % de commission'), findsOneWidget);

    // Deuxième code → erreur (remplace le succès)
    await tester.enterText(promoField, 'INVALID');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Appliquer'));
    await tester.pump();
    bidStream.add(
      BidPromoError(const ServerException('Code expiré')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Code WELCOME10 : 6 % de commission'), findsNothing);
    expect(find.text('Code expiré'), findsOneWidget);
  });

  // ── 7. Total reflète la remise promo ─────────────────────────────────────

  testWidgets('promo appliqué → total remisé affiché (ancien barré + nouveau)',
      (tester) async {
    await _openSheet(tester);
    await _scrollTo(tester, find.text('CODE PROMO (OPTIONNEL)'));

    final promoField = find.ancestor(
      of: find.text('Ex: WELCOME10'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(promoField, 'WELCOME10');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Appliquer'));
    await tester.pump();

    // Devis serveur : net 60 € (5 kg × 12 €/kg), promo 6 % → total 63,60 €.
    bidStream.add(BidQuoteLoaded(const BidQuoteResponse(
      netEur: 60.0,
      kgNetEur: 60.0,
      gridNetEur: 0.0,
      rate: 0.06,
      commissionEur: 3.60,
      totalEur: 63.60,
      promoApplied: true,
      promoLabel: 'Code WELCOME10 : 6 % de commission',
    )));
    await tester.pumpAndSettle();

    final totalFinder = find.byKey(const Key('bid-total-amount'));
    await _scrollTo(tester, totalFinder);

    // Le total à payer affiché reflète la remise (63,60 €), pas le tarif plein.
    expect(tester.widget<Text>(totalFinder).data, contains('63,60'));
    // L'ancien total (67,20 € = 60 × 1,12) est affiché barré.
    expect(find.textContaining('67,20'), findsOneWidget);
  });

  // ── 8. Détail commission + réduction ─────────────────────────────────────

  testWidgets(
      'promo à taux réduit → ligne commission ET ligne réduction affichées',
      (tester) async {
    await _openSheet(tester);
    await _scrollTo(tester, find.text('CODE PROMO (OPTIONNEL)'));

    final promoField = find.ancestor(
      of: find.text('Ex: WELCOME10'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(promoField, 'WELCOME10');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Appliquer'));
    await tester.pump();

    // Rate global du fichier = 12 % ; promo → 6 % : économie réelle de 3,60 €
    // (60 € net × (0,12 − 0,06)), identique ici à la commission finale (60×0,06).
    bidStream.add(BidQuoteLoaded(const BidQuoteResponse(
      netEur: 60.0,
      kgNetEur: 60.0,
      rate: 0.06,
      commissionEur: 3.60,
      totalEur: 63.60,
      promoApplied: true,
      promoLabel: 'Code WELCOME10 : 6 % de commission',
    )));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Commission Yadony (6 %)'));
    expect(find.text('Commission Yadony (6 %)'), findsOneWidget);
    expect(find.text('Réduction code promo'), findsOneWidget);
    // Espace insécable entre le montant et le symbole (NumberFormat fr_FR) :
    // match partiel plutôt qu'une chaîne exacte fragile sur l'encodage.
    expect(find.textContaining('3,60'), findsWidgets);
  });

  testWidgets(
      'promo au même taux que le taux courant → aucune ligne de réduction '
      '(pas de fausse économie affichée)', (tester) async {
    await _openSheet(tester);
    await _scrollTo(tester, find.text('CODE PROMO (OPTIONNEL)'));

    final promoField = find.ancestor(
      of: find.text('Ex: WELCOME10'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(promoField, 'WELCOME05');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Appliquer'));
    await tester.pump();

    // Le taux promo (12 %, pinné par ce fichier) égale le taux courant sans
    // promo — c'est exactement le cas WELCOME05 en prod (5 % promo = 5 %
    // taux global depuis le passage 12 %→5 %).
    bidStream.add(BidQuoteLoaded(const BidQuoteResponse(
      netEur: 60.0,
      kgNetEur: 60.0,
      rate: 0.12,
      commissionEur: 7.20,
      totalEur: 67.20,
      promoApplied: true,
      promoLabel: 'Code WELCOME05 : 12 % de commission',
    )));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Commission Yadony (12 %)'));
    expect(find.text('Commission Yadony (12 %)'), findsOneWidget);
    expect(find.text('Réduction code promo'), findsNothing);
  });
}
