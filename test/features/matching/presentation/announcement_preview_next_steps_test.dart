import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_preview_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Le bloc « Ensuite » de l'aperçu rassure un premier voyageur avant qu'il
/// publie, et la feuille d'identité dit pourquoi on la lui demande.
void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  Future<void> pump(
    WidgetTester tester, {
    PriceWarning? priceWarning,
    Locale locale = const Locale('fr'),
  }) => tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: AnnouncementPreviewSheet(
            formState: AnnouncementFormState(
              pricePerKg: 5,
              availableKg: 10,
              priceWarning: priceWarning,
            ),
            onConfirm: () {},
          ),
        ),
      ),
    ),
  );

  testWidgets('l\'aperçu dit ce qui se passe après la publication', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byKey(const Key('preview-next-steps')), findsOneWidget);
    expect(find.text('Ensuite'), findsOneWidget);
    expect(
      find.text('Votre trajet n\'est visible qu\'après avoir touché Publier.'),
      findsOneWidget,
    );
    expect(
      find.text('Vous êtes prévenu quand un expéditeur vous fait une demande.'),
      findsOneWidget,
    );
    expect(
      find.text('Vous choisissez les colis que vous acceptez.'),
      findsOneWidget,
    );
    expect(
      find.text('Vous pouvez modifier ou annuler votre trajet ensuite.'),
      findsOneWidget,
    );
  });

  testWidgets('aucun tiret cadratin dans les textes affichés', (tester) async {
    await pump(tester);
    expect(find.textContaining('—'), findsNothing);
  });

  testWidgets('l\'avertissement de prix reste affiché avec le bloc', (
    tester,
  ) async {
    await pump(tester, priceWarning: PriceWarning.tooHigh);
    expect(find.byKey(const Key('preview-next-steps')), findsOneWidget);
    expect(find.textContaining('élevé'), findsWidgets);
  });

  testWidgets('en anglais', (tester) async {
    await pump(tester, locale: const Locale('en'));
    expect(find.text('What happens next'), findsOneWidget);
    expect(find.text('You choose which parcels you accept.'), findsOneWidget);
  });

  test(
    'la feuille d\'identité dit pourquoi, pour un trajet et une demande',
    () {
      final fr = lookupAppLocalizations(const Locale('fr'));
      expect(fr.publishKycGateBodyTrip, contains('en confiance'));
      expect(fr.publishKycGateBodyRequest, contains('en confiance'));
      expect(fr.publishKycGateBodyUnsaved, contains('en confiance'));
      expect(fr.publishKycGateBodyTrip, contains('expéditeurs'));
      expect(fr.publishKycGateBodyRequest, contains('voyageurs'));
      final en = lookupAppLocalizations(const Locale('en'));
      expect(en.publishKycGateBodyTrip, contains('confidence'));
    },
  );
}
