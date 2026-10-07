import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockLocationService extends Mock implements LocationService {}

_MockLocationService _service({required bool granted}) {
  final s = _MockLocationService();
  when(() => s.isLocationServiceEnabled()).thenAnswer((_) async => true);
  when(() => s.checkPermission()).thenAnswer(
    (_) async =>
        granted ? LocationPermission.whileInUse : LocationPermission.denied,
  );
  when(
    () => s.requestPermission(),
  ).thenAnswer((_) async => LocationPermission.denied);
  // Position introuvable : la carte retombe sur son cadrage par défaut.
  when(() => s.getCurrentPosition()).thenThrow(Exception('pas de GPS'));
  return s;
}

Widget _map(LocationService service, {bool isNearMeActive = false}) =>
    localizedApp(
      Scaffold(
        body: AnnouncementMapView(
          announcements: const [],
          locationService: service,
          isNearMeActive: isNearMeActive,
          onNearMeToggle: () {},
        ),
      ),
    );

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(AppL10n.fr);
  });

  group('mapNoticeMessage (FLUTTER-CD)', () {
    test('tout va bien : aucun message', () {
      expect(
        mapNoticeMessage(
          l,
          mapUnavailable: false,
          locationAccess: LocationAccess.granted,
        ),
        isNull,
      );
      expect(
        mapNoticeMessage(l, mapUnavailable: false, locationAccess: null),
        isNull,
      );
    });

    test('localisation refusée ou coupée : la carte montre tout', () {
      for (final access in [
        LocationAccess.denied,
        LocationAccess.deniedForever,
        LocationAccess.serviceDisabled,
      ]) {
        expect(
          mapNoticeMessage(l, mapUnavailable: false, locationAccess: access),
          l.listingMapLocationOff,
        );
      }
    });

    test('carte indisponible : ce message prime', () {
      expect(
        mapNoticeMessage(
          l,
          mapUnavailable: true,
          locationAccess: LocationAccess.denied,
        ),
        l.listingMapUnavailable,
      );
    });
  });

  group('AnnouncementMapView — message de la carte (FLUTTER-CD)', () {
    testWidgets('position refusée : message discret, fermable', (tester) async {
      await tester.pumpWidget(_map(_service(granted: false)));
      await tester.pumpAndSettle();

      expect(find.text(l.listingMapLocationOff), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-notice-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-notice')), findsNothing);
    });

    testWidgets('position accordée : aucun message', (tester) async {
      await tester.pumpWidget(_map(_service(granted: true)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-notice')), findsNothing);
    });

    testWidgets('carte jamais créée : « la carte ne se charge pas »', (
      tester,
    ) async {
      await tester.pumpWidget(_map(_service(granted: true)));
      await tester.pumpAndSettle();
      expect(find.text(l.listingMapUnavailable), findsNothing);

      await tester.pump(kMapLoadTimeout);
      await tester.pumpAndSettle();

      expect(find.text(l.listingMapUnavailable), findsOneWidget);
    });

    testWidgets('« Près de moi » actif : pas de message sur la carte', (
      tester,
    ) async {
      await tester.pumpWidget(
        _map(_service(granted: false), isNearMeActive: true),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-notice')), findsNothing);
    });
  });
}
