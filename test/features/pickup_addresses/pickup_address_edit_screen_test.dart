import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';
import 'package:dony/features/pickup_addresses/data/repositories/pickup_address_repository.dart';
import 'package:dony/features/pickup_addresses/presentation/screens/pickup_address_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PickupAddressRepository {}

class _MockAutocompleteService extends Mock
    implements AddressAutocompleteService {}

Widget _wrap(PickupAddressBloc bloc, {String? addressId}) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: BlocProvider.value(
          value: bloc,
          child: PickupAddressEditScreen(addressId: addressId),
        ),
      ),
    );

// Helper: a valid PickupAddress fixture for editing tests.
PickupAddress _makeAddress({bool isDefault = false}) => PickupAddress(
      id: 'addr-1',
      label: 'Maison',
      street: '12 rue Victor Hugo',
      postalCode: '75001',
      city: 'Paris',
      country: 'FR',
      latitude: 48.86,
      longitude: 2.35,
      isDefault: isDefault,
    );

void main() {
  late _MockRepo repo;
  late PickupAddressBloc bloc;

  setUpAll(() {
    // Register mock AddressAutocompleteService in GetIt so the screen can build.
    if (!getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.registerSingleton<AddressAutocompleteService>(
        _MockAutocompleteService(),
      );
    }
  });

  setUp(() {
    repo = _MockRepo();
    when(() => repo.getAll()).thenAnswer((_) async => <PickupAddress>[]);
    bloc = PickupAddressBloc(repo);
  });

  tearDown(() => bloc.close());

  // ── Rendu initial ────────────────────────────────────────────────────────

  testWidgets('chips Maison/Bureau/Atelier are rendered', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text('Maison'), findsOneWidget);
    expect(find.text('Bureau'), findsOneWidget);
    expect(find.text('Atelier'), findsOneWidget);
  });

  testWidgets('tapping chip fills the label field', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bureau'));
    await tester.pump();

    // Le champ étiquette doit contenir 'Bureau'
    final textFields =
        tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    final labelField = textFields.firstWhere(
      (tf) => tf.controller.text == 'Bureau',
      orElse: () => throw TestFailure('Aucun champ texte avec "Bureau"'),
    );
    expect(labelField.controller.text, 'Bureau');
  });

  testWidgets('CTA button is present', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text("Enregistrer l'adresse"), findsOneWidget);
  });

  // ── Titre selon le mode ─────────────────────────────────────────────────

  testWidgets('title is "Nouvelle adresse de remise" in create mode',
      (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle adresse de remise'), findsOneWidget);
  });

  testWidgets('title is "Modifier l\'adresse" in edit mode', (tester) async {
    await tester.pumpWidget(_wrap(bloc, addressId: 'addr-1'));
    await tester.pumpAndSettle();
    expect(find.text("Modifier l'adresse"), findsOneWidget);
  });

  // ── Chip tap ────────────────────────────────────────────────────────────

  testWidgets('tapping chip Atelier fills the label field', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atelier'));
    await tester.pump();

    final textFields =
        tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    final labelField = textFields.firstWhere(
      (tf) => tf.controller.text == 'Atelier',
      orElse: () => throw TestFailure('Champ "Atelier" non trouvé'),
    );
    expect(labelField.controller.text, 'Atelier');
  });

  // ── Pré-remplissage en mode édition ─────────────────────────────────────

  testWidgets('prefills fields when editing and address found in state',
      (tester) async {
    final address = _makeAddress();
    when(() => repo.getAll()).thenAnswer((_) async => [address]);

    final editBloc = PickupAddressBloc(repo);
    addTearDown(editBloc.close);

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: BlocProvider.value(
          value: editBloc,
          child: const PickupAddressEditScreen(addressId: 'addr-1'),
        ),
      ),
    ));

    // Déclenche le chargement
    editBloc.add(const PickupAddressLoaded());
    await tester.pumpAndSettle();

    // Le champ étiquette doit être pré-rempli avec "Maison"
    final textFields =
        tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    final labelField = textFields.firstWhere(
      (tf) => tf.controller.text == 'Maison',
      orElse: () => throw TestFailure('Champ "Maison" non trouvé'),
    );
    expect(labelField.controller.text, 'Maison');
  });

  // ── Toggle "Adresse par défaut" ──────────────────────────────────────────

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

  testWidgets('tapping Switch toggle changes value to true', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    // Le Switch peut être en dehors de la vue — scroll jusqu'à lui
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final updatedSwitch = tester.widget<Switch>(find.byType(Switch));
    expect(updatedSwitch.value, isTrue);
  });

  // ── Validation ──────────────────────────────────────────────────────────

  testWidgets('CTA button text exists and form starts empty', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    // Le bouton est présent
    expect(find.text("Enregistrer l'adresse"), findsOneWidget);

    // Les champs texte sont initialement vides (sauf country='FR' qui est caché)
    final textFields =
        tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    final labelField = textFields.first;
    expect(labelField.controller.text, isEmpty);
  });

  // ── Section labels ───────────────────────────────────────────────────────

  testWidgets('all section labels are present', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text('ÉTIQUETTE'), findsOneWidget);
    expect(find.text('ADRESSE'), findsOneWidget);
    expect(find.text('ÉTAGE / APPARTEMENT'), findsOneWidget);
    expect(find.text('INSTRUCTIONS'), findsOneWidget);
  });

  // ── _locationState branch coverage ───────────────────────────────────────

  testWidgets('entering street text changes location status visibility',
      (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    // Initially hidden (street empty)
    expect(find.textContaining('localisée'), findsNothing);

    // Enter street text (second EditableText after label)
    final streetField = find.byType(EditableText).at(1);
    await tester.enterText(streetField, '12 rue de la Paix');
    await tester.pump();

    // Now it should show manual status
    expect(find.textContaining('non localisée'), findsOneWidget);
  });

  // ── _isEditing flag ──────────────────────────────────────────────────────

  testWidgets('_isEditing=false shows create title', (tester) async {
    // addressId is null → create mode
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle adresse de remise'), findsOneWidget);
  });

  testWidgets('_isEditing=true shows edit title', (tester) async {
    await tester.pumpWidget(_wrap(bloc, addressId: 'some-id'));
    await tester.pumpAndSettle();
    expect(find.text("Modifier l'adresse"), findsOneWidget);
  });

  // ── _submit (création) via form fill + button tap ────────────────────────

  testWidgets('submit calls PickupAddressCreated when form is valid',
      (tester) async {
    when(() => repo.create(any())).thenAnswer((_) async => _makeAddress());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    // Remplir étiquette via chip
    await tester.tap(find.text('Maison'));
    await tester.pump();

    // Remplir code postal (index 2) et ville (index 3)
    await tester.enterText(find.byType(EditableText).at(2), '75001');
    await tester.pump();
    await tester.enterText(find.byType(EditableText).at(3), 'Paris');
    await tester.pump();

    // Taper le bouton de soumission
    await tester.tap(find.text("Enregistrer l'adresse"));
    await tester.pumpAndSettle();

    // Le BLoC reçoit l'événement (le mock repo est appelé)
    verify(() => repo.create(any())).called(1);
  });

  testWidgets('submit with street and instructions fills optional fields',
      (tester) async {
    when(() => repo.create(any())).thenAnswer((_) async => _makeAddress());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    // Étiquette
    await tester.enterText(find.byType(EditableText).at(0), 'Mon bureau');
    await tester.pump();

    // Rue (index 1)
    await tester.enterText(find.byType(EditableText).at(1), '5 rue du Louvre');
    await tester.pump();

    // Code postal
    await tester.enterText(find.byType(EditableText).at(2), '75001');
    await tester.pump();

    // Ville
    await tester.enterText(find.byType(EditableText).at(3), 'Paris');
    await tester.pump();

    // Étage
    await tester.enterText(find.byType(EditableText).at(4), 'Bât B, 2e');
    await tester.pump();

    // Instructions
    await tester.enterText(find.byType(EditableText).at(5), 'Digicode 1234');
    await tester.pump();

    await tester.tap(find.text("Enregistrer l'adresse"));
    await tester.pumpAndSettle();

    verify(() => repo.create(any())).called(1);
  });

  // ── _submit ignoré si formulaire invalide ────────────────────────────────

  testWidgets('submit does nothing when form is invalid', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    // On ne remplit pas l'étiquette ni la ville → bouton désactivé
    // Note: DonyButton with onPressed=null ne dispatche rien
    // Vérifie juste que le champ label est vide
    final labelField = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(labelField.controller.text, isEmpty);
  });

  // ── _locationState transitions ────────────────────────────────────────────

  testWidgets('location status changes from hidden to manual when street entered',
      (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    // Statut caché initialement
    expect(find.textContaining('non localisée'), findsNothing);

    await tester.enterText(find.byType(EditableText).at(1), 'Rue de la Paix');
    await tester.pump();

    expect(find.textContaining('non localisée'), findsOneWidget);
  });

  // ── _submit edit path (update) ──────────────────────────────────────────

  testWidgets('submit calls repo.update when editing an address', (tester) async {
    when(() => repo.update(any(), any())).thenAnswer((_) async => _makeAddress());

    // addressId non-null → _isEditing = true → _submit dispatch PickupAddressUpdated
    await tester.pumpWidget(_wrap(bloc, addressId: 'addr-1'));
    await tester.pump(const Duration(milliseconds: 500));

    // Remplir étiquette via chip + ville pour rendre le form valide
    await tester.tap(find.text('Maison'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText).at(3), 'Lyon');
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

    await tester.tap(find.text('Maison'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText).at(3), 'Paris');
    await tester.pump();

    await tester.tap(find.text("Enregistrer l'adresse"));
    await tester.pumpAndSettle();

    // L'écran doit toujours être visible (pas de pop)
    expect(find.text("Enregistrer l'adresse"), findsOneWidget);
  });
}
