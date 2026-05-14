import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/config/bloc/config_bloc.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConfigRepository extends Mock implements IConfigRepository {}

void main() {
  late MockConfigRepository mockRepo;

  setUp(() {
    mockRepo = MockConfigRepository();
  });

  ConfigBloc buildBloc() => ConfigBloc(mockRepo);

  group('ConfigBloc', () {
    test('initial state is ConfigInitial', () {
      expect(buildBloc().state, isA<ConfigInitial>());
    });

    group('ConfigCommissionRateRequested', () {
      blocTest<ConfigBloc, ConfigState>(
        'emits [ConfigLoading, ConfigLoaded] on success',
        build: buildBloc,
        setUp: () {
          when(() => mockRepo.getCommissionRate())
              .thenAnswer((_) async => 0.12);
        },
        act: (bloc) => bloc.add(const ConfigCommissionRateRequested()),
        expect: () => [
          isA<ConfigLoading>(),
          isA<ConfigLoaded>().having(
            (s) => s.commissionRate,
            'commissionRate',
            0.12,
          ),
        ],
      );

      blocTest<ConfigBloc, ConfigState>(
        'emits [ConfigLoading, ConfigLoaded] with custom rate',
        build: buildBloc,
        setUp: () {
          when(() => mockRepo.getCommissionRate())
              .thenAnswer((_) async => 0.10);
        },
        act: (bloc) => bloc.add(const ConfigCommissionRateRequested()),
        expect: () => [
          isA<ConfigLoading>(),
          isA<ConfigLoaded>().having(
            (s) => s.commissionRate,
            'commissionRate',
            0.10,
          ),
        ],
      );

      blocTest<ConfigBloc, ConfigState>(
        'emits [ConfigLoading, ConfigError] on failure',
        build: buildBloc,
        setUp: () {
          when(() => mockRepo.getCommissionRate())
              .thenThrow(Exception('Network error'));
        },
        act: (bloc) => bloc.add(const ConfigCommissionRateRequested()),
        expect: () => [
          isA<ConfigLoading>(),
          isA<ConfigError>(),
        ],
      );

      blocTest<ConfigBloc, ConfigState>(
        'ConfigError contains error message',
        build: buildBloc,
        setUp: () {
          when(() => mockRepo.getCommissionRate())
              .thenThrow(Exception('Server down'));
        },
        act: (bloc) => bloc.add(const ConfigCommissionRateRequested()),
        expect: () => [
          isA<ConfigLoading>(),
          isA<ConfigError>().having(
            (s) => s.error.message,
            'message',
            contains('Server down'),
          ),
        ],
      );
    });
  });
}
