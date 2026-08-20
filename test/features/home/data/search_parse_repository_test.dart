import 'package:dony/features/home/data/datasources/search_parse_datasource.dart';
import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/data/repositories/search_parse_repository.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSearchParseDatasource extends Mock implements SearchParseDatasource {}

void main() {
  late MockSearchParseDatasource mockDatasource;
  late SearchParseRepository repository;

  setUp(() {
    mockDatasource = MockSearchParseDatasource();
    repository = SearchParseRepository(mockDatasource);
  });

  group('SearchParseRepository.parse', () {
    test('délègue au datasource avec le même texte et le même mode', () async {
      const expected = SearchParseResult(
        filters: {'arrivalCity': 'Abidjan'},
        recognized: [],
        unresolved: [],
      );
      when(
        () => mockDatasource.parse('vers Abidjan', SearchMode.trips),
      ).thenAnswer((_) async => expected);

      final result = await repository.parse('vers Abidjan', SearchMode.trips);

      expect(result, same(expected));
      verify(
        () => mockDatasource.parse('vers Abidjan', SearchMode.trips),
      ).called(1);
    });

    test('propage l\'erreur du datasource sans la transformer', () async {
      when(
        () => mockDatasource.parse('x', SearchMode.parcels),
      ).thenThrow(Exception('boom'));

      expect(
        () => repository.parse('x', SearchMode.parcels),
        throwsA(isA<Exception>()),
      );
    });
  });
}
