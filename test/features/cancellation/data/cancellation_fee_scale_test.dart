import 'package:dony/features/cancellation/data/cancellation_fee_scale.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../cancellation_fee_test_support.dart';

final _after = kFeeEffectiveFrom.add(const Duration(days: 1));

CancellationFeeConfigModel _config({
  bool active = true,
  DateTime? effectiveFrom,
  double? cap = 30,
  List<CancellationFeeTier>? tiers,
}) => CancellationFeeConfigModel(
  effectiveFrom: active ? (effectiveFrom ?? kFeeEffectiveFrom) : null,
  capEur: cap,
  tiers: tiers ?? kActiveFeeConfig.tiers,
);

CancellationFeeScale? _scale(CancellationFeeConfigModel c, {DateTime? now}) =>
    CancellationFeeScale.fromConfig(c, now: now ?? _after);

CancellationFeeTier _t(int days, double rate) =>
    CancellationFeeTier(minDaysBefore: days, rate: rate);

void main() {
  group('CancellationFeeScale.fromConfig', () {
    test('barème type : 5 → 0, 3 → 10, 1 → 20, 0 → 30, plafond 30', () {
      final scale = _scale(_config())!;
      expect(scale.capEur, 30);
      expect(scale.rows.map((r) => (r.kind, r.fromDays, r.days, r.percent)), [
        (CancellationFeeScaleKind.moreThan, null, 5, 0),
        (CancellationFeeScaleKind.between, 5, 3, 10),
        (CancellationFeeScaleKind.between, 3, 1, 20),
        (CancellationFeeScaleKind.lessThan, null, 1, 30),
      ]);
    });

    test('paliers personnalisés : seuils et taux viennent de la config', () {
      final scale = _scale(
        _config(tiers: [_t(7, 0), _t(2, 0.15), _t(0, 0.5)], cap: 45),
      )!;
      expect(scale.capEur, 45);
      expect(scale.rows.map((r) => (r.kind, r.fromDays, r.days, r.percent)), [
        (CancellationFeeScaleKind.moreThan, null, 7, 0),
        (CancellationFeeScaleKind.between, 7, 2, 15),
        (CancellationFeeScaleKind.lessThan, null, 2, 50),
      ]);
    });

    test('éteint : null', () {
      expect(_scale(CancellationFeeConfigModel.inactive), isNull);
      expect(_scale(_config(active: false)), isNull);
    });

    test('date d\'effet pas encore passée : null ; à l\'instant même : ok', () {
      final before = kFeeEffectiveFrom.subtract(const Duration(seconds: 1));
      expect(_scale(_config(), now: before), isNull);
      expect(_scale(_config(), now: kFeeEffectiveFrom), isNotNull);
    });

    test('plafond absent ou nul : ligne omise, barème gardé', () {
      expect(_scale(_config(cap: null))!.capEur, isNull);
      expect(_scale(_config(cap: 0))!.capEur, isNull);
    });

    final malformed = <String, List<CancellationFeeTier>>{
      'vide': const [],
      'un seul palier': [_t(5, 0)],
      'seuils non décroissants': [_t(3, 0), _t(5, 0.1)],
      'seuils égaux': [_t(3, 0), _t(3, 0.1)],
      'seuil négatif': [_t(3, 0), _t(-1, 0.1)],
      'taux au-dessus de 1': [_t(3, 0), _t(0, 1.5)],
      'taux négatif': [_t(3, -0.1), _t(0, 0.2)],
      'taux qui baisse près du départ': [_t(3, 0.2), _t(0, 0.1)],
      'taux à fraction de pourcent (0.125)': [_t(3, 0), _t(0, 0.125)],
      'dernier palier au-dessus de 0 jour': [_t(5, 0), _t(1, 0.2)],
    };
    malformed.forEach((label, tiers) {
      test('paliers incohérents ($label) : null', () {
        expect(_scale(_config(tiers: tiers)), isNull);
      });
    });
  });
}
