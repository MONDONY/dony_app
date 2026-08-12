import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/connectivity/bloc/connectivity_cubit.dart';
import 'package:dony/features/connectivity/bloc/connectivity_state.dart';
import 'package:dony/features/connectivity/presentation/widgets/connectivity_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConnectivityCubit extends MockCubit<ConnectivityState>
    implements ConnectivityCubit {}

void main() {
  late _MockConnectivityCubit cubit;

  setUp(() => cubit = _MockConnectivityCubit());

  Widget wrap() => MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    home: Scaffold(
      body: BlocProvider<ConnectivityCubit>.value(
        value: cubit,
        child: const ConnectivityBanner(),
      ),
    ),
  );

  testWidgets('rien affiché quand online', (tester) async {
    when(() => cubit.state).thenReturn(const ConnectivityState());
    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Pas de connexion internet'), findsNothing);
    expect(find.text('Connexion instable'), findsNothing);
    expect(find.text('Connexion rétablie'), findsNothing);
  });

  testWidgets('bandeau rouge "Pas de connexion internet" quand offline', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const ConnectivityState(status: ConnectivityStatus.offline));
    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Pas de connexion internet'), findsOneWidget);
  });

  testWidgets('bandeau ambre "Connexion instable" quand weak', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(const ConnectivityState(status: ConnectivityStatus.weak));
    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Connexion instable'), findsOneWidget);
  });

  testWidgets(
    'bandeau vert "Connexion rétablie" quand justReconnected, même si status online',
    (tester) async {
      when(() => cubit.state).thenReturn(
        const ConnectivityState(
          status: ConnectivityStatus.online,
          justReconnected: true,
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Connexion rétablie'), findsOneWidget);
    },
  );
}
