import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const _geolocator = MethodChannel('flutter.baseflow.com/geolocator');
const _exif = MethodChannel('native_exif');

class _FakeGeocoding extends GeocodingPlatform with MockPlatformInterfaceMixin {
  List<Placemark> places = const [];
  Object? error;

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    if (error case final e?) throw e;
    return places;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late _FakeGeocoding geocoding;
  late List<MethodCall> geoCalls;
  late List<MethodCall> exifCalls;
  late Map<String, Object? Function()> geoAnswers;

  setUp(() {
    geocoding = _FakeGeocoding();
    GeocodingPlatform.instance = geocoding;
    geoCalls = [];
    exifCalls = [];
    geoAnswers = {};
    messenger.setMockMethodCallHandler(_geolocator, (call) async {
      geoCalls.add(call);
      final answer = geoAnswers[call.method];
      if (answer == null) throw MissingPluginException();
      return answer();
    });
    messenger.setMockMethodCallHandler(_exif, (call) async {
      exifCalls.add(call);
      return call.method == 'initPath' ? 7 : null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_geolocator, null);
    messenger.setMockMethodCallHandler(_exif, null);
  });

  Map<String, Object> position(double lat, double lon) => {
    'latitude': lat,
    'longitude': lon,
    'timestamp': 0,
  };

  group('captureCoordinates', () {
    test('permission refusée : aucune position, aucun relevé', () async {
      geoAnswers['requestPermission'] = () => 0; // denied
      expect(await const ScanLocator().captureCoordinates(), isNull);
      expect(geoCalls.map((c) => c.method), ['requestPermission']);
    });

    test('relevé frais quand la permission est accordée', () async {
      geoAnswers['requestPermission'] = () => 2; // whileInUse
      geoAnswers['getCurrentPosition'] = () => position(14.7, -17.4);

      final p = await const ScanLocator().captureCoordinates();

      expect(p, isNotNull);
      expect(p!.lat, 14.7);
      expect(p.lon, -17.4);
      expect(p.label, isNull);
    });

    test('relevé en échec : repli sur la dernière position connue', () async {
      geoAnswers['requestPermission'] = () => 3; // always
      geoAnswers['getCurrentPosition'] = () =>
          throw PlatformException(code: 'TIMEOUT');
      geoAnswers['getLastKnownPosition'] = () => position(48.8, 2.3);

      final p = await const ScanLocator().captureCoordinates();

      expect(p!.lat, 48.8);
      expect(geoCalls.map((c) => c.method), contains('getLastKnownPosition'));
    });

    test('ni relevé ni dernière position : null', () async {
      geoAnswers['requestPermission'] = () => 2;
      geoAnswers['getCurrentPosition'] = () =>
          throw PlatformException(code: 'TIMEOUT');
      geoAnswers['getLastKnownPosition'] = () => null;

      expect(await const ScanLocator().captureCoordinates(), isNull);
    });
  });

  group('captureCoordinatesIfGranted', () {
    test('permission non accordée : null, sans jamais la demander', () async {
      geoAnswers['checkPermission'] = () => 0; // denied
      expect(await const ScanLocator().captureCoordinatesIfGranted(), isNull);
      expect(await const ScanLocator().isPermissionGranted(), isFalse);
      expect(
        geoCalls.map((c) => c.method),
        isNot(contains('requestPermission')),
      );
    });

    test('permission accordée : relevé frais, sans demande', () async {
      geoAnswers['checkPermission'] = () => 2; // whileInUse
      geoAnswers['getCurrentPosition'] = () => position(14.7, -17.4);
      final p = await const ScanLocator().captureCoordinatesIfGranted();
      expect(p!.lat, 14.7);
      expect(await const ScanLocator().isPermissionGranted(), isTrue);
      expect(
        geoCalls.map((c) => c.method),
        isNot(contains('requestPermission')),
      );
    });

    test('relevé en échec : dernière position connue', () async {
      geoAnswers['checkPermission'] = () => 3; // always
      geoAnswers['getCurrentPosition'] = () =>
          throw PlatformException(code: 'TIMEOUT');
      geoAnswers['getLastKnownPosition'] = () => position(48.8, 2.3);
      final p = await const ScanLocator().captureCoordinatesIfGranted();
      expect(p!.lat, 48.8);
    });

    test('plugin absent : null, pas d\'erreur', () async {
      expect(await const ScanLocator().captureCoordinatesIfGranted(), isNull);
      expect(await const ScanLocator().isPermissionGranted(), isFalse);
    });
  });

  group('capture / resolveLabel', () {
    test('ajoute le lieu lisible issu du géocodage inverse', () async {
      geoAnswers['requestPermission'] = () => 2;
      geoAnswers['getCurrentPosition'] = () => position(14.7, -17.4);
      geocoding.places = const [
        Placemark(street: 'Rue 10', locality: 'Dakar', country: 'Sénégal'),
      ];

      final p = await const ScanLocator().capture();

      expect(p!.label, 'Rue 10, Dakar, Sénégal');
      expect(p.lat, 14.7);
    });

    test('sans permission, capture rend null', () async {
      geoAnswers['requestPermission'] = () => 1; // deniedForever
      expect(await const ScanLocator().capture(), isNull);
    });

    test('aucun lieu trouvé : label null', () async {
      geocoding.places = const [];
      final p = await const ScanLocator().resolveLabel(
        const ScanPosition(lat: 1, lon: 2, label: 'ancien'),
      );
      expect(p.label, isNull);
      expect(p.lat, 1);
    });

    test('géocodage en erreur : label null, pas d’exception', () async {
      geocoding.error = PlatformException(code: 'NETWORK');
      final p = await const ScanLocator().resolveLabel(
        const ScanPosition(lat: 1, lon: 2),
      );
      expect(p.label, isNull);
    });
  });

  group('writeExif', () {
    test('inscrit latitude/longitude et leurs hémisphères', () async {
      await const ScanLocator().writeExif(
        '/tmp/photo.jpg',
        const ScanPosition(lat: -14.5, lon: 2.5),
      );

      expect(exifCalls.map((c) => c.method), [
        'initPath',
        'setAttributes',
        'close',
      ]);
      expect(exifCalls.first.arguments, '/tmp/photo.jpg');
      final args = exifCalls[1].arguments as Map;
      expect(args['id'], 7);
      expect(args['values'], {
        'GPSLatitude': '14/1,30/1,0/100',
        'GPSLatitudeRef': 'S',
        'GPSLongitude': '2/1,30/1,0/100',
        'GPSLongitudeRef': 'E',
      });
    });

    test('hémisphères nord et ouest', () async {
      await const ScanLocator().writeExif(
        '/tmp/photo.jpg',
        const ScanPosition(lat: 14.5, lon: -17.25),
      );
      final values = (exifCalls[1].arguments as Map)['values'] as Map;
      expect(values['GPSLatitudeRef'], 'N');
      expect(values['GPSLongitudeRef'], 'W');
    });

    test('un échec EXIF est ignoré', () async {
      messenger.setMockMethodCallHandler(_exif, (call) async {
        throw PlatformException(code: 'IO');
      });
      await expectLater(
        const ScanLocator().writeExif(
          '/tmp/x.jpg',
          const ScanPosition(lat: 0, lon: 0),
        ),
        completes,
      );
    });
  });
}
