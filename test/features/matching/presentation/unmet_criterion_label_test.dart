import 'package:dony/features/matching/data/models/similar_announcement.dart';
import 'package:dony/features/matching/presentation/unmet_criterion_label.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  String lab(UnmetCriterion c, {bool english = false}) => unmetCriterionLabel(
    english ? en : fr,
    c,
    localeName: english ? 'en' : 'fr',
  );

  test('DATE : date localisée, jamais la chaîne ISO', () {
    final s = lab(
      const UnmetCriterion(
        code: 'DATE',
        requested: '2026-11-10',
        actual: '2026-11-12',
      ),
    );
    expect(s, contains('12'));
    expect(s, contains('10'));
    expect(s, isNot(contains('2026-11')));
    expect(s, startsWith('Départ le'));
  });

  test('URGENT avec date : date localisée', () {
    final s = lab(const UnmetCriterion(code: 'URGENT', actual: '2026-11-12'));
    expect(s, 'Départ hors de la fenêtre urgente');
  });

  test('kilos et note', () {
    expect(
      lab(
        const UnmetCriterion(
          code: 'AVAILABLE_KG',
          requested: '10',
          actual: '5',
        ),
      ),
      '5 kg disponibles au lieu de 10',
    );
    expect(
      lab(
        const UnmetCriterion(
          code: 'MAX_AVAILABLE_KG',
          requested: '5',
          actual: '20',
        ),
      ),
      '20 kg disponibles, plus que les 5 kg souhaités',
    );
    expect(
      lab(
        const UnmetCriterion(
          code: 'MIN_RATING',
          requested: '4.5',
          actual: '4.0',
        ),
      ),
      'Note de 4.0 au lieu de 4.5 minimum',
    );
  });

  test('TRANSPORT_MODE réutilise le libellé localisé', () {
    final s = lab(
      const UnmetCriterion(
        code: 'TRANSPORT_MODE',
        requested: 'PLANE',
        actual: 'BUS',
      ),
    );
    expect(s, contains(fr.tripTransportBus));
    expect(s, contains(fr.tripTransportPlane));
  });

  test('CONTENT_TYPE, RADIUS, URGENT, KILO_PRO_ONLY', () {
    expect(
      lab(const UnmetCriterion(code: 'CONTENT_TYPE', requested: 'liquides')),
      "N'accepte pas : liquides",
    );
    expect(lab(const UnmetCriterion(code: 'RADIUS')), fr.unmetRadius);
    expect(lab(const UnmetCriterion(code: 'URGENT')), fr.unmetUrgent);
    expect(lab(const UnmetCriterion(code: 'KILO_PRO_ONLY')), fr.unmetGpPro);
  });

  test('weekend_maps_english_day_name_to_localized_day', () {
    expect(
      lab(const UnmetCriterion(code: 'WEEKEND_ONLY', actual: 'THURSDAY')),
      'Départ un jeudi (pas un week-end)',
    );
    expect(
      lab(
        const UnmetCriterion(code: 'WEEKEND_ONLY', actual: 'THURSDAY'),
        english: true,
      ),
      contains('Thursday'),
    );
    expect(
      lab(const UnmetCriterion(code: 'WEEKEND_ONLY', actual: 'FUNDAY')),
      fr.unmetGeneric,
    );
  });

  test('unknown_code_uses_generic', () {
    expect(lab(const UnmetCriterion(code: 'NEW_THING')), fr.unmetGeneric);
  });

  test('empty_values_never_print_null_or_blank_placeholders', () {
    for (final code in [
      'DATE',
      'AVAILABLE_KG',
      'MAX_AVAILABLE_KG',
      'TRANSPORT_MODE',
      'MIN_RATING',
      'CONTENT_TYPE',
      'WEEKEND_ONLY',
    ]) {
      expect(lab(UnmetCriterion(code: code)), fr.unmetGeneric, reason: code);
    }
  });

  test('unparseable_date_falls_back_to_raw_text_without_crash', () {
    final s = lab(
      const UnmetCriterion(
        code: 'DATE',
        requested: 'bientôt',
        actual: 'demain',
      ),
    );
    expect(s, 'Départ le demain au lieu du bientôt');
  });
}
