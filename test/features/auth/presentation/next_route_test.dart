import 'package:dony/features/auth/presentation/next_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeNextRoute', () {
    test('accepte un chemin interne', () {
      expect(sanitizeNextRoute('/trips/create'), '/trips/create');
      expect(sanitizeNextRoute('/trips/create?a=1'), '/trips/create?a=1');
    });

    for (final raw in [
      null,
      '',
      'trips/create',
      '//evil.com',
      '//evil.com/trips',
      'https://evil.com',
      'https:/evil.com',
      'javascript:alert(1)',
      r'/\evil.com',
      ' /trips/create',
    ]) {
      test('rejette ${raw ?? 'null'} et retombe sur /home', () {
        expect(sanitizeNextRoute(raw), '/home');
      });
    }
  });
}
