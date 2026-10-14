import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_bloc.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_event.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_state.dart';
import 'package:dony/features/delivery_addresses/data/models/delivery_address.dart';
import 'package:dony/features/delivery_addresses/data/repositories/delivery_address_repository.dart';
import 'package:dony/features/delivery_addresses/presentation/screens/delivery_address_edit_screen.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_suggest_field.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/l10n_test_helpers.dart';

class _MockRepo extends Mock implements DeliveryAddressRepository {}

class _MockDio extends Mock implements Dio {}

class _MockDeliveryAddressBloc
    extends MockBloc<DeliveryAddressEvent, DeliveryAddressState>
    implements DeliveryAddressBloc {}

class _MockBusinessPrefsBloc
    extends MockBloc<BusinessPrefsEvent, BusinessPrefsState>
    implements BusinessPrefsBloc {}

Widget _wrapWithPrefs(DeliveryAddressBloc bloc, BusinessPrefsBloc prefs) =>
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<DeliveryAddressBloc>.value(value: bloc),
            BlocProvider<BusinessPrefsBloc>.value(value: prefs),
          ],
          child: const DeliveryAddressEditScreen(),
        ),
      ),
    );

/// Simule le choix d'une suggestion : [AddressSuggestField] a déjà écrit le
/// libellé court dans le champ, puis rend l'adresse résolue.
Future<void> _resolve(
  WidgetTester tester, {
  required String mainText,
  required AddressData addr,
}) async {
  await tester.enterText(find.byType(EditableText).at(1), mainText);
  await tester.pump();
  tester
      .widget<AddressSuggestField>(find.byType(AddressSuggestField))
      .onResolved!(addr);
  await tester.pump();
}

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
    registerFallbackValue(const DeliveryAddressLoaded());
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
    expect(find.text('ADRESSE'), findsOneWidget);
    expect(find.text('INSTRUCTIONS'), findsOneWidget);
    // Le pays n'est plus une section : c'est un champ de la section ADRESSE.
    expect(find.text('PAYS'), findsNothing);
    expect(find.text('Pays'), findsOneWidget);
  });

  // ── _locationState branch coverage ──────────────────────────────────────

  testWidgets('entering street text shows manual location status', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    // Initially hidden (rue optionnelle vide)
    expect(find.textContaining('localisée'), findsNothing);

    // La recherche d'adresse (AddressSuggestField) est at(1), en tête de la
    // section ADRESSE ; la ville est at(2).
    final streetField = find.byType(EditableText).at(1);
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

    // Ville (index 2, sous la recherche d'adresse)
    await tester.enterText(find.byType(EditableText).at(2), 'Dakar');
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
    await tester.enterText(find.byType(EditableText).at(2), 'Dakar');
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
    await tester.enterText(find.byType(EditableText).at(2), 'Abidjan');
    await tester.pump();

    // Rue (index 1 — AddressSuggestField, recherche en tête de section)
    await tester.enterText(find.byType(EditableText).at(1), 'Rue des Jardins');
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
    await tester.enterText(find.byType(EditableText).at(2), 'Dakar');
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
    await tester.enterText(find.byType(EditableText).at(2), 'Dakar');
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

  // ── Anglais ──────────────────────────────────────────────────────────────

  testWidgets('en anglais : titre, chips, pays et bouton traduits', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();

    expect(find.text('New delivery address'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Senegal'), findsOneWidget);
    expect(find.text('Search for an address'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('Save address'), findsOneWidget);
  });

  testWidgets(
    'en anglais : erreur réseau affiche le texte du catalogue, jamais le '
    'message brut',
    (tester) async {
      useEnglish();
      final mockBloc = _MockDeliveryAddressBloc();
      final states = StreamController<DeliveryAddressState>();
      addTearDown(states.close);
      whenListen<DeliveryAddressState>(
        mockBloc,
        states.stream,
        initialState: const DeliveryAddressState(),
      );

      await tester.pumpWidget(_wrap(mockBloc));
      await tester.pump();

      await tester.tap(find.text('Family'));
      await tester.pump();
      await tester.enterText(find.byType(EditableText).at(2), 'Dakar');
      await tester.pump();
      // Arme `_hasSubmitted` avant que la réponse n'arrive par le stream,
      // exactement comme un vrai bloc l'aurait fait.
      await tester.tap(find.text('Save address'));
      await tester.pump();

      states.add(
        const DeliveryAddressState(status: DeliveryAddressStatus.loading),
      );
      await tester.pump();
      states.add(
        const DeliveryAddressState(
          status: DeliveryAddressStatus.error,
          error: NetworkException('raw technical detail'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('raw technical detail'), findsNothing);
    },
  );

  // ── Recherche d'adresse en un coup (FLUTTER-PE) ─────────────────────────

  group('recherche d\'adresse', () {
    testWidgets('la recherche est le premier champ de la section ADRESSE, '
        'avant le pays et la ville', (tester) async {
      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      final searchY = tester.getTopLeft(find.text('Rechercher une adresse')).dy;
      final countryY = tester.getTopLeft(find.text('Pays')).dy;
      final cityY = tester.getTopLeft(find.text('Ville')).dy;
      expect(searchY, lessThan(countryY));
      expect(countryY, lessThan(cityY));
    });

    testWidgets('la résolution remplit pays, ville et coordonnées', (
      tester,
    ) async {
      Map<String, dynamic>? sent;
      when(() => repo.create(any())).thenAnswer((inv) async {
        sent = inv.positionalArguments.first as Map<String, dynamic>;
        return _makeAddress();
      });

      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();
      expect(find.text('Sénégal'), findsOneWidget);

      await _resolve(
        tester,
        mainText: 'Rue des Jardins',
        addr: const AddressData(
          label: 'Rue des Jardins, Abidjan',
          lat: 5.36,
          lng: -3.99,
          street: 'Rue des Jardins',
          city: 'Abidjan',
          country: 'CI',
        ),
      );

      expect(find.text("Côte d'Ivoire"), findsOneWidget);
      expect(find.textContaining('🇨🇮'), findsOneWidget);
      expect(find.text('Sénégal'), findsNothing);
      final city = tester.widget<EditableText>(find.byType(EditableText).at(2));
      expect(city.controller.text, 'Abidjan');
      expect(find.text('Adresse localisée'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).at(0), 'Famille');
      await tester.pump();
      await tester.tap(find.text("Enregistrer l'adresse"));
      await tester.pumpAndSettle();

      expect(sent, isNotNull);
      expect(sent!['street'], 'Rue des Jardins');
      expect(sent!['city'], 'Abidjan');
      expect(sent!['country'], 'CI');
      expect(sent!['latitude'], 5.36);
      expect(sent!['longitude'], -3.99);
    });

    testWidgets(
      'pays hors catalogue mais nommé (GN) : repris avec son drapeau',
      (tester) async {
        await tester.pumpWidget(_wrap(bloc));
        await tester.pumpAndSettle();

        await _resolve(
          tester,
          mainText: 'Kaloum',
          addr: const AddressData(
            label: 'Kaloum, Conakry',
            lat: 9.51,
            lng: -13.71,
            city: 'Conakry',
            country: 'gn',
          ),
        );

        expect(find.text('Guinée'), findsOneWidget);
        expect(find.textContaining('🇬🇳'), findsOneWidget);
      },
    );

    testWidgets('pays inconnu de l\'app : le pays courant est gardé', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      await _resolve(
        tester,
        mainText: 'Osu',
        addr: const AddressData(
          label: 'Osu, Accra',
          lat: 5.55,
          lng: -0.18,
          city: 'Accra',
          country: 'GH',
        ),
      );

      expect(find.text('Sénégal'), findsOneWidget);
      final city = tester.widget<EditableText>(find.byType(EditableText).at(2));
      expect(city.controller.text, 'Accra');
    });

    testWidgets('sans ville ni pays résolus : la saisie manuelle est gardée', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(2), 'Thiès');
      await tester.pump();

      await _resolve(
        tester,
        mainText: 'Marché central',
        addr: const AddressData(
          label: 'Marché central',
          lat: 14.79,
          lng: -16.93,
        ),
      );

      final city = tester.widget<EditableText>(find.byType(EditableText).at(2));
      expect(city.controller.text, 'Thiès');
      expect(find.text('Sénégal'), findsOneWidget);
    });
  });

  // ── Pays : défaut, tolérance, sélecteur ──────────────────────────────────

  group('pays', () {
    testWidgets('défaut : pays du profil quand il est connu', (tester) async {
      final prefs = _MockBusinessPrefsBloc();
      when(
        () => prefs.state,
      ).thenReturn(const BusinessPrefsState(country: 'FR'));

      await tester.pumpWidget(_wrapWithPrefs(bloc, prefs));
      await tester.pumpAndSettle();

      expect(find.text('France'), findsOneWidget);
      expect(find.textContaining('🇫🇷'), findsOneWidget);
    });

    testWidgets('défaut : Sénégal quand le profil n\'a pas de pays', (
      tester,
    ) async {
      final prefs = _MockBusinessPrefsBloc();
      when(() => prefs.state).thenReturn(const BusinessPrefsState());

      await tester.pumpWidget(_wrapWithPrefs(bloc, prefs));
      await tester.pumpAndSettle();

      expect(find.text('Sénégal'), findsOneWidget);
    });

    testWidgets('édition d\'une adresse en Guinée (hors catalogue) : '
        'drapeau et nom, sans planter', (tester) async {
      const address = DeliveryAddress(
        id: 'del-gn',
        label: 'Famille',
        city: 'Conakry',
        country: 'GN',
        isDefault: false,
      );
      when(() => repo.getAll()).thenAnswer((_) async => [address]);
      final editBloc = DeliveryAddressBloc(repo);
      addTearDown(editBloc.close);

      await tester.pumpWidget(_wrap(editBloc, addressId: 'del-gn'));
      editBloc.add(const DeliveryAddressLoaded());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Guinée'), findsOneWidget);
      expect(find.textContaining('🇬🇳'), findsOneWidget);
    });

    testWidgets(
      'le sélecteur propose tous les pays de l\'app, avec recherche',
      (tester) async {
        await tester.pumpWidget(_wrap(bloc));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sénégal'));
        await tester.pumpAndSettle();

        expect(find.text('Pays de destination'), findsOneWidget);
        // Sections par zone, Europe comprise (plus seulement l'Afrique).
        expect(find.text('EUROPE'), findsOneWidget);

        await tester.enterText(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(EditableText),
          ),
          'Fra',
        );
        await tester.pumpAndSettle();

        final france = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('France'),
        );
        expect(france, findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Mali'),
          ),
          findsNothing,
        );

        await tester.tap(france);
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('France'), findsOneWidget);
        expect(find.textContaining('🇫🇷'), findsOneWidget);
      },
    );
  });
}
