import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dony/features/connectivity/data/connectivity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  late MockDio dio;
  late MockConnectivity connectivity;
  late ConnectivityRepository repository;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = MockDio();
    connectivity = MockConnectivity();
    repository = ConnectivityRepository(connectivity, dio);
  });

  group('hasConnection()', () {
    test('true dès qu\'une interface est != none', () async {
      when(() => connectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.none, ConnectivityResult.wifi],
      );
      expect(await repository.hasConnection(), isTrue);
    });

    test('false quand toutes les interfaces sont none', () async {
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);
      expect(await repository.hasConnection(), isFalse);
    });
  });

  group('onHasConnectionChanged', () {
    test('mappe le flux brut en booléen agrégé', () {
      when(() => connectivity.onConnectivityChanged).thenAnswer(
        (_) => Stream.fromIterable([
          [ConnectivityResult.wifi],
          [ConnectivityResult.none],
          [ConnectivityResult.mobile, ConnectivityResult.none],
        ]),
      );
      expect(
        repository.onHasConnectionChanged,
        emitsInOrder([true, false, true]),
      );
    });
  });

  group('isApiResponsive()', () {
    test('true quand le ping /actuator/health répond', () async {
      when(() => dio.get(any(), options: any(named: 'options')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/actuator/health'),
                statusCode: 200,
              ));
      expect(await repository.isApiResponsive(), isTrue);
    });

    test('false quand le ping time out', () async {
      when(() => dio.get(any(), options: any(named: 'options'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/actuator/health'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(await repository.isApiResponsive(), isFalse);
    });

    test('false quand le ping échoue (erreur serveur)', () async {
      when(() => dio.get(any(), options: any(named: 'options')))
          .thenThrow(Exception('boom'));
      expect(await repository.isApiResponsive(), isFalse);
    });
  });
}
