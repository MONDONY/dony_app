import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
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

class _FakeBidEvent extends Fake implements BidEvent {}

// ── Données de test ──────────────────────────────────────────────────────────

AnnouncementModel _announcement({
  List<String>? acceptedContentTypes,
  List<String>? refusedTypes,
}) =>
    AnnouncementModel(
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
  late StreamController<BidState> bidStream;

  setUpAll(() {
    registerFallbackValue(_FakeBidEvent());
  });

  setUp(() {
    bidStream = StreamController<BidState>.broadcast();
    bidBloc = _MockBidBloc();
    paymentBloc = _MockPaymentBloc();
    walletBloc = _MockWalletBloc();
    photosCubit = _MockBidPhotosCubit();

    whenListen(bidBloc, bidStream.stream, initialState: BidInitial());
    whenListen(paymentBloc, const Stream<PaymentState>.empty(),
        initialState: const PaymentInitial());
    whenListen(walletBloc, const Stream<WalletState>.empty(),
        initialState: WalletInitial());
    whenListen(photosCubit, const Stream<List<BidPhotoUpload>>.empty(),
        initialState: const <BidPhotoUpload>[]);

    void register<T extends Object>(T mock) {
      if (getIt.isRegistered<T>()) getIt.unregister<T>();
      getIt.registerSingleton<T>(mock);
    }

    register<BidBloc>(bidBloc);
    register<PaymentBloc>(paymentBloc);
    register<WalletBloc>(walletBloc);
    register<BidPhotosCubit>(photosCubit);
  });

  tearDown(() async {
    await bidStream.close();
    if (getIt.isRegistered<BidBloc>()) getIt.unregister<BidBloc>();
    if (getIt.isRegistered<PaymentBloc>()) getIt.unregister<PaymentBloc>();
    if (getIt.isRegistered<WalletBloc>()) getIt.unregister<WalletBloc>();
    if (getIt.isRegistered<BidPhotosCubit>()) {
      getIt.unregister<BidPhotosCubit>();
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
        GoRoute(path: '/bids/:id', builder: (_, __) => const SizedBox()),
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
        'shows accepted category chip and refused chip with REFUSÉ label',
        (tester) async {
      await openSheet(
        tester,
        _announcement(
          acceptedContentTypes: ['Vêtements'],
          refusedTypes: ['Hi-fi'],
        ),
      );

      // Accepted category chip is present.
      expect(find.text('Vêtements'), findsOneWidget);

      // Refused section label and refused chip are present.
      expect(find.text('REFUSÉ PAR LE VOYAGEUR'), findsOneWidget);
      expect(find.text('Hi-fi'), findsOneWidget);
    });

    testWidgets('tapping Ajouter chip opens the add-item dialog', (tester) async {
      await openSheet(
        tester,
        _announcement(
          acceptedContentTypes: ['Vêtements'],
          refusedTypes: ['Hi-fi'],
        ),
      );

      // Tap the "Ajouter" chip.
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      // The dialog should appear.
      expect(find.text('Ajouter un élément'), findsOneWidget);
    });
  });
}
