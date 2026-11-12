import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
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
import 'package:dony/features/matching/data/models/item_size.dart';
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

import '../../../../helpers/l10n_test_helpers.dart';

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

late _MockBidBloc _bidBloc;
late _MockPaymentBloc _paymentBloc;
late _MockWalletBloc _walletBloc;
late _MockBidPhotosCubit _photosCubit;
late _MockRecipientBloc _recipientBloc;

// ── Fixtures ───────────────────────────────────────────────────────────────────

/// Trajet en route à tarif au kilo. [cash] ajoute les espèces : le formulaire
/// passe alors par l'étape « Comment veux-tu payer ? ».
AnnouncementModel _trip({
  ItemSize? maxItemSize,
  double? maxParcelWeightKg,
  double availableKg = 1500,
  String? capacityUnit,
  TransportMode? mode = TransportMode.car,
  bool cash = false,
}) => AnnouncementModel(
  id: 'ann-road',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 8, 15),
  availableKg: availableKg,
  totalKg: availableKg,
  pricePerKg: 2,
  status: 'ACTIVE',
  capacityUnit: capacityUnit ?? 'KG',
  transportMode: mode,
  maxItemSize: maxItemSize,
  maxParcelWeightKg: maxParcelWeightKg,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  acceptedPaymentMethods: cash
      ? const {BidPaymentMethod.stripe, BidPaymentMethod.cash}
      : const {BidPaymentMethod.stripe},
);

// ── Harness ────────────────────────────────────────────────────────────────────

Widget _harness(AnnouncementModel announcement, {Locale locale = _fr}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => Scaffold(
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
        path: '/bids/new',
        builder: (_, state) => CreateBidScreen(
          announcement: (state.extra! as CreateBidArgs).announcement,
          negotiation: (state.extra! as CreateBidArgs).negotiation,
        ),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, _) => const Scaffold(body: Text('Bid détail')),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    locale: locale,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
  );
}

const _fr = Locale('fr', 'FR');

Future<void> _open(
  WidgetTester tester,
  AnnouncementModel announcement, {
  Size size = const Size(800, 5000),
  Locale locale = _fr,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_harness(announcement, locale: locale));
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

/// Remplit tout ce qui est obligatoire (poids, contenu, coordonnées, accord)
/// sans toucher à la taille du colis. Le champ de poids numérique, quand il
/// existe, décale d'un cran l'ordre des champs de texte.
Future<void> _fill(WidgetTester tester, {String? weightText}) async {
  final weightField = find.byKey(const Key('weight-field'));
  final slider = find.byType(Slider);
  if (weightField.evaluate().isNotEmpty) {
    await tester.enterText(weightField, weightText ?? '5');
    await tester.pump();
  } else if (slider.evaluate().isNotEmpty) {
    tester.widget<Slider>(slider).onChanged!(5);
    await tester.pump();
  }
  final shift = weightField.evaluate().isNotEmpty ? 1 : 0;
  await tester.tap(find.byKey(const Key('bid-content-field')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const Key('bid-content-item-Vêtements & tissus')),
  );
  await tester.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(1 + shift), 'Cartons');
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(2 + shift), 'Amadou Diallo');
  await tester.pump();
  await tester.enterText(
    find.byType(TextField).at(3 + shift),
    '+221 77 000 00 00',
  );
  await tester.pump();
  await tester.tap(find.byType(Checkbox).first);
  await tester.pump();
}

BidCheckoutRequested _lastCheckout() =>
    verify(
          () => _bidBloc.add(captureAny(that: isA<BidCheckoutRequested>())),
        ).captured.single
        as BidCheckoutRequested;

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
    getIt
      ..registerFactory<BidBloc>(() => _bidBloc)
      ..registerFactory<PaymentBloc>(() => _paymentBloc)
      ..registerFactory<WalletBloc>(() => _walletBloc)
      ..registerFactory<BidPhotosCubit>(() => _photosCubit)
      ..registerFactory<RecipientBloc>(() => _recipientBloc)
      ..registerFactory<IContentCategoryRepository>(
        _FakeContentCategoryRepository.new,
      );
  });

  tearDownAll(() async {
    await getIt.reset();
  });

  setUp(() {
    _bidBloc = _MockBidBloc();
    when(() => _bidBloc.state).thenReturn(BidInitial());
    when(() => _bidBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => _bidBloc.close()).thenAnswer((_) async {});

    _paymentBloc = _MockPaymentBloc();
    when(() => _paymentBloc.state).thenReturn(const PaymentInitial());
    when(() => _paymentBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => _paymentBloc.close()).thenAnswer((_) async {});

    _walletBloc = _MockWalletBloc();
    when(() => _walletBloc.state).thenReturn(WalletInitial());
    when(() => _walletBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => _walletBloc.close()).thenAnswer((_) async {});

    _photosCubit = _MockBidPhotosCubit();
    when(() => _photosCubit.state).thenReturn(const <BidPhotoUpload>[]);
    when(() => _photosCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => _photosCubit.close()).thenAnswer((_) async {});
    when(
      () => _photosCubit.readyKeys,
    ).thenReturn(const <String>['bids/photo-1.jpg']);

    _recipientBloc = _MockRecipientBloc();
    when(() => _recipientBloc.state).thenReturn(const RecipientState());
    when(() => _recipientBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => _recipientBloc.close()).thenAnswer((_) async {});
    when(() => _recipientBloc.add(any())).thenReturn(null);
  });

  group('Taille du colis sur un trajet qui porte une taille max', () {
    testWidgets('taille max M : S et M proposées, pas L ni XL', (tester) async {
      await _open(tester, _trip(maxItemSize: ItemSize.m, availableKg: 30));

      expect(find.text('Taille du colis (facultatif)'), findsOneWidget);
      expect(find.byKey(const Key('item-size-S')), findsOneWidget);
      expect(find.byKey(const Key('item-size-M')), findsOneWidget);
      expect(find.byKey(const Key('item-size-L')), findsNothing);
      expect(find.byKey(const Key('item-size-XL')), findsNothing);
    });

    testWidgets('taille max XL : les quatre tailles sont proposées', (
      tester,
    ) async {
      await _open(tester, _trip(maxItemSize: ItemSize.xl, availableKg: 30));

      for (final code in const ['S', 'M', 'L', 'XL']) {
        expect(find.byKey(Key('item-size-$code')), findsOneWidget);
      }
    });

    testWidgets('la validation reste active sans taille (C24) et rien ne '
        'part sur itemSize', (tester) async {
      await _open(tester, _trip(maxItemSize: ItemSize.m, availableKg: 30));
      await _fill(tester);

      final button = tester.widget<DonyButton>(
        find.byKey(const Key('bid-submit-btn')),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pump();

      expect(_lastCheckout().itemSize, isNull);
    });

    testWidgets('taille M choisie : le colis part avec itemSize M', (
      tester,
    ) async {
      await _open(tester, _trip(maxItemSize: ItemSize.l, availableKg: 30));
      await _fill(tester);
      await tester.tap(find.byKey(const Key('item-size-M')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pump();

      expect(_lastCheckout().itemSize, ItemSize.m);
    });

    testWidgets('un second tap sur la taille choisie la retire', (
      tester,
    ) async {
      await _open(tester, _trip(maxItemSize: ItemSize.l, availableKg: 30));
      await _fill(tester);
      await tester.tap(find.byKey(const Key('item-size-M')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('item-size-M')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pump();

      expect(_lastCheckout().itemSize, isNull);
    });

    testWidgets('espèces : BidCreateRequested porte la taille choisie', (
      tester,
    ) async {
      await _open(
        tester,
        _trip(maxItemSize: ItemSize.l, availableKg: 30, cash: true),
      );
      await _fill(tester);
      await tester.tap(find.byKey(const Key('item-size-L')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pump();

      final sent =
          verify(
                () => _bidBloc.add(captureAny(that: isA<BidCreateRequested>())),
              ).captured.single
              as BidCreateRequested;
      expect(sent.itemSize, ItemSize.l);
      expect(sent.paymentMethod, BidPaymentMethod.cash);
    });
  });

  group('Trajet sans taille max', () {
    testWidgets('pas de bloc taille, payload sans itemSize', (tester) async {
      await _open(tester, _trip(availableKg: 30));
      await _fill(tester);

      expect(find.text('Taille du colis (facultatif)'), findsNothing);
      expect(find.byKey(const Key('bid-item-size-block')), findsNothing);

      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pump();

      expect(_lastCheckout().itemSize, isNull);
    });

    testWidgets('trajet avion sans limites : aucun bloc taille', (
      tester,
    ) async {
      await _open(tester, _trip(mode: TransportMode.plane, availableKg: 20));

      expect(find.byKey(const Key('bid-item-size-block')), findsNothing);
      expect(find.byType(Slider), findsOneWidget);
    });
  });

  group('Poids en tonnes', () {
    testWidgets('route 1 500 kg restants : 1 200 kg partent tels quels', (
      tester,
    ) async {
      await _open(tester, _trip());
      await _fill(tester, weightText: '1200');

      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pump();

      expect(_lastCheckout().weightKg, 1200);
    });

    testWidgets('kilo libre, max 20 kg par colis : 18 kg partent, le poids '
        'est borné à 20', (tester) async {
      await _open(
        tester,
        _trip(
          capacityUnit: 'KG_FREE',
          availableKg: 1,
          maxParcelWeightKg: 20,
          mode: null,
        ),
      );
      await _fill(tester, weightText: '18');

      await tester.tap(find.byKey(const Key('bid-submit-btn')));
      await tester.pump();

      expect(_lastCheckout().weightKg, 18);
    });
  });

  group('422 du lot à l\'envoi', () {
    for (final (code, detail) in const [
      ('parcel-too-big', 'Ce voyageur accepte au plus la taille M.'),
      ('parcel-too-heavy', 'Ce voyageur accepte 20 kg au plus par colis.'),
    ]) {
      testWidgets('$code : détail du serveur affiché, la feuille reste '
          'ouverte et rien n\'est perdu', (tester) async {
        final ctrl = StreamController<BidState>.broadcast();
        addTearDown(ctrl.close);
        when(() => _bidBloc.stream).thenAnswer((_) => ctrl.stream);

        await _open(tester, _trip(maxItemSize: ItemSize.m, availableKg: 30));
        await _fill(tester);
        await tester.tap(find.byKey(const Key('item-size-M')));
        await tester.pump();

        ctrl.add(BidError(ValidationException(detail, code: code)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.textContaining(detail), findsWidgets);
        // La feuille est toujours là, le bouton aussi, la taille reste choisie.
        expect(find.byKey(const Key('bid-submit-btn')), findsOneWidget);
        expect(find.byKey(const Key('item-size-M')), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField).at(1));
        expect(field.controller?.text, 'Cartons');
      });
    }
  });

  group('360 dp', () {
    for (final (locale, send) in const [
      (Locale('fr', 'FR'), 'Envoyer'),
      (Locale('en'), 'Send'),
    ]) {
      testWidgets('${locale.languageCode} : bouton de validation sur une '
          'ligne, aucun débordement', (tester) async {
        if (locale.languageCode == 'en') useEnglish();
        await _open(
          tester,
          _trip(maxItemSize: ItemSize.xl, availableKg: 30),
          size: const Size(360, 2400),
          locale: locale,
        );

        expect(tester.takeException(), isNull);
        expect(find.text(send), findsOneWidget);
        expect(
          find.text(
            locale.languageCode == 'en'
                ? 'Parcel size (optional)'
                : 'Taille du colis (facultatif)',
          ),
          findsOneWidget,
        );
        final height = tester.getSize(find.byKey(const Key('bid-submit-btn')));
        expect(height.height, lessThanOrEqualTo(56));
        // Les quatre tuiles de taille tiennent dans la largeur.
        for (final code in const ['S', 'M', 'L', 'XL']) {
          final rect = tester.getRect(find.byKey(Key('item-size-$code')));
          expect(rect.right, lessThanOrEqualTo(360));
        }
      });
    }
  });
}
