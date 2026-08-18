import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/features/settings/bloc/connected_devices_bloc.dart';
import 'package:dony/features/settings/data/models/device_model.dart';
import 'package:dony/features/settings/presentation/screens/connected_devices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectedDevicesBloc
    extends MockBloc<ConnectedDevicesEvent, ConnectedDevicesState>
    implements ConnectedDevicesBloc {}

class _FakeConnectedDevicesEvent extends Fake
    implements ConnectedDevicesEvent {}

DeviceModel _dev({bool current = false}) => DeviceModel(
  deviceId: current ? 'cur' : 'other',
  deviceName: current ? 'iPhone 14' : 'Galaxy S22',
  platform: current ? 'ios' : 'android',
  lastSeenAt: DateTime(2026, 5, 22),
  isCurrent: current,
);

DeviceModel _webDev() => DeviceModel(
  deviceId: 'web-123',
  deviceName: 'Chrome sur Windows',
  platform: 'web',
  lastSeenAt: DateTime(2026, 5, 22),
  isCurrent: false,
);

Widget _wrap(ConnectedDevicesBloc bloc) => MaterialApp(
  home: BlocProvider<ConnectedDevicesBloc>.value(
    value: bloc,
    child: const ConnectedDevicesScreen(),
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeConnectedDevicesEvent());
  });

  late MockConnectedDevicesBloc bloc;

  setUp(() => bloc = MockConnectedDevicesBloc());

  testWidgets('Loading → skeleton', (tester) async {
    when(() => bloc.state).thenReturn(const ConnectedDevicesLoading());
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump();
    expect(find.byType(DonyUserCardSkeleton), findsWidgets);
  });

  testWidgets('Loaded → liste avec badge appareil courant et bouton Révoquer', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(ConnectedDevicesLoaded([_dev(current: true), _dev()]));
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('iPhone 14'), findsOneWidget);
    expect(find.text('Galaxy S22'), findsOneWidget);
    expect(find.text('Cet appareil'), findsOneWidget);
    expect(find.text('Révoquer'), findsOneWidget);
    expect(find.text('Déconnecter tous les autres appareils'), findsOneWidget);
  });

  testWidgets(
    'Loaded avec un seul appareil courant → pas de bouton déconnexion globale',
    (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(ConnectedDevicesLoaded([_dev(current: true)]));
      await tester.pumpWidget(_wrap(bloc));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Déconnecter tous les autres appareils'), findsNothing);
    },
  );

  testWidgets('Error → message + bouton Réessayer', (tester) async {
    when(() => bloc.state).thenReturn(
      const ConnectedDevicesError('Impossible de charger les appareils'),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump();
    expect(find.text('Impossible de charger les appareils'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('Revoking → spinner', (tester) async {
    when(() => bloc.state).thenReturn(const DeviceRevoking('other'));
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('bouton Réessayer dispatche DevicesLoadRequested en état Error', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const ConnectedDevicesError('Impossible de charger les appareils'),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump();
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    verify(() => bloc.add(const DevicesLoadRequested())).called(1);
  });

  testWidgets('état Initial → rien de visible (SizedBox)', (tester) async {
    when(() => bloc.state).thenReturn(const ConnectedDevicesInitial());
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Réessayer'), findsNothing);
  });

  testWidgets('Loaded avec appareil web → tile affiché avec le nom correct', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(ConnectedDevicesLoaded([_dev(current: true), _webDev()]));
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Chrome sur Windows'), findsOneWidget);
    // Le tile doit s'afficher sans erreur de rendu
    expect(find.byType(ConnectedDevicesScreen), findsOneWidget);
  });
}
