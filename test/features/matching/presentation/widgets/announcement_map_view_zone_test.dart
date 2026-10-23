import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_google_maps_platform.dart';
import '../../../../helpers/l10n_test_helpers.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockLocationService extends Mock implements LocationService {}

AnnouncementModel _ann(String id, double lat, double lng) => AnnouncementModel(
  id: id,
  travelerId: 't1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  arrivalCountryCode: 'SN',
  departureDate: DateTime(2026, 6, 15),
  availableKg: 8,
  totalKg: 8,
  pricePerKg: 12,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  pickupAddress: AddressData(label: id, lat: lat, lng: lng),
);

/// Service de localisation refusé : la carte ne tente aucune position.
LocationService _denied() {
  final svc = _MockLocationService();
  when(() => svc.isLocationServiceEnabled()).thenAnswer((_) async => false);
  return svc;
}

void main() {
  late FakeGoogleMapsPlatform platform;
  late GoogleMapsFlutterPlatform previous;

  setUp(() {
    previous = GoogleMapsFlutterPlatform.instance;
    platform = FakeGoogleMapsPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
  });
  tearDown(() => GoogleMapsFlutterPlatform.instance = previous);

  /// Fin de mouvement de caméra, puis laisse les futures de la plateforme se
  /// vider en vrai temps (la lecture de la région visible est asynchrone).
  Future<void> idle(WidgetTester tester) async {
    platform.emitCameraIdle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }

  Future<void> pump(
    WidgetTester tester, {
    List<AnnouncementModel>? announcements,
    int fitAllSignal = 0,
    ValueChanged<bool>? onZoneEmptyChanged,
    VoidCallback? onMapTapped,
    LatLng? previewCenter,
    double? previewRadiusKm,
    String? currentUserId,
  }) async {
    final auth = _MockAuthBloc();
    when(() => auth.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(
      localizedApp(
        BlocProvider<AuthBloc>.value(
          value: auth,
          child: Scaffold(
            body: AnnouncementMapView(
              announcements: announcements ?? [_ann('a1', 48.85, 2.35)],
              locationService: _denied(),
              fitAllSignal: fitAllSignal,
              onZoneEmptyChanged: onZoneEmptyChanged,
              onMapTapped: onMapTapped,
              previewCenter: previewCenter,
              previewRadiusKm: previewRadiusKm,
              currentUserId: currentUserId,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('zone visible sans trajet', () {
    testWidgets('signale une zone vide, puis de nouveau pleine', (
      tester,
    ) async {
      final signals = <bool>[];
      await pump(tester, onZoneEmptyChanged: signals.add);

      // Région qui contient Paris : rien à signaler.
      await idle(tester);
      expect(signals, isEmpty);

      // Région au large du Pacifique : plus aucun trajet visible.
      platform.visibleRegion = LatLngBounds(
        southwest: const LatLng(-10, -170),
        northeast: const LatLng(10, -150),
      );
      await idle(tester);
      expect(signals, [true]);

      // Un second relevé identique ne répète pas le signal.
      await idle(tester);
      expect(signals, [true]);

      // Retour sur Paris.
      platform.visibleRegion = LatLngBounds(
        southwest: const LatLng(40, 0),
        northeast: const LatLng(50, 10),
      );
      await idle(tester);
      expect(signals, [true, false]);
    });

    testWidgets('une région qui franchit l\'antiméridien est bien lue', (
      tester,
    ) async {
      final signals = <bool>[];
      await pump(
        tester,
        announcements: [_ann('fiji', -17.7, 178.0)],
        onZoneEmptyChanged: signals.add,
      );

      // De 170° E à 170° O, en passant par 180° : Fidji (178° E) est dedans.
      platform.visibleRegion = LatLngBounds(
        southwest: const LatLng(-30, 170),
        northeast: const LatLng(-10, -170),
      );
      await idle(tester);
      expect(signals, isEmpty);

      // Même région côté ouest du globe : Fidji en est exclu.
      platform.visibleRegion = LatLngBounds(
        southwest: const LatLng(-30, -60),
        northeast: const LatLng(-10, -40),
      );
      await idle(tester);
      expect(signals, [true]);
    });

    testWidgets('aucun trajet chargé : jamais de zone vide à signaler', (
      tester,
    ) async {
      final signals = <bool>[];
      await pump(
        tester,
        announcements: const [],
        onZoneEmptyChanged: signals.add,
      );

      platform.visibleRegion = LatLngBounds(
        southwest: const LatLng(-10, -170),
        northeast: const LatLng(10, -150),
      );
      await idle(tester);
      expect(signals, isEmpty);
    });
  });

  group('recadrage et tap', () {
    testWidgets('fitAllSignal recadre la carte sur tous les trajets', (
      tester,
    ) async {
      await pump(tester);
      final avant = platform.cameraUpdates.length;

      await pump(tester, fitAllSignal: 1);
      await tester.pump();

      expect(platform.cameraUpdates.length, greaterThan(avant));
    });

    testWidgets('un tap sur la carte appelle onMapTapped', (tester) async {
      var taps = 0;
      await pump(tester, onMapTapped: () => taps++);

      tester.widget<GoogleMap>(find.byType(GoogleMap)).onTap!(
        const LatLng(0, 0),
      );

      expect(taps, 1);
    });
  });

  group('aperçu du rayon', () {
    testWidgets('trace le cercle d\'aperçu avant l\'activation du filtre', (
      tester,
    ) async {
      await pump(
        tester,
        previewCenter: const LatLng(48.85, 2.35),
        previewRadiusKm: 30,
      );

      final cercles = tester.widget<GoogleMap>(find.byType(GoogleMap)).circles;
      expect(cercles, hasLength(1));
      expect(cercles.single.center, const LatLng(48.85, 2.35));
      expect(cercles.single.radius, 30000);
    });

    testWidgets('sans aperçu ni filtre, aucun cercle', (tester) async {
      await pump(tester);
      expect(tester.widget<GoogleMap>(find.byType(GoogleMap)).circles, isEmpty);
    });

    testWidgets('un nouveau rayon d\'aperçu recadre la carte sur le cercle', (
      tester,
    ) async {
      await pump(
        tester,
        previewCenter: const LatLng(48.85, 2.35),
        previewRadiusKm: 30,
      );
      final avant = platform.cameraUpdates.length;

      await pump(
        tester,
        previewCenter: const LatLng(48.85, 2.35),
        previewRadiusKm: 80,
      );
      await tester.pump();

      expect(platform.cameraUpdates.length, greaterThan(avant));
    });
  });

  testWidgets(
    'son propre trajet : la carte se reconstruit avec l\'utilisateur',
    (tester) async {
      await pump(tester);
      await pump(tester, currentUserId: 't1');

      expect(tester.takeException(), isNull);
      expect(find.byType(GoogleMap), findsOneWidget);
    },
  );
}
