import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la période par défaut est 30 jours', () {
    expect(StatsPeriodCubit().state, StatsPeriod.thirtyDays);
  });

  test('chaque période a une valeur API et un libellé', () {
    expect(StatsPeriod.sevenDays.apiValue, '7d');
    expect(StatsPeriod.thirtyDays.apiValue, '30d');
    expect(StatsPeriod.twelveMonths.apiValue, '12m');

    expect(StatsPeriod.sevenDays.label, '7 jours');
    expect(StatsPeriod.thirtyDays.label, '30 jours');
    expect(StatsPeriod.twelveMonths.label, '12 mois');
  });

  blocTest<StatsPeriodCubit, StatsPeriod>(
    'select change la période',
    build: StatsPeriodCubit.new,
    act: (c) => c.select(StatsPeriod.twelveMonths),
    expect: () => [StatsPeriod.twelveMonths],
  );

  blocTest<StatsPeriodCubit, StatsPeriod>(
    'sélectionner la période courante n\'émet rien — pas de rechargement inutile',
    build: StatsPeriodCubit.new,
    act: (c) => c.select(StatsPeriod.thirtyDays),
    expect: () => <StatsPeriod>[],
  );
}
