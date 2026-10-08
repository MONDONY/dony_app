import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/matching/bloc/pinned_trips_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockBox extends Mock implements Box<dynamic> {}

AnnouncementModel _trip(String id, {String status = 'ACTIVE'}) =>
    AnnouncementModel(
      id: id,
      travelerId: 't',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 11),
      availableKg: 10,
      totalKg: 23,
      pricePerKg: 8,
      status: status,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// Épinglage de « Mes trajets » (FLUTTER-FS).
void main() {
  late _MockBox box;

  setUp(() {
    box = _MockBox();
    when(() => box.put(any(), any())).thenAnswer((_) async {});
  });

  test('relit les épingles enregistrées sur l\'appareil', () {
    when(() => box.get(HiveService.kPinnedTripIds)).thenReturn(['a', 'b']);
    final cubit = PinnedTripsCubit(box);
    expect(cubit.state.ids, {'a', 'b'});
  });

  test('valeur absente ou illisible : aucune épingle, sans planter', () {
    when(() => box.get(HiveService.kPinnedTripIds)).thenReturn('oups');
    expect(PinnedTripsCubit(box).state.ids, isEmpty);
    when(() => box.get(HiveService.kPinnedTripIds)).thenThrow(StateError('x'));
    expect(PinnedTripsCubit(box).state.ids, isEmpty);
  });

  test('toggle épingle puis désépingle, et persiste chaque fois', () async {
    when(() => box.get(HiveService.kPinnedTripIds)).thenReturn(null);
    final cubit = PinnedTripsCubit(box);

    await cubit.toggle('a');
    expect(cubit.state.isPinned('a'), isTrue);
    verify(() => box.put(HiveService.kPinnedTripIds, ['a'])).called(1);

    await cubit.toggle('a');
    expect(cubit.state.isPinned('a'), isFalse);
    verify(() => box.put(HiveService.kPinnedTripIds, <String>[])).called(1);
  });

  test('une écriture en échec garde l\'épingle pour la session', () async {
    when(() => box.get(HiveService.kPinnedTripIds)).thenReturn(null);
    when(() => box.put(any(), any())).thenThrow(StateError('disque plein'));
    final cubit = PinnedTripsCubit(box);
    await cubit.toggle('a');
    expect(cubit.state.isPinned('a'), isTrue);
  });

  test('syncWith retire terminés, annulés et supprimés', () async {
    when(
      () => box.get(HiveService.kPinnedTripIds),
    ).thenReturn(['actif', 'fini', 'annule', 'supprime']);
    final cubit = PinnedTripsCubit(box);

    await cubit.syncWith([
      _trip('actif'),
      _trip('fini', status: 'COMPLETED'),
      _trip('annule', status: 'CANCELLED'),
    ]);

    expect(cubit.state.ids, {'actif'});
    verify(() => box.put(HiveService.kPinnedTripIds, ['actif'])).called(1);
  });

  test('syncWith sans changement n\'écrit rien', () async {
    when(() => box.get(HiveService.kPinnedTripIds)).thenReturn(['actif']);
    final cubit = PinnedTripsCubit(box);
    await cubit.syncWith([_trip('actif', status: 'IN_PROGRESS')]);
    verifyNever(() => box.put(any(), any()));
  });

  test('canPin : brouillons et trajets en cours oui, terminés non', () {
    expect(PinnedTripsCubit.canPin(_trip('a', status: 'DRAFT')), isTrue);
    expect(PinnedTripsCubit.canPin(_trip('a', status: 'FULL')), isTrue);
    expect(PinnedTripsCubit.canPin(_trip('a', status: 'COMPLETED')), isFalse);
    expect(PinnedTripsCubit.canPin(_trip('a', status: 'CANCELLED')), isFalse);
  });
}
