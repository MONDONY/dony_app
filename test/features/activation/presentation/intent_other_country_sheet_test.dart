import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/presentation/widgets/intent_other_country_sheet.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les 24 pays du `CountryCatalog.java` hors UEMOA + CEMAC : 20 pays de la
/// zone euro, Suisse, Royaume-Uni, Canada, États-Unis.
const _others = [
  'AT', 'BE', 'HR', 'CY', 'EE', 'FI', 'FR', 'DE', 'GR', 'IE', //
  'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PT', 'SK', 'SI', 'ES', //
  'CH', 'GB', 'CA', 'US', //
];

void main() {
  // Résultat de la feuille, capturé par le bouton qui l'ouvre.
  String? result;
  var closed = false;

  Future<void> openSheet(
    WidgetTester tester, {
    Locale locale = const Locale('fr'),
    String? selectedCode,
  }) async {
    result = null;
    closed = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => DonyButton(
              key: const Key('open'),
              label: 'open', // i18n-ignore
              onPressed: () async {
                result = await IntentOtherCountrySheet.show(
                  context,
                  selectedCode: selectedCode,
                );
                closed = true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  Iterable<String> visibleCodes(WidgetTester tester) => tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map((t) => (t.key as ValueKey<String>?)?.value ?? '')
      .where((k) => k.startsWith('intent-other-country-'))
      .map((k) => k.substring('intent-other-country-'.length))
      .where((c) => c != 'not-listed');

  test('les 24 autres pays exacts du catalogue serveur', () {
    expect(kIntentOtherCountries, hasLength(24));
    expect(kIntentOtherCountries.toSet(), _others.toSet());
    for (final code in _others) {
      expect(isIntentOtherCountry(code), isTrue, reason: code);
    }
    expect(isIntentOtherCountry('SN'), isFalse);
    expect(isIntentOtherCountry(kIntentOtherDestination), isFalse);
    expect(isIntentOtherCountry(null), isFalse);
  });

  test('tri par nom français, accents ignorés', () {
    final ordered = orderedIntentOtherCountries(
      lookupAppLocalizations(const Locale('fr')),
    );
    expect(ordered, hasLength(24));
    expect(ordered.first, 'DE'); // Allemagne
    // « États-Unis » entre « Estonie » et « Finlande », pas en fin de liste.
    expect(ordered.indexOf('US'), ordered.indexOf('EE') + 1);
    expect(ordered.indexOf('FI'), ordered.indexOf('US') + 1);
    expect(ordered.last, 'CH'); // Suisse
  });

  test('tri par nom anglais', () {
    final ordered = orderedIntentOtherCountries(
      lookupAppLocalizations(const Locale('en')),
    );
    expect(ordered.first, 'AT'); // Austria
    expect(ordered.last, 'US'); // United States
  });

  testWidgets('affiche les 24 pays avec drapeau et nom localisé', (
    tester,
  ) async {
    await openSheet(tester);
    expect(find.text('Choisissez votre pays'), findsOneWidget);
    expect(
      visibleCodes(tester).toList(),
      orderedIntentOtherCountries(lookupAppLocalizations(const Locale('fr'))),
    );
    expect(find.text('France'), findsOneWidget);
    expect(find.text('🇫🇷'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text("Mon pays n'est pas dans la liste"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recherche sans accent : « etats » trouve États-Unis', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(
      find.byKey(const Key('intent-other-country-search')),
      'etats',
    );
    await tester.pump();
    expect(visibleCodes(tester), ['US']);
    expect(find.text('🇺🇸'), findsOneWidget);
  });

  testWidgets('recherche avec accent : « Grèce » trouve GR', (tester) async {
    await openSheet(tester);
    await tester.enterText(
      find.byKey(const Key('intent-other-country-search')),
      'Grèce',
    );
    await tester.pump();
    expect(visibleCodes(tester), ['GR']);
  });

  testWidgets('recherche par nom français de référence en anglais', (
    tester,
  ) async {
    await openSheet(tester, locale: const Locale('en'));
    await tester.enterText(
      find.byKey(const Key('intent-other-country-search')),
      'allemagne',
    );
    await tester.pump();
    expect(visibleCodes(tester), ['DE']);
    expect(find.text('Germany'), findsOneWidget);
  });

  testWidgets('un pays UEMOA n\'est pas proposé ici', (tester) async {
    await openSheet(tester);
    await tester.enterText(
      find.byKey(const Key('intent-other-country-search')),
      'senegal',
    );
    await tester.pump();
    expect(visibleCodes(tester), isEmpty);
    expect(find.text('Aucun pays trouvé'), findsOneWidget);
    expect(
      find.byKey(const Key('intent-other-country-not-listed')),
      findsOneWidget,
    );
  });

  testWidgets('choisir un pays renvoie son code ISO2', (tester) async {
    await openSheet(tester);
    await tester.enterText(
      find.byKey(const Key('intent-other-country-search')),
      'france',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('intent-other-country-FR')));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, 'FR');
  });

  testWidgets('« pas dans la liste » renvoie OTHER', (tester) async {
    await openSheet(tester);
    await tester.enterText(
      find.byKey(const Key('intent-other-country-search')),
      'zzz',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('intent-other-country-not-listed')));
    await tester.pumpAndSettle();
    expect(result, kIntentOtherDestination);
  });

  testWidgets('le pays courant est coché', (tester) async {
    await openSheet(tester, selectedCode: 'BE');
    final tile = tester.widget<ListTile>(
      find.byKey(const Key('intent-other-country-BE')),
    );
    expect(tile.selected, isTrue);
    expect(tile.trailing, isNotNull);
  });

  testWidgets('fermer sans choisir renvoie null', (tester) async {
    await openSheet(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });
}
