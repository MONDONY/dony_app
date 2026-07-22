# Recherche par mode : trajets ou colis (Flutter)

**Date :** 2026-07-22
**Status :** ✅ Complète
**Branche :** `feature/recherche-modes-colis-trajets`
**Backend associé :** `dony-back` branche `feature/matching-my-trips-filter`
**Spec :** `docs/superpowers/specs/2026-07-22-recherche-modes-colis-trajets-design.md`
**Plan :** `docs/superpowers/plans/2026-07-22-recherche-modes-colis-trajets.md`

## Résumé

L'écran Rechercher passe de trois modes (trajets, colis, les deux) à deux modes exclusifs dont un est toujours actif. Le corridor et la date deviennent des filtres communs qui survivent au changement de mode, les deux feuilles de filtres asymétriques fusionnent en une seule qui s'adapte, et « Pour mes trajets » cesse d'être un raccourci vers un écran séparé pour devenir un filtre serveur.

## Fichiers créés

- `lib/features/home/domain/search_mode.dart` — l'énumération à deux valeurs, avec `isTrips`, `isParcels` et `other`
- `lib/features/home/domain/home_search_filters.dart` — l'état de recherche immuable, sans dépendance Flutter, avec ses trois méthodes de sortie
- `lib/features/home/presentation/widgets/search_mode_selector.dart` — le contrôle segmenté à deux états
- `lib/features/home/presentation/widgets/home_filter_chips_row.dart` — la rangée de chips, fusion des deux rangées privées d'origine
- `lib/features/home/presentation/widgets/search_filter_sheet.dart` — la feuille de filtres unique
- `lib/features/home/presentation/widgets/search_filter_fields.dart` — les champs partagés, extraits de l'ancienne feuille trajets

## Fichiers supprimés

- `lib/features/home/presentation/home_map_focus.dart` — l'énumération à trois modes et sa fonction de visibilité
- `lib/features/home/presentation/widgets/home_focus_filter.dart` — le sélecteur à trois segments
- `lib/features/package_request/presentation/screens/traveler/colis_match_screen.dart` — l'écran dédié, remplacé par le filtre
- `lib/features/package_request/bloc/trip_matching_bloc.dart` — son bloc

Plus la route `/package-requests/match`, son enregistrement d'injection, et les quatre fichiers de test correspondants.

## Fichiers modifiés notables

- `lib/features/home/presentation/home_screen.dart` — de 3456 à environ 2520 lignes ; dix-huit champs de filtre remplacés par `_mode` et `_filters`
- `lib/features/matching/presentation/widgets/search_form_bottom_sheet.dart` — de 1083 à 611 lignes, consomme désormais les champs partagés
- `lib/features/package_request/data/models/package_request_search_item.dart` — trois champs de match nullables
- `lib/features/package_request/data/package_request_repository.dart` — paramètre `matchingMyTrips`
- `lib/features/package_request/bloc/package_request_search_bloc.dart` — le champ traverse l'événement, l'état et les trois gestionnaires
- `lib/features/settings/presentation/screens/notification_settings_screen.dart` — accueille la cloche des colis compatibles
- `lib/features/city/presentation/widgets/city_autocomplete_field.dart` — callback `onCleared` optionnel

## Comment ça fonctionne

### Flux utilisateur

1. L'écran s'ouvre en mode Trajets, quel que soit le profil. Le rôle voyageur est universel côté serveur depuis le backfill V176, il n'y a donc plus de déduction à faire.
2. La rangée de chips défile horizontalement. Le sélecteur de mode en est le premier élément, suivi d'un séparateur, des filtres communs, puis de ceux du mode courant.
3. Le tap sur la barre corridor ouvre la feuille de filtres du mode courant. Son bloc haut, ville de départ, ville d'arrivée et date, est le même widget dans les deux modes.
4. Valider relance la recherche du mode courant. Basculer de mode relance celle de l'autre, en conservant les filtres communs.
5. Zéro résultat affiche une tuile proposant l'autre mode, si celui-ci en a. Le tap bascule en gardant corridor et date.

### État

`HomeSearchFilters` porte trois familles de champs et produit trois sorties distinctes, à ne pas confondre :

| Méthode | Destination |
|---|---|
| `toAnnouncementQuery()` | l'événement `AnnouncementSearchRequested`, la vraie recherche de trajets |
| `toPackageRequestQuery()` | l'événement `SearchFiltersChanged`, la recherche de demandes |
| `toSearchParams()` | le pré-remplissage de la feuille de filtres, **jamais** une recherche |

`activeCountFor(mode)` alimente le badge de la barre corridor. `otherModeCountIsMeaningful` dit si le compteur du segment inactif porte une information : vrai avec un corridor, une date ou « près de moi », faux avec le seul filtre urgent, qui donnerait un total plateforme.

### Appels API

- `GET /announcements` — recherche de trajets, inchangée
- `GET /package-requests` — recherche de demandes, avec le nouveau `matchingMyTrips=true` quand le filtre est actif
- `GET /announcements?size=1` via `countAnnouncements` — le compteur du segment inactif, qui ne lit que le total
- `GET` et `PUT /notifications/package-match-alert` — la cloche, désormais depuis les réglages

## Pièges

1. **`weightMin` et `maxWeight` ont des sémantiques opposées** malgré le mot « poids » commun. Le premier est la capacité minimale attendue d'un voyageur, filtre trajets. Le second le poids maximal des demandes recherchées, filtre colis. Ils ne se propagent jamais l'un vers l'autre.

2. **`toSearchParams()` ne sert pas à chercher.** Confondre les trois méthodes de sortie produit des filtres affichés actifs mais sans effet, défaut effectivement rencontré et corrigé pendant l'implémentation. `SearchParams` n'a ni `urgent` ni fourchette de capacité.

3. **Tout filtre compté par `activeCountFor` doit être transmis.** Un test énumère les filtres du mode trajets et vérifie que chacun figure dans le payload, précisément pour empêcher le retour des filtres fantômes.

4. **Le corridor ne peut pas être vidé par la saisie seule.** `CityAutocompleteField` ne notifiait que sur choix d'une suggestion ; effacer le champ laissait le filtre actif, avec un champ affiché vide. Le callback `onCleared` corrige cela. Il est optionnel et nul par défaut, les treize autres sites d'appel du widget sont inchangés.

5. **La clé du sélecteur de mode doit rester constante.** Une clé qui varierait selon la présence du compteur démonterait le sous-arbre à chaque bascule et ferait perdre son animation au segment actif. Un test compare l'identité de l'élément avant et après l'arrivée du compteur.

6. **Le nombre de trajets actifs peut être inconnu.** `TripsSummaryCubit` masque son état sur toute erreur réseau et ne réessaie pas. Confondre inconnu et zéro ferait affirmer « Aucun trajet actif » à un voyageur qui en a. `knownActiveTrips` distingue les trois cas, et l'inconnu laisse la pastille active pour que le serveur tranche.

7. **Le bandeau « Tirer pour voir N résultats » doit suivre le mode.** Il lisait le nombre de trajets même en mode Colis. `_pullHintForMode` branche le compteur sur le bloc de recherche des demandes quand le mode l'exige.

## Critères d'acceptation couverts

- [x] Deux modes exclusifs, un toujours actif, Trajets par défaut pour tous
- [x] Corridor et date partagés, vérifiés sur les requêtes réelles reçues par le serveur
- [x] Feuille de filtres unique, bloc commun partagé, libellé de bouton unifié, « Tout effacer » conditionnel
- [x] Compteur sur le segment inactif, affiché seulement s'il porte une information
- [x] Tuile de bascule dans l'état vide, avec accords en nombre et gestion des corridors partiels
- [x] « Pour mes trajets » filtre côté serveur, avec score et trajet retenu sur les cartes
- [x] Garde-fou sans trajet actif, garde-fou rôle voyageur retiré
- [x] Écran dédié supprimé, cloche relogée dans les réglages
- [x] Trois événements analytiques ajoutés, deux déclencheurs corrigés, table du `CLAUDE.md` à jour

## Tests

- `flutter test` — suite complète verte
- `flutter analyze` — zéro erreur, zéro avertissement sur les fichiers touchés
- Validation sur appareil Android réel : bascule de mode, feuille adaptative, garde-fous, et surtout la persistance du corridor vérifiée sur les requêtes serveur

Non validé faute de données : le filtre « Pour mes trajets » en action et le badge de score, qui exigent un compte avec au moins un trajet publié.

## Décisions techniques

**Deux modes plutôt que trois.** Les filtres des deux domaines ne se recouvrent qu'en partie, les résultats n'ont pas d'unité de tri commune, et une carte à deux natures de marqueurs rend le tap ambigu. Le mode mixte ouvrait par ailleurs la feuille de filtres des trajets, laissant les colis jamais filtrés.

**Le bloc commun est un seul widget, instancié hors de la branche de mode.** Une duplication visuellement équivalente aurait vidé la tâche de son sens ; ici la divergence est structurellement impossible.

**Le plan ne migre pas les `setState` de l'écran vers un Cubit.** Dix-huit champs deviennent deux, manipulés par les `setState` déjà en place. La migration BLoC de cet écran reste un chantier séparé.

**« Pour mes trajets » passe par un paramètre serveur** plutôt qu'un filtrage local, pour rester combinable avec les autres filtres, paginé, et trié par score. Cela a demandé une évolution backend, livrée sur sa propre branche.
