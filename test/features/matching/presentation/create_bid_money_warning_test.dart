import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/money_keyword_warning.dart';
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

AnnouncementModel _announcement() => AnnouncementModel(
  id: 'ann-money-warning-test',
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
);

// ── Tests ─────────────────────────────────────────────────────────────────────

/// Bandeau « Envoi d'argent interdit » sous la description du colis, dans la
/// demande sur un trajet (CreateBidScreen).
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
    when(
      () => photosCubit.readyKeys,
    ).thenReturn(const <String>['bids/photo-1.jpg']);

    void register<T extends Object>(T mock) {
      if (getIt.isRegistered<T>()) getIt.unregister<T>();
      getIt.registerSingleton<T>(mock);
    }

    register<BidBloc>(bidBloc);
    register<PaymentBloc>(paymentBloc);
    register<WalletBloc>(walletBloc);
    register<BidPhotosCubit>(photosCubit);
    register<RecipientBloc>(recipientBloc);

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
        // Miroir de l'enregistrement réel dans lib/app/router.dart.
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
    return MaterialApp.router(routerConfig: router);
  }

  /// Ouvre l'écran à 360 dp de large, la plus petite largeur visée.
  Future<void> openNarrow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(_announcement()));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  final description = find.byKey(const Key('bid-description-field'));
  final banner = find.byKey(MoneyKeywordWarning.bannerKey);

  Future<void> typeDescription(WidgetTester tester, String text) async {
    await tester.ensureVisible(description);
    await tester.enterText(description, text);
    await tester.pumpAndSettle();
  }

  group('Demande sur un trajet : description qui évoque de l\'argent', () {
    testWidgets(
      '« cash » affiche le bandeau, l\'effacer le retire (360 dp, sans erreur)',
      (tester) async {
        await openNarrow(tester);
        expect(banner, findsNothing);

        await typeDescription(tester, 'cash');
        expect(banner, findsOneWidget);
        expect(find.text("Envoi d'argent interdit"), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Le bandeau suit directement le champ description.
        expect(
          tester.getTopLeft(banner).dy,
          greaterThan(tester.getBottomLeft(description).dy),
        );

        await typeDescription(tester, '');
        expect(banner, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('« vêtements » n\'affiche aucun bandeau', (tester) async {
      await openNarrow(tester);

      await typeDescription(tester, 'vêtements');
      expect(banner, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en anglais : bandeau traduit, sans erreur à 360 dp', (
      tester,
    ) async {
      useEnglish();
      await openNarrow(tester);

      await typeDescription(tester, 'some money');
      expect(banner, findsOneWidget);
      expect(find.text('Sending money is prohibited'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
