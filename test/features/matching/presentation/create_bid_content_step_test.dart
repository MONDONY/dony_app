import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
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
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
  List<String>? acceptedContentTypes,
  List<String>? refusedTypes,
}) => AnnouncementModel(
  id: 'ann-content-test',
  travelerId: 'traveler-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 8),
  availableKg: 10.0,
  totalKg: 10.0,
  pricePerKg: 12.0,
  capacityUnit: 'SUITCASE_23KG',
  status: 'OPEN',
  bidsCount: 0,
  createdAt: DateTime(2026, 7),
  updatedAt: DateTime(2026, 7),
  acceptedContentTypes: acceptedContentTypes,
  refusedTypes: refusedTypes,
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBidBloc bidBloc;
  late _MockPaymentBloc paymentBloc;
  late _MockWalletBloc walletBloc;
  late _MockBidPhotosCubit photosCubit;
  late _MockRecipientBloc recipientBloc;
  late StreamController<BidState> bidStream;

  setUpAll(() {
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
    // Depuis 57ce4308 (PR #130, recipient quick action), la RecipientSection
    // de CreateBidScreen résout getIt<RecipientBloc>() dans initState.
    whenListen(
      recipientBloc,
      const Stream<RecipientState>.empty(),
      initialState: const RecipientState(),
    );
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

    void register<T extends Object>(T mock) {
      if (getIt.isRegistered<T>()) getIt.unregister<T>();
      getIt.registerSingleton<T>(mock);
    }

    register<BidBloc>(bidBloc);
    register<PaymentBloc>(paymentBloc);
    register<WalletBloc>(walletBloc);
    register<BidPhotosCubit>(photosCubit);
    register<RecipientBloc>(recipientBloc);

    // Depuis 8b164c47 (PR #139, catalogue unifié), CreateBidScreen charge le
    // catalogue de types de contenu via getIt<IContentCategoryRepository>().
    if (!getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.registerFactory<IContentCategoryRepository>(
        () => _FakeContentCategoryRepository(),
      );
    }
  });

  tearDown(() async {
    await bidStream.close();
    if (getIt.isRegistered<BidBloc>()) getIt.unregister<BidBloc>();
    if (getIt.isRegistered<PaymentBloc>()) getIt.unregister<PaymentBloc>();
    if (getIt.isRegistered<WalletBloc>()) getIt.unregister<WalletBloc>();
    if (getIt.isRegistered<BidPhotosCubit>()) {
      getIt.unregister<BidPhotosCubit>();
    }
    if (getIt.isRegistered<RecipientBloc>()) {
      getIt.unregister<RecipientBloc>();
    }
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
        // Depuis 06a9a2bc (PR #126), CreateBidBottomSheet.show() délègue à
        // context.push('/bids/new') : CreateBidScreen est un écran GoRouter
        // plein écran — miroir de l'enregistrement réel dans lib/app/router.dart.
        GoRoute(
          path: '/bids/new',
          builder: (_, state) =>
              CreateBidScreen(announcement: state.extra as AnnouncementModel),
        ),
        GoRoute(path: '/bids/:id', builder: (_, _) => const SizedBox()),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  Future<void> openSheet(
    WidgetTester tester,
    AnnouncementModel announcement,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(announcement));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  group('Content step driven by announcement', () {
    testWidgets(
      'le combobox propose les types acceptés, la section refusé reste visible',
      (tester) async {
        await openSheet(
          tester,
          _announcement(
            acceptedContentTypes: ['Vêtements'],
            refusedTypes: ['Hi-fi'],
          ),
        );

        // La section « refusé » est affichée sans ouvrir le combobox.
        expect(find.text('REFUSÉ PAR LE VOYAGEUR'), findsOneWidget);
        expect(find.text('Hi-fi'), findsOneWidget);

        // Ouvrir le combobox → le type accepté apparaît dans la liste déroulante.
        await tester.ensureVisible(find.byKey(const Key('bid-content-field')));
        await tester.tap(find.byKey(const Key('bid-content-field')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('bid-content-item-Vêtements')),
          findsOneWidget,
        );
      },
    );

    testWidgets('ajout libre via le combobox ajoute un tag de contenu', (
      tester,
    ) async {
      await openSheet(
        tester,
        _announcement(
          acceptedContentTypes: ['Vêtements'],
          refusedTypes: ['Hi-fi'],
        ),
      );

      // Ouvrir le combobox, taper un type hors catalogue → ligne « Ajouter ».
      await tester.ensureVisible(find.byKey(const Key('bid-content-field')));
      await tester.tap(find.byKey(const Key('bid-content-field')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('bid-content-field')),
        'Épices maison',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bid-content-item-add')));
      await tester.pumpAndSettle();

      // Le tag custom apparaît au-dessus du champ.
      expect(
        find.byKey(const Key('bid-content-tag-Épices maison')),
        findsOneWidget,
      );
    });

    testWidgets(
      'la ligne « Ajouter » reste proposée même quand un item du catalogue '
      'matche encore (saisie libre)',
      (tester) async {
        await openSheet(
          tester,
          _announcement(
            acceptedContentTypes: ['Vêtements'],
            refusedTypes: ['Hi-fi'],
          ),
        );

        await tester.ensureVisible(find.byKey(const Key('bid-content-field')));
        await tester.tap(find.byKey(const Key('bid-content-field')));
        await tester.pumpAndSettle();
        // « Vêt » matche encore l'item accepté « Vêtements »…
        await tester.enterText(
          find.byKey(const Key('bid-content-field')),
          'Vêt',
        );
        await tester.pumpAndSettle();

        // …mais la ligne d'ajout est tout de même proposée (contenu libre).
        expect(
          find.byKey(const Key('bid-content-item-Vêtements')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('bid-content-item-add')), findsOneWidget);
      },
    );

    testWidgets('un type refusé saisi librement est écarté (pas de tag)', (
      tester,
    ) async {
      await openSheet(
        tester,
        _announcement(
          acceptedContentTypes: ['Vêtements'],
          refusedTypes: ['Hi-fi'],
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('bid-content-field')));
      await tester.tap(find.byKey(const Key('bid-content-field')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('bid-content-field')),
        'Hi-fi',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bid-content-item-add')));
      await tester.pumpAndSettle();

      // Aucun tag « Hi-fi » : le contenu refusé par le voyageur est bloqué.
      expect(find.byKey(const Key('bid-content-tag-Hi-fi')), findsNothing);
    });
  });
}
