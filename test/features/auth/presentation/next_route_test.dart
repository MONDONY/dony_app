import 'package:dony/features/auth/presentation/next_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeNextRoute', () {
    test('accepte un chemin interne', () {
      expect(sanitizeNextRoute('/trips/create'), '/trips/create');
      expect(sanitizeNextRoute('/trips/create?a=1'), '/trips/create?a=1');
    });

    test('documente le comportement actuel sur les formes ambiguës', () {
      // Chemins internes valides : acceptés tels quels.
      expect(sanitizeNextRoute('/%5Cevil'), '/%5Cevil');
      expect(sanitizeNextRoute('/trips/create#frag'), '/trips/create#frag');
      // Espace blanc interne : go_router le traite comme un chemin, pas un hôte.
      expect(sanitizeNextRoute('/a\tb'), '/a\tb');
      expect(sanitizeNextRoute('/a\nb'), '/a\nb');
    });

    for (final raw in [
      null,
      '/auth/country-selection',
      '/auth/country-selection?next=%2Ftrips%2Fcreate',
      '/auth/country-selection/',
      '/auth/country-selection#x',
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
