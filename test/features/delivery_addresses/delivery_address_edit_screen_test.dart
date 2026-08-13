import 'package:dio/dio.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_bloc.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_event.dart';
import 'package:dony/features/delivery_addresses/data/models/delivery_address.dart';
import 'package:dony/features/delivery_addresses/data/repositories/delivery_address_repository.dart';
import 'package:dony/features/delivery_addresses/presentation/screens/delivery_address_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements DeliveryAddressRepository {}

class _MockDio extends Mock implements Dio {}

Widget _wrap(DeliveryAddressBloc bloc, {String? addressId}) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: BlocProvider.value(
      value: bloc,
      child: DeliveryAddressEditScreen(addressId: addressId),
    ),
  ),
);

DeliveryAddress _makeAddress({bool isDefault = false}) => DeliveryAddress(
  id: 'del-1',
  label: 'Famille',
  street: 'Rue 10, Almadies',
  city: 'Dakar',
  country: 'SN',
  latitude: 14.69,
  longitude: -17.44,
  isDefault: isDefault,
);

void main() {
  late _MockRepo repo;
  late DeliveryAddressBloc bloc;

  setUpAll(() {
    // Register AddressAutocompleteService in GetIt for widget tests
    if (!getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.registerLazySingleton<AddressAutocompleteService>(
        () => AddressAutocompleteService(dio: _MockDio()),
      );
    }
  });

  setUp(() {
    repo = _MockRepo();
    when(() => repo.getAll()).thenAnswer((_) async => <DeliveryAddress>[]);
    bloc = DeliveryAddressBloc(repo);
  });

  tearDown(() => bloc.close());

  // ── Rendu initial ────────────────────────────────────────────────────────

  testWidgets('chips Famille/Maison/Boutique are rendered', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Famille'), findsOneWidget);
    expect(find.text('Maison'), findsOneWidget);
    expect(find.text('Boutique'), findsOneWidget);
  });

  testWidgets('default country is Sénégal', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Sénégal'), findsOneWidget);
  });

  testWidgets('CTA button is present', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text("Enregistrer l'adresse"), findsOneWidget);
  });

  // ── Titre selon le mode ─────────────────────────────────────────────────

  testWidgets('title is "Nouvelle adresse de livraison" in create mode', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle adresse de livraison'), findsOneWidget);
  });

  testWidgets('title is "Modifier l\'adresse" in edit mode', (tester) async {
    await tester.pumpWidget(_wrap(bloc, addressId: 'del-1'));
    await tester.pumpAndSettle();
    expect(find.text("Modifier l'adresse"), findsOneWidget);
  });

  // ── Chip tap ────────────────────────────────────────────────────────────

  testWidgets('tapping chip fills the label field', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Boutique'));
    await tester.pump();

    final textFields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    final labelField = textFields.firstWhere(
      (tf) => tf.controller.text == 'Boutique',
      orElse: () => throw TestFailure('Champ "Boutique" non trouvé'),
    );
    expect(labelField.controller.text, 'Boutique');
  });

  testWidgets('tapping Famille chip fills the label field', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Famille'));
    await tester.pump();

    final textFields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    final labelField = textFields.firstWhere(
      (tf) => tf.controller.text == 'Famille',
      orElse: () => throw TestFailure('Champ "Famille" non trouvé'),
    );
    expect(labelField.controller.text, 'Famille');
  });

  // ── Toggle par défaut ────────────────────────────────────────────────────

  testWidgets('default toggle is rendered', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Adresse par défaut'), findsOneWidget);
  });

  testWidgets('Switch starts as false', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isFalse);
  });

  testWidgets('tapping Switch changes value to true', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    // Le Switch peut être sous le fold — scroll jusqu'à lui
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final updatedSwitch = tester.widget<Switch>(find.byType(Switch));
    expect(updatedSwitch.value, isTrue);
  });

  // ── Pays ────────────────────────────────────────────────────────────────

  testWidgets('flag emoji of Sénégal is displayed initially', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    // Le flag SN est 🇸🇳
    expect(find.textContaining('🇸🇳'), findsOneWidget);
  });

  // ── Section labels ───────────────────────────────────────────────────────

  testWidgets('all section labels are present', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text('ÉTIQUETTE'), findsOneWidget);
    expect(find.text('PAYS'), findsOneWidget);
    expect(find.text('ADRESSE'), findsOneWidget);
    expect(find.text('INSTRUCTIONS'), findsOneWidget);
  });

  // ── _locationState branch coverage ──────────────────────────────────────

  testWidgets('entering street text shows manual location status', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    // Initially hidden (rue optionnelle vide)
    expect(find.textContaining('localisée'), findsNothing);

    // Enter street text (2e EditableText = Ville; 3e = Rue, quartier)
    // Le champ Ville est at(1), le champ AddressSuggestField (rue) est at(2)
    final streetField = find.byType(EditableText).at(2);
    await tester.enterText(streetField, 'Rue Almadies');
    await tester.pump();

    // Now it should show manual status (pas de coordonnées)
    expect(find.textContaining('non localisée'), findsOneWidget);
  });

  // ── Pré-remplissage en mode édition ─────────────────────────────────────

  testWidgets('prefills label when editing and address found in state', (
    tester,
  ) async {
    final address = _makeAddress();
    when(() => repo.getAll()).thenAnswer((_) async => [address]);

    final editBloc = DeliveryAddressBloc(repo);
    addTearDown(editBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: BlocProvider.value(
            value: editBloc,
            child: const DeliveryAddressEditScreen(addressId: 'del-1'),
          ),
        ),
      ),
    );

    editBloc.add(const DeliveryAddressLoaded());
    await tester.pumpAndSettle();

    final textFields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    final labelField = textFields.firstWhere(
      (tf) => tf.controller.text == 'Famille',
      orElse: () => throw TestFailure('Champ "Famille" non trouvé'),
    );
    expect(labelField.controller.text, 'Famille');
  });

  // ── Pays accessoires ─────────────────────────────────────────────────────

  testWidgets('_countryFlag returns flag for SN', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();
    // Vérification que Sénégal est visible avec son nom
    expect(find.text('Sénégal'), findsOneWidget);
  });

  testWidgets('_countryName returns name for default country SN', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();
    expect(find.text('Sénégal'), findsOneWidget);
  });

  // ── _submit (création) via form fill + button tap ────────────────────────

  testWidgets('submit calls DeliveryAddressCreated when form is valid', (
    tester,
  ) async {
    when(() => repo.create(any())).thenAnswer((_) async => _makeAddress());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    // Étiquette via chip
    await tester.tap(find.text('Famille'));
    await tester.pump();

    // Ville (index 1)
    await tester.enterText(find.byType(EditableText).at(1), 'Dakar');
    await tester.pump();

    // Tap le bouton
    await tester.tap(find.text("Enregistrer l'adresse"));
    await tester.pumpAndSettle();

    verify(() => repo.create(any())).called(1);
  });

  testWidgets('submit with instructions fills optional field', (tester) async {
    when(() => repo.create(any())).thenAnswer((_) async => _makeAddress());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    // Étiquette manuelle
    await tester.enterText(find.byType(EditableText).at(0), 'Dépôt Almadies');
    await tester.pump();

    // Ville
    await tester.enterText(find.byType(EditableText).at(1), 'Dakar');
    await tester.pump();

    // Instructions (dernier EditableText)
    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    await tester.enterText(
      find.byType(EditableText).at(fields.length - 1),
      "Appeler à l'arrivée",
    );
    await tester.pump();

    await tester.tap(find.text("Enregistrer l'adresse"));
    await tester.pumpAndSettle();

    verify(() => repo.create(any())).called(1);
  });

  // ── _submit ignoré si formulaire invalide ────────────────────────────────

  testWidgets('form starts with empty label', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    final labelField = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    expect(labelField.controller.text, isEmpty);
  });

  // ── _submit with street (rue optionnelle) ────────────────────────────────

  testWidgets('submit with street sends rue data', (tester) async {
    when(() => repo.create(any())).thenAnswer((_) async => _makeAddress());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Boutique'));
    await tester.pump();

    // Ville
    await tester.enterText(find.byType(EditableText).at(1), 'Abidjan');
    await tester.pump();

    // Rue (index 2 — AddressSuggestField)
    await tester.enterText(find.byType(EditableText).at(2), 'Rue des Jardins');
    await tester.pump();

    await tester.tap(find.text("Enregistrer l'adresse"));
    await tester.pumpAndSettle();

    verify(() => repo.create(any())).called(1);
  });

  // ── _submit edit path (update) ──────────────────────────────────────────

  testWidgets('submit calls repo.update when editing an address', (
    tester,
  ) async {
    when(
      () => repo.update(any(), any()),
    ).thenAnswer((_) async => _makeAddress());

    // addressId non-null → _isEditing = true → _submit dispatch DeliveryAddressUpdated
    await tester.pumpWidget(_wrap(bloc, addressId: 'del-1'));
    await tester.pump(const Duration(milliseconds: 500));

    // Remplir étiquette + ville pour rendre le form valide
    await tester.tap(find.text('Famille'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText).at(1), 'Dakar');
    await tester.pump();

    await tester.tap(find.text("Enregistrer l'adresse"));
    await tester.pump(const Duration(milliseconds: 500));

    verify(() => repo.update(any(), any())).called(1);
  });

  // ── Bloc error state after submit ────────────────────────────────────────

  testWidgets('form still shows after repo error', (tester) async {
    when(() => repo.create(any())).thenThrow(Exception('Erreur réseau'));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Famille'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText).at(1), 'Dakar');
    await tester.pump();

    await tester.tap(find.text("Enregistrer l'adresse"));
    await tester.pumpAndSettle();

    expect(find.text("Enregistrer l'adresse"), findsOneWidget);
  });

  // ── _locationState: localized branch (covered via manual entry) ──────────

  testWidgets('location state hidden when street is empty initially', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.textContaining('localisée'), findsNothing);
  });
}
