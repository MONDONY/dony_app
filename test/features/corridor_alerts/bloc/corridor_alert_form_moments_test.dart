import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_form_cubit.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../video_modal/moment_test_support.dart';

class _MockRepo extends Mock implements CorridorAlertRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

CorridorAlertModel _alert() => CorridorAlertModel(
  id: 'a1',
  departureCity: 'Paris',
  arrivalCity: 'Bamako',
  active: true,
  createdAt: DateTime(2026, 6, 20),
);

/// Une alerte de corridor créée est un « favori » : moment avec son corridor.
void main() {
  late _MockRepo repo;
  late RecordingMoments moments;

  setUpAll(() {
    registerFallbackValue(
      const CorridorAlertDraft(departureCity: 'x', arrivalCity: 'y'),
    );
  });

  setUp(() {
    repo = _MockRepo();
    moments = useRecordingMoments();
  });

  CorridorAlertFormCubit build({CorridorAlertModel? editing}) {
    final analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    return CorridorAlertFormCubit(repo, analytics, editing: editing);
  }

  test('création : un moment « favori ajouté » avec villes et pays', () async {
    when(() => repo.create(any())).thenAnswer((_) async => _alert());
    final c = build()
      ..setDeparture(' Paris ', 'FR')
      ..setArrival('Bamako', 'ML');
    await c.submit();
    expect(moments.triggers, [VideoModalTrigger.favoriteAdded]);
    final corridor = moments.emitted.single.corridor!;
    expect(
      const VideoModalCorridor(from: 'france', to: 'mali').matches(corridor),
      isTrue,
    );
    expect(
      const VideoModalCorridor(from: 'paris', to: 'bamako').matches(corridor),
      isTrue,
    );
  });

  test('modification d\'une alerte : aucun moment', () async {
    when(() => repo.update('a1', any())).thenAnswer((_) async => _alert());
    await build(editing: _alert()).submit();
    expect(moments.emitted, isEmpty);
  });

  test('échec de la création : aucun moment', () async {
    when(() => repo.create(any())).thenThrow(Exception('422'));
    final c = build()
      ..setDeparture('Paris', 'FR')
      ..setArrival('Bamako', 'ML');
    await c.submit();
    expect(moments.emitted, isEmpty);
  });

  test('formulaire invalide : rien n\'est envoyé, aucun moment', () async {
    await build().submit();
    expect(moments.emitted, isEmpty);
  });
}
