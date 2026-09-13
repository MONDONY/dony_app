import 'dart:async';

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

  group('feuille retirée pendant le chargement', () {
    test("n'émet rien après close quand la requête aboutit", () async {
      final completer = Completer<RevenueDetailsModel>();
      when(
        () => repo.getRevenueDetails(period: '7d'),
      ).thenAnswer((_) => completer.future);
      final cubit = RevenueDetailsCubit(repo);
      final emitted = <RevenueDetailsState>[];
      final sub = cubit.stream.listen(emitted.add);

      final loading = cubit.load(StatsPeriod.sevenDays);
      await cubit.close();
      completer.complete(details);
      await loading;

      expect(emitted, const [
        RevenueDetailsState(status: RevenueDetailsStatus.loading),
      ]);
      expect(cubit.state.status, RevenueDetailsStatus.loading);
      await sub.cancel();
    });

    test("n'émet rien après close quand la requête échoue", () async {
      final completer = Completer<RevenueDetailsModel>();
      when(
        () => repo.getRevenueDetails(period: '7d'),
      ).thenAnswer((_) => completer.future);
      final cubit = RevenueDetailsCubit(repo);
      final emitted = <RevenueDetailsState>[];
      final sub = cubit.stream.listen(emitted.add);

      final loading = cubit.load(StatsPeriod.sevenDays);
      await cubit.close();
      completer.completeError(Exception('hors ligne'));
      await loading;

      expect(emitted, const [
        RevenueDetailsState(status: RevenueDetailsStatus.loading),
      ]);
      expect(cubit.state.status, RevenueDetailsStatus.loading);
      await sub.cancel();
    });
  });
}
