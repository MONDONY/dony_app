import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_summary_cubit.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCorridorAlertRepository extends Mock
    implements CorridorAlertRepository {}

CorridorAlertModel _alert(
  String id,
  String from,
  String to, {
  int fresh = 0,
  bool active = true,
  DateTime? dateTo,
  AlertDirection direction = AlertDirection.senderWantsTrips,
}) => CorridorAlertModel(
  id: id,
  departureCity: from,
  arrivalCity: to,
  active: active,
  matchCount: fresh + 3,
  newMatchCount: fresh,
  dateTo: dateTo,
  direction: direction,
  createdAt: DateTime(2026, 6, 20),
);

void main() {
  final now = DateTime(2026, 9, 4);

  group('CorridorAlertSummaryState.fromAlerts', () {
    test('cumule les nouveautés et classe les corridors par volume', () {
      final s = CorridorAlertSummaryState.fromAlerts([
        _alert('a', 'Lyon', 'Abidjan', fresh: 1),
        _alert('b', 'Paris', 'Dakar', fresh: 2),
        _alert('c', 'Marseille', 'Bamako'),
      ], now: now);

      expect(s.isLoaded, isTrue);
      expect(s.hasNews, isTrue);
      expect(s.newMatchCount, 3);
      expect(s.newCorridors, ['Paris → Dakar', 'Lyon → Abidjan']);
    });

    test('ignore les alertes en pause et expirées', () {
      final s = CorridorAlertSummaryState.fromAlerts([
        _alert('a', 'Lyon', 'Abidjan', fresh: 4, active: false),
        _alert('b', 'Paris', 'Dakar', fresh: 2, dateTo: DateTime(2026, 8, 31)),
        _alert('c', 'Paris', 'Douala', fresh: 1),
      ], now: now);

      expect(s.newMatchCount, 1);
      expect(s.newCorridors, ['Paris → Douala']);
    });

    test('un corridor guetté dans les deux sens ne compte qu\'une fois', () {
      final s = CorridorAlertSummaryState.fromAlerts([
        _alert('a', 'Paris', 'Dakar', fresh: 2),
        _alert(
          'b',
          'Paris',
          'Dakar',
          fresh: 1,
          direction: AlertDirection.travelerWantsPackages,
        ),
      ], now: now);

      expect(s.newMatchCount, 3);
      expect(s.newCorridors, ['Paris → Dakar']);
    });

    test('rien de neuf → loaded sans signal', () {
      final s = CorridorAlertSummaryState.fromAlerts([
        _alert('c', 'Marseille', 'Bamako'),
      ], now: now);
      expect(s.isLoaded, isTrue);
      expect(s.hasNews, isFalse);
      expect(s.newCorridors, isEmpty);
    });
  });

  group('CorridorAlertSummaryCubit', () {
    late MockCorridorAlertRepository repo;

    setUp(() => repo = MockCorridorAlertRepository());

    blocTest<CorridorAlertSummaryCubit, CorridorAlertSummaryState>(
      'load → loading puis résumé',
      build: () => CorridorAlertSummaryCubit(repo),
      setUp: () => when(
        () => repo.getMyAlerts(),
      ).thenAnswer((_) async => [_alert('b', 'Paris', 'Dakar', fresh: 2)]),
      act: (c) => c.load(),
      expect: () => [
        const CorridorAlertSummaryState.loading(),
        isA<CorridorAlertSummaryState>()
            .having((s) => s.hasNews, 'hasNews', isTrue)
            .having((s) => s.newMatchCount, 'newMatchCount', 2),
      ],
    );

    blocTest<CorridorAlertSummaryCubit, CorridorAlertSummaryState>(
      'échec réseau → hidden, jamais un faux « rien de neuf »',
      build: () => CorridorAlertSummaryCubit(repo),
      setUp: () => when(() => repo.getMyAlerts()).thenThrow(Exception('down')),
      act: (c) => c.load(),
      expect: () => [
        const CorridorAlertSummaryState.loading(),
        const CorridorAlertSummaryState.hidden(),
      ],
    );

    blocTest<CorridorAlertSummaryCubit, CorridorAlertSummaryState>(
      'rechargement : pas de loading intermédiaire une fois chargé',
      build: () => CorridorAlertSummaryCubit(repo),
      setUp: () => when(() => repo.getMyAlerts()).thenAnswer((_) async => []),
      act: (c) async {
        await c.load();
        await c.load();
      },
      expect: () => [
        const CorridorAlertSummaryState.loading(),
        isA<CorridorAlertSummaryState>().having(
          (s) => s.isLoaded,
          'loaded',
          isTrue,
        ),
      ],
    );
  });
}
