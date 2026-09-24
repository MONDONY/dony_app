import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

export 'package:dony/l10n/generated/app_localizations.dart';

/// Interrupteur de mise en service de l'anglais.
///
/// Reste à `false` tant que tous les écrans ne sont pas traduits : la langue
/// résolue est alors toujours le français et le choix « English » est masqué
/// dans Réglages. La dernière PR du chantier i18n le passe à `true`.
const bool kEnglishEnabled = false;

/// Point d'entrée unique de la langue de l'app.
abstract final class AppL10n {
  static const Locale fr = Locale('fr');
  static const Locale en = Locale('en');

  static bool? _debugEnglishEnabled;

  /// Force l'interrupteur dans un test. `null` rétablit [kEnglishEnabled].
  @visibleForTesting
  static set debugEnglishEnabled(bool? value) => _debugEnglishEnabled = value;

  static bool get englishEnabled => _debugEnglishEnabled ?? kEnglishEnabled;

  /// Choix de langue effectif à partir de la préférence stockée ('system',
  /// 'fr' ou 'en') : un 'en' stocké vaut 'fr' tant que l'anglais n'est pas
  /// activé.
  static String effectiveChoice(String stored) =>
      stored == 'en' && !englishEnabled ? 'fr' : stored;

  /// Langue de l'app à partir des langues préférées : un choix manuel
  /// (`[Locale('en')]`) ou la liste du téléphone. Seule la première langue
  /// compte : anglais si elle est anglaise, français sinon.
  static Locale resolve(List<Locale>? preferred) {
    if (!englishEnabled || preferred == null || preferred.isEmpty) return fr;
    return preferred.first.languageCode == 'en' ? en : fr;
  }

  /// Branché sur `MaterialApp.localeListResolutionCallback`. Fonction pure :
  /// elle n'écrit pas `Intl.defaultLocale`, car Flutter ne l'appelle pas
  /// toujours avec la langue effective (résultat en cache avec
  /// `locale: null`, liste du téléphone passée malgré un choix manuel). La
  /// synchro passe par [syncIntl].
  static Locale localeListResolution(
    List<Locale>? preferred,
    Iterable<Locale> supported,
  ) => resolve(preferred);

  /// Recopie la langue effective dans `Intl.defaultLocale`, que lit le code
  /// sans `BuildContext` (formats de date, catalogue d'erreurs, client
  /// réseau). Appelée depuis le `builder` de `MaterialApp`, sous
  /// `Localizations` : il se reconstruit à chaque changement de langue
  /// effective, choix manuel comme langue du téléphone.
  static void syncIntl(Locale effective) =>
      Intl.defaultLocale = effective.languageCode;

  /// Langue courante hors contexte. Français tant que l'app n'a rien résolu
  /// (démarrage, tests unitaires).
  static Locale get currentLocale =>
      (Intl.defaultLocale ?? '').startsWith('en') ? en : fr;

  /// Code de langue pour `DateFormat`/`NumberFormat` : `'fr'` ou `'en'`.
  static String get localeName => currentLocale.languageCode;

  /// Traductions de la langue courante, pour le code sans `BuildContext`.
  static AppLocalizations get current => lookupAppLocalizations(currentLocale);
}

extension AppL10nContext on BuildContext {
  /// Traductions du contexte. Sans délégué monté (test widget sur une
  /// MaterialApp nue), retombe sur [AppL10n.current] au lieu de planter.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppL10n.current;
}

/// Joint une liste d'éléments pour l'affichage, sans concaténation de mots.
///
/// `''` si vide, l'élément seul s'il y en a un, [AppLocalizations.commonListPair]
/// pour deux, et [AppLocalizations.commonListLast] pour trois ou plus (tête
/// jointe par `", "`).
String joinList(AppLocalizations l, List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  if (items.length == 2) {
    return l.commonListPair(items[0], items[1]);
  }
  final head = items.sublist(0, items.length - 1).join(', ');
  return l.commonListLast(head, items.last);
}

/// Formate [value] avec une décimale, à la langue (`,` en français, `.` en
/// anglais) — jamais `toStringAsFixed(1).replaceAll('.', ',')` ni
/// `replaceFirst('.', ',')`, qui figent la virgule française quelle que soit
/// la langue effective.
String formatOneDecimal(AppLocalizations l, double value) =>
    NumberFormat.decimalPatternDigits(
      locale: l.localeName,
      decimalDigits: 1,
    ).format(value);
