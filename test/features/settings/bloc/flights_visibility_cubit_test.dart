import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/flights_visibility_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockBox extends Mock implements Box<dynamic> {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

/// Box Hive en mémoire : ce qui est écrit est relu par un nouveau cubit,
/// comme après un redémarrage de l'app.
_MockBox _memoryBox(Map<dynamic, dynamic> store) {
  final box = _MockBox();
  when(
    () => box.get(any(), defaultValue: any(named: 'defaultValue')),
  ).thenAnswer(
    (inv) => store.containsKey(inv.positionalArguments.first)
        ? store[inv.positionalArguments.first]
        : inv.namedArguments[#defaultValue],
  );
  when(() => box.put(any(), any())).thenAnswer((inv) async {
    store[inv.positionalArguments[0]] = inv.positionalArguments[1];
  });
  return box;
}

void main() {
  late Map<dynamic, dynamic> store;
  late _MockBox box;
  late _MockAnalyticsService analytics;

  setUp(() {
    store = {};
    box = _memoryBox(store);
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  test('par défaut, les billets sont visibles', () async {
    final cubit = FlightsVisibilityCubit(box, analytics);
    expect(cubit.state, isTrue);
    await cubit.close();
  });

  test('masquer : état, écriture Hive et événement analytics', () async {
    final cubit = FlightsVisibilityCubit(box, analytics);
    await cubit.setVisible(false);

    expect(cubit.state, isFalse);
    expect(store[HiveService.kFlightsVisible], isFalse);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.settingsFlightsVisibilityChanged,
        properties: {'visible': false},
      ),
    ).called(1);
    await cubit.close();
  });

  test('la préférence est relue par un nouveau cubit', () async {
    final first = FlightsVisibilityCubit(box, analytics);
    await first.setVisible(false);
    await first.close();

    final second = FlightsVisibilityCubit(box, analytics);
    expect(second.state, isFalse);

    await second.setVisible(true);
    expect(second.state, isTrue);
    expect(store[HiveService.kFlightsVisible], isTrue);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.settingsFlightsVisibilityChanged,
        properties: {'visible': true},
      ),
    ).called(1);
    await second.close();
  });

  test('même valeur : ni écriture ni événement', () async {
    final cubit = FlightsVisibilityCubit(box, analytics);
    await cubit.setVisible(true);

    verifyNever(() => box.put(any(), any()));
    verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    );
    await cubit.close();
  });
}
