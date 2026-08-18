import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:dony/features/payments/cash/presentation/screens/commission_method_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

class _FakeCommissionMethodEvent extends Fake
    implements CommissionMethodEvent {}

const _fakeCard = CommissionMethod(
  brand: 'visa',
  last4: '4242',
  expMonth: 12,
  expYear: 2028,
  expirationStatus: ExpirationStatus.valid,
);

const _expiredCard = CommissionMethod(
  brand: 'mastercard',
  last4: '0001',
  expMonth: 1,
  expYear: 2023,
  expirationStatus: ExpirationStatus.expired,
);

Widget _wrap(Widget child, CommissionMethodBloc bloc) => MaterialApp(
  home: BlocProvider<CommissionMethodBloc>.value(value: bloc, child: child),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeCommissionMethodEvent());
  });

  late MockCommissionMethodBloc bloc;

  setUp(() {
    bloc = MockCommissionMethodBloc();
  });

  tearDown(() {
    bloc.close();
  });

  testWidgets('shows skeleton when CommissionMethodLoading', (tester) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoading()),
      initialState: CommissionMethodLoading(),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    expect(find.byType(DonyDetailSkeleton), findsOneWidget);
  });

  testWidgets('shows empty state when CommissionMethodNotConfigured', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodNotConfigured()),
      initialState: CommissionMethodNotConfigured(),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    // pumpAndSettle : laisse l'animation flutter_animate de la mascotte
    // (empty state) se terminer, sinon "A Timer is still pending" au teardown.
    await tester.pumpAndSettle();
    expect(find.text('Ajouter une carte'), findsOneWidget);
  });

  testWidgets('shows card preview and action buttons when Loaded', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_fakeCard)),
      initialState: CommissionMethodLoaded(_fakeCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    expect(find.text('•••• •••• •••• 4242'), findsOneWidget);
    expect(find.text('Remplacer la carte'), findsOneWidget);
    expect(find.text('Supprimer la carte'), findsOneWidget);
  });

  testWidgets('shows expiration banner when card is expired', (tester) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_expiredCard)),
      initialState: CommissionMethodLoaded(_expiredCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    expect(find.textContaining('expiré'), findsOneWidget);
  });

  testWidgets('setup event dispatched when add card tapped', (tester) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodNotConfigured()),
      initialState: CommissionMethodNotConfigured(),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter une carte'));
    verify(
      () => bloc.add(any(that: isA<CommissionMethodSetupRequested>())),
    ).called(1);
  });

  testWidgets('replace card button dispatches SetupRequested', (tester) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_fakeCard)),
      initialState: CommissionMethodLoaded(_fakeCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    await tester.tap(find.text('Remplacer la carte'));
    verify(
      () => bloc.add(any(that: isA<CommissionMethodSetupRequested>())),
    ).called(1);
  });

  testWidgets('delete button shows confirmation sheet', (tester) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_fakeCard)),
      initialState: CommissionMethodLoaded(_fakeCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    await tester.tap(find.text('Supprimer la carte'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer'), findsWidgets);
  });

  testWidgets('confirm delete dispatches DeleteRequested', (tester) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_fakeCard)),
      initialState: CommissionMethodLoaded(_fakeCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    await tester.tap(find.text('Supprimer la carte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    verify(
      () => bloc.add(any(that: isA<CommissionMethodDeleteRequested>())),
    ).called(1);
  });

  testWidgets('cancel delete closes sheet without dispatching event', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_fakeCard)),
      initialState: CommissionMethodLoaded(_fakeCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    await tester.tap(find.text('Supprimer la carte'));
    await tester.pumpAndSettle();
    expect(find.text('Annuler'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    verifyNever(
      () => bloc.add(any(that: isA<CommissionMethodDeleteRequested>())),
    );
  });

  testWidgets('dispatches LoadRequested when app resumes from background', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_fakeCard)),
      initialState: CommissionMethodLoaded(_fakeCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    clearInteractions(bloc);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    verify(
      () => bloc.add(any(that: isA<CommissionMethodLoadRequested>())),
    ).called(1);
  });
}
