import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
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

import '../../../helpers/commission_grid_test_doubles.dart';

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

class _MockNegotiationBloc
    extends MockBloc<BidNegotiationEvent, BidNegotiationState>
    implements BidNegotiationBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

// ── Données de test ──────────────────────────────────────────────────────────

/// Trajet en euros au kilo. Sous grille, le serveur sert le prix au kilo au
/// NET (`pricePerKgDisplay` = `pricePerKg`) : les frais de service s'ajoutent
/// au total, pas au kilo.
AnnouncementModel _announcement({
  double pricePerKg = 2.5,
  double? pricePerKgDisplay = 2.5,
  bool negotiable = false,
}) => AnnouncementModel(
  id: 'ann-grid-test',
  travelerId: 'traveler-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 11),
  departureTime: '10:00',
  arrivalTime: '22:00',
  pickupAddress: const AddressData(label: 'CDG', lat: 49.0097, lng: 2.5479),
  deliveryAddress: const AddressData(label: 'DSS', lat: 14.7397, lng: -17.4902),
  availableKg: 10.0,
  totalKg: 10.0,
  pricePerKg: pricePerKg,
  pricePerKgDisplay: pricePerKgDisplay,
  status: 'OPEN',
  bidsCount: 0,
  negotiable: negotiable,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
  acceptedPaymentMethods: {BidPaymentMethod.stripe},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBidBloc bidBloc;
  late _MockPaymentBloc paymentBloc;
  late _MockWalletBloc walletBloc;
  late _MockBidPhotosCubit photosCubit;
  late _MockRecipientBloc recipientBloc;
  late _MockNegotiationBloc negotiationBloc;
  late StreamController<BidState> bidStream;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(_FakeBidEvent());
    registerFallbackValue(const BidNegotiationFetchRequested('fallback'));
  });

  setUp(() {
    CommissionGridStore.reset();
    DonySnackbar.clearDedup();
    bidStream = StreamController<BidState>.broadcast();
    bidBloc = _MockBidBloc();
    paymentBloc = _MockPaymentBloc();
    walletBloc = _MockWalletBloc();
    photosCubit = _MockBidPhotosCubit();
    recipientBloc = _MockRecipientBloc();
    negotiationBloc = _MockNegotiationBloc();

    whenListen(bidBloc, bidStream.stream, initialState: BidInitial());
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
    when(
      () => photosCubit.readyKeys,
    ).thenReturn(const <String>['bids/photo-1.jpg']);
    whenListen(
      recipientBloc,
      const Stream<RecipientState>.empty(),
      initialState: const RecipientState(),
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

  tearDown(() async {
    await bidStream.close();
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

  Widget testApp(AnnouncementModel announcement, {bool negotiation = false}) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open'),
                onPressed: () => CreateBidBottomSheet.show(
                  ctx,
                  announcement: announcement,
                  negotiation: negotiation,
                ),
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
        GoRoute(path: '/bids/:id', builder: (_, _) => const SizedBox()),
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

  Future<void> openSheet(
    WidgetTester tester, {
    AnnouncementModel? announcement,
    bool negotiation = false,
  }) async {
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(announcement ?? _announcement(), negotiation: negotiation),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  Future<void> setWeight(WidgetTester tester, double kg) async {
    tester.widget<Slider>(find.byType(Slider)).onChanged!(kg);
    await tester.pumpAndSettle();
    // Laisse passer l'attente du devis automatique (sous grille), pour ne
    // laisser aucun minuteur en fin de test.
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Demandes de devis envoyées au BLoC depuis le dernier `verify`.
  List<BidQuoteRequested> capturedQuotes() => verify(
    () => bidBloc.add(captureAny(that: isA<BidQuoteRequested>())),
  ).captured.cast<BidQuoteRequested>();

  Future<void> applyPromo(WidgetTester tester, String code) async {
    final promoField = find.ancestor(
      of: find.text('Ex: WELCOME10'),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(promoField);
    await tester.enterText(promoField, code);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Appliquer'));
    await tester.pump();
  }

  String textOf(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data!;

  /// Chiffres et séparateurs seulement : `NumberFormat` fr pose une espace
  /// insécable avant « € », et le tag « (minimum) » suit une autre insécable.
  String squash(String s) => s.replaceAll(RegExp(r'\s'), ' ');

  const totalKey = Key('bid-total-amount');
  const feeKey = Key('bid-service-fee-amount');

  group('sous grille de commission', () {
    testWidgets(
      'sous grille, 2 kg : lignes 5,00 €, frais 1,00 € (minimum), total 6,00 €',
      (tester) async {
        useTestCommissionGrid();
        await openSheet(tester);
        await setWeight(tester, 2);

        // Ligne au net : 2 kg × 2,50 € = 5,00 €.
        expect(find.textContaining('2 kg × 2,50'), findsOneWidget);
        expect(find.textContaining('5,00'), findsWidgets);
        // 7 % de 5 € = 0,35 €, relevé au minimum EUR de la grille (1 €).
        expect(squash(textOf(tester, feeKey)), '1,00 €');
        expect(find.text('Frais de service'), findsOneWidget);
        expect(squash(textOf(tester, totalKey)), '6,00 €');
      },
    );

    testWidgets('sous grille, 8 kg à 2,50 € : frais 1,40 €, total 21,40 €', (
      tester,
    ) async {
      useTestCommissionGrid();
      await openSheet(tester);
      await setWeight(tester, 8);

      expect(find.textContaining('8 kg × 2,50'), findsOneWidget);
      expect(find.textContaining('20,00'), findsOneWidget);
      // 7 % de 20 € = 1,40 € : au-dessus du minimum, pas de tag.
      expect(squash(textOf(tester, feeKey)), '1,40 €');
      expect(squash(textOf(tester, totalKey)), '21,40 €');
    });

    testWidgets(
      'le devis serveur prime : totalEur 21,00 et minimumApplied affichent '
      '21,00 € et « (minimum) »',
      (tester) async {
        useTestCommissionGrid();
        await openSheet(tester);
        await setWeight(tester, 8);
        await applyPromo(tester, 'WELCOME10');

        bidStream.add(
          BidQuoteLoaded(
            const BidQuoteResponse(
              netEur: 20.0,
              kgNetEur: 20.0,
              rate: 0.05,
              commissionEur: 1.0,
              totalEur: 21.0,
              promoApplied: false,
              currency: 'EUR',
              minimumApplied: true,
              minimumAmount: 1.0,
              commissionGridId: kTestGridId,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(squash(textOf(tester, totalKey)), '21,00 €');
        expect(squash(textOf(tester, feeKey)), '1,00 €');
      },
    );

    testWidgets(
      'code promo appliqué : total du devis, prix barré net + frais avant code',
      (tester) async {
        useTestCommissionGrid();
        await openSheet(tester);
        await setWeight(tester, 8);
        await applyPromo(tester, 'WELCOME10');

        bidStream.add(
          BidQuoteLoaded(
            const BidQuoteResponse(
              netEur: 20.0,
              kgNetEur: 20.0,
              rate: 0.07,
              commissionEur: 1.40,
              totalEur: 21.10,
              promoApplied: true,
              promoLabel: 'Code WELCOME10',
              currency: 'EUR',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(squash(textOf(tester, totalKey)), '21,10 €');
        // Frais après code = total − net.
        expect(squash(textOf(tester, feeKey)), '1,10 €');
        final struck = tester.widget<Text>(
          find.byWidgetPredicate(
            (w) =>
                w is Text && w.style?.decoration == TextDecoration.lineThrough,
          ),
        );
        expect(squash(struck.data!), '21,40 €');
        // Pas de ligne de réduction : les lignes (net + frais) somment déjà
        // au total, une réduction en plus la compterait deux fois.
        expect(find.text('Réduction code promo'), findsNothing);
      },
    );

    testWidgets(
      'promo sans effet : message « Ce code ne change rien sur ce montant '
      '(frais minimum) », pas de prix barré',
      (tester) async {
        useTestCommissionGrid();
        await openSheet(tester);
        await setWeight(tester, 2);
        await applyPromo(tester, 'WELCOME10');

        bidStream.add(
          BidQuoteLoaded(
            const BidQuoteResponse(
              netEur: 5.0,
              kgNetEur: 5.0,
              rate: 0.07,
              commissionEur: 1.0,
              totalEur: 6.0,
              promoApplied: false,
              currency: 'EUR',
              minimumApplied: true,
              minimumAmount: 1.0,
              promoIneffectiveReason: 'COMMISSION_MINIMUM',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final message = find.text('Ce code ne change rien sur ce montant');
        expect(message, findsOneWidget);
        // Information, pas erreur : jamais la couleur d'erreur.
        final style = tester.widget<Text>(message).style;
        expect(style?.color, isNot(const Color(0xFFE53935)));
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text && w.style?.decoration == TextDecoration.lineThrough,
          ),
          findsNothing,
        );
        // Le code reste saisi : il partira avec l'offre.
        final field = tester.widget<TextFormField>(
          find.ancestor(
            of: find.text('WELCOME10'),
            matching: find.byType(TextFormField),
          ),
        );
        expect(field.controller?.text, 'WELCOME10');
        expect(squash(textOf(tester, totalKey)), '6,00 €');
      },
    );

    testWidgets(
      'mode négociation : la suggestion vaut net + frais de la grille',
      (tester) async {
        useTestCommissionGrid();
        await openSheet(
          tester,
          announcement: _announcement(negotiable: true),
          negotiation: true,
        );
        await setWeight(tester, 8);

        final proposal = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const Key('negotiation-proposal-field')),
            matching: find.byType(EditableText),
          ),
        );
        // 20,00 € net + 1,40 € de frais.
        expect(proposal.controller.text, '21.40');
        expect(
          squash(textOf(tester, const Key('negotiation-suggested-hint'))),
          contains('21,40 €'),
        );
      },
    );
  });

  group('devis exact et devis automatique sous grille', () {
    testWidgets('net au kilo exact : 8,5 kg × 1,15 € → 9,78 €, comme le back', (
      tester,
    ) async {
      useTestCommissionGrid();
      await openSheet(
        tester,
        announcement: _announcement(pricePerKg: 1.15, pricePerKgDisplay: 1.15),
      );
      await setWeight(tester, 8.5);

      // En double, 8.5 × 1.15 = 9.774999… : arrondi naïf à 9,77 €. Le back
      // calcule en décimal exact (9,775) puis HALF_UP : 9,78 €.
      expect(find.textContaining('9,78'), findsOneWidget);
      expect(find.textContaining('9,77'), findsNothing);
      // 7 % de 9,78 € < 1 € : minimum, total 10,78 €.
      expect(squash(textOf(tester, feeKey)), '1,00 €');
      expect(squash(textOf(tester, totalKey)), '10,78 €');
    });

    testWidgets(
      'devis sans code émis sous grille après changement de poids (debounce)',
      (tester) async {
        useTestCommissionGrid();
        await openSheet(tester);

        tester.widget<Slider>(find.byType(Slider)).onChanged!(8);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        verifyNever(() => bidBloc.add(any(that: isA<BidQuoteRequested>())));

        await tester.pump(const Duration(milliseconds: 200));
        final sent = capturedQuotes();
        expect(sent, hasLength(1));
        expect(sent.single.promoCode, isNull);
        expect(sent.single.weightKg, 8);
        expect(sent.single.announcementId, 'ann-grid-test');
        final key = sent.single.backgroundKey;
        expect(key, isNotNull);

        // Calcul local en attendant le devis.
        expect(squash(textOf(tester, totalKey)), '21,40 €');

        // Le devis porte le taux spécial de l'expéditeur, inconnu de l'app.
        bidStream.add(
          BidQuoteLoaded(
            const BidQuoteResponse(
              netEur: 20.0,
              kgNetEur: 20.0,
              rate: 0.04,
              commissionEur: 0.80,
              totalEur: 20.80,
              promoApplied: false,
              currency: 'EUR',
            ),
            backgroundKey: key,
          ),
        );
        await tester.pumpAndSettle();
        expect(squash(textOf(tester, totalKey)), '20,80 €');
        expect(squash(textOf(tester, feeKey)), '0,80 €');
      },
    );

    testWidgets(
      'code appliqué, changement de poids : devis de fond émis avec le code',
      (tester) async {
        useTestCommissionGrid();
        await openSheet(tester);
        await setWeight(tester, 8);
        await applyPromo(tester, 'WELCOME10');
        bidStream.add(
          BidQuoteLoaded(
            const BidQuoteResponse(
              netEur: 20.0,
              kgNetEur: 20.0,
              rate: 0.07,
              commissionEur: 1.40,
              totalEur: 21.10,
              promoApplied: true,
              promoLabel: 'Code WELCOME10',
            ),
          ),
        );
        await tester.pumpAndSettle();
        capturedQuotes();

        await setWeight(tester, 5);
        final sent = capturedQuotes();
        expect(sent, hasLength(1));
        expect(sent.single.promoCode, 'WELCOME10');
        expect(sent.single.weightKg, 5);
        final key = sent.single.backgroundKey;
        expect(key, isNotNull);

        // Le total affiché reste celui qui sera prélevé : code compris.
        bidStream.add(
          BidQuoteLoaded(
            const BidQuoteResponse(
              netEur: 12.5,
              kgNetEur: 12.5,
              rate: 0.07,
              commissionEur: 1.0,
              totalEur: 13.20,
              promoApplied: true,
              promoLabel: 'Code WELCOME10',
            ),
            backgroundKey: key,
          ),
        );
        await tester.pumpAndSettle();
        expect(squash(textOf(tester, totalKey)), '13,20 €');
      },
    );

    testWidgets(
      'code devenu invalide au devis de fond : message promo, devis sans code '
      'affiché, le suivant part sans code',
      (tester) async {
        useTestCommissionGrid();
        await openSheet(tester);
        await setWeight(tester, 8);
        await applyPromo(tester, 'WELCOME10');
        bidStream.add(
          BidQuoteLoaded(
            const BidQuoteResponse(
              netEur: 20.0,
              kgNetEur: 20.0,
              rate: 0.07,
              commissionEur: 1.40,
              totalEur: 21.10,
              promoApplied: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        capturedQuotes();

        await setWeight(tester, 5);
        final key = capturedQuotes().single.backgroundKey;
        bidStream.add(
          BidQuoteBackgroundPromoRejected(
            const ServerException('not found', 'promo-not-found'),
            key,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            "Ce code promo n'existe pas. Vérifiez la saisie et réessayez. "
            "Un code parrain se saisit à l'inscription ou dans Moi › "
            "« J'ai un code parrain ».",
          ),
          findsWidgets,
        );

        bidStream.add(
          BidQuoteLoaded(
            const BidQuoteResponse(
              netEur: 12.5,
              kgNetEur: 12.5,
              rate: 0.07,
              commissionEur: 1.0,
              totalEur: 13.50,
              promoApplied: false,
            ),
            backgroundKey: key,
          ),
        );
        await tester.pumpAndSettle();
        expect(squash(textOf(tester, totalKey)), '13,50 €');

        await setWeight(tester, 6);
        expect(capturedQuotes().single.promoCode, isNull);
      },
    );

    testWidgets(
      'code accepté, champ vidé sans « Appliquer », changement de poids : '
      'devis de fond sans code',
      (tester) async {
        useTestCommissionGrid();
        await openSheet(tester);
        await setWeight(tester, 8);
        await applyPromo(tester, 'WELCOME10');
        bidStream.add(
          BidQuoteLoaded(
            const BidQuoteResponse(
              netEur: 20.0,
              kgNetEur: 20.0,
              rate: 0.07,
              commissionEur: 1.40,
              totalEur: 21.10,
              promoApplied: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        capturedQuotes();

        // Le champ vidé : l'offre partirait sans code, le devis aussi.
        await tester.enterText(
          find.ancestor(
            of: find.text('WELCOME10'),
            matching: find.byType(TextFormField),
          ),
          '',
        );
        await tester.pump();
        await setWeight(tester, 5);
        final sent = capturedQuotes();
        expect(sent, hasLength(1));
        expect(sent.single.promoCode, isNull);
        expect(sent.single.backgroundKey, isNotNull);
      },
    );

    testWidgets(
      'code refusé : message promo gardé et devis de fond sans code affiché',
      (tester) async {
        useTestCommissionGrid();
        await openSheet(tester);
        await setWeight(tester, 8);
        capturedQuotes();
        await applyPromo(tester, 'PARRAIN42');
        capturedQuotes();

        bidStream.add(
          BidPromoError(const ServerException('not found', 'promo-not-found')),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));

        final sent = capturedQuotes();
        expect(sent, hasLength(1));
        expect(sent.single.promoCode, isNull);
        final key = sent.single.backgroundKey;
        expect(key, isNotNull);

        bidStream.add(
          BidQuoteLoaded(
            const BidQuoteResponse(
              netEur: 20.0,
              kgNetEur: 20.0,
              rate: 0.04,
              commissionEur: 0.80,
              totalEur: 20.80,
              promoApplied: false,
            ),
            backgroundKey: key,
          ),
        );
        await tester.pumpAndSettle();

        expect(squash(textOf(tester, totalKey)), '20,80 €');
        // Le message sous le champ reste visible.
        expect(
          find.text(
            "Ce code promo n'existe pas. Vérifiez la saisie et réessayez. "
            "Un code parrain se saisit à l'inscription ou dans Moi › "
            "« J'ai un code parrain ».",
          ),
          findsWidgets,
        );
      },
    );

    testWidgets('un devis automatique périmé est ignoré', (tester) async {
      useTestCommissionGrid();
      await openSheet(tester);
      await setWeight(tester, 8);
      final staleKey = capturedQuotes().single.backgroundKey;

      await setWeight(tester, 2);
      bidStream.add(
        BidQuoteLoaded(
          const BidQuoteResponse(
            netEur: 20.0,
            kgNetEur: 20.0,
            rate: 0.04,
            commissionEur: 0.80,
            totalEur: 20.80,
            promoApplied: false,
          ),
          backgroundKey: staleKey,
        ),
      );
      await tester.pumpAndSettle();

      // Le devis répondait pour 8 kg : on garde le calcul local de 2 kg.
      expect(squash(textOf(tester, totalKey)), '6,00 €');
    });

    testWidgets(
      'devis automatique en échec : calcul local gardé, aucun message',
      (tester) async {
        useTestCommissionGrid();
        await openSheet(tester);
        await setWeight(tester, 8);
        final key = capturedQuotes().single.backgroundKey;

        bidStream.add(BidQuoteBackgroundFailed(key));
        await tester.pumpAndSettle();

        expect(squash(textOf(tester, totalKey)), '21,40 €');
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  });

  group('sans grille de commission', () {
    setUpAll(() => setDonyCommissionRate(0.12));
    tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

    testWidgets(
      'sans grille : répartition au prorata inchangée, aucune ligne de frais',
      (tester) async {
        await openSheet(
          tester,
          announcement: _announcement(pricePerKg: 10, pricePerKgDisplay: null),
        );
        await setWeight(tester, 5);
        await tester.pump(const Duration(seconds: 1));
        // Sans grille, aucun devis automatique : seul le code promo en demande.
        verifyNever(() => bidBloc.add(any(that: isA<BidQuoteRequested>())));

        // Taux unique : 5 kg × 11,20 € (10 € + 12 %) = 56,00 €.
        expect(find.textContaining('5 kg × 11,20'), findsOneWidget);
        expect(squash(textOf(tester, totalKey)), '56,00 €');
        expect(find.byKey(feeKey), findsNothing);
        expect(find.text('Frais de service'), findsNothing);

        // Devis promo : la ligne poids prend tout le total (prorata).
        await applyPromo(tester, 'WELCOME10');
        bidStream.add(
          BidQuoteLoaded(
            const BidQuoteResponse(
              netEur: 50.0,
              kgNetEur: 50.0,
              rate: 0.12,
              commissionEur: 6.0,
              totalEur: 53.0,
              promoApplied: true,
              promoLabel: 'Code WELCOME10',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('5 kg × 10,60'), findsOneWidget);
        expect(squash(textOf(tester, totalKey)), '53,00 €');
        expect(find.text('Réduction code promo'), findsOneWidget);
        expect(find.byKey(feeKey), findsNothing);
      },
    );
  });
}
