import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
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
import 'package:dony/features/matching/data/models/transport_mode.dart';
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

import '../../../helpers/l10n_test_helpers.dart';

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

class _FakeRecipientEvent extends Fake implements RecipientEvent {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

// ── Données de test ──────────────────────────────────────────────────────────

AnnouncementModel _announcement({
  required String capacityUnit,
  double availableKg = 10.0,
  TransportMode? transportMode,
  double? maxParcelWeightKg,
}) => AnnouncementModel(
  id: 'ann-weight-test',
  travelerId: 'traveler-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 8),
  availableKg: availableKg,
  totalKg: availableKg,
  pricePerKg: 12.0,
  capacityUnit: capacityUnit,
  transportMode: transportMode,
  maxParcelWeightKg: maxParcelWeightKg,
  status: 'OPEN',
  bidsCount: 0,
  createdAt: DateTime(2026, 7),
  updatedAt: DateTime(2026, 7),
);

// ── Tests ────────────────────────────────────────────────────────────────────

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

  Widget testApp(AnnouncementModel announcement) {
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
        // CreateBidBottomSheet.show() délègue à context.push('/bids/new')
        // depuis le refactor 06a9a2bc (#126) : CreateBidScreen est un écran
        // GoRouter plein écran — miroir de lib/app/router.dart.
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
    WidgetTester tester,
    AnnouncementModel announcement,
  ) async {
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(announcement));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  /// Lit le poids affiché dans le gros chiffre du `_WeightSection` (kilo libre).
  String displayedWeight(WidgetTester tester) {
    final field = tester.widget<TextField>(
      find.byKey(const Key('weight-field')),
    );
    return field.controller?.text ?? '';
  }

  // ── 1. Trajet borné : conserve le slider (garde-fou de non-régression) ──────

  group('Trajet borné (SUITCASE)', () {
    testWidgets('affiche toujours un Slider', (tester) async {
      await openSheet(tester, _announcement(capacityUnit: 'SUITCASE_23KG'));

      expect(find.byType(Slider), findsOneWidget);
      // Pas de steppers en mode borné.
      expect(find.byKey(const Key('weight-increment')), findsNothing);
      expect(find.byKey(const Key('weight-field')), findsNothing);
    });

    testWidgets('affiche le repère "max 10 kg"', (tester) async {
      await openSheet(tester, _announcement(capacityUnit: 'SUITCASE_23KG'));

      expect(find.text('max 10 kg'), findsOneWidget);
    });

    testWidgets('le drag du slider ne crashe pas', (tester) async {
      await openSheet(tester, _announcement(capacityUnit: 'SUITCASE_23KG'));

      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pump();

      expect(find.byType(Slider), findsOneWidget);
    });
  });

  // ── 2. Kilo libre : stepper / saisie sans plafond ───────────────────────────

  group('Trajet kilo libre (KG_FREE)', () {
    testWidgets('aucun Slider rendu, steppers présents', (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      expect(find.byType(Slider), findsNothing);
      expect(find.byKey(const Key('weight-increment')), findsOneWidget);
      expect(find.byKey(const Key('weight-decrement')), findsOneWidget);
      expect(find.text('Kilo libre : choisissez votre poids'), findsOneWidget);
    });

    testWidgets('poids initial = 0 (obligatoire, jamais pré-rempli)', (
      tester,
    ) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      expect(displayedWeight(tester), '0');
    });

    testWidgets('le « + » dépasse 10 kg → aucun plafond 30/availableKg', (
      tester,
    ) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      // Départ à 0, +0,5 répété → on franchit largement 10.
      for (var i = 0; i < 24; i++) {
        await tester.tap(find.byKey(const Key('weight-increment')));
        await tester.pump();
      }

      expect(int.parse(displayedWeight(tester)), greaterThan(10));
      expect(displayedWeight(tester), '12');
    });

    testWidgets('saisie directe "42" → poids = 42', (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      await tester.enterText(find.byKey(const Key('weight-field')), '42');
      await tester.pump();

      expect(displayedWeight(tester), '42');
    });

    testWidgets('vider le champ puis saisir "99" → reste à 99 (pas de snap-back, '
        'pas de plafond)', (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      // Vider le champ d'abord : l'ancien comportement le rebasculait à « 1 »
      // immédiatement, empêchant de retaper un nombre multi-chiffres.
      await tester.enterText(find.byKey(const Key('weight-field')), '');
      await tester.pump();
      // Le champ reste vide pendant l'édition (pas de coercition à _min).
      expect(displayedWeight(tester), '');

      await tester.enterText(find.byKey(const Key('weight-field')), '99');
      await tester.pump();

      // 99 > availableKg(1) et > ancien plafond 30 → la valeur tient : pas de cap.
      expect(displayedWeight(tester), '99');
    });

    testWidgets('champ vidé puis perte de focus → retombe au minimum (0 kg)', (
      tester,
    ) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      // Amener le champ à une valeur non nulle d'abord, sinon vider un champ
      // déjà à "0" ne prouve rien sur la coercition.
      await tester.enterText(find.byKey(const Key('weight-field')), '7');
      await tester.pump();

      // Champ vidé : reste vide tant que le focus est dans le champ.
      await tester.enterText(find.byKey(const Key('weight-field')), '');
      await tester.pump();
      expect(displayedWeight(tester), '');

      // Perte de focus → coercition au minimum.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(displayedWeight(tester), '0');
    });

    testWidgets(
      'le « + » incrémente de 0,5 kg et le prix parent (_weightNotifier) suit',
      (tester) async {
        await openSheet(
          tester,
          _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
        );

        // À l'ouverture, poids = 0 → total local = 0 → le récap de prix ne
        // s'affiche pas du tout (cf. `if (total <= 0) return SizedBox.shrink()`).
        expect(displayedWeight(tester), '0');
        expect(find.textContaining('kg ×'), findsNothing);

        await tester.tap(find.byKey(const Key('weight-increment')));
        await tester.pump();

        // Affichage incrémenté d'un demi-kilo (FLUTTER-7Q)…
        expect(displayedWeight(tester), '0,5');
        // …et le parent (_weightNotifier) a bien reçu 0,5 → récap enfin
        // affiché (ligne « 0,5 kg × … »).
        expect(find.textContaining('0,5 kg ×'), findsOneWidget);
      },
    );

    testWidgets('le « − » se bloque au minimum (1 kg)', (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      await tester.enterText(find.byKey(const Key('weight-field')), '1');
      await tester.pump();

      // À 1, le bouton décrément est désactivé (onTap == null).
      await tester.tap(find.byKey(const Key('weight-decrement')));
      await tester.pump();

      expect(displayedWeight(tester), '1');
    });
  });

  // ── 3. Demi-kilo et aide au poids (Sentry FLUTTER-7Q) ───────────────────────
  // Un téléphone (environ 300 g) ne pouvait se déclarer qu'à 1 kg, et le
  // bouton restait grisé sans dire qu'il manquait le poids.

  group('Poids au demi-kilo', () {
    testWidgets('slider : un cran tous les 0,5 kg, valeur affichée « 0,5 »', (
      tester,
    ) async {
      await openSheet(tester, _announcement(capacityUnit: 'SUITCASE_23KG'));

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.divisions, 20);
      expect(slider.max, 10);

      slider.onChanged!(0.5000000001);
      await tester.pump();

      final value = tester.widget<Text>(find.byKey(const Key('weight-value')));
      expect(value.data, '0,5');
      expect(find.textContaining('0,5 kg ×'), findsOneWidget);
    });

    testWidgets('slider : capacité non multiple du pas → arrêt au demi-kilo '
        'inférieur', (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'SUITCASE_23KG', availableKg: 10.3),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.divisions, 20);
      expect(slider.max, 10);
    });

    testWidgets('kilo libre : saisie décimale à la virgule « 0,5 »', (
      tester,
    ) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      await tester.enterText(find.byKey(const Key('weight-field')), '0,5');
      await tester.pump();

      expect(displayedWeight(tester), '0,5');
      expect(find.textContaining('0,5 kg ×'), findsOneWidget);
    });

    testWidgets(
      'kilo libre : saisie au point « 1.5 » acceptée, reformatée à la '
      'perte de focus',
      (tester) async {
        await openSheet(
          tester,
          _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
        );

        await tester.enterText(find.byKey(const Key('weight-field')), '1.5');
        await tester.pump();
        expect(find.textContaining('1,5 kg ×'), findsOneWidget);

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(displayedWeight(tester), '1,5');
      },
    );

    testWidgets('kilo libre : lettres et second séparateur refusés', (
      tester,
    ) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      await tester.enterText(find.byKey(const Key('weight-field')), '2,5');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('weight-field')), '2,5,1');
      await tester.pump();
      expect(displayedWeight(tester), '2,5');

      await tester.enterText(find.byKey(const Key('weight-field')), 'abc');
      await tester.pump();
      expect(displayedWeight(tester), '2,5');
    });

    testWidgets('aide visible tant que le poids manque, retirée dès qu\'il est '
        'saisi', (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      expect(find.byKey(const Key('bid-submit-hint')), findsOneWidget);
      expect(
        find.text(
          'Indiquez le poids estimé, par ex. 0,5 kg pour un téléphone.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('weight-increment')));
      await tester.pump();

      expect(find.byKey(const Key('bid-submit-hint')), findsNothing);
    });
  });
  // ── 4. Poids max par colis et tonnes (lot « route ») ─────────────────────────
  // Le maximum de la feuille est le plus petit entre les kilos restants (ou
  // illimité en kilo libre) et le poids max par colis du trajet. Au-delà de
  // 50 kg sur un mode lourd (route, bateau), le curseur laisse la place à une
  // saisie numérique : 3 000 crans de 0,5 kg ne se règlent pas au doigt.

  group('Poids max par colis et tonnes', () {
    testWidgets('kilo libre, max 20 kg par colis : le repère « max 20 kg » '
        'est affiché', (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', maxParcelWeightKg: 20),
      );

      expect(find.byKey(const Key('weight-field')), findsOneWidget);
      expect(find.text('max 20 kg'), findsOneWidget);
    });

    testWidgets('kilo libre, max 20 kg par colis : « 42 » est ramené à 20', (
      tester,
    ) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', maxParcelWeightKg: 20),
      );

      await tester.enterText(find.byKey(const Key('weight-field')), '42');
      await tester.pump();

      expect(displayedWeight(tester), '20');
      expect(find.textContaining('20 kg ×'), findsOneWidget);
    });

    testWidgets('kilo libre, max 20 kg par colis : « 15 » reste 15', (
      tester,
    ) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', maxParcelWeightKg: 20),
      );

      await tester.enterText(find.byKey(const Key('weight-field')), '15');
      await tester.pump();

      expect(displayedWeight(tester), '15');
    });

    testWidgets('kilo libre, max 20 kg : le « + » s\'arrête à 20', (
      tester,
    ) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', maxParcelWeightKg: 20),
      );
      await tester.enterText(find.byKey(const Key('weight-field')), '20');
      await tester.pump();

      await tester.tap(find.byKey(const Key('weight-increment')));
      await tester.pump();

      expect(displayedWeight(tester), '20');
    });

    testWidgets('trajet route 1 500 kg restants : saisie numérique, pas de '
        'curseur, 1 200 kg acceptés', (tester) async {
      await openSheet(
        tester,
        _announcement(
          capacityUnit: 'KG',
          availableKg: 1500,
          transportMode: TransportMode.car,
        ),
      );

      expect(find.byType(Slider), findsNothing);
      expect(find.text('max 1\u202f500 kg'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('weight-field')), '1200');
      await tester.pump();

      expect(displayedWeight(tester), '1\u202f200');
      expect(find.textContaining('1\u202f200 kg ×'), findsOneWidget);
    });

    testWidgets('trajet route 1 500 kg restants : 1 600 est ramené à 1 500', (
      tester,
    ) async {
      await openSheet(
        tester,
        _announcement(
          capacityUnit: 'KG',
          availableKg: 1500,
          transportMode: TransportMode.car,
        ),
      );

      await tester.enterText(find.byKey(const Key('weight-field')), '1600');
      await tester.pump();

      expect(displayedWeight(tester), '1\u202f500');
    });

    testWidgets('route 1 500 kg restants, max 40 kg par colis : le plus petit '
        'gagne, curseur de 0 à 40', (tester) async {
      await openSheet(
        tester,
        _announcement(
          capacityUnit: 'KG',
          availableKg: 1500,
          transportMode: TransportMode.car,
          maxParcelWeightKg: 40,
        ),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.max, 40);
      expect(find.text('max 40 kg'), findsOneWidget);
    });

    testWidgets('route 8 kg restants, max 40 kg par colis : les kilos restants '
        'gagnent', (tester) async {
      await openSheet(
        tester,
        _announcement(
          capacityUnit: 'KG',
          availableKg: 8,
          transportMode: TransportMode.car,
          maxParcelWeightKg: 40,
        ),
      );

      expect(tester.widget<Slider>(find.byType(Slider)).max, 8);
    });

    testWidgets('trajet avion de 69 kg restants : curseur inchangé (jusqu\'à '
        '69)', (tester) async {
      await openSheet(
        tester,
        _announcement(
          capacityUnit: 'SUITCASE_23KG',
          availableKg: 69,
          transportMode: TransportMode.plane,
        ),
      );

      expect(tester.widget<Slider>(find.byType(Slider)).max, 69);
      expect(find.byKey(const Key('weight-field')), findsNothing);
    });

    testWidgets('trajet sans mode connu de 60 kg restants : curseur inchangé', (
      tester,
    ) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG', availableKg: 60),
      );

      expect(tester.widget<Slider>(find.byType(Slider)).max, 60);
    });

    testWidgets('kilo libre sans limite par colis : repère absent, '
        'comportement inchangé', (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      expect(find.textContaining('max '), findsNothing);
      await tester.enterText(find.byKey(const Key('weight-field')), '99');
      await tester.pump();
      expect(displayedWeight(tester), '99');
    });

    testWidgets('kilo libre sur la route : milliers groupés, 1 200 kg', (
      tester,
    ) async {
      await openSheet(
        tester,
        _announcement(
          capacityUnit: 'KG_FREE',
          availableKg: 1,
          transportMode: TransportMode.car,
        ),
      );

      await tester.enterText(find.byKey(const Key('weight-field')), '1200');
      await tester.pump();

      expect(displayedWeight(tester), '1\u202f200');
      expect(find.textContaining('1\u202f200 kg ×'), findsOneWidget);
    });
  });
  group('Bornage au pas des boutons', () {
    testWidgets('kilo libre, max 22,3 : « + » depuis 22 ne dépasse jamais '
        '22,3', (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', maxParcelWeightKg: 22.3),
      );
      await tester.enterText(find.byKey(const Key('weight-field')), '22');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('weight-increment')));
      await tester.pump();
      expect(displayedWeight(tester), '22,3');

      // Au maximum : « + » est désactivé, le poids ne bouge plus.
      await tester.tap(find.byKey(const Key('weight-increment')));
      await tester.pump();
      expect(displayedWeight(tester), '22,3');
    });

    testWidgets('kilo libre, max 22,3 : « − » depuis 22,3 revient au demi-kilo '
        'et jamais sous 0', (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', maxParcelWeightKg: 22.3),
      );
      await tester.enterText(find.byKey(const Key('weight-field')), '22,3');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('weight-decrement')));
      await tester.pump();
      expect(displayedWeight(tester), '22');

      await tester.enterText(find.byKey(const Key('weight-field')), '0,5');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('weight-decrement')));
      await tester.pump();
      expect(displayedWeight(tester), '0');
      // À 0, « − » est désactivé.
      await tester.tap(find.byKey(const Key('weight-decrement')));
      await tester.pump();
      expect(displayedWeight(tester), '0');
    });

    testWidgets('route 1 497,8 kg restants : « + » depuis 1 497 s\'arrête à '
        '1 497,8', (tester) async {
      await openSheet(
        tester,
        _announcement(
          capacityUnit: 'KG',
          availableKg: 1497.8,
          transportMode: TransportMode.car,
        ),
      );
      await tester.enterText(find.byKey(const Key('weight-field')), '1497');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('weight-increment')));
      await tester.pump();
      expect(displayedWeight(tester), '1\u202f497,5');

      // Le pas suivant (1 498) dépasserait : le poids prend la borne exacte.
      await tester.tap(find.byKey(const Key('weight-increment')));
      await tester.pump();
      expect(displayedWeight(tester), '1\u202f497,8');
    });
  });

  group('Repères du curseur', () {
    testWidgets('avion, 10,7 kg restants : le repère annonce le dernier '
        'cran (10,5), pas 11', (tester) async {
      await openSheet(
        tester,
        _announcement(
          capacityUnit: 'SUITCASE_23KG',
          availableKg: 10.7,
          transportMode: TransportMode.plane,
        ),
      );

      expect(tester.widget<Slider>(find.byType(Slider)).max, 10.5);
      expect(find.text('max 10,5 kg'), findsOneWidget);
      expect(find.text('10,5 kg'), findsOneWidget);
      expect(find.text('max 11 kg'), findsNothing);
    });

    testWidgets('avion, capacité entière : repères inchangés', (tester) async {
      await openSheet(
        tester,
        _announcement(
          capacityUnit: 'SUITCASE_23KG',
          availableKg: 23,
          transportMode: TransportMode.plane,
        ),
      );

      expect(find.text('max 23 kg'), findsOneWidget);
      expect(find.text('23 kg'), findsOneWidget);
      expect(find.text('0 kg'), findsOneWidget);
    });
  });

  group('Saisie lourde en anglais', () {
    testWidgets('« 1200 » : le champ écrit 1,200 comme le récap', (
      tester,
    ) async {
      useEnglish();
      await openSheet(
        tester,
        _announcement(
          capacityUnit: 'KG_FREE',
          availableKg: 1,
          transportMode: TransportMode.car,
        ),
      );

      await tester.enterText(find.byKey(const Key('weight-field')), '1200');
      await tester.pump();

      expect(displayedWeight(tester), '1,200');
      expect(find.textContaining('1,200 kg ×'), findsOneWidget);
    });

    testWidgets('ajouter un chiffre à « 1,200 » donne 12,000 (pas 1,20)', (
      tester,
    ) async {
      useEnglish();
      await openSheet(
        tester,
        _announcement(
          capacityUnit: 'KG_FREE',
          availableKg: 1,
          transportMode: TransportMode.car,
        ),
      );
      await tester.enterText(find.byKey(const Key('weight-field')), '1200');
      await tester.pump();

      await tester.enterText(find.byKey(const Key('weight-field')), '1,2000');
      await tester.pump();

      expect(displayedWeight(tester), '12,000');
      expect(find.textContaining('12,000 kg ×'), findsOneWidget);
    });

    testWidgets('« 1,200.5 » : point décimal, relu à l\'identique au blur', (
      tester,
    ) async {
      useEnglish();
      await openSheet(
        tester,
        _announcement(
          capacityUnit: 'KG_FREE',
          availableKg: 1,
          transportMode: TransportMode.car,
        ),
      );

      await tester.enterText(find.byKey(const Key('weight-field')), '1,200.5');
      await tester.pump();
      expect(find.textContaining('1,200.5 kg ×'), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(displayedWeight(tester), '1,200.5');
      expect(find.textContaining('1,200.5 kg ×'), findsOneWidget);
    });

    testWidgets('route 1 500 kg restants, anglais : repère « max 1,500 kg »', (
      tester,
    ) async {
      useEnglish();
      await openSheet(
        tester,
        _announcement(
          capacityUnit: 'KG',
          availableKg: 1500,
          transportMode: TransportMode.car,
        ),
      );

      expect(find.text('max 1,500 kg'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('weight-field')), '1600');
      await tester.pump();
      expect(displayedWeight(tester), '1,500');
    });
  });
}
