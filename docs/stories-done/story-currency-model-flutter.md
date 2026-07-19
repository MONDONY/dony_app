# Story — Affichage devise dual (EUR/F CFA) + synchro registre au démarrage (Flutter)

**Date :** 2026-07-19 | **Status :** ✅ Complète (PR #161)

## Résumé

Volet Flutter du modèle multi-devise dony (backend : PR dony-back#116). Un nouveau package `core/money/` synchronise un référentiel de devises depuis le backend au démarrage (avec repli hors-ligne) et affiche, sur l'écran de confirmation de paiement, l'équivalent en franc CFA à côté du montant EUR — **affichage indicatif uniquement, jamais un montant calculé côté client pour un débit réel** (règle R1 de la spec).

**Spec :** `docs-claude/docs/specs/2026-07-18-modele-devise-design.md` (v3), section 6 (Composants Flutter)
**Plan :** `docs-claude/docs/superpowers/plans/2026-07-18-modele-devise-plan.md` (tasks 14-15 ; tasks 1-13 = backend, dony-back#116)

## Règle produit non négociable (R1)

Le client **n'invente et ne calcule jamais** un montant destiné à être débité. Tout montant transactionnel (ce qui sera réellement chargé) vient du serveur, tel quel. Le package `core/money/` ne sert qu'à l'**affichage** — la conversion locale et le repli hors-ligne ne pilotent jamais un paiement.

## Fichiers créés

- `core/money/currency_info.dart` — `CurrencyInfo(code, minorUnit, symbol, pegRateToEur, roundingIncrement)`, parsing JSON aligné sur le contrat backend `CurrencyResponse`
- `core/money/currency_fallback.dart` — repli hors-ligne EUR/XOF/XAF (parité 655,957) codé en dur, **indicatif uniquement** — jamais utilisé pour un montant transactionnel
- `core/money/currency_registry.dart` — singleton synchronisé au démarrage via `GET /config/currencies` (même pattern que `core/pricing/dony_pricing.dart` pour le taux de commission) ; en cas d'échec réseau, conserve le repli sans jamais planter
- `core/money/money_formatter.dart` — `formatEur`, `formatDual` (`"12 € (7 871 F CFA)"`, retombe sur EUR seul si la devise est inconnue ou non arrimée — jamais d'estimation inventée), `formatLocalTransactional` (affiche un montant **serveur** en unités mineures, avec le code ISO pour lever l'ambiguïté F CFA XOF/XAF, ne calcule jamais rien)
- `test/core/money/money_formatter_test.dart`, `test/core/money/currency_registry_test.dart` — couvrent le format dual, le repli, et les 3 chemins réels de la synchro (succès, `DioException`, réponse vide)

## Fichiers modifiés

- `lib/main.dart` — `CurrencyRegistry.sync(dio)` ajouté au démarrage, `unawaited()`, même emplacement et même style fire-and-forget que la synchro existante du taux de commission
- `lib/features/payments/presentation/screens/payment_screen.dart` — l'écran de confirmation escrow (`_EscrowConfirmedView`) affiche désormais `formatDual(amount, localeCurrency: userCurrencyCode)` au lieu de `${amount.toStringAsFixed(2)} €` ; `userCurrencyCode` lu depuis la clé Hive existante `kCurrencyCode`
- `lib/features/payments/data/payment_gateway.dart` — commentaire de garde ajouté au-dessus des deux `currencyCode: 'EUR'` (Apple Pay / Google Pay) : **aucun changement fonctionnel**, la PaymentSheet dérive déjà la devise du PaymentIntent correctement

## Comment ça fonctionne

### Flux utilisateur

1. Au démarrage, l'app tire `GET /config/currencies` en tâche de fond ; en cas de succès le registre en mémoire remplace le repli, sinon il le garde
2. Sur l'écran de confirmation de paiement, si la devise locale de l'utilisateur (`kCurrencyCode`) a une parité connue, le montant EUR est affiché avec son équivalent local entre parenthèses ; sinon, EUR seul

### Contrat backend ↔ Flutter

`CurrencyResponse(code, minorUnit, symbol, pegRateToEur, roundingIncrement)` (backend, `GET /config/currencies`) ↔ `CurrencyInfo.fromJson` lit exactement ces 5 clés, avec coercion nullable correcte pour `pegRateToEur` (absent = devise flottante, aucune estimation affichée).

### Pièges et points d'attention

- **Un seul des trois montants affichés sur l'écran de paiement est en dual format.** L'écran de confirmation (`_EscrowConfirmedView`) affiche le dual ; le bouton de paiement et le total du récapitulatif (`_PaymentSummaryView`, écran distinct, jamais visible en même temps) restent en EUR seul — migrer ces deux-là aurait exigé de modifier 7 assertions de test existantes en dot-decimal, hors périmètre de cette task. **Décision produit ouverte, non tranchée dans cette story** : un utilisateur en zone CFA ne voit son équivalent local qu'*après* avoir payé (écran de confirmation), jamais au point de décision (bouton payer). Ajouter l'équivalent au point de décision nécessiterait un montant **figé côté serveur** affiché via `formatLocalTransactional` — jamais `formatDual`, qui reste indicatif — pour ne pas violer R1.
- **`formatLocalTransactional` n'est câblé sur aucun écran aujourd'hui** — le flux de paiement actuel est entièrement EUR/Stripe. Cette fonction est prête pour le jour où un débit en devise locale (mobile money réel) sera branché côté UI ; ce n'est pas un oubli.
- **Piège Hive connu du repo** : écrire dans Hive depuis `testWidgets` bloque sous fake-async — tout test touchant `kCurrencyCode` via une vraie écriture Hive doit passer par `tester.runAsync(...)`. Ne s'applique pas aux tests de cette story (le mock Hive utilisé est un `MockBox` mocktail, pas un vrai `Hive.openBox`).
- **Style de séparateur de milliers** : le formateur utilise l'espace insécable classique (U+00A0), alors que les formatages `intl` `fr_FR` déjà présents ailleurs dans l'app utilisent l'espace fine insécable (U+202F). Incohérence mineure entre les deux styles de formatage monétaire de l'app, à réconcilier dans une passe de polish ultérieure — pas un bug.
- **`roundingIncrement` sur `CurrencyInfo`** est parsé et stocké mais non consommé par `formatDual` (qui arrondit à l'unité la plus proche, incrément 1 — le comportement indicatif attendu). C'est prévu (l'incrément transactionnel, ex. multiple de 5 F CFA, ne s'applique qu'au débit réel côté serveur), gardé pour la symétrie de contrat avec le backend.

## Critères d'acceptation couverts

- [x] Registre de devises synchronisé au démarrage, repli hors-ligne fonctionnel, jamais de plantage si le backend est injoignable
- [x] Affichage dual EUR + F CFA sur l'écran de confirmation de paiement
- [x] Devise inconnue ou non arrimée → EUR seul, jamais d'estimation inventée (R1)
- [x] Zéro décimale pour XOF/XAF, virgule française pour EUR
- [x] Chemin Apple Pay / Google Pay non modifié fonctionnellement
- [x] Aucun test existant modifié — uniquement des ajouts

## Tests

- `flutter test test/core/money/` — 11/11 verts (7 formatter + 4 registry)
- `flutter test test/features/payments/presentation/screens/payment_screen_test.dart` — 10/10 verts (8 préexistants inchangés + 2 nouveaux : affichage XOF, absence d'overflow avec un montant multi-chiffres)
- `flutter analyze` — 0 issue sur les fichiers touchés
- Revue finale whole-branch (opus) : règle R1 tracée end-to-end (aucun chemin où le repli client pourrait influencer un montant réellement chargé), contrat backend/Flutter confirmé cohérent, chemin d'erreur de synchro réellement testé (`DioException`, pas seulement le cas heureux)

## Décisions techniques

| Décision | Choix | Alternatives écartées | Raison |
|---|---|---|---|
| Architecture `core/money/` | Calquée sur `core/pricing/dony_pricing.dart` (sync + repli, singleton, pas de BLoC) | BLoC dédié, service GetIt avec état | Donnée de référence en lecture seule, pas de l'état applicatif — précédent déjà établi et validé dans ce repo |
| `sync(Dio)` fait l'appel HTTP directement dans `core/money/` | Pas de split datasource/repository comme `dony_pricing.dart` | Suivre le split exact (datasource séparée) | Hors périmètre de cette task (le câblage réel est une task distincte) ; `sync()` n'expose jamais d'exception, donc le câblage reste aussi simple qu'avec un split |
| Périmètre d'affichage dual | Un seul écran (confirmation), pas les 3 sites de montant | Migrer les 3 sites du même écran | Les 2 autres sites sont sur un écran distinct (jamais visible simultanément) et leur migration aurait cassé 7 assertions de test existantes, hors règle "ne jamais modifier les tests existants" de ce plan |
| Outil de mock HTTP | `mocktail` (confirmé via `pubspec.yaml` et les tests existants du repo) | `http_mock_adapter` (assumé par le plan initial, n'existe pas dans ce repo) | Le plan avait deviné le mauvais outil ; corrigé en suivant la convention réellement établie |
