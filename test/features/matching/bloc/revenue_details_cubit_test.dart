import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/revenue_details_cubit.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/data/models/revenue_details_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

void main() {
  late _MockAnnouncementRepository repo;
  const details = RevenueDetailsModel(period: '7d', deliveries: 0, groups: []);

  setUp(() => repo = _MockAnnouncementRepository());

  blocTest<RevenueDetailsCubit, RevenueDetailsState>(
    'charge le détail de la période demandée',
    build: () {
      when(
        () => repo.getRevenueDetails(period: '7d'),
      ).thenAnswer((_) async => details);
      return RevenueDetailsCubit(repo);
    },
    act: (cubit) => cubit.load(StatsPeriod.sevenDays),
    expect: () => const [
      RevenueDetailsState(status: RevenueDetailsStatus.loading),
      RevenueDetailsState(
        status: RevenueDetailsStatus.loaded,
        details: details,
      ),
    ],
  );

  blocTest<RevenueDetailsCubit, RevenueDetailsState>(
    'passe en erreur quand le backend échoue, sans rejeter',
    build: () {
      when(
        () => repo.getRevenueDetails(period: '30d'),
      ).thenThrow(Exception('hors ligne'));
      return RevenueDetailsCubit(repo);
    },
    act: (cubit) => cubit.load(StatsPeriod.thirtyDays),
    expect: () => const [
      RevenueDetailsState(status: RevenueDetailsStatus.loading),
      RevenueDetailsState(status: RevenueDetailsStatus.error),
    ],
  );
}
