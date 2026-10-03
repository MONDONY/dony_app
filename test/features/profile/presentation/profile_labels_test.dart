import 'package:dony/features/profile/presentation/profile_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('spokenLanguageLabel', () {
    test('chaque langue de la liste (FLUTTER-9Z) a son libellé fr', () {
      // Le libellé français est la valeur enregistrée elle-même : un cas
      // manquant du switch retomberait sur `value` sans qu'on le voie, d'où
      // le contrôle en anglais ci-dessous sur les langues traduites.
      for (final lang in kSpokenLanguages) {
        expect(spokenLanguageLabel(fr, lang), lang);
      }
      expect(kSpokenLanguages.toSet().length, kSpokenLanguages.length);
    });

    test('langues ajoutées traduites en anglais', () {
      expect(spokenLanguageLabel(en, 'Portugais'), 'Portuguese');
      expect(spokenLanguageLabel(en, 'Peul'), 'Fula');
      expect(spokenLanguageLabel(en, 'Haoussa'), 'Hausa');
      expect(spokenLanguageLabel(en, 'Amharique'), 'Amharic');
      expect(spokenLanguageLabel(en, 'Chinois'), 'Chinese');
    });

    test('langue saisie librement : affichée telle quelle', () {
      expect(spokenLanguageLabel(en, 'Kabyle'), 'Kabyle');
    });

    test('Français — fr et en', () {
      expect(spokenLanguageLabel(fr, 'Français'), 'Français');
      expect(spokenLanguageLabel(en, 'Français'), 'French');
    });

    test('Wolof — identique fr et en', () {
      expect(spokenLanguageLabel(fr, 'Wolof'), 'Wolof');
      expect(spokenLanguageLabel(en, 'Wolof'), 'Wolof');
    });

    test('Bambara — identique fr et en', () {
      expect(spokenLanguageLabel(fr, 'Bambara'), 'Bambara');
      expect(spokenLanguageLabel(en, 'Bambara'), 'Bambara');
    });

    test('Anglais — fr et en', () {
      expect(spokenLanguageLabel(fr, 'Anglais'), 'Anglais');
      expect(spokenLanguageLabel(en, 'Anglais'), 'English');
    });

    test('Espagnol — fr et en', () {
      expect(spokenLanguageLabel(fr, 'Espagnol'), 'Espagnol');
      expect(spokenLanguageLabel(en, 'Espagnol'), 'Spanish');
    });

    test('Arabe — fr et en', () {
      expect(spokenLanguageLabel(fr, 'Arabe'), 'Arabe');
      expect(spokenLanguageLabel(en, 'Arabe'), 'Arabic');
    });

    test('valeur inconnue (ancienne saisie) rendue telle quelle', () {
      expect(spokenLanguageLabel(fr, 'Créole'), 'Créole');
      expect(spokenLanguageLabel(en, 'Créole'), 'Créole');
    });
  });
}
