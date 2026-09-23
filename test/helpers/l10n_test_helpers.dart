import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// Monte [child] dans une MaterialApp branchée sur les traductions de l'app.
Widget localizedApp(Widget child, {Locale locale = AppL10n.fr}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// Passe la langue hors contexte (`Intl.defaultLocale`) en anglais pour le
/// test courant, puis la restaure.
void useEnglish() {
  final previous = Intl.defaultLocale;
  Intl.defaultLocale = 'en';
  addTearDown(() => Intl.defaultLocale = previous);
}

/// Active l'interrupteur de l'anglais pour le test courant, puis le coupe.
void enableEnglish() {
  AppL10n.debugEnglishEnabled = true;
  addTearDown(() => AppL10n.debugEnglishEnabled = null);
}
