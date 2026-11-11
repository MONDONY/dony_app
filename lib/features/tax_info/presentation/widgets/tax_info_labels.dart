import 'package:dony/features/tax_info/bloc/tax_info_state.dart';
import 'package:dony/l10n/l10n.dart';

/// Page de l'administration fiscale derrière « En savoir plus ».
final Uri kTaxInfoLearnMoreUrl = Uri.parse(
  'https://www.impots.gouv.fr/economie-collaborative-et-plateformes-numeriques',
);

/// Libellés traduits des erreurs d'enregistrement des informations fiscales.
extension TaxInfoLabels on AppLocalizations {
  /// [code] : code du back (`tax-info-invalid`, `dac7-disabled`), `network` ou
  /// `unknown`. Aucun message ne recopie la valeur saisie.
  String taxInfoError(String code) => switch (code) {
    kTaxInfoInvalidCode => taxInfoErrorInvalid,
    'network' => taxInfoErrorNetwork,
    'dac7-disabled' => taxInfoErrorUnavailable,
    _ => taxInfoErrorGeneric,
  };
}
