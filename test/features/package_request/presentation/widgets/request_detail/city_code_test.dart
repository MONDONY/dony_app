import 'package:dony/features/package_request/presentation/widgets/request_detail/city_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trois premières lettres en majuscules', () {
    expect(cityCode('Divo'), 'DIV');
    expect(cityCode('Annemasse'), 'ANN');
  });
  test('accents et ponctuation retirés', () {
    expect(cityCode('Épinal'), 'EPI');
    expect(cityCode("N'Djamena"), 'NDJ');
  });
  test('suffixe aéroport ignoré', () {
    expect(cityCode('Paris · CDG, ORY'), 'PAR');
  });
  test('nom court ou vide', () {
    expect(cityCode('Aÿ'), 'AY');
    expect(cityCode(''), '···');
  });
}
