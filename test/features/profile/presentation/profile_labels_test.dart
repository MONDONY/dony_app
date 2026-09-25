import 'package:dony/features/profile/presentation/profile_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('spokenLanguageLabel', () {
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
