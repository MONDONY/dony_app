import 'package:dony/features/tax_info/bloc/tax_info_state.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/data/repositories/tax_info_repository.dart';
import 'package:dony/l10n/l10n.dart';

/// Page derrière « En savoir plus ».
///
/// Emplacement de la FAQ DAC7 (tâche 6 du plan « collecte ciblée ») : tant
/// qu'elle n'existe pas dans l'app, le lien mène à la page de
/// l'administration fiscale sur les plateformes numériques.
final Uri kTaxInfoLearnMoreUrl = Uri.parse(
  'https://www.impots.gouv.fr/economie-collaborative-et-plateformes-numeriques',
);

/// Libellés traduits des informations fiscales.
extension TaxInfoLabels on AppLocalizations {
  /// [code] : code du back (`tax-info-invalid`, `dac7-disabled`…), `network`
  /// ou `unknown`. Aucun message ne recopie la valeur saisie.
  String taxInfoError(String code) => switch (code) {
    kTaxInfoInvalidCode => taxInfoErrorInvalid,
    kTaxInfoReadOnlyCode => taxInfoErrorReadOnly,
    'tax-info-not-applicable' => taxInfoErrorNotApplicable,
    kTaxResidenceLockedCode => taxInfoErrorCountryLocked,
    kTaxResidenceResetsPayoutCode => taxInfoErrorCountryResetsPayout,
    'network' => taxInfoErrorNetwork,
    'dac7-disabled' => taxInfoErrorUnavailable,
    _ => taxInfoErrorGeneric,
  };

  /// Aide au-dessus d'« Enregistrer » grisé.
  String taxInfoMissingInput(TaxInfoMissingInput input) => switch (input) {
    TaxInfoMissingInput.residence => taxInfoSaveMissingResidence,
    TaxInfoMissingInput.name => taxInfoSaveMissingName,
    TaxInfoMissingInput.birthDate => taxInfoSaveMissingBirthDate,
    TaxInfoMissingInput.address => taxInfoSaveMissingAddress,
    TaxInfoMissingInput.taxNumber => taxInfoSaveMissingNumber,
    TaxInfoMissingInput.birthPlace => taxInfoSaveMissingBirthPlace,
    TaxInfoMissingInput.vat => taxInfoSaveMissingVat,
    TaxInfoMissingInput.taxCountry => taxInfoSaveMissingCountry,
  };

  /// Champ manquant cité dans l'en-tête (« votre adresse »), `null` pour le
  /// pays (demandé à part, jamais listé).
  String? taxInfoMissingFieldName(TaxInfoField field) => switch (field) {
    TaxInfoField.name => taxInfoMissingName,
    TaxInfoField.birthDate => taxInfoMissingBirthDate,
    TaxInfoField.address => taxInfoMissingAddress,
    TaxInfoField.taxIdentificationNumber => taxInfoMissingTaxNumber,
    TaxInfoField.residenceCountry => null,
  };

  /// « votre adresse et votre numéro fiscal », « a, b et c » ; `null` si
  /// rien à citer.
  String? taxInfoMissingList(List<TaxInfoField> fields) {
    final names = [for (final f in fields) ?taxInfoMissingFieldName(f)];
    return names.isEmpty ? null : joinList(this, names);
  }
}
