// Réservation directe d'un trajet bateau (lot 3, tâche A4) : dimensions du
// colis, volume et prix au m³ avant paiement, total du serveur dès qu'il
// répond, refus local d'un colis trop grand, erreur 422 du back (réservation
// au m³ pas encore ouverte), texte « versé au dépôt », avion inchangé, boutons
// à 360 dp en français et en anglais.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/core/design/design_system.dart';
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
import 'package:dony/features/matching/data/models/bid_quote_response.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/reimbursement_info_banner.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/label_fit_expectations.dart';
import '../../../helpers/plane_icon_expectations.dart';
import 'widgets/trip_owner/trip_card_harness.dart' show loadAppFonts;

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

class _FakeRecipientEvent extends Fake implements RecipientEvent {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

// ── Trajets ───────────────────────────────────────────────────────────────────

/// Trajet bateau vendu au m³ : aucun kilo, volume restant [availableM3], prix
/// au m³ affiché à l'expéditeur (frais inclus) 600.
AnnouncementModel _boatM3({
  double availableM3 = 5,
  double? pricePerM3Display = 600,
  Set<BidPaymentMethod> methods = const {BidPaymentMethod.stripe},
}) => AnnouncementModel(
  id: 'boat-m3-1',
  travelerId: 'trav-1',
  departureCity: 'Marseille',
  arrivalCity: 'Abidjan',
  departureDate: DateTime(2026, 12, 20),
  availableKg: 0,
  totalKg: 0,
  transportMode: TransportMode.boat,
  volumeCapacityM3: 20,
  availableVolumeM3: availableM3,
  pricePerM3: 500,
  pricePerM3Display: pricePerM3Display,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 11),
  updatedAt: DateTime(2026, 11),
  acceptedPaymentMethods: methods,
);

AnnouncementModel _kgTrip(
  TransportMode mode, {
  Set<BidPaymentMethod> methods = const {BidPaymentMethod.stripe},
  String currency = 'EUR',
}) => AnnouncementModel(
  currency: currency,
  id: 'kg-${mode.name}-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 12, 20),
  availableKg: mode == TransportMode.plane ? 30 : 800,
  totalKg: mode == TransportMode.plane ? 30 : 1000,
  pricePerKg: 8,
  pricePerKgDisplay: 9,
  transportMode: mode,
  capacityUnit: mode == TransportMode.plane ? null : 'KG_FREE',
  status: 'ACTIVE',
  createdAt: DateTime(2026, 11),
  updatedAt: DateTime(2026, 11),
  acceptedPaymentMethods: methods,
);

const _bothMethods = {BidPaymentMethod.stripe, BidPaymentMethod.cash};

BidQuoteResponse _quote({double total = 118.5}) => BidQuoteResponse(
  netEur: total - 6,
  rate: 0.05,
  commissionEur: 6,
  totalEur: total,
  promoApplied: false,
  currency: 'EUR',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBidBloc bidBloc;
  late _MockPaymentBloc paymentBloc;
  late _MockWalletBloc walletBloc;
  late _MockBidPhotosCubit photosCubit;
  late _MockRecipientBloc recipientBloc;
  late StreamController<BidState> bidStream;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    registerFallbackValue(_FakeBidEvent());
    registerFallbackValue(_FakeRecipientEvent());
  });

  setUp(() {
    bidStream = StreamController<BidState>.broadcast();
    bidBloc = _MockBidBloc();
    paymentBloc = _MockPaymentBloc();
    walletBloc = _MockWalletBloc();
    photosCubit = _MockBidPhotosCubit();
    recipientBloc = _MockRecipientBloc();

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

    void register<T extends Object>(T mock) {
      if (getIt.isRegistered<T>()) getIt.unregister<T>();
      getIt.registerSingleton<T>(mock);
    }

    register<BidBloc>(bidBloc);
    register<PaymentBloc>(paymentBloc);
    register<WalletBloc>(walletBloc);
    register<BidPhotosCubit>(photosCubit);
    register<RecipientBloc>(recipientBloc);
    register<IContentCategoryRepository>(_FakeContentCategoryRepository());
  });

  tearDown(() async {
    resetTransportModesForTest();
    await bidStream.close();
    if (getIt.isRegistered<BidBloc>()) getIt.unregister<BidBloc>();
    if (getIt.isRegistered<PaymentBloc>()) getIt.unregister<PaymentBloc>();
    if (getIt.isRegistered<WalletBloc>()) getIt.unregister<WalletBloc>();
    if (getIt.isRegistered<BidPhotosCubit>()) {
      getIt.unregister<BidPhotosCubit>();
    }
    if (getIt.isRegistered<RecipientBloc>()) getIt.unregister<RecipientBloc>();
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
  });

  Widget testApp(AnnouncementModel announcement, Locale locale) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open'),
                onPressed: () =>
                    CreateBidBottomSheet.show(ctx, announcement: announcement),
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
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }

  Future<void> openSheet(
    WidgetTester tester,
    AnnouncementModel announcement, {
    Locale locale = AppL10n.fr,
    Size size = const Size(1000, 5000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(announcement, locale));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  Future<void> typeDimensions(
    WidgetTester tester, {
    String length = '100',
    String width = '50',
    String height = '40',
  }) async {
    await tester.enterText(
      find.byKey(const Key('bid-dimension-length')),
      length,
    );
    await tester.enterText(find.byKey(const Key('bid-dimension-width')), width);
    await tester.enterText(
      find.byKey(const Key('bid-dimension-height')),
      height,
    );
    await tester.pump();
  }

  /// Remplit contenu, description, destinataire et accord, hors dimensions et
  /// hors poids.
  Future<void> fillRest(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('bid-content-field')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('bid-content-item-Vêtements & tissus')),
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    final phone = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('bid-recipient-phone-field')),
        matching: find.byType(TextField),
      ),
    );
    final phoneIndex = fields.indexOf(phone);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('bid-description-field')),
        matching: find.byType(TextField),
      ),
      'Vêtements',
    );
    await tester.enterText(
      find.byType(TextField).at(phoneIndex - 1),
      'Awa Diop',
    );
    await tester.enterText(
      find.byType(TextField).at(phoneIndex),
      '+22507000000',
    );
    await tester.pump();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
  }

  DonyButton submit(WidgetTester tester) =>
      tester.widget<DonyButton>(find.byKey(const Key('bid-submit-btn')));

  List<T> sentEvents<T extends BidEvent>() =>
      verify(() => bidBloc.add(captureAny())).captured.whereType<T>().toList();

  group('trajet bateau au m³', () {
    testWidgets('boatCheckout_sendsDimensions', (tester) async {
      await openSheet(tester, _boatM3());
      // Ni curseur ni poids : le colis se mesure.
      expect(find.byType(Slider), findsNothing);
      expect(find.byKey(const Key('weight-field')), findsNothing);

      await typeDimensions(tester);
      await fillRest(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(submit(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pump();

      final events = [...sentEvents<BidCheckoutRequested>()];
      expect(events, hasLength(1));
      final checkout = events.single;
      expect(checkout.volume?.lengthCm, 100);
      expect(checkout.volume?.widthCm, 50);
      expect(checkout.volume?.heightCm, 40);
      expect(checkout.weightKg, 0);
    });

    testWidgets('le devis de fond part avec les dimensions', (tester) async {
      await openSheet(tester, _boatM3());
      await typeDimensions(tester);
      await tester.pump(const Duration(milliseconds: 500));

      final quotes = sentEvents<BidQuoteRequested>();
      expect(quotes, isNotEmpty);
      expect(quotes.last.volume?.lengthCm, 100);
      expect(quotes.last.weightKg, isNull);
      expect(quotes.last.backgroundKey, isNotNull);
    });

    testWidgets('volume et prix calculés avant paiement', (tester) async {
      await openSheet(tester, _boatM3());
      expect(find.byKey(const Key('bid-volume-preview')), findsNothing);
      expect(find.byKey(const Key('bid-total-amount')), findsNothing);

      await typeDimensions(tester);

      // 100 × 50 × 40 cm = 0,2 m³ ; 0,2 × 600 = 120 .
      expect(find.text('Volume : 0,20 m³'), findsOneWidget);
      expect(find.textContaining('0,20 m³ × 600'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('bid-total-amount'))).data,
        contains('120,00'),
      );
      expect(find.text('Volume restant sur ce trajet : 5 m³'), findsOneWidget);
    });

    testWidgets('prix arrondi à l\'unité mineure de la devise', (tester) async {
      // 30 × 30 × 30 = 27 000 cm³ = 0,027 m³ ; 0,027 × 600 = 16,2.
      await openSheet(tester, _boatM3());
      await typeDimensions(tester, length: '30', width: '30', height: '30');
      expect(find.text('Volume : 0,027 m³'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('bid-total-amount'))).data,
        contains('16,20'),
      );
    });

    testWidgets('boatCheckout_showsServerTotal', (tester) async {
      await openSheet(tester, _boatM3());
      await typeDimensions(tester);
      await tester.pump(const Duration(milliseconds: 500));
      Text total() =>
          tester.widget<Text>(find.byKey(const Key('bid-total-amount')));
      expect(total().data, contains('120,00'));

      final key = sentEvents<BidQuoteRequested>().last.backgroundKey;
      bidStream.add(BidQuoteLoaded(_quote(), backgroundKey: key));
      await tester.pumpAndSettle();

      // Le total du serveur remplace l'estimation locale.
      expect(total().data, contains('118,50'));
      expect(total().data, isNot(contains('120,00')));
    });

    testWidgets('M6 : devis du serveur différent du produit, la ligne garde '
        'son calcul sans montant contradictoire', (tester) async {
      await openSheet(tester, _boatM3());
      await typeDimensions(tester);
      await tester.pump(const Duration(milliseconds: 500));
      // Estimation locale : la ligne montre son montant (0,2 × 600).
      expect(
        tester
            .widget<Text>(find.byKey(const Key('bid-volume-line-amount')))
            .data,
        contains('120,00'),
      );

      final key = sentEvents<BidQuoteRequested>().last.backgroundKey;
      bidStream.add(BidQuoteLoaded(_quote(), backgroundKey: key));
      await tester.pumpAndSettle();

      // Total du serveur 118,50 ≠ 0,2 × 600 : la formule reste, sans montant.
      expect(find.byKey(const Key('bid-volume-line-amount')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('bid-volume-line-label')))
            .data,
        contains('0,20 m³ × 600'),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('bid-total-amount'))).data,
        contains('118,50'),
      );
      expect(find.textContaining('120,00'), findsNothing);
    });

    testWidgets('M6 : devis du serveur égal au produit, montant affiché', (
      tester,
    ) async {
      await openSheet(tester, _boatM3());
      await typeDimensions(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final key = sentEvents<BidQuoteRequested>().last.backgroundKey;
      bidStream.add(BidQuoteLoaded(_quote(total: 120), backgroundKey: key));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bid-volume-line-label')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('bid-volume-line-amount')))
            .data,
        contains('120,00'),
      );
    });

    testWidgets('M2 : un curseur déplacé ou un tap dans une dimension ne '
        'relance pas le devis et garde le total du serveur', (tester) async {
      final seen = <BidEvent>[];
      when(() => bidBloc.add(any())).thenAnswer((i) {
        seen.add(i.positionalArguments.first as BidEvent);
      });
      List<BidQuoteRequested> quotes() =>
          seen.whereType<BidQuoteRequested>().toList();

      await openSheet(tester, _boatM3());
      await typeDimensions(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final key = quotes().last.backgroundKey;
      bidStream.add(BidQuoteLoaded(_quote(), backgroundKey: key));
      await tester.pumpAndSettle();
      Text total() =>
          tester.widget<Text>(find.byKey(const Key('bid-total-amount')));
      expect(total().data, contains('118,50'));
      final quotesBefore = quotes().length;

      // Curseur déplacé : le contrôleur notifie, le texte ne change pas.
      final field = find.byKey(const Key('bid-dimension-length'));
      final controller = tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .controller;
      controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();
      // Tap dans un champ : focus, sans modification de texte.
      await tester.tap(find.byKey(const Key('bid-dimension-width')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(total().data, contains('118,50'));
      expect(quotes().length, quotesBefore);

      // Une vraie modification invalide le total du serveur et relance un devis.
      await typeDimensions(tester, height: '60');
      await tester.pump(const Duration(milliseconds: 500));
      expect(total().data, contains('180,00'));
      expect(quotes().length, greaterThan(quotesBefore));
    });

    testWidgets('un devis périmé (dimensions changées) est écarté', (
      tester,
    ) async {
      await openSheet(tester, _boatM3());
      await typeDimensions(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final staleKey = sentEvents<BidQuoteRequested>().last.backgroundKey;

      await typeDimensions(tester, height: '60');
      bidStream.add(BidQuoteLoaded(_quote(), backgroundKey: staleKey));
      await tester.pump();

      // 100 × 50 × 60 = 0,3 m³ ; 0,3 × 600 = 180 : estimation locale gardée.
      expect(
        tester.widget<Text>(find.byKey(const Key('bid-total-amount'))).data,
        contains('180,00'),
      );
    });

    testWidgets('boatCheckout_volumeTooLarge_localError', (tester) async {
      // 0,2 m³ demandé, 0,1 m³ restant.
      await openSheet(tester, _boatM3(availableM3: 0.1));
      await typeDimensions(tester);
      await fillRest(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('bid-volume-too-large')), findsOneWidget);
      expect(
        find.text(
          'Ce colis fait 0,20 m³ et il ne reste que 0,10 m³ sur ce trajet.',
        ),
        findsWidgets,
      );
      // Bouton grisé, aucun prix, aucun appel au serveur.
      expect(submit(tester).onPressed, isNull);
      expect(find.byKey(const Key('bid-total-amount')), findsNothing);
      verifyNever(() => bidBloc.add(any(that: isA<BidQuoteRequested>())));
      verifyNever(() => bidBloc.add(any(that: isA<BidCheckoutRequested>())));
    });

    testWidgets('un colis pile au volume restant passe', (tester) async {
      await openSheet(tester, _boatM3(availableM3: 0.2));
      await typeDimensions(tester);
      expect(find.byKey(const Key('bid-volume-too-large')), findsNothing);
      expect(find.byKey(const Key('bid-total-amount')), findsOneWidget);
    });

    testWidgets('dimensions manquantes : bouton grisé et explication', (
      tester,
    ) async {
      await openSheet(tester, _boatM3());
      await fillRest(tester);
      expect(submit(tester).onPressed, isNull);
      expect(
        find.text(
          'Indiquez les trois dimensions du colis pour calculer le prix.',
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('bid-dimension-length')),
        '100',
      );
      await tester.enterText(
        find.byKey(const Key('bid-dimension-width')),
        '50',
      );
      await tester.pump();
      expect(submit(tester).onPressed, isNull);

      // Hors bornes : refusé avec le message du champ.
      await tester.enterText(
        find.byKey(const Key('bid-dimension-height')),
        '401',
      );
      await tester.pump();
      expect(submit(tester).onPressed, isNull);
      expect(find.text('Entre 1 et 400 cm'), findsOneWidget);
    });

    testWidgets('refus 422 du back : message affiché, formulaire gardé', (
      tester,
    ) async {
      await openSheet(tester, _boatM3());
      await typeDimensions(tester);
      await fillRest(tester);

      bidStream.add(
        BidError(const ValidationException('raw', code: 'insufficient-volume')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Ce trajet n'a pas assez de volume restant"),
        findsWidgets,
      );
      // Le formulaire reste là, saisie comprise.
      expect(find.byKey(const Key('bid-dimension-length')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('bid-dimension-length')),
            )
            .controller
            ?.text,
        '100',
      );
    });

    testWidgets('aucune icône d\'avion', (tester) async {
      await openSheet(tester, _boatM3());
      await typeDimensions(tester);
      expectNoPlaneIcon(tester);
    });

    testWidgets('payé au dépôt : pas de bandeau « Yadony rembourse »', (
      tester,
    ) async {
      setTransportModes(
        const TransportModesAvailability(road: false, boat: true),
      );
      await openSheet(tester, _boatM3());
      expect(
        find.byType(ReimbursementInfoBanner, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('back qui ne sert que le net au m³ : le prix reste affiché '
        '(repli, comme la carte)', (tester) async {
      await openSheet(tester, _boatM3(pricePerM3Display: null));
      await typeDimensions(tester);
      // 0,2 m³ × 500 (net servi) : une ligne de prix, jamais rien.
      expect(find.textContaining('0,20 m³ × 500'), findsOneWidget);
    });
  });

  group('texte du paiement au dépôt', () {
    Future<void> goToPicker(WidgetTester tester) async {
      await fillRest(tester);
      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pumpAndSettle();
    }

    testWidgets('boatCheckout_depositWording', (tester) async {
      setTransportModes(
        const TransportModesAvailability(road: false, boat: true),
      );
      await openSheet(tester, _boatM3(methods: _bothMethods));
      await typeDimensions(tester);
      await goToPicker(tester);

      expect(
        find.text('Versé au transporteur au dépôt du colis'),
        findsOneWidget,
      );
      expect(find.text("Bloqué jusqu'à la livraison"), findsNothing);
      // Carte ouverte par défaut : explication adaptée et montant.
      expect(
        find.text(
          'Bloqué par Yadony dès maintenant, versé au transporteur quand vous déposez le colis.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('payment-panel-amount'))).data,
        contains('120'),
      );
      // Aucun remboursement automatique après le dépôt : le support tranche.
      expect(find.text("Remboursé si le colis n'arrive pas"), findsNothing);
      expect(
        find.text('Un litige se règle avec le support Yadony.'),
        findsOneWidget,
      );
      expectNoPlaneIcon(tester);
    });

    testWidgets('boatCheckout_depositWording_en', (tester) async {
      setTransportModes(
        const TransportModesAvailability(road: false, boat: true),
      );
      await openSheet(
        tester,
        _boatM3(methods: _bothMethods),
        locale: AppL10n.en,
      );
      await typeDimensions(tester);
      await goToPicker(tester);

      expect(
        find.text('Disputes are handled by Yadony support.'),
        findsOneWidget,
      );
      expect(find.text("Refunded if the parcel doesn't arrive"), findsNothing);
    });

    for (final mode in [TransportMode.boat, TransportMode.car]) {
      testWidgets('mobile money (${mode.name}) : corps du mode, litige ou '
          'remboursement selon le mode', (tester) async {
        setTransportModes(
          const TransportModesAvailability(road: true, boat: true),
        );
        await openSheet(
          tester,
          _kgTrip(
            mode,
            methods: {BidPaymentMethod.cash, BidPaymentMethod.mobileMoney},
            currency: 'XOF',
          ),
        );
        await tester.enterText(find.byKey(const Key('weight-field')), '40');
        await tester.pump();
        await fillRest(tester);
        await tester.tap(find.byKey(const Key('bid-submit-btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('payment-method-mobile-money')));
        await tester.pumpAndSettle();

        final deposit = mode == TransportMode.boat;
        expect(
          find.text(
            "Après l'accord du transporteur, vous recevez une demande de "
            'paiement sur votre téléphone. Le montant est versé au '
            'transporteur au dépôt du colis.',
          ),
          deposit ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(
            "Après l'accord du voyageur, vous recevez une demande de paiement "
            'sur votre téléphone. Le montant est bloqué par Yadony jusqu\'à '
            'la livraison.',
          ),
          deposit ? findsNothing : findsOneWidget,
        );
        expect(
          find.text("Remboursé si le colis n'arrive pas"),
          deposit ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Un litige se règle avec le support Yadony.'),
          deposit ? findsOneWidget : findsNothing,
        );
        expectNoPlaneIcon(tester);
      });
    }

    testWidgets('bateau éteint côté serveur : texte actuel', (tester) async {
      await openSheet(tester, _boatM3(methods: _bothMethods));
      await typeDimensions(tester);
      await goToPicker(tester);
      expect(find.text("Bloqué jusqu'à la livraison"), findsOneWidget);
      expect(
        find.text('Versé au transporteur au dépôt du colis'),
        findsNothing,
      );
      expect(find.text("Remboursé si le colis n'arrive pas"), findsOneWidget);
      expect(find.textContaining('support Yadony'), findsNothing);
    });

    testWidgets('trajet bateau au kilo : kilos envoyés, texte du dépôt', (
      tester,
    ) async {
      setTransportModes(
        const TransportModesAvailability(road: false, boat: true),
      );
      await openSheet(
        tester,
        _kgTrip(TransportMode.boat, methods: _bothMethods),
      );
      // Au kilo : pas de dimensions, un champ de poids (kilo libre).
      expect(find.byKey(const Key('bid-dimension-length')), findsNothing);
      await tester.enterText(find.byKey(const Key('weight-field')), '40');
      await tester.pump();
      await fillRest(tester);
      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pumpAndSettle();
      expect(
        find.text('Versé au transporteur au dépôt du colis'),
        findsOneWidget,
      );
      expectNoPlaneIcon(tester);
    });

    testWidgets('route : jamais le texte du dépôt, aucun avion', (
      tester,
    ) async {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: true),
      );
      await openSheet(
        tester,
        _kgTrip(TransportMode.car, methods: _bothMethods),
      );
      await tester.enterText(find.byKey(const Key('weight-field')), '40');
      await tester.pump();
      await fillRest(tester);
      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pumpAndSettle();
      expect(find.text("Bloqué jusqu'à la livraison"), findsOneWidget);
      expect(
        find.text('Versé au transporteur au dépôt du colis'),
        findsNothing,
      );
      expect(find.text("Remboursé si le colis n'arrive pas"), findsOneWidget);
      expect(find.textContaining('support Yadony'), findsNothing);
      expectNoPlaneIcon(tester);
    });
  });

  group('avion inchangé', () {
    testWidgets('planeCheckout_unchanged', (tester) async {
      setTransportModes(
        const TransportModesAvailability(road: true, boat: true),
      );
      await openSheet(
        tester,
        _kgTrip(TransportMode.plane, methods: _bothMethods),
      );

      // Poids, jamais de dimensions.
      expect(find.byKey(const Key('bid-dimension-length')), findsNothing);
      expect(find.byKey(const Key('bid-volume-preview')), findsNothing);
      expect(find.byType(Slider), findsOneWidget);
      tester.widget<Slider>(find.byType(Slider)).onChanged!(5);
      await tester.pump();
      await fillRest(tester);
      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pumpAndSettle();

      // Même texte qu'avant, même avec le bateau allumé.
      expect(find.text("Bloqué jusqu'à la livraison"), findsOneWidget);
      expect(find.text("Remboursé si le colis n'arrive pas"), findsOneWidget);
      expect(find.textContaining('support Yadony'), findsNothing);
      expect(
        find.text('Versé au transporteur au dépôt du colis'),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pump();
      final checkout = sentEvents<BidCheckoutRequested>().single;
      expect(checkout.weightKg, 5);
      expect(checkout.volume, isNull);
    });

    testWidgets('aucun devis ni volume envoyé en avion', (tester) async {
      await openSheet(tester, _kgTrip(TransportMode.plane));
      tester.widget<Slider>(find.byType(Slider)).onChanged!(5);
      await tester.pump(const Duration(milliseconds: 500));
      // Sans grille de commission, aucun devis de fond hors promo.
      verifyNever(() => bidBloc.add(any(that: isA<BidQuoteRequested>())));
    });
  });

  group('boutons sur une ligne à 360 dp', () {
    setUpAll(loadAppFonts);

    for (final locale in [AppL10n.fr, AppL10n.en]) {
      testWidgets(
        'trajet au m³, formulaire et paiement (${locale.languageCode})',
        (tester) async {
          setTransportModes(
            const TransportModesAvailability(road: false, boat: true),
          );
          await openSheet(
            tester,
            _boatM3(methods: _bothMethods),
            locale: locale,
            size: const Size(360, 5000),
          );
          await typeDimensions(tester);
          await fillRest(tester);
          expect(tester.takeException(), isNull);
          final formButton = tester.getSize(
            find.byKey(const Key('bid-submit-btn')),
          );
          expectButtonLabelNominal(
            tester,
            find.byKey(const Key('bid-submit-btn')),
            reason: 'formulaire',
          );

          await tester.tap(find.byKey(const Key('bid-submit-btn')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectButtonLabelNominal(
            tester,
            find.byKey(const Key('bid-submit-btn')),
            reason: 'carte',
          );
          expect(
            tester.getSize(find.byKey(const Key('bid-submit-btn'))).height,
            formButton.height,
          );

          await tester.tap(find.byKey(const Key('payment-method-cash')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectButtonLabelNominal(
            tester,
            find.byKey(const Key('bid-submit-btn')),
            reason: 'espèces',
          );
        },
      );
    }
  });
}
