import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/address_suggestion.dart';
import 'package:dony/features/matching/presentation/widgets/address_picker_field.dart';
import 'package:dony/core/widgets/dony_icon.dart';

class MockAddressAutocompleteService extends Mock
    implements AddressAutocompleteService {}

void main() {
  late MockAddressAutocompleteService mockService;

  setUp(() {
    mockService = MockAddressAutocompleteService();
  });

  Widget buildWidget({
    AddressData? initialValue,
    void Function(AddressData?)? onSaved,
    GlobalKey<FormState>? formKey,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: AddressPickerField(
            fieldLabel: 'Lieu de remise',
            isRequired: true,
            autocompleteService: mockService,
            initialValue: initialValue,
            onSaved: onSaved,
          ),
        ),
      ),
    );
  }

  testWidgets('affiche le label hint quand vide', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('Lieu de remise'), findsOneWidget);
  });

  testWidgets('initialValue affiche le label au chargement', (tester) async {
    const initial = AddressData(label: 'Lyon déjà saisie', lat: 45.748, lng: 4.846);
    await tester.pumpWidget(buildWidget(initialValue: initial));
    expect(find.text('Lyon déjà saisie'), findsOneWidget);
  });

  testWidgets('bouton GPS est visible', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'locate-fixed'), findsOneWidget);
  });

  testWidgets('validation échoue si aucune adresse sélectionnée', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(buildWidget(formKey: formKey));

    formKey.currentState!.validate();
    await tester.pump();

    expect(find.text('Adresse obligatoire'), findsOneWidget);
  });

  testWidgets('widget_overlay_showsMainAndSecondaryText', (tester) async {
    when(() => mockService.search(any(), any())).thenAnswer((_) async => const [
      AddressSuggestion(
        placeId: 'id1',
        mainText: '12 rue Victor Hugo',
        secondaryText: 'Lyon, France',
      ),
    ]);

    await tester.pumpWidget(buildWidget());
    await tester.enterText(find.byType(TextField), 'Victor');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // mainText as title, secondaryText as subtitle — both visible in overlay
    expect(find.text('12 rue Victor Hugo'), findsOneWidget);
    expect(find.text('Lyon, France'), findsOneWidget);
  });

  testWidgets('widget_tapSuggestion_callsResolvePlace', (tester) async {
    when(() => mockService.search(any(), any())).thenAnswer((_) async => const [
      AddressSuggestion(placeId: 'ChIJi', mainText: 'Paris', secondaryText: 'France'),
    ]);
    when(() => mockService.resolvePlace(any(), any())).thenAnswer((_) async =>
        const AddressData(label: 'Paris, France', lat: 48.8566, lng: 2.3522));

    await tester.pumpWidget(buildWidget());
    await tester.enterText(find.byType(TextField), 'Paris');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Tap the suggestion in the overlay: find Paris in a ListTile
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    verify(() => mockService.resolvePlace('ChIJi', any())).called(1);
    // After resolve, the field displays the resolved label
    expect(find.text('Paris, France'), findsOneWidget);
  });

  testWidgets('sessionToken_generatedOnFirstTyping', (tester) async {
    String? capturedToken;
    when(() => mockService.search(any(), any())).thenAnswer((inv) async {
      capturedToken = inv.positionalArguments[1] as String;
      return const [];
    });

    await tester.pumpWidget(buildWidget());
    await tester.enterText(find.byType(TextField), 'P');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(capturedToken, isNotNull);
    expect(capturedToken, isNotEmpty);
  });

  testWidgets('sessionToken_sameTokenAcrossConsecutiveTypings', (tester) async {
    final capturedTokens = <String>[];
    when(() => mockService.search(any(), any())).thenAnswer((inv) async {
      capturedTokens.add(inv.positionalArguments[1] as String);
      return const [];
    });

    await tester.pumpWidget(buildWidget());
    await tester.enterText(find.byType(TextField), 'P');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Pa');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(capturedTokens.length, 2);
    expect(capturedTokens[0], equals(capturedTokens[1])); // same session
  });

  testWidgets('sessionToken_resetAfterResolve_newTokenOnNextSearch', (tester) async {
    final capturedTokens = <String>[];
    var searchCallCount = 0;

    when(() => mockService.search(any(), any())).thenAnswer((inv) async {
      capturedTokens.add(inv.positionalArguments[1] as String);
      searchCallCount++;
      if (searchCallCount == 1) {
        return const [
          AddressSuggestion(placeId: 'id1', mainText: 'Lyon', secondaryText: 'France'),
        ];
      }
      return const [];
    });
    when(() => mockService.resolvePlace(any(), any())).thenAnswer((_) async =>
        const AddressData(label: 'Lyon, France', lat: 45.748, lng: 4.846));

    await tester.pumpWidget(buildWidget());

    // First search
    await tester.enterText(find.byType(TextField), 'Lyon');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Tap to resolve (resets session token): find Lyon in the overlay ListTile
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // Clear field and search again
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Dakar');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(capturedTokens.length, 2);
    expect(capturedTokens[0], isNot(equals(capturedTokens[1]))); // different sessions
  });

  testWidgets('resolvePlace_throws_showsOfflineBanner', (tester) async {
    when(() => mockService.search(any(), any())).thenAnswer((_) async => const [
      AddressSuggestion(placeId: 'id1', mainText: 'Lyon', secondaryText: 'France'),
    ]);
    when(() => mockService.resolvePlace(any(), any())).thenThrow(Exception('network'));

    await tester.pumpWidget(buildWidget());
    await tester.enterText(find.byType(TextField), 'Lyon');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Connexion requise'), findsOneWidget);
  });

  testWidgets('focusLoss_restoresCommittedLabel', (tester) async {
    when(() => mockService.search(any(), any())).thenAnswer((_) async => const [
      AddressSuggestion(placeId: 'id1', mainText: 'Paris', secondaryText: 'France'),
    ]);
    when(() => mockService.resolvePlace(any(), any())).thenAnswer((_) async =>
        const AddressData(label: 'Paris, France', lat: 48.8566, lng: 2.3522));

    await tester.pumpWidget(buildWidget());

    // Select an address to commit it
    await tester.enterText(find.byType(TextField), 'Paris');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // Start typing again to dirty the field
    await tester.enterText(find.byType(TextField), 'Lyon partiel');
    await tester.pump();

    // Simulate focus loss by explicitly unfocusing
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // Field should revert to committed label
    expect(find.text('Paris, France'), findsOneWidget);
  });

  testWidgets('showGpsButton: true par défaut → bouton GPS visible', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'locate-fixed'), findsOneWidget);
  });

  testWidgets('showGpsButton: false → bouton GPS masqué', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          child: AddressPickerField(
            fieldLabel: 'Lieu de remise',
            isRequired: true,
            autocompleteService: mockService,
            showGpsButton: false,
          ),
        ),
      ),
    ));
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'locate-fixed'), findsNothing);
    expect(find.text('Utiliser ma position actuelle'), findsNothing);
  });
}
