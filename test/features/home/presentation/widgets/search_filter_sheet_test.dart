// Tests de SearchFilterSheet — la sheet de filtres unique de l'écran Rechercher.
//
// Le point vérifié ici n'est pas la richesse des filtres mais le partage : le
// bloc corridor + date doit être le MÊME widget dans les deux modes, sinon le
// corridor se reperd à chaque bascule. Les finders visent donc surtout ce bloc.
//
// Au-delà du rendu, ces tests exercent le CONTRAT de `show` (valeur retournée
// à la validation, `null` à la fermeture) et les interactions qui produisent
// cette valeur : c'est la seule chose que consommera l'écran Rechercher.
//
// Écarts assumés par rapport au brief :
//  - `DonyButton` n'est pas un `ElevatedButton` (variante primary = conteneur
//    dégradé + InkWell) → on cible `DonyButton`.
//  - la croix de `DonyBottomSheet` est un SVG `DonyIcon('x')`, pas un
//    `Icons.close` → on referme la sheet par le barrier modal.

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_fields.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_sheet.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockCityRepository extends Mock implements CityRepository {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

void main() {
  // La date personnalisée s'affiche via DateFormat('d MMM', 'fr').
  setUpAll(() => initializeDateFormatting('fr'));

  // Résultat de `SearchFilterSheet.show` : `valide` distingue « pas encore
  // fermée » de « fermée sans valider », les deux donnant `resultat == null`.
  HomeSearchFilters? resultat;
  var ferme = false;

  setUp(() {
    resultat = null;
    ferme = false;

    final cityRepo = _MockCityRepository();
    when(() => cityRepo.searchCities(any())).thenAnswer((_) async => []);
    when(() => cityRepo.getPopularCorridors()).thenAnswer((_) async => []);

    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
    getIt.registerFactory<CitySearchBloc>(() => CitySearchBloc(cityRepo));

    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
    getIt.registerFactory<IContentCategoryRepository>(
      () => _FakeContentCategoryRepository(),
    );
  });

  tearDown(() {
    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
    if (getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.unregister<IContentCategoryRepository>();
    }
  });

  /// [activeTrips] : trajets actifs de l'utilisateur. Au-dessus de zéro, la
  /// pastille « Pour mes trajets » est utilisable ; à zéro elle est grisée et
  /// n'ouvre qu'une explication ; à `null` le nombre est inconnu et la pastille
  /// reste utilisable.
  /// L'overlay de suggestions du sélecteur de contenu se place sous le champ :
  /// dans un viewport de 600 px il tombe hors écran et les taps n'atteignent
  /// rien.
  void vueHaute(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    // `view.reset` et non `resetPhysicalSize` : ce dernier laisse fuiter le
    // devicePixelRatio sur les tests suivants du fichier.
    addTearDown(tester.view.reset);
  }

  Future<void> ouvrir(
    WidgetTester tester, {
    required SearchMode mode,
    HomeSearchFilters initial = const HomeSearchFilters(),
    int? activeTrips = 2,
    VoidCallback? onPublishTrip,
  }) async {
    resultat = null;
    ferme = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              resultat = await SearchFilterSheet.show(
                ctx,
                mode: mode,
                initial: initial,
                activeTrips: activeTrips,
                onPublishTrip: onPublishTrip,
              );
              ferme = true;
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  Future<void> fermer(WidgetTester tester) async {
    // Tap sur le barrier modal, au-dessus de la sheet.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  }

  /// Tap sur un élément du contenu défilant : il faut d'abord le ramener dans
  /// la zone visible, la sheet ne fait que 85 % de la hauteur d'écran.
  Future<void> taper(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// Valide la sheet et rend la valeur retournée par `show`.
  Future<HomeSearchFilters?> rechercher(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(DonyButton, 'Rechercher'));
    await tester.pumpAndSettle();
    return resultat;
  }

  Finder dansPicker(Finder f) =>
      find.descendant(of: find.byType(SimpleSheet), matching: f);

  /// `RendererBinding.rootPipelineOwner` (non deprecated) est la racine d'un
  /// ARBRE de `PipelineOwner` (un par vue) et sa recherche du `SemanticsOwner`
  /// de la vue de test s'est montrée instable d'un test à l'autre dans ce
  /// binding. `WidgetsBinding.pipelineOwner` (deprecated) reste le seul accès
  /// fiable et constant à l'owner de la vue de test unique utilisée ici.
  SemanticsOwner semanticsOwnerActif(WidgetTester tester) =>
      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!;

  /// Le `Slider` M3 loge son indicateur de valeur dans un `OverlayPortal` :
  /// le nœud sémantique du `RenderObject` trouvé via `find.byType(Slider)`
  /// n'est qu'une frontière englobante sans action. Les actions
  /// `increase`/`decrease` vivent sur un nœud descendant (le vrai rendu du
  /// slider) qu'il faut retrouver en parcourant l'arbre sémantique.
  SemanticsNode noeudSliderSemantics(WidgetTester tester) {
    late SemanticsNode trouve;
    void chercher(SemanticsNode n) {
      if (n.getSemanticsData().hasAction(SemanticsAction.decrease)) {
        trouve = n;
        return;
      }
      n.visitChildren((c) {
        chercher(c);
        return true;
      });
    }

    chercher(semanticsOwnerActif(tester).rootSemanticsNode!);
    return trouve;
  }

  /// Déplace le curseur du sélecteur de poids par pas exacts d'1 kg, via les
  /// actions sémantiques du `Slider` (incrément/décrément = 1 kg ici,
  /// `divisions: 29` sur l'intervalle 1-30 kg). Précis au kg près : un
  /// `tester.drag` en pixels dépendrait de la largeur réelle du widget et ne
  /// permettrait pas d'atteindre une valeur exacte de façon fiable.
  Future<void> ajusterPoids(
    WidgetTester tester, {
    required bool diminuer,
    required int pas,
  }) async {
    final handle = tester.ensureSemantics();
    await tester.pump();
    final owner = semanticsOwnerActif(tester);
    for (var i = 0; i < pas; i++) {
      final noeud = noeudSliderSemantics(tester);
      owner.performAction(
        noeud.id,
        diminuer ? SemanticsAction.decrease : SemanticsAction.increase,
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    handle.dispose();
  }

  // ── Rendu ──────────────────────────────────────────────────────────────────

  testWidgets('mode trajets : titre et filtres spécifiques', (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);

    expect(find.text('Filtrer les trajets'), findsOneWidget);
    expect(find.text('Kilo Pro'), findsOneWidget);
    expect(find.text('Identité vérifiée'), findsOneWidget);
  });

  testWidgets('mode colis : titre et filtres spécifiques', (tester) async {
    await ouvrir(tester, mode: SearchMode.parcels);

    expect(find.text('Filtrer les colis'), findsOneWidget);
    expect(find.text('Kilo Pro'), findsNothing);
    expect(find.text('Identité vérifiée'), findsNothing);
  });

  testWidgets('le bloc commun est présent dans les deux modes', (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);
    expect(find.byType(CommonFilterBlock), findsOneWidget);
    expect(find.text('Ville de départ'), findsOneWidget);
    expect(find.text("Ville d'arrivée"), findsOneWidget);

    await fermer(tester);

    await ouvrir(tester, mode: SearchMode.parcels);
    expect(find.byType(CommonFilterBlock), findsOneWidget);
    expect(find.text('Ville de départ'), findsOneWidget);
    expect(find.text("Ville d'arrivée"), findsOneWidget);
  });

  testWidgets('le corridor initial est pré-rempli dans les deux modes',
      (tester) async {
    const initial =
        HomeSearchFilters(departureCity: 'Paris', arrivalCity: 'Dakar');

    await ouvrir(tester, mode: SearchMode.parcels, initial: initial);
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);

    await fermer(tester);

    await ouvrir(tester, mode: SearchMode.trips, initial: initial);
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
  });

  testWidgets('le bouton porte le même libellé dans les deux modes',
      (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);
    expect(find.widgetWithText(DonyButton, 'Rechercher'), findsOneWidget);
    expect(find.text('Appliquer'), findsNothing);

    await fermer(tester);

    await ouvrir(tester, mode: SearchMode.parcels);
    expect(find.widgetWithText(DonyButton, 'Rechercher'), findsOneWidget);
    expect(find.text('Appliquer'), findsNothing);
  });

  testWidgets('« Tout effacer » absent quand aucun filtre actif',
      (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);

    expect(find.text('Tout effacer'), findsNothing);
  });

  testWidgets('« Tout effacer » présent dès qu\'un filtre est actif',
      (tester) async {
    await ouvrir(
      tester,
      mode: SearchMode.trips,
      initial: const HomeSearchFilters(kiloProOnly: true),
    );

    expect(find.text('Tout effacer'), findsOneWidget);
  });

  // ── Contrat de retour de `show` ────────────────────────────────────────────

  testWidgets('« Rechercher » retourne les filtres édités', (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);

    await taper(tester, find.text('Kilo Pro'));
    final valeur = await rechercher(tester);

    expect(ferme, isTrue);
    expect(valeur, isNotNull);
    expect(valeur!.kiloProOnly, isTrue);
  });

  testWidgets('fermer sans valider retourne null', (tester) async {
    await ouvrir(
      tester,
      mode: SearchMode.trips,
      initial: const HomeSearchFilters(departureCity: 'Paris'),
    );

    await taper(tester, find.text('Kilo Pro'));
    await fermer(tester);

    expect(ferme, isTrue);
    expect(resultat, isNull);
  });

  // ── Défaut 1 : vider un champ de ville vide bien le filtre ─────────────────

  testWidgets('la croix du champ départ vide le filtre départ, pas l\'arrivée',
      (tester) async {
    await ouvrir(
      tester,
      mode: SearchMode.trips,
      initial: const HomeSearchFilters(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
      ),
    );

    final croix = find.descendant(
      of: find.byKey(const Key('filter-departure-city')),
      matching: find.byType(IconButton),
    );
    await taper(tester, croix);

    final valeur = await rechercher(tester);
    expect(valeur!.departureCity, isNull);
    expect(valeur.arrivalCity, 'Dakar');
  });

  testWidgets('effacer le texte du champ arrivée vide le filtre arrivée',
      (tester) async {
    await ouvrir(
      tester,
      mode: SearchMode.parcels,
      initial: const HomeSearchFilters(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
      ),
    );

    await tester.enterText(find.byKey(const Key('filter-arrival-city')), '');
    await tester.pumpAndSettle();

    final valeur = await rechercher(tester);
    expect(valeur!.arrivalCity, isNull);
    expect(valeur.departureCity, 'Paris');
  });

  // ── Défaut 3 : « Tout effacer » ────────────────────────────────────────────

  testWidgets(
      '« Tout effacer » en mode trajets efface communs + trajets, garde colis',
      (tester) async {
    await ouvrir(
      tester,
      mode: SearchMode.trips,
      initial: const HomeSearchFilters(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        datePreset: DonyDatePreset.today,
        urgentOnly: true,
        nearMeActive: true,
        nearMeRadiusKm: 10,
        kiloProOnly: true,
        minRating: 4.5,
        weightMin: 12,
        maxPricePerKg: 8,
        weekendOnly: true,
        kycVerifiedOnly: true,
        transportMode: TransportMode.plane,
        contentType: 'Chaussures',
        urgencyFilter: UrgencyFilter.urgent,
        // Filtres colis : ils doivent survivre.
        maxWeight: 10,
        parcelSize: ParcelSize.medium,
        matchingMyTrips: true,
      ),
    );

    await tester.tap(find.text('Tout effacer'));
    await tester.pumpAndSettle();
    final valeur = await rechercher(tester);

    // Communs effacés.
    expect(valeur!.departureCity, isNull);
    expect(valeur.arrivalCity, isNull);
    expect(valeur.datePreset, DonyDatePreset.none);
    // urgentOnly / nearMeActive ne sont pas exposés dans la sheet mais sont
    // comptés par activeCountFor : les épargner laisserait un « Tout effacer »
    // qui n'efface pas tout et qui reste affiché. Décision documentée dans
    // `SearchFilterSheet._cleared`.
    expect(valeur.urgentOnly, isFalse);
    expect(valeur.nearMeActive, isFalse);
    // Trajets effacés.
    expect(valeur.kiloProOnly, isFalse);
    expect(valeur.minRating, isNull);
    expect(valeur.weightMin, isNull);
    expect(valeur.maxPricePerKg, isNull);
    expect(valeur.weekendOnly, isFalse);
    expect(valeur.kycVerifiedOnly, isFalse);
    expect(valeur.transportMode, isNull);
    expect(valeur.contentType, isNull);
    expect(valeur.urgencyFilter, isNull);
    // Colis préservés.
    expect(valeur.maxWeight, 10);
    expect(valeur.parcelSize, ParcelSize.medium);
    expect(valeur.matchingMyTrips, isTrue);
  });

  testWidgets(
      '« Tout effacer » en mode colis efface communs + colis, garde trajets',
      (tester) async {
    await ouvrir(
      tester,
      mode: SearchMode.parcels,
      initial: const HomeSearchFilters(
        departureCity: 'Paris',
        datePreset: DonyDatePreset.thisWeek,
        maxWeight: 10,
        parcelSize: ParcelSize.large,
        matchingMyTrips: true,
        kiloProOnly: true,
        transportMode: TransportMode.car,
      ),
    );

    await tester.tap(find.text('Tout effacer'));
    await tester.pumpAndSettle();
    final valeur = await rechercher(tester);

    expect(valeur!.departureCity, isNull);
    expect(valeur.datePreset, DonyDatePreset.none);
    expect(valeur.maxWeight, isNull);
    expect(valeur.parcelSize, isNull);
    expect(valeur.matchingMyTrips, isFalse);
    // Trajets préservés.
    expect(valeur.kiloProOnly, isTrue);
    expect(valeur.transportMode, TransportMode.car);
  });

  // ── Bloc commun : date ─────────────────────────────────────────────────────

  testWidgets('les presets de date s\'activent et se désactivent',
      (tester) async {
    await ouvrir(tester, mode: SearchMode.parcels);

    await taper(tester, find.text('Cette semaine'));
    expect(find.text('Tout effacer'), findsOneWidget);

    await taper(tester, find.text('Cette semaine'));
    expect(find.text('Tout effacer'), findsNothing);

    await taper(tester, find.text("Aujourd'hui"));
    final valeur = await rechercher(tester);
    expect(valeur!.datePreset, DonyDatePreset.today);
  });

  testWidgets('la date précise passe en preset custom puis se vide',
      (tester) async {
    await ouvrir(tester, mode: SearchMode.parcels);

    await taper(tester, find.text('DATE PRÉCISE'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Choisir'), findsNothing);

    await taper(tester, find.byType(DateField));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final valeur = await rechercher(tester);
    expect(valeur!.datePreset, DonyDatePreset.none);
    expect(valeur.customDate, isNull);
  });

  // ── Section colis ──────────────────────────────────────────────────────────

  testWidgets('section colis : poids max, taille et « Pour mes trajets »',
      (tester) async {
    await ouvrir(tester, mode: SearchMode.parcels);

    await taper(tester, find.text('≤ 10 kg'));
    await taper(tester, find.text('Moyen'));
    await taper(tester, find.text('Pour mes trajets'));

    final valeur = await rechercher(tester);
    expect(valeur!.maxWeight, 10);
    expect(valeur.parcelSize, ParcelSize.medium);
    expect(valeur.matchingMyTrips, isTrue);
  });

  testWidgets(
      'section colis : sans trajet actif, la pastille est grisée et n\'active '
      'rien', (tester) async {
    await ouvrir(tester, mode: SearchMode.parcels, activeTrips: 0);

    await tester.ensureVisible(find.byKey(const Key('chip-matching-my-trips')));
    await tester.pumpAndSettle();

    final griseee = tester
        .widgetList<Opacity>(find.ancestor(
          of: find.byKey(const Key('chip-matching-my-trips')),
          matching: find.byType(Opacity),
        ))
        .any((o) => o.opacity == 0.4);
    expect(griseee, isTrue);

    await tester.tap(find.byKey(const Key('chip-matching-my-trips')));
    await tester.pumpAndSettle();

    // L'explication remplace l'activation du filtre.
    expect(find.text('Aucun trajet actif'), findsOneWidget);
    expect(find.text('Publier un trajet'), findsOneWidget);
  });

  testWidgets('section colis : avec un trajet actif, la pastille n\'est pas '
      'grisée', (tester) async {
    await ouvrir(tester, mode: SearchMode.parcels, activeTrips: 1);

    await tester.ensureVisible(find.byKey(const Key('chip-matching-my-trips')));
    await tester.pumpAndSettle();

    final grisee = tester
        .widgetList<Opacity>(find.ancestor(
          of: find.byKey(const Key('chip-matching-my-trips')),
          matching: find.byType(Opacity),
        ))
        .any((o) => o.opacity == 0.4);
    expect(grisee, isFalse);
  });

  testWidgets(
      'section colis : nombre de trajets INCONNU, la pastille reste utilisable',
      (tester) async {
    // Résumé d'activité en échec réseau : on ne sait pas combien de trajets
    // l'utilisateur a. Griser reviendrait à affirmer « aucun », ce qui peut
    // être faux. La pastille reste donc active et le serveur tranchera.
    await ouvrir(tester, mode: SearchMode.parcels, activeTrips: null);

    await tester.ensureVisible(find.byKey(const Key('chip-matching-my-trips')));
    await tester.pumpAndSettle();

    final grisee = tester
        .widgetList<Opacity>(find.ancestor(
          of: find.byKey(const Key('chip-matching-my-trips')),
          matching: find.byType(Opacity),
        ))
        .any((o) => o.opacity == 0.4);
    expect(grisee, isFalse);

    await tester.tap(find.byKey(const Key('chip-matching-my-trips')));
    await tester.pumpAndSettle();

    // Pas d'explication mensongère, et le filtre part réellement.
    expect(find.text('Aucun trajet actif'), findsNothing);
    final valeur = await rechercher(tester);
    expect(valeur!.matchingMyTrips, isTrue);
  });

  testWidgets(
      'section colis : « Publier un trajet » ferme tout et délègue à l\'appelant',
      (tester) async {
    // La feuille ne navigue pas elle-même : elle est fermée à cet instant, et
    // seul l'appelant survit pour attendre le retour puis recharger le résumé.
    var appels = 0;
    await ouvrir(
      tester,
      mode: SearchMode.parcels,
      activeTrips: 0,
      onPublishTrip: () => appels++,
    );

    await tester.ensureVisible(find.byKey(const Key('chip-matching-my-trips')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chip-matching-my-trips')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Publier un trajet'));
    await tester.pumpAndSettle();

    expect(appels, 1);
    // Les deux feuilles ont bien été fermées.
    expect(find.text('Aucun trajet actif'), findsNothing);
    expect(find.text('Filtrer les colis'), findsNothing);
    expect(ferme, isTrue);
  });

  testWidgets('section colis : retaper une pastille active la désactive',
      (tester) async {
    await ouvrir(
      tester,
      mode: SearchMode.parcels,
      initial: const HomeSearchFilters(
        maxWeight: 5,
        parcelSize: ParcelSize.small,
      ),
    );

    await taper(tester, find.text('≤ 5 kg'));
    await taper(tester, find.text('Petit'));

    final valeur = await rechercher(tester);
    expect(valeur!.maxWeight, isNull);
    expect(valeur.parcelSize, isNull);
  });

  // ── Section trajets ────────────────────────────────────────────────────────

  testWidgets('section trajets : les pastilles rapides basculent',
      (tester) async {
    await ouvrir(
      tester,
      mode: SearchMode.trips,
      initial: const HomeSearchFilters(minRating: 4.5),
    );

    await taper(tester, find.text('Note ≥ 4.5'));
    await taper(tester, find.text('Week-end'));
    await taper(tester, find.text('Identité vérifiée'));

    final valeur = await rechercher(tester);
    expect(valeur!.minRating, isNull);
    expect(valeur.weekendOnly, isTrue);
    expect(valeur.kycVerifiedOnly, isTrue);
  });

  testWidgets(
      'section trajets : type de contenu par suggestion puis désélection',
      (tester) async {
    // Les onze pastilles dépliées sont remplacées par l'autocomplétion : on
    // tape pour faire apparaître la suggestion, au lieu de scanner la liste.
    vueHaute(tester);
    await ouvrir(tester, mode: SearchMode.trips);

    final champ = find.byKey(const Key('filter-content-field'));
    await tester.ensureVisible(champ);
    await tester.tap(champ);
    await tester.pumpAndSettle();
    await tester.enterText(champ, 'Chauss');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter-content-item-Chaussures')));
    await tester.pumpAndSettle();
    // La liste déroulante reste ouverte et recouvre la barre d'action : on la
    // referme avant de valider, comme le ferait l'utilisateur.
    primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    var valeur = await rechercher(tester);
    expect(valeur!.contentType, 'Chaussures');

    // Retaper la même entrée la désélectionne.
    await ouvrir(
      tester,
      mode: SearchMode.trips,
      initial: const HomeSearchFilters(contentType: 'Chaussures'),
    );
    final champ2 = find.byKey(const Key('filter-content-field'));
    await tester.ensureVisible(champ2);
    await tester.tap(champ2);
    await tester.pumpAndSettle();
    await tester.enterText(champ2, 'Chauss');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter-content-item-Chaussures')));
    await tester.pumpAndSettle();
    primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    valeur = await rechercher(tester);
    expect(valeur!.contentType, isNull);
  });

  testWidgets('section trajets : saisie libre de type de contenu',
      (tester) async {
    vueHaute(tester);
    await ouvrir(tester, mode: SearchMode.trips);

    // Un type absent du catalogue s'ajoute par la même frappe, sans bouton
    // « + » séparé.
    final champ = find.byKey(const Key('filter-content-field'));
    await tester.ensureVisible(champ);
    await tester.tap(champ);
    await tester.pumpAndSettle();

    await tester.enterText(champ, 'Poissons');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter-content-item-add')));
    await tester.pumpAndSettle();

    // Le filtre ne retient qu'un type : le second remplace le premier.
    await tester.enterText(champ, 'Épices');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter-content-item-add')));
    await tester.pumpAndSettle();
    primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final valeur = await rechercher(tester);
    expect(valeur!.contentType, 'Épices');
  });

  testWidgets('section trajets : urgence du départ', (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);

    await taper(tester, find.text('3–7j'));
    var valeur = await rechercher(tester);
    expect(valeur!.urgencyFilter, UrgencyFilter.urgent);

    await ouvrir(
      tester,
      mode: SearchMode.trips,
      initial: const HomeSearchFilters(urgencyFilter: UrgencyFilter.urgent),
    );
    await taper(tester, find.text('3–7j'));
    valeur = await rechercher(tester);
    expect(valeur!.urgencyFilter, isNull);
  });

  // ── Sélecteurs partagés ────────────────────────────────────────────────────

  testWidgets(
      'sélecteur de poids : confirmer une valeur précise pose le filtre exact',
      (tester) async {
    // État initial (20 kg) volontairement différent de la valeur attendue
    // après interaction (15 kg) : l'assertion ne peut être satisfaite sans
    // que le `Slider` ait réellement été bougé puis confirmé.
    await ouvrir(
      tester,
      mode: SearchMode.trips,
      initial: const HomeSearchFilters(weightMin: 20),
    );

    await taper(tester, find.text('POIDS MIN'));
    expect(find.text('Poids minimum du trajet'), findsOneWidget);

    await ajusterPoids(tester, diminuer: true, pas: 5); // 20 kg → 15 kg
    await tester.tap(find.widgetWithText(DonyButton, 'Confirmer'));
    await tester.pumpAndSettle();

    final valeur = await rechercher(tester);
    expect(valeur!.weightMin, 15.0);
  });

  testWidgets('sélecteur de poids : atteindre 6 kg vaut « pas de filtre »',
      (tester) async {
    // État initial (12 kg) différent de null : si le bouton « Confirmer »
    // ne propageait plus la valeur du slider, le filtre resterait à 12 kg
    // au lieu de disparaître.
    await ouvrir(
      tester,
      mode: SearchMode.trips,
      initial: const HomeSearchFilters(weightMin: 12),
    );

    await taper(tester, find.text('POIDS MIN'));
    await ajusterPoids(tester, diminuer: true, pas: 6); // 12 kg → 6 kg
    await tester.tap(find.widgetWithText(DonyButton, 'Confirmer'));
    await tester.pumpAndSettle();

    final valeur = await rechercher(tester);
    expect(valeur!.weightMin, isNull);
  });

  testWidgets('sélecteur de prix : appliquer un prix puis le relâcher',
      (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);

    await taper(tester, find.text('PRIX MAX'));
    expect(find.text('Tous les prix'), findsOneWidget);
    await tester.drag(dansPicker(find.byType(Slider)), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(dansPicker(find.widgetWithText(DonyButton, 'Appliquer')));
    await tester.pumpAndSettle();

    var valeur = await rechercher(tester);
    expect(valeur!.maxPricePerKg, isNotNull);

    // Curseur au maximum = « tous les prix » = filtre retiré.
    await ouvrir(
      tester,
      mode: SearchMode.trips,
      initial: const HomeSearchFilters(maxPricePerKg: 10),
    );
    await taper(tester, find.text('PRIX MAX'));
    await tester.drag(dansPicker(find.byType(Slider)), const Offset(400, 0));
    await tester.pumpAndSettle();
    await tester.tap(dansPicker(find.widgetWithText(DonyButton, 'Appliquer')));
    await tester.pumpAndSettle();

    valeur = await rechercher(tester);
    expect(valeur!.maxPricePerKg, isNull);
  });

  testWidgets('sélecteur de transport : choisir puis désélectionner',
      (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);

    await taper(tester, find.text('TRANSPORT'));
    expect(find.text('Mode de transport'), findsOneWidget);
    await tester.tap(dansPicker(find.text('Avion')));
    await tester.pumpAndSettle();
    await tester.tap(dansPicker(find.widgetWithText(DonyButton, 'Appliquer')));
    await tester.pumpAndSettle();

    var valeur = await rechercher(tester);
    expect(valeur!.transportMode, TransportMode.plane);

    await ouvrir(
      tester,
      mode: SearchMode.trips,
      initial: const HomeSearchFilters(transportMode: TransportMode.plane),
    );
    await taper(tester, find.text('TRANSPORT'));
    await tester.tap(dansPicker(find.text('Avion')));
    await tester.pumpAndSettle();
    await tester.tap(dansPicker(find.widgetWithText(DonyButton, 'Appliquer')));
    await tester.pumpAndSettle();

    valeur = await rechercher(tester);
    expect(valeur!.transportMode, isNull);
  });
}
