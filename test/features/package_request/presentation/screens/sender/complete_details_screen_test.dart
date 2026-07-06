import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/complete_details_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/presentation/screens/sender/complete_details_screen.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

/// Task 10 — wiring test for `RecipientSection` inside `CompleteDetailsScreen`.
///
/// The deep behaviour of `RecipientSection` (3-state picker, toggle
/// visibility, manual-entry save payload) is already covered by Task 9's
/// `recipient_section_test.dart`. Here we only assert the WIRING: the section
/// renders on the loaded form, `fallbackCity` comes from
/// `state.request?.arrivalCity`, and `RecipientSectionController
/// .maybeSaveManualEntry()` fires on a successful submission (dispatching
/// `RecipientCreated` on the section's own bloc) before the screen pops.
class _MockCompleteDetailsBloc
    extends MockBloc<CompleteDetailsEvent, CompleteDetailsState>
    implements CompleteDetailsBloc {}

// CompleteDetailsEvent is sealed and can't be Fake-implemented outside its
// library — use one of its concrete subclasses as the mocktail fallback.
const _fallbackCompleteDetailsEvent = CompleteDetailsStarted('fallback');

class _MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class _FakeRecipientEvent extends Fake implements RecipientEvent {}

PackageRequest _fakeRequest() => PackageRequest(
  id: 'pr-1',
  senderId: 'sender-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 8, 15),
  dateToleranceDays: 3,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: const ['Vêtements'],
  status: PackageRequestStatus.negotiating,
  createdAt: DateTime(2026),
  acceptedPaymentMethods: const {PaymentMethod.stripe},
);

Widget _buildApp() {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/complete/:id',
        builder: (ctx, state) =>
            CompleteDetailsScreen(requestId: state.pathParameters['id']!),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
}

void main() {
  setUpAll(() {
    initializeDateFormatting('fr');
    registerFallbackValue(_fallbackCompleteDetailsEvent);
    registerFallbackValue(_FakeRecipientEvent());
  });

  late _MockCompleteDetailsBloc completeDetailsBloc;
  late _MockRecipientBloc recipientBloc;

  setUp(() {
    completeDetailsBloc = _MockCompleteDetailsBloc();
    recipientBloc = _MockRecipientBloc();
    when(() => recipientBloc.state).thenReturn(const RecipientState());

    if (getIt.isRegistered<CompleteDetailsBloc>()) {
      getIt.unregister<CompleteDetailsBloc>();
    }
    getIt.registerFactory<CompleteDetailsBloc>(() => completeDetailsBloc);

    if (getIt.isRegistered<RecipientBloc>()) {
      getIt.unregister<RecipientBloc>();
    }
    getIt.registerFactory<RecipientBloc>(() => recipientBloc);
  });

  tearDown(() {
    if (getIt.isRegistered<CompleteDetailsBloc>()) {
      getIt.unregister<CompleteDetailsBloc>();
    }
    if (getIt.isRegistered<RecipientBloc>()) {
      getIt.unregister<RecipientBloc>();
    }
  });

  Future<void> pumpLoaded(WidgetTester tester) async {
    final loadedState = CompleteDetailsState(
      loaded: true,
      request: _fakeRequest(),
    );
    when(() => completeDetailsBloc.state).thenReturn(loadedState);
    whenListen(
      completeDetailsBloc,
      const Stream<CompleteDetailsState>.empty(),
      initialState: loadedState,
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    // Navigate to the screen under test (initial route is a plain home stub
    // so a successful pop() has somewhere to land).
    final context = tester.element(find.text('HOME'));
    unawaited(GoRouter.of(context).push('/complete/pr-1'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the recipient picker button on the loaded form', (
    tester,
  ) async {
    await pumpLoaded(tester);

    expect(find.text('DESTINATAIRE'), findsOneWidget);
    expect(find.text('Choisir un destinataire'), findsOneWidget);
    // The 3 raw fields are still there, unchanged, as RecipientSection's
    // children.
    expect(find.byType(TextFormField), findsNWidgets(4));
  });

  testWidgets(
    'successful submission saves the manual recipient (fallbackCity wired) '
    'then pops',
    (tester) async {
      final loadedState = CompleteDetailsState(
        loaded: true,
        request: _fakeRequest(),
      );
      final successState = loadedState.copyWith(
        status: CompleteDetailsStatus.success,
      );
      final stateController = StreamController<CompleteDetailsState>();
      addTearDown(stateController.close);

      when(() => completeDetailsBloc.state).thenReturn(loadedState);
      whenListen(
        completeDetailsBloc,
        stateController.stream,
        initialState: loadedState,
      );

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
      final homeContext = tester.element(find.text('HOME'));
      unawaited(GoRouter.of(homeContext).push('/complete/pr-1'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Fatou Ndiaye'); // recipient name
      await tester.enterText(fields.at(1), '+221771112233'); // recipient phone
      // City left empty on purpose: maybeSave must fall back to
      // state.request!.arrivalCity ('Dakar').
      await tester.enterText(fields.at(3), '120'); // declared value
      await tester.pump();

      // Toggle "Enregistrer ce destinataire" appears once the phone is a
      // valid, unknown E.164 number.
      expect(find.byType(SwitchListTile), findsOneWidget);

      await tester.tap(find.text('Continuer vers le paiement'));
      await tester.pump();

      final submittedEvents = verify(
        () => completeDetailsBloc.add(captureAny()),
      ).captured.whereType<CompleteDetailsSubmitted>();
      expect(submittedEvents, hasLength(1));
      expect(submittedEvents.single.recipientName, 'Fatou Ndiaye');
      expect(submittedEvents.single.recipientPhone, '+221771112233');
      expect(submittedEvents.single.declaredValueEur, 120.0);

      // Simulate the backend confirming success — this is when the listener
      // must call RecipientSectionController.maybeSaveManualEntry() BEFORE
      // popping.
      stateController.add(successState);
      await tester.pump();
      await tester.pump();

      final createdEvents = verify(
        () => recipientBloc.add(captureAny()),
      ).captured.whereType<RecipientCreated>();
      expect(createdEvents, hasLength(1));
      expect(createdEvents.single.fullName, 'Fatou Ndiaye');
      expect(createdEvents.single.phoneE164, '+221771112233');
      // fallbackCity came from state.request!.arrivalCity, not a hardcoded
      // value.
      expect(createdEvents.single.city, 'Dakar');

      // The screen popped back to the caller.
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    },
  );

  testWidgets('does not save a recipient when the submission errors', (
    tester,
  ) async {
    final loadedState = CompleteDetailsState(
      loaded: true,
      request: _fakeRequest(),
    );
    final errorState = loadedState.copyWith(
      status: CompleteDetailsStatus.error,
      errorMessage: 'Erreur réseau',
    );
    final stateController = StreamController<CompleteDetailsState>();
    addTearDown(stateController.close);

    when(() => completeDetailsBloc.state).thenReturn(loadedState);
    whenListen(
      completeDetailsBloc,
      stateController.stream,
      initialState: loadedState,
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final homeContext = tester.element(find.text('HOME'));
    unawaited(GoRouter.of(homeContext).push('/complete/pr-1'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Fatou Ndiaye');
    await tester.enterText(fields.at(1), '+221771112233');
    await tester.enterText(fields.at(3), '120');
    await tester.pump();

    await tester.tap(find.text('Continuer vers le paiement'));
    await tester.pump();

    stateController.add(errorState);
    await tester.pump();
    await tester.pump();

    verifyNever(() => recipientBloc.add(any(that: isA<RecipientCreated>())));
    // Still on the form — no pop on error.
    expect(find.text('Continuer vers le paiement'), findsOneWidget);
  });
}
