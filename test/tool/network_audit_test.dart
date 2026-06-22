import 'package:test/test.dart';
import '../../tool/network_audit.dart';

void main() {
  test('détecte Image.network', () {
    final f = auditSource('a.dart', "Widget b() => Image.network(url);");
    expect(f.any((e) => e.rule == 'image_network'), isTrue);
  });
  test('détecte un appel réseau dans une boucle (N+1)', () {
    final f = auditSource('b.dart', '''
for (final id in ids) { await _apiClient.dio.get('/x/\$id'); }
''');
    expect(f.any((e) => e.rule == 'loop_request'), isTrue);
  });
  test('code propre = aucun finding', () {
    final f = auditSource('c.dart', "final x = 1;");
    expect(f, isEmpty);
  });
}
