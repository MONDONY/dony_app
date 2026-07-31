import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/pickup_address_picker_sheet.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockPickupAddressBloc
    extends MockBloc<PickupAddressEvent, PickupAddressState>
    implements PickupAddressBloc {}

class _MockAddressAutocompleteService extends Mock
    implements AddressAutocompleteService {}

class _MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {}

class _MockConnectivityPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements ConnectivityPlatform {}

void main() {
  late _MockPickupAddressBloc bloc;
  late _MockAddressAutocompleteService service;
  late _MockGeolocatorPlatform geolocator;
  late _MockConnectivityPlatform connectivity;

  setUpAll(() {
    registerFallbackValue(const LocationSettings());
    Hive.init(Directory.systemTemp.createTempSync('hive_test_').path);
  });

  setUp(() async {
    bloc = _MockPickupAddressBloc();
    when(
      () => bloc.state,
    ).thenReturn(const PickupAddressState(status: PickupAddressStatus.success));

    service = _MockAddressAutocompleteService();
    getIt.registerLazySingleton<AddressAutocompleteService>(() => service);

    final prefsBox = await Hive.openBox(HiveService.userPrefsBox);
    await prefsBox.clear();
    getIt.registerLazySingleton<HiveService>(() => HiveService());

    geolocator = _MockGeolocatorPlatform();
    GeolocatorPlatform.instance = geolocator;

    connectivity = _MockConnectivityPlatform();
    ConnectivityPlatform.instance = connectivity;
  });

  tearDown(() => getIt.reset());

  Future<void> pump(WidgetTester tester, {AddressData? current}) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider<PickupAddressBloc>.value(
            value: bloc,
            child: PickupAddressPickerSheet(current: current),
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

    testWidgets(
      'reverseGeocode échoue à chaque tentative → « Adresse introuvable », '
      'jamais de repli sur les coordonnées brutes',
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
        ).thenAnswer(
          (_) async => Position(
            latitude: 48.8566,
            longitude: 2.3522,
            timestamp: DateTime.now(),
            accuracy: 5,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
        );
        when(
          () => service.reverseGeocode(any(), any()),
        ).thenThrow(Exception('502 bad gateway'));

        await pump(tester);
        await tester.tap(find.text('Utiliser ma position actuelle'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        verify(() => service.reverseGeocode(any(), any())).called(3);
        expect(find.text('Adresse introuvable'), findsOneWidget);
        expect(find.textContaining('Position GPS'), findsNothing);
      },
    );
  });

  group('adresses récentes — cache local', () {
    testWidgets(
      'une adresse mise en cache s\'affiche et se sélectionne sans appel API',
      (tester) async {
        // tester.runAsync() est obligatoire : une écriture Hive réelle
        // (dart:io) appelée directement dans le corps de testWidgets hang
        // sous l'horloge fake-async du binding de test (déjà vu sur Scan &
        // Suivi — cf. mémoire projet_scan_suivi_redesign).
        await tester.runAsync(() async {
          final prefsBox = Hive.box(HiveService.userPrefsBox);
          await prefsBox.put('recent_pickup_addresses', [
            {
              'label': '10 Rue de Rivoli, Paris',
              'lat': 48.8566,
              'lng': 2.3522,
              'street': null,
              'city': 'Paris',
              'postalCode': '75001',
              'country': 'FR',
            },
          ]);
        });

        await pump(tester);

        expect(find.text('RECHERCHES RÉCENTES'), findsOneWidget);
        expect(find.text('10 Rue de Rivoli, Paris'), findsOneWidget);

        await tester.tap(find.text('10 Rue de Rivoli, Paris'));
        await tester.pump();

        verifyNever(() => service.resolvePlace(any(), any()));
        verifyNever(() => service.search(any(), any()));

        // La sélection est une simple pré-sélection : le sheet reste ouvert,
        // seul le bouton « Confirmer cette adresse » referme le sheet.
        expect(find.text('RECHERCHES RÉCENTES'), findsOneWidget);
        expect(find.text('Confirmer cette adresse'), findsOneWidget);
      },
    );

    testWidgets(
      'la réouverture avec une adresse récente déjà confirmée la montre '
      'cochée sans action, pour ne pas se retromper',
      (tester) async {
        const previouslyChosen = AddressData(
          label: '10 Rue de Rivoli, Paris',
          lat: 48.8566,
          lng: 2.3522,
          city: 'Paris',
          postalCode: '75001',
          country: 'FR',
        );
        await tester.runAsync(() async {
          final prefsBox = Hive.box(HiveService.userPrefsBox);
          await prefsBox.put('recent_pickup_addresses', [
            previouslyChosen.toJson(),
          ]);
        });

        await pump(tester, current: previouslyChosen);

        expect(
          find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'check'),
          findsOneWidget,
        );
      },
    );
  });
}
