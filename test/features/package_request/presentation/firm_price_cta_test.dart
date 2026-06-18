// Tests for Task 10 — firm price CTA + canCounter guard
//
// Test 1: PackageRequestPublicDetailScreen body — negotiable=false
//   → shows Key('take-firm-price') button / "Prendre à X €" text
//   → hides "Faire une offre" button
//
// Test 2: ThreadStateCtaBar — canCounter=false (sender)
//   → hides "Contre-offre" for sender when canCounter=false
//   → still shows "Accepter" button

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/package_request_public_detail_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_cta_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}


// ─── Helpers ─────────────────────────────────────────────────────────────────

PackageRequest _firmRequest({double targetPriceEur = 35}) => PackageRequest(
      id: 'pr-1',
      senderId: 'sender-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 8, 1),
      dateToleranceDays: 3,
      weightKg: 5,
      parcelSize: ParcelSize.small,
      transportMode: TransportMode.plane,
      contentCategory: ContentCategory.vetements,
      status: PackageRequestStatus.open,
      createdAt: DateTime(2026, 6, 1),
      negotiable: false,
      targetPriceEur: targetPriceEur,
    );

PackageRequest _negotiableRequest() => PackageRequest(
      id: 'pr-2',
      senderId: 'sender-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 8, 1),
      dateToleranceDays: 3,
      weightKg: 5,
      parcelSize: ParcelSize.small,
      transportMode: TransportMode.plane,
      contentCategory: ContentCategory.vetements,
      status: PackageRequestStatus.open,
      createdAt: DateTime(2026, 6, 1),
      negotiable: true,
      targetPriceEur: 35,
    );

PackageRequest _requestWithPayments(Set<PaymentMethod> methods) =>
    PackageRequest(
      id: 'pr-3',
      senderId: 'sender-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 8, 1),
      dateToleranceDays: 3,
      weightKg: 5,
      parcelSize: ParcelSize.small,
      transportMode: TransportMode.plane,
      contentCategory: ContentCategory.vetements,
      status: PackageRequestStatus.open,
      createdAt: DateTime(2026, 6, 1),
      negotiable: true,
      targetPriceEur: 35,
      acceptedPaymentMethods: methods,
    );

NegotiationThread _thread({
  bool canCounter = true,
  bool canAccept = true,
  String viewer = 'sender-1',
}) {
  final messages = <NegotiationMessage>[
    NegotiationMessage(
      id: 'm1',
      threadId: 't1',
      fromUserId: 'other-user',
      kind: NegotiationMessageKind.counter,
      proposedPriceEur: 38,
      createdAt: DateTime(2026, 5, 11, 10),
    ),
  ];
  return NegotiationThread(
    id: 't1',
    packageRequestId: 'pr-1',
    travelerId: 'traveler-1',
    travelerTravelDate: DateTime(2026, 6, 15),
    travelerAvailableKg: 10,
    status: NegotiationThreadStatus.open,
    currentPriceEur: 38,
    roundsCount: 2,
    canAccept: canAccept,
    canCounter: canCounter,
    lastActivityAt: DateTime(2026, 5, 11, 10),
    createdAt: DateTime(2026, 5, 11, 9),
    messages: messages,
  );
}

// ─── Test 1 — Detail screen body ─────────────────────────────────────────────

void main() {
  // Register a mock NegotiationBloc in getIt so _FirmPriceCta can use it.
  late _MockNegotiationBloc mockNegotiationBloc;

  setUp(() {
    mockNegotiationBloc = _MockNegotiationBloc();
    when(() => mockNegotiationBloc.state)
        .thenReturn(const NegotiationInitial());
    when(() => mockNegotiationBloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());

    if (getIt.isRegistered<NegotiationBloc>()) {
      getIt.unregister<NegotiationBloc>();
    }
    getIt.registerFactory<NegotiationBloc>(() => mockNegotiationBloc);
  });

  tearDown(() async {
    if (getIt.isRegistered<NegotiationBloc>()) {
      getIt.unregister<NegotiationBloc>();
    }
  });

  group('PackageRequestPublicDetailBody — firm price (negotiable=false)', () {
    Widget wrap(PackageRequest request) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PackageRequestPublicDetailBody(request: request),
          ),
        );

    testWidgets(
      'negotiable=false → bouton Key("take-firm-price") visible',
      (tester) async {
        await tester.pumpWidget(wrap(_firmRequest()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('take-firm-price')), findsOneWidget);
      },
    );

    testWidgets(
      'negotiable=false, targetPriceEur=35 → texte "Prendre à 35,00 €" visible',
      (tester) async {
        await tester.pumpWidget(wrap(_firmRequest(targetPriceEur: 35)));
        await tester.pumpAndSettle();

        expect(find.textContaining('Prendre à'), findsOneWidget);
        expect(find.textContaining('Prendre à 35,00 €'), findsOneWidget);
      },
    );

    testWidgets(
      'negotiable=false → "Faire une offre" masqué',
      (tester) async {
        await tester.pumpWidget(wrap(_firmRequest()));
        await tester.pumpAndSettle();

        expect(find.text('Faire une offre'), findsNothing);
      },
    );

    testWidgets(
      'negotiable=false → badge "PRIX FERME" affiché',
      (tester) async {
        await tester.pumpWidget(wrap(_firmRequest()));
        await tester.pumpAndSettle();

        expect(find.textContaining('PRIX FERME'), findsOneWidget);
      },
    );

    testWidgets(
      'negotiable=true → "Faire une offre" visible (comportement inchangé)',
      (tester) async {
        await tester.pumpWidget(wrap(_negotiableRequest()));
        await tester.pumpAndSettle();

        expect(find.text('Proposer mon trajet'), findsOneWidget);
        expect(find.byKey(const Key('take-firm-price')), findsNothing);
      },
    );
  });

  // ─── Mode de paiement souhaité par l'expéditeur ──────────────────────────
  group('PackageRequestPublicDetailBody — mode de paiement', () {
    Widget wrap(PackageRequest request) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PackageRequestPublicDetailBody(request: request),
          ),
        );

    testWidgets(
      'acceptedPaymentMethods {Carte, Cash} → carte + chips visibles',
      (tester) async {
        await tester.pumpWidget(wrap(_requestWithPayments(
            {PaymentMethod.stripe, PaymentMethod.cash})));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('payment-methods-card')), findsOneWidget);
        expect(find.text('Mode de paiement souhaité'), findsOneWidget);
        expect(find.text('Carte'), findsOneWidget);
        expect(find.text('Cash'), findsOneWidget);
        expect(
            find.byKey(const Key('payment-method-chip-stripe')), findsOneWidget);
        expect(
            find.byKey(const Key('payment-method-chip-cash')), findsOneWidget);
      },
    );

    testWidgets(
      'mobile money {Wave, Orange Money} → labels affichés',
      (tester) async {
        await tester.pumpWidget(wrap(_requestWithPayments(
            {PaymentMethod.wave, PaymentMethod.orangeMoney})));
        await tester.pumpAndSettle();

        expect(find.text('Wave'), findsOneWidget);
        expect(find.text('Orange Money'), findsOneWidget);
        expect(find.byKey(const Key('payment-method-chip-stripe')), findsNothing);
      },
    );

    testWidgets(
      'acceptedPaymentMethods vide → carte masquée',
      (tester) async {
        await tester.pumpWidget(wrap(_requestWithPayments(const {})));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('payment-methods-card')), findsNothing);
        expect(find.text('Mode de paiement souhaité'), findsNothing);
      },
    );
  });

  // ─── Test 2 — ThreadStateCtaBar canCounter=false (sender) ─────────────────

  group('ThreadStateCtaBar — sender · canCounter=false', () {
    Widget wrapCtaBar(NegotiationThread thread, String viewerUserId) =>
        MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider<NegotiationBloc>.value(
            value: mockNegotiationBloc,
            child: Scaffold(
              body: ThreadStateCtaBar(
                thread: thread,
                viewerUserId: viewerUserId,
                actionInProgress: false,
              ),
            ),
          ),
        );

    testWidgets(
      'sender · canCounter=false → "Contre-offre" masqué',
      (tester) async {
        await tester.pumpWidget(wrapCtaBar(
          _thread(canCounter: false, canAccept: true, viewer: 'sender-1'),
          'sender-1',
        ));
        await tester.pump();

        expect(find.text('Contre-offre'), findsNothing);
      },
    );

    testWidgets(
      'sender · canCounter=false → bouton "Accepter" toujours présent',
      (tester) async {
        await tester.pumpWidget(wrapCtaBar(
          _thread(canCounter: false, canAccept: true, viewer: 'sender-1'),
          'sender-1',
        ));
        await tester.pump();

        expect(find.textContaining('Accepter'), findsOneWidget);
      },
    );

    testWidgets(
      'sender · canCounter=true → "Contre-offre" visible',
      (tester) async {
        await tester.pumpWidget(wrapCtaBar(
          _thread(canCounter: true, canAccept: true, viewer: 'sender-1'),
          'sender-1',
        ));
        await tester.pump();

        expect(find.text('Contre-offre'), findsOneWidget);
      },
    );
  });
}
