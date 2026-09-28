import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('formatPlacemark : trois parties au plus, sans doublon ni vide', () {
    expect(
      ScanLocator.formatPlacemark(
        const Placemark(
          street: ' Rue 10 ',
          locality: 'Dakar',
          administrativeArea: 'Dakar',
          country: 'Sénégal',
        ),
      ),
      'Rue 10, Dakar, Sénégal',
    );
    expect(ScanLocator.formatPlacemark(const Placemark(street: '  ')), isNull);
  });

  test('toExifDms : degrés, minutes, centièmes de seconde', () {
    expect(ScanLocator.toExifDms(14.5), '14/1,30/1,0/100');
    expect(ScanLocator.toExifDms(0.01), '0/1,0/1,3600/100');
  });

  test(
    'sans plugin de localisation : pas de position, pas d\'erreur',
    () async {
      expect(await const ScanLocator().capture(), isNull);
      await const ScanLocator().writeExif(
        '/tmp/inexistant.jpg',
        const ScanPosition(lat: 1, lon: 2),
      );
    },
  );
}
