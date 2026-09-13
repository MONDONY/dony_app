import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/kg_sold_cubit.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/data/models/kg_sold_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

void main() {
  late _MockAnnouncementRepository repo;
  const details = KgSoldModel(period: '7d', totalKg: 0, parcels: 0, trips: []);

  setUp(() => repo = _MockAnnouncementRepository());

  blocTest<KgSoldCubit, KgSoldState>(
    'charge le détail de la période demandée',
    build: () {
      when(() => repo.getKgSold(period: '7d')).thenAnswer((_) async => details);
      return KgSoldCubit(repo);
    },
    act: (cubit) => cubit.load(StatsPeriod.sevenDays),
    expect: () => const [
      KgSoldState(status: KgSoldStatus.loading),
      KgSoldState(status: KgSoldStatus.loaded, details: details),
    ],
  );

  blocTest<KgSoldCubit, KgSoldState>(
    'passe en erreur quand le backend échoue, sans rejeter',
    build: () {
      when(
        () => repo.getKgSold(period: '30d'),
      ).thenThrow(Exception('hors ligne'));
      return KgSoldCubit(repo);
    },
    act: (cubit) => cubit.load(StatsPeriod.thirtyDays),
    expect: () => const [
      KgSoldState(status: KgSoldStatus.loading),
      KgSoldState(status: KgSoldStatus.error),
    ],
  );
}
