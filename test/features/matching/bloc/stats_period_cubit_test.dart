import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/presentation/activity_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l = lookupAppLocalizations(AppL10n.fr);

  test('la période par défaut est 30 jours', () {
    expect(StatsPeriodCubit().state, StatsPeriod.thirtyDays);
  });

  test('chaque période a une valeur API et un libellé', () {
    expect(StatsPeriod.sevenDays.apiValue, '7d');
    expect(StatsPeriod.thirtyDays.apiValue, '30d');
    expect(StatsPeriod.twelveMonths.apiValue, '12m');

    expect(StatsPeriod.sevenDays.label(l), '7 jours');
    expect(StatsPeriod.thirtyDays.label(l), '30 jours');
    expect(StatsPeriod.twelveMonths.label(l), '12 mois');
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

  test('detailLabel nomme la fenêtre pour les feuilles de détail', () {
    expect(StatsPeriod.sevenDays.detailLabel(l), '7 derniers jours');
    expect(StatsPeriod.thirtyDays.detailLabel(l), '30 derniers jours');
    expect(StatsPeriod.twelveMonths.detailLabel(l), '12 derniers mois');
  });
}
