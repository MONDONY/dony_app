import 'package:dony/l10n/l10n.dart';

/// Langues proposées dans la liste « Langues parlées » du profil
/// (FLUTTER-9Z) : les plus parlées au monde, puis celles de la diaspora
/// d'Afrique de l'Ouest et centrale. Une langue absente s'ajoute par
/// « Autre langue » et s'enregistre telle que saisie.
const kSpokenLanguages = [
  'Français', // i18n-ignore — valeur de donnée
  'Anglais', // i18n-ignore — valeur de donnée
  'Arabe', // i18n-ignore — valeur de donnée
  'Espagnol', // i18n-ignore — valeur de donnée
  'Portugais', // i18n-ignore — valeur de donnée
  'Allemand', // i18n-ignore — valeur de donnée
  'Italien', // i18n-ignore — valeur de donnée
  'Chinois', // i18n-ignore — valeur de donnée
  'Hindi', // i18n-ignore — valeur de donnée
  'Russe', // i18n-ignore — valeur de donnée
  'Turc', // i18n-ignore — valeur de donnée
  'Wolof', // i18n-ignore — valeur de donnée
  'Bambara', // i18n-ignore — valeur de donnée
  'Dioula', // i18n-ignore — valeur de donnée
  'Peul', // i18n-ignore — valeur de donnée
  'Soninké', // i18n-ignore — valeur de donnée
  'Malinké', // i18n-ignore — valeur de donnée
  'Haoussa', // i18n-ignore — valeur de donnée
  'Yoruba', // i18n-ignore — valeur de donnée
  'Igbo', // i18n-ignore — valeur de donnée
  'Lingala', // i18n-ignore — valeur de donnée
  'Swahili', // i18n-ignore — valeur de donnée
  'Amharique', // i18n-ignore — valeur de donnée
  'Moré', // i18n-ignore — valeur de donnée
];

/// Longueur maximale d'une langue saisie (colonne `user_languages.language`).
const kSpokenLanguageMaxLength = 32;

/// Libellé affiché d'une langue parlée.
///
/// [kSpokenLanguages] contient des **valeurs
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
    case 'Portugais': // i18n-ignore — valeur de donnée
      return l.profileLanguagePortuguese;
    case 'Allemand': // i18n-ignore — valeur de donnée
      return l.profileLanguageGerman;
    case 'Italien': // i18n-ignore — valeur de donnée
      return l.profileLanguageItalian;
    case 'Chinois': // i18n-ignore — valeur de donnée
      return l.profileLanguageChinese;
    case 'Hindi': // i18n-ignore — valeur de donnée
      return l.profileLanguageHindi;
    case 'Russe': // i18n-ignore — valeur de donnée
      return l.profileLanguageRussian;
    case 'Turc': // i18n-ignore — valeur de donnée
      return l.profileLanguageTurkish;
    case 'Dioula': // i18n-ignore — valeur de donnée
      return l.profileLanguageDioula;
    case 'Peul': // i18n-ignore — valeur de donnée
      return l.profileLanguageFula;
    case 'Soninké': // i18n-ignore — valeur de donnée
      return l.profileLanguageSoninke;
    case 'Malinké': // i18n-ignore — valeur de donnée
      return l.profileLanguageMalinke;
    case 'Haoussa': // i18n-ignore — valeur de donnée
      return l.profileLanguageHausa;
    case 'Yoruba': // i18n-ignore — valeur de donnée
      return l.profileLanguageYoruba;
    case 'Igbo': // i18n-ignore — valeur de donnée
      return l.profileLanguageIgbo;
    case 'Lingala': // i18n-ignore — valeur de donnée
      return l.profileLanguageLingala;
    case 'Swahili': // i18n-ignore — valeur de donnée
      return l.profileLanguageSwahili;
    case 'Amharique': // i18n-ignore — valeur de donnée
      return l.profileLanguageAmharic;
    case 'Moré': // i18n-ignore — valeur de donnée
      return l.profileLanguageMoore;
    default:
      return value;
  }
}
