# Spec — Refonte des formulaires « Mes adresses » (remise + livraison)

**Date :** 2026-06-01
**Statut :** ✅ Approuvé
**Portée :** Full-stack (Flutter `dony_app` + Spring Boot `dony-back`)

**Fichiers cibles principaux :**
- `dony_app/lib/features/pickup_addresses/presentation/screens/pickup_address_edit_screen.dart`
- `dony_app/lib/features/delivery_addresses/presentation/screens/delivery_address_edit_screen.dart`
- `dony_app/lib/features/matching/presentation/widgets/address_suggest_field.dart`
- `dony_app/lib/features/matching/data/models/address_data.dart`
- `dony_app/lib/core/services/address_autocomplete_service.dart`
- `dony-back/.../address/GoogleAddressService.java` + `dto/PlaceDetailsResponse.java` + `AddressController.java`

---

## 1. Contexte & problème

Les deux écrans d'édition d'adresse (remise = retrait en France, livraison = destination en Afrique) souffrent de quatre défauts :

1. **Saisie trop longue** — tout est manuel (rue, code postal, ville, étage). L'autocomplete existant ne remplit que le champ rue + des coordonnées, jamais ville/code postal.
2. **Incohérence remise ≠ livraison** — ordre des sections, champs et vocabulaire diffèrent sans raison.
3. **Vocabulaire peu clair** — labels/hints pas assez parlants pour la diaspora.
4. **Design plat, peu guidé** — pas de hiérarchie, pas de point d'entrée évident.

**Objectif** : une expérience **« Cherche, confirme, affine »** homogène, à faible friction, qui s'appuie sur l'autocomplete pour pré-remplir les champs, tout en restant robuste là où Google couvre mal (villes et communes africaines parfois sans adresse).

---

## 2. Direction validée (Approche 1)

Squelette **identique** des deux côtés, piloté par une config par type. Le champ de recherche est l'entrée principale ; les champs détaillés restent toujours visibles et éditables (correction Google ou saisie 100 % manuelle).

### Ordre vertical (commun)

```
ÉTIQUETTE        → champ nom + chips rapides (tap = remplit)
ADRESSE          → champ recherche HERO (autocomplete)
                   ↳ indicateur de statut léger (✓ localisée / saisie manuelle)
                   ↳ champs détaillés pré-remplis + éditables
INSTRUCTIONS     → multiline optionnel
ADRESSE PAR DÉFAUT → toggle
[ Enregistrer l'adresse ]  → stickyBottom
```

### Ce qui diffère (config par type)

| Aspect | **Remise** (FR) | **Livraison** (Afrique) |
|--------|-----------------|--------------------------|
| Pays | `FR` fixe, **caché** dans l'UI | Sélecteur 8 pays, **section dédiée mise en avant** (avant Adresse) |
| Code postal | champ optionnel (row CP + Ville) | **absent** |
| Étage / appartement | champ optionnel | **absent** |
| Couleur d'accent | `colorScheme.primary` (bleu) | `colorScheme.secondary` (orange) |
| Chips étiquette | Maison · Bureau · Atelier | Famille · Maison · Boutique |
| Variant du CTA | `DonyButtonVariant` par défaut | `DonyButtonVariant.secondary` |
| Sous-titre toggle | « …prochaines **demandes** » | « …prochaines **annonces** » |

---

## 3. Règles de validation (décision : identique partout)

- **Obligatoire (les deux formulaires)** : `étiquette` (label) + `ville` (city). Côté livraison, `pays` est aussi requis mais possède toujours une valeur par défaut (`SN`), donc jamais bloquant.
- **Optionnels partout** : `rue`/`numéro` (street) **et** `code postal` (postalCode), y compris pour la remise en France — justification : certaines villes/communes africaines n'ont pas d'adresse précise, et on garde la cohérence des deux côtés.
- CTA `Enregistrer` désactivé (`onPressed: null`) tant que `étiquette` ou `ville` est vide, et pendant le loading.

Changement concret de `_isValid` :
- **Remise** : `label.isNotEmpty && city.isNotEmpty` (avant : exigeait aussi street + postalCode).
- **Livraison** : inchangé (`label.isNotEmpty && city.isNotEmpty`).

---

## 4. Contrat backend (enrichissement `/addresses/details`)

### 4.1 DTO `PlaceDetailsResponse`
`dony-back/.../address/dto/PlaceDetailsResponse.java`

Avant :
```java
public record PlaceDetailsResponse(String label, Double lat, Double lng) {}
```
Après (champs ajoutés **nullable**, rétrocompatible) :
```java
public record PlaceDetailsResponse(
    String label, Double lat, Double lng,
    String street, String city, String postalCode, String country) {}
```

### 4.2 `GoogleAddressService`
- **Field mask** (constante `DETAILS_FIELD_MASK`) :
  `"id,formattedAddress,location"` → `"id,formattedAddress,location,addressComponents"`.
- **`parsePlaceDetailsNew(...)`** : extraire `addressComponents` (format API Places New : chaque composant a `longText`, `shortText`, `types[]`) et mapper :
  - `street` = `streetNumber.longText` + " " + `route.longText` (trim ; si l'un manque, garder l'autre ; sinon `null`).
  - `city` = `locality.longText`, fallback `postalTown.longText`, fallback `administrative_area_level_2.longText`, sinon `null`.
  - `postalCode` = `postalCode.longText`, sinon `null`.
  - `country` = `country.shortText` (code ISO, ex. `FR`, `SN`), sinon `null`.
- `reverse(...)` (geocode) : peut rester sur label/lat/lng (les nouveaux champs restent `null`) — hors périmètre, pas de régression.

### 4.3 Datasource Google
Le format des `address_components` de l'API Places New utilise `types` (array), `longText`, `shortText`. Helper interne `findComponent(List components, String type)` qui retourne le premier composant dont `types` contient `type`.

---

## 5. Contrat front

### 5.1 Modèle `AddressData`
`dony_app/lib/features/matching/data/models/address_data.dart`

Ajouter quatre champs **nullable** (`street`, `city`, `postalCode`, `country`) + les parser dans `fromJson` (clés `street`, `city`, `postalCode`, `country`). Les usages existants (pickers de matching) ne lisent que `label`/`lat`/`lng` → ajout purement additif, aucune régression.

### 5.2 `AddressAutocompleteService.resolvePlace`
`dony_app/lib/core/services/address_autocomplete_service.dart`

Propager les nouveaux champs depuis la réponse `/addresses/details` vers `AddressData` :
```dart
return AddressData(
  label: raw['label'] as String,
  lat: (raw['lat'] as num).toDouble(),
  lng: (raw['lng'] as num).toDouble(),
  street: raw['street'] as String?,
  city: raw['city'] as String?,
  postalCode: raw['postalCode'] as String?,
  country: raw['country'] as String?,
);
```

### 5.3 `AddressSuggestField`
`dony_app/lib/features/matching/presentation/widgets/address_suggest_field.dart`

`_selectSuggestion` construit aujourd'hui un `AddressData` minimal (label + coords) pour `onResolved`. Le modifier pour **transmettre l'objet enrichi complet** retourné par `resolvePlace` (au lieu de reconstruire avec le seul `mainText`), afin que les écrans reçoivent ville/CP/pays. Conserver `s.mainText` comme texte affiché dans le champ.

---

## 6. Comportement de pré-remplissage (écrans)

À la sélection d'une suggestion (`onResolved(AddressData addr)`), chaque écran remplit ses contrôleurs **uniquement si la donnée existe**, sans écraser une saisie utilisateur par du `null` :

- **Remise** : `street` (texte du champ recherche déjà posé via `mainText`), `_cityCtrl ← addr.city`, `_postalCtrl ← addr.postalCode`, `_lat/_lng`. Le pays reste `FR`.
- **Livraison** : `_cityCtrl ← addr.city`, `_lat/_lng`. Le champ rue garde `mainText`. `addr.country` **n'écrase pas** le pays choisi par l'utilisateur (le sélecteur reste maître ; on ne mappe pas automatiquement le pays car les 8 pays sont une liste fermée orientée diaspora).

Règle : `if (addr.city != null && addr.city!.isNotEmpty) _cityCtrl.text = addr.city!;` — idem CP. Toujours appeler `setState(() {})` pour rafraîchir validité + UI.

**Indicateur de statut** sous le champ recherche :
- coords résolues (`_lat != null`) → `✓ Adresse localisée` (couleur `success`).
- texte non vide mais pas de coords → `Adresse non localisée — tu peux la saisir à la main` (couleur `hint`/`onSurfaceVariant`, **pas** une erreur).
- champ vide → rien.

---

## 7. Wording (source de vérité)

| Emplacement | Remise | Livraison |
|-------------|--------|-----------|
| Titre (création) | `Nouvelle adresse de remise` | `Nouvelle adresse de livraison` |
| Titre (édition) | `Modifier l'adresse` | `Modifier l'adresse` |
| Section 1 | `ÉTIQUETTE` | `ÉTIQUETTE` |
| Label champ nom | `Nom de l'adresse` | `Nom de l'adresse` |
| Hint nom | `Ex : Maison, Bureau…` | `Ex : Famille Dakar, Dépôt…` |
| Chips | Maison · Bureau · Atelier | Famille · Maison · Boutique |
| Section pays | — | `PAYS` |
| Section adresse | `ADRESSE` | `ADRESSE` |
| Hint recherche | `Rechercher une rue, un quartier, une ville…` | `Rechercher une rue, un quartier…` |
| Statut localisé | `✓ Adresse localisée` | `✓ Adresse localisée` |
| Statut manuel | `Adresse non localisée — tu peux la saisir à la main` | idem |
| Champ ville | `Ville` · hint `Paris` | `Ville` · hint `Ex : Dakar, Abidjan, Bamako…` |
| Champ CP | `Code postal` · hint `75001` | — |
| Champ rue détaillé | (le champ recherche fait office de rue) | `Rue, quartier` · hint `Optionnel — Ex : Rue 10, Almadies` |
| Champ étage | `Étage / Appartement` · hint `Optionnel — Ex : Bât. B, 3ème étage` | — |
| Section instructions | `INSTRUCTIONS` | `INSTRUCTIONS` |
| Hint instructions | `Optionnel — digicode, horaires…` | `Optionnel — appeler à l'arrivée, portail rouge…` |
| Toggle titre | `Adresse par défaut` | `Adresse par défaut` |
| Toggle sous-titre | `Pré-remplie lors de tes prochaines demandes` | `Pré-remplie lors de tes prochaines annonces` |
| CTA | `Enregistrer l'adresse` | `Enregistrer l'adresse` |

---

## 8. Structure de code (widgets partagés)

Les écrans **restent dans leurs features respectives** (deux BLoCs distincts, archi feature-first respectée). On extrait les briques aujourd'hui dupliquées et on ajoute deux nouveaux widgets partagés.

Emplacement proposé : `dony_app/lib/core/widgets/address/` (UI générique, sans dépendance feature).

| Widget | Rôle | Origine |
|--------|------|---------|
| `AddressSectionLabel` | label de section majuscule (ex-`_SectionLabel`, dupliqué × 2) | extraction |
| `AddressDefaultToggle` | toggle « adresse par défaut » avec param `activeColor` | extraction (fusion des deux variantes) |
| `AddressLabelChips` | rangée de chips qui remplit le champ étiquette ; param `chips` + `controller` + `accentColor` | **nouveau** |
| `AddressLocationStatus` | indicateur léger localisée / manuelle ; param `state` + `accentColor` | **nouveau** |

Chaque écran réécrit son `body` avec le même ordre de sections en consommant ces widgets — corps mince et lisible des deux côtés. Le `_DefaultToggle`/`_SectionLabel` locaux sont supprimés.

> Note : on ne crée **pas** un `AddressFormBody` paramétrique unique. Les deux écrans ont des BLoCs, des contrôleurs et une logique de submit différents ; un widget unique paramétrique ajouterait plus de complexité qu'il n'en retire. Le partage se fait au niveau des briques, pas du formulaire entier.

---

## 9. États & navigation (inchangés)

- `BlocConsumer` : `listener` gère prefill (édition), succès (snackbar + `context.pop(true)`), erreur (snackbar). `builder` rend l'UI selon `status`.
- `loading` → `DonyButton(isLoading: true)`.
- Le contrat de retour `context.pop(true)` après save est conservé (l'écran liste recharge sur résultat `true`).
- Animations d'entrée existantes (`fadeIn`/`slideY` staggered 40 ms) conservées et étendues aux nouvelles sections.

---

## 10. Tests (≥ 90 %)

### Backend (`dony-back`)
- `GoogleAddressServiceTest` :
  - parsing `addressComponents` complet (FR : streetNumber + route + locality + postalCode + country).
  - cas sans `postalCode` / sans `locality` → champs `null`, pas d'exception.
  - cas `addressComponents` absent → `street/city/postalCode/country = null` (rétrocompat).
- `AddressControllerTest` (MockMvc) : `/addresses/details` renvoie les nouveaux champs sérialisés.

### Front (`dony_app`)
- `AddressData.fromJson` : parse les 4 nouveaux champs (présents / absents → `null`).
- `AddressAutocompleteService.resolvePlace` : propage les champs enrichis (mock Dio).
- `AddressSuggestField` : `onResolved` reçoit l'`AddressData` enrichi (test du nouveau chemin de `_selectSuggestion`).
- Widget tests `PickupAddressEditScreen` :
  - validité = ville seule (sans CP ni rue) → CTA actif.
  - tap chip « Maison » → champ étiquette rempli.
  - `onResolved` simulé → ville + CP remplis + statut « localisée ».
- Widget tests `DeliveryAddressEditScreen` :
  - validité = étiquette + ville → CTA actif.
  - sélecteur de pays met à jour le drapeau/nom.
  - `onResolved` ne change pas le pays sélectionné.
- Widgets partagés (`AddressLabelChips`, `AddressLocationStatus`, `AddressDefaultToggle`) : tests unitaires de rendu + callback.
- `flutter analyze` propre, `flutter test --coverage` ≥ 90 %.

---

## 11. Hors périmètre

- Pas de carte interactive (écartée).
- Pas de refonte des `*AddressPickerSheet` du matching (ils continuent de consommer `AddressData` ; les nouveaux champs sont simplement ignorés).
- Pas de modification des BLoCs/repositories/datasources adresses (events/states inchangés — la structure des données persistées ne change pas).
- `/addresses/reverse` non enrichi (pas de régression).

---

## 12. Risques & points d'attention

- **Quota Google Places** : ajouter `addressComponents` au field mask peut changer la facturation du Place Details (champs « Basic » vs « Contact/Atmosphere »). `addressComponents` est dans le tier *Basic* de l'API New → pas de surcoût attendu, mais à vérifier.
- **Ne jamais écraser une saisie manuelle** par un `null` venu de l'autocomplete (cf. §6).
- **Couverture Afrique faible** : `city` peut revenir `null` même après résolution → l'utilisateur complète à la main, le statut affiche « non localisée » uniquement si pas de coords (coords présentes mais city null = on reste « localisée », ville à compléter).
- `setState` est utilisé dans ces écrans pour la validité locale (pattern déjà en place dans le repo pour ces formulaires) — conservé, conforme à l'usage existant ; aucun nouvel état métier hors BLoC.
