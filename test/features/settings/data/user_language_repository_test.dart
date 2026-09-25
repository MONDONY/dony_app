import 'package:dony/features/settings/data/datasources/user_language_remote_datasource.dart';
import 'package:dony/features/settings/data/repositories/user_language_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUserLanguageRemoteDatasource extends Mock
    implements UserLanguageRemoteDatasource {}

void main() {
  late MockUserLanguageRemoteDatasource datasource;
  late UserLanguageRepository repository;

  setUp(() {
    datasource = MockUserLanguageRemoteDatasource();
    repository = UserLanguageRepository(datasource);
  });

  group('update', () {
    test('délègue à la datasource et renvoie true en cas de succès', () async {
      when(() => datasource.update('en')).thenAnswer((_) async => true);

      final result = await repository.update('en');

      expect(result, isTrue);
      verify(() => datasource.update('en')).called(1);
    });

    test('renvoie false sans relancer (backend ancien, route 404)', () async {
      when(() => datasource.update('fr')).thenAnswer((_) async => false);

      final result = await repository.update('fr');

      expect(result, isFalse);
      verify(() => datasource.update('fr')).called(1);
    });
  });
}
