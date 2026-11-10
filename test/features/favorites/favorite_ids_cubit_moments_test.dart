import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../video_modal/moment_test_support.dart';

class _MockRepo extends Mock implements FavoriteRepository {}

/// Moment « trajet ajouté aux favoris » : seulement à l'ajout confirmé par le
/// serveur, avec le corridor du trajet.
void main() {
  late _MockRepo repo;
  late RecordingMoments moments;
  final corridor = VideoModalMomentCorridor(
    fromCity: 'Paris',
    toCity: 'Abidjan',
  );

  setUp(() {
    repo = _MockRepo();
    moments = useRecordingMoments();
  });

  test('ajout confirmé : un moment avec le corridor', () async {
    when(() => repo.add(any(), any())).thenAnswer((_) async {});
    final cubit = FavoriteIdsCubit(repo)..emitSeed(trips: {}, requests: {});
    await cubit.toggleTrip('t1', corridor: corridor);
    expect(moments.triggers, [VideoModalTrigger.favoriteAdded]);
    expect(moments.emitted.single.corridor, corridor);
  });

  test('ajout sans corridor connu : le moment part quand même', () async {
    when(() => repo.add(any(), any())).thenAnswer((_) async {});
    final cubit = FavoriteIdsCubit(repo)..emitSeed(trips: {}, requests: {});
    await cubit.toggleTrip('t1');
    expect(moments.emitted.single.corridor, isNull);
  });

  test('retrait : aucun moment', () async {
    when(() => repo.remove(any(), any())).thenAnswer((_) async {});
    final cubit = FavoriteIdsCubit(repo)..emitSeed(trips: {'t1'}, requests: {});
    await cubit.toggleTrip('t1', corridor: corridor);
    expect(moments.emitted, isEmpty);
  });

  test('échec du serveur (annulation de l\'ajout) : aucun moment', () async {
    when(() => repo.add(any(), any())).thenThrow(Exception('réseau'));
    final cubit = FavoriteIdsCubit(repo)..emitSeed(trips: {}, requests: {});
    await expectLater(
      cubit.toggleTrip('t1', corridor: corridor),
      throwsException,
    );
    expect(moments.emitted, isEmpty);
  });

  test(
    'favori de demande d\'envoi : aucun moment (trajet ou alerte seulement)',
    () async {
      when(() => repo.add(any(), any())).thenAnswer((_) async {});
      final cubit = FavoriteIdsCubit(repo)..emitSeed(trips: {}, requests: {});
      await cubit.toggleRequest('r1');
      expect(moments.emitted, isEmpty);
    },
  );
}
