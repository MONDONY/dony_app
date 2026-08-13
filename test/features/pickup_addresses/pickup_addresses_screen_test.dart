import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';
import 'package:dony/features/pickup_addresses/presentation/screens/pickup_addresses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockPickupAddressBloc
    extends MockBloc<PickupAddressEvent, PickupAddressState>
    implements PickupAddressBloc {}

class FakePickupAddressEvent extends Fake implements PickupAddressEvent {}

const _addr1 = PickupAddress(
  id: 'addr-1',
  label: 'Maison',
  street: '12 rue de la Paix',
  postalCode: '75001',
  city: 'Paris',
  country: 'France',
  isDefault: true,
);

const _addr2 = PickupAddress(
  id: 'addr-2',
  label: 'Bureau',
  street: '5 avenue Montaigne',
  postalCode: '75008',
  city: 'Paris',
  country: 'France',
  isDefault: false,
);

Widget _wrap(PickupAddressBloc bloc) => BlocProvider<PickupAddressBloc>.value(
  value: bloc,
  child: MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const PickupAddressesScreen()),
        GoRoute(
          path: '/profile/addresses/new',
          builder: (_, __) => const Scaffold(body: Text('New Address')),
        ),
        GoRoute(
          path: '/profile/addresses/:id',
          builder: (_, __) => const Scaffold(body: Text('Edit Address')),
        ),
      ],
    ),
  ),
);

void main() {
  late MockPickupAddressBloc bloc;

  setUpAll(() => registerFallbackValue(FakePickupAddressEvent()));

  setUp(() {
    bloc = MockPickupAddressBloc();
    when(() => bloc.state).thenReturn(const PickupAddressState());
  });

  testWidgets('shows loading state', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const PickupAddressState(status: PickupAddressStatus.loading));
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PickupAddressesScreen), findsOneWidget);
  });

  testWidgets('shows empty state when no addresses', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const PickupAddressState(status: PickupAddressStatus.success));
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Aucune adresse'), findsOneWidget);
  });

  testWidgets('shows list of addresses', (tester) async {
    when(() => bloc.state).thenReturn(
      const PickupAddressState(
        status: PickupAddressStatus.success,
        addresses: [_addr1, _addr2],
      ),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Maison'), findsOneWidget);
    expect(find.text('Bureau'), findsOneWidget);
  });

  testWidgets('shows Par défaut badge on default address', (tester) async {
    when(() => bloc.state).thenReturn(
      const PickupAddressState(
        status: PickupAddressStatus.success,
        addresses: [_addr1],
      ),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Par défaut'), findsOneWidget);
  });

  testWidgets('shows error state with retry button', (tester) async {
    when(() => bloc.state).thenReturn(
      const PickupAddressState(
        status: PickupAddressStatus.error,
        error: 'Erreur réseau',
      ),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Erreur de chargement'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('retry button dispatches PickupAddressLoaded', (tester) async {
    when(() => bloc.state).thenReturn(
      const PickupAddressState(
        status: PickupAddressStatus.error,
        error: 'Erreur réseau',
      ),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(any(that: isA<PickupAddressLoaded>()))).called(1);
  });
}
