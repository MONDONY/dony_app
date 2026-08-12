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

class _FakeRecipientEvent extends Fake implements RecipientEvent {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

// ── Données de test ──────────────────────────────────────────────────────────

AnnouncementModel _announcement({
  required String capacityUnit,
  double availableKg = 10.0,
}) =>
    AnnouncementModel(
      id: 'ann-weight-test',
      travelerId: 'traveler-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 8),
      availableKg: availableKg,
      totalKg: availableKg,
      pricePerKg: 12.0,
      capacityUnit: capacityUnit,
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
    whenListen(paymentBloc, const Stream<PaymentState>.empty(),
        initialState: const PaymentInitial());
    whenListen(walletBloc, const Stream<WalletState>.empty(),
        initialState: WalletInitial());
    whenListen(photosCubit, const Stream<List<BidPhotoUpload>>.empty(),
        initialState: const <BidPhotoUpload>[]);
    when(() => photosCubit.readyKeys).thenReturn(const <String>[]);
    whenListen(recipientBloc, const Stream<RecipientState>.empty(),
        initialState: const RecipientState());

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
    if (getIt.isRegistered<BidPhotosCubit>()) getIt.unregister<BidPhotosCubit>();
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
            announcement: state.extra! as AnnouncementModel,
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
    final field = tester.widget<TextField>(find.byKey(const Key('weight-field')));
    return field.controller?.text ?? '';
  }

  // ── 1. Trajet borné : conserve le slider (garde-fou de non-régression) ──────

  group('Trajet borné (SUITCASE)', () {
    testWidgets('affiche toujours un Slider', (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'SUITCASE_23KG'),
      );

      expect(find.byType(Slider), findsOneWidget);
      // Pas de steppers en mode borné.
      expect(find.byKey(const Key('weight-increment')), findsNothing);
      expect(find.byKey(const Key('weight-field')), findsNothing);
    });

    testWidgets('affiche le repère "max 10 kg"', (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'SUITCASE_23KG'),
      );

      expect(find.text('max 10 kg'), findsOneWidget);
    });

    testWidgets('le drag du slider ne crashe pas', (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'SUITCASE_23KG'),
      );

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

    testWidgets('poids initial = 5 (pas 1, malgré availableKg = 1)',
        (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      expect(displayedWeight(tester), '5');
    });

    testWidgets('le « + » dépasse 10 kg → aucun plafond 30/availableKg',
        (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      // Départ à 5, +1 répété → on franchit largement 10.
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byKey(const Key('weight-increment')));
        await tester.pump();
      }

      expect(int.parse(displayedWeight(tester)), greaterThan(10));
      expect(displayedWeight(tester), '13');
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

    testWidgets(
        'vider le champ puis saisir "99" → reste à 99 (pas de snap-back, '
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

    testWidgets(
        'champ vidé puis perte de focus → retombe au minimum (1 kg)',
        (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      // Champ vidé : reste vide tant que le focus est dans le champ.
      await tester.enterText(find.byKey(const Key('weight-field')), '');
      await tester.pump();
      expect(displayedWeight(tester), '');

      // Perte de focus → coercition au minimum.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(displayedWeight(tester), '1');
    });

    testWidgets(
        'le « + » incrémente de 1 et le prix parent (_weightNotifier) suit',
        (tester) async {
      await openSheet(
        tester,
        _announcement(capacityUnit: 'KG_FREE', availableKg: 1),
      );

      // Le récap de prix reflète le poids porté par le _weightNotifier parent
      // (pricePerKg = 12 → ligne « N kg × 12€ »). À l'ouverture : 5 kg.
      expect(displayedWeight(tester), '5');
      expect(find.textContaining('5 kg ×'), findsOneWidget);

      await tester.tap(find.byKey(const Key('weight-increment')));
      await tester.pump();

      // Affichage incrémenté de 1…
      expect(displayedWeight(tester), '6');
      // …et le parent (_weightNotifier) a bien reçu 6 → récap mis à jour.
      expect(find.textContaining('6 kg ×'), findsOneWidget);
      expect(find.textContaining('5 kg ×'), findsNothing);
    });

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
}
