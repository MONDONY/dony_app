import 'package:dony/features/ai_form_draft/data/ai_text_fold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('minuscules, sans accents ni espaces en trop', () {
    expect(foldForMatch('  Vêtements  '), 'vetements');
    expect(foldForMatch('CÔTE D’IVOIRE'), 'cote d ivoire');
    expect(foldForMatch('Saint-Louis'), 'saint louis');
    expect(foldForMatch('Œuvres  d’art'), 'oeuvres d art');
    expect(foldForMatch('Douala'), 'douala');
  });
}
