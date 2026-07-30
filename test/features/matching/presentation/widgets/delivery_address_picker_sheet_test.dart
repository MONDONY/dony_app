import 'package:bloc_test/bloc_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_bloc.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_event.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_state.dart';
import 'package:dony/features/matching/presentation/widgets/delivery_address_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockDeliveryAddressBloc
    extends MockBloc<DeliveryAddressEvent, DeliveryAddressState>
    implements DeliveryAddressBloc {}

class _MockAddressAutocompleteService extends Mock
    implements AddressAutocompleteService {}

class _MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {}

class _MockConnectivityPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements ConnectivityPlatform {}

void main() {
  late _MockDeliveryAddressBloc bloc;
  late _MockAddressAutocompleteService service;
  late _MockGeolocatorPlatform geolocator;
  late _MockConnectivityPlatform connectivity;

  setUpAll(() {
    registerFallbackValue(const LocationSettings());
  });

  setUp(() {
    bloc = _MockDeliveryAddressBloc();
    when(() => bloc.state).thenReturn(
      const DeliveryAddressState(status: DeliveryAddressStatus.success),
    );

    service = _MockAddressAutocompleteService();
    getIt.registerLazySingleton<AddressAutocompleteService>(() => service);

    geolocator = _MockGeolocatorPlatform();
    GeolocatorPlatform.instance = geolocator;

    connectivity = _MockConnectivityPlatform();
    ConnectivityPlatform.instance = connectivity;
  });

  tearDown(() => getIt.reset());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider<DeliveryAddressBloc>.value(
            value: bloc,
            child: const DeliveryAddressPickerSheet(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  group('recherche d\'adresse — connectivité', () {
    testWidgets(
      'une erreur backend sur un device connecté affiche « Erreur », pas '
      '« Connexion requise »',
      (tester) async {
        when(
          () => connectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);
        when(
          () => service.search(any(), any()),
        ).thenThrow(Exception('500 backend'));

        await pump(tester);
        await search(tester, '12 rue de Paris');

        expect(find.text('Erreur'), findsOneWidget);
        expect(find.text('Connexion requise'), findsNothing);
      },
    );

    testWidgets(
      'un device réellement hors ligne affiche « Connexion requise »',
      (tester) async {
        when(
          () => connectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.none]);
        when(
          () => service.search(any(), any()),
        ).thenThrow(Exception('network unreachable'));

        await pump(tester);
        await search(tester, '12 rue de Paris');

        expect(find.text('Connexion requise'), findsOneWidget);
        expect(find.text('Erreur'), findsNothing);
      },
    );
  });

  group('position actuelle — GPS', () {
    testWidgets('service de localisation désactivé → « GPS désactivé »', (
      tester,
    ) async {
      when(
        () => geolocator.isLocationServiceEnabled(),
      ).thenAnswer((_) async => false);

      await pump(tester);
      await tester.tap(find.text('Utiliser ma position actuelle'));
      await tester.pumpAndSettle();

      expect(find.text('GPS désactivé'), findsOneWidget);
    });

    testWidgets(
      'GPS actif sans fix disponible → « Position indisponible », pas '
      '« GPS désactivé »',
      (tester) async {
        when(
          () => geolocator.isLocationServiceEnabled(),
        ).thenAnswer((_) async => true);
        when(
          () => geolocator.checkPermission(),
        ).thenAnswer((_) async => LocationPermission.always);
        when(
          () => geolocator.getCurrentPosition(
            locationSettings: any(named: 'locationSettings'),
          ),
        ).thenThrow(Exception('timeout'));
        when(
          () => geolocator.getLastKnownPosition(),
        ).thenAnswer((_) async => null);

        await pump(tester);
        await tester.tap(find.text('Utiliser ma position actuelle'));
        await tester.pumpAndSettle();

        expect(find.text('Position indisponible'), findsOneWidget);
        expect(find.text('GPS désactivé'), findsNothing);
        expect(find.text('Réessayer'), findsOneWidget);
      },
    );
  });
}
