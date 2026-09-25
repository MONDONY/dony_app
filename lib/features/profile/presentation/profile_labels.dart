import 'package:dony/l10n/l10n.dart';

/// Libellé affiché d'une langue parlée.
///
/// `_kAvailableLanguages` (`edit_profile_screen.dart`) contient des **valeurs
/// enregistrées** dans le profil (`Français`, `Wolof`, `Bambara`, `Anglais`,
/// `Espagnol`, `Arabe`) : la sélection, la sauvegarde et la comparaison
/// (`_selectedLanguages.contains(lang)`) travaillent sur ces valeurs telles
/// quelles, jamais traduites. Seul l'affichage (`Text(lang)`) passe par cette
/// fonction. Une valeur inconnue (ancienne saisie, ou langue retirée de la
/// liste depuis) est rendue telle quelle plutôt que de disparaître.
String spokenLanguageLabel(AppLocalizations l, String value) {
  switch (value) {
    case 'Français': // i18n-ignore — valeur de donnée
      return l.profileLanguageFrench;
    case 'Wolof': // i18n-ignore — valeur de donnée
      return l.profileLanguageWolof;
    case 'Bambara': // i18n-ignore — valeur de donnée
      return l.profileLanguageBambara;
    case 'Anglais': // i18n-ignore — valeur de donnée
      return l.profileLanguageEnglish;
    case 'Espagnol': // i18n-ignore — valeur de donnée
      return l.profileLanguageSpanish;
    case 'Arabe': // i18n-ignore — valeur de donnée
      return l.profileLanguageArabic;
    default:
      return value;
  }
}
