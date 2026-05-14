import 'package:bloc_test/bloc_test.dart';
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

class _FakeCommissionMethodEvent extends Fake implements CommissionMethodEvent {}

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

Widget _wrap(Widget child, CommissionMethodBloc bloc) =>
    MaterialApp(home: BlocProvider<CommissionMethodBloc>.value(value: bloc, child: child));

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

  testWidgets('shows loading indicator when CommissionMethodLoading', (tester) async {
    whenListen(bloc, Stream.value(CommissionMethodLoading()),
        initialState: CommissionMethodLoading());
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows empty state when CommissionMethodNotConfigured', (tester) async {
    whenListen(bloc, Stream.value(CommissionMethodNotConfigured()),
        initialState: CommissionMethodNotConfigured());
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    expect(find.text('Ajouter une carte'), findsOneWidget);
  });

  testWidgets('shows card preview and action buttons when Loaded', (tester) async {
    whenListen(bloc, Stream.value(CommissionMethodLoaded(_fakeCard)),
        initialState: CommissionMethodLoaded(_fakeCard));
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    expect(find.text('•••• •••• •••• 4242'), findsOneWidget);
    expect(find.text('Remplacer la carte'), findsOneWidget);
    expect(find.text('Supprimer la carte'), findsOneWidget);
  });

  testWidgets('shows expiration banner when card is expired', (tester) async {
    whenListen(bloc, Stream.value(CommissionMethodLoaded(_expiredCard)),
        initialState: CommissionMethodLoaded(_expiredCard));
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    expect(find.textContaining('expiré'), findsOneWidget);
  });

  testWidgets('setup event dispatched when add card tapped', (tester) async {
    whenListen(bloc, Stream.value(CommissionMethodNotConfigured()),
        initialState: CommissionMethodNotConfigured());
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    await tester.tap(find.text('Ajouter une carte'));
    verify(() => bloc.add(any(that: isA<CommissionMethodSetupRequested>()))).called(1);
  });
}
