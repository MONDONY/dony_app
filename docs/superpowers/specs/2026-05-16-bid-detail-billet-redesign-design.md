# Refonte — Détail du colis « Billet de colis »

**Date :** 2026-05-16
**Écran :** `lib/features/matching/presentation/screens/bid_detail_screen.dart` — « Mon colis #DON-… »
**Type :** Refonte visuelle **et** structurelle. Écran adaptatif (expéditeur / voyageur), piloté par les 7 états du colis.

---

## 1. Contexte & objectif

L'écran de détail du colis affiche le suivi d'une demande de transport (`bid`). Il est adaptatif (expéditeur vs voyageur) et piloté par 7 états. La version actuelle présente 6 problèmes de design :

1. **« Card soup »** — 5 à 9 cartes blanches quasi identiques empilées, sans hiérarchie ; tout pèse le même poids visuel.
2. **Casse des titres incohérente** — « VOYAGEUR », « NUMÉRO DE SUIVI » en majuscules ; « Détails du trajet », « Colis » en capitalisé.
3. **Carte itinéraire pauvre** — deux pills grises + ligne pointillée, ni belle ni informative.
4. **Pastille de statut isolée** — flotte en haut, déconnectée du reste.
5. **Action clé noyée** — le n° de suivi (à copier/partager) a le même traitement qu'une ligne d'info.
6. **Faible densité, scroll excessif** — l'information est diluée, l'écran paraît long et générique.

**Objectif :** une refonte visuelle et structurelle autour d'une métaphore forte — le **billet de colis** — qui donne une identité, impose une hiérarchie et rend l'action en cours évidente à chaque état.

---

## 2. Périmètre

**Inclus :**
- Refonte complète de `bid_detail_screen.dart` — vues expéditeur + voyageur, 7 états.
- Découpage du fichier (3000+ lignes, ~36 classes internes) en widgets dédiés.
- Intégration du **QR code** et du **code de retrait** dans le billet.
- Talon voyageur **actionnable** : scan de prise en charge + confirmation de livraison depuis cet écran.
- Suppression de la section « ÉTAPES » statique, remplacée par le bottom sheet de suivi existant.

**Hors périmètre :**
- Backend — aucun changement (tous les endpoints, blocs et repositories existent).
- L'écran de détail d'annonce (`announcement_detail_screen.dart`).
- Le scanner QR (`qr_scanner_screen.dart`, route `/tracking/scan`) — réutilisé tel quel.
- La logique métier des blocs (`BidBloc`, `TrackingBloc`, `BidAcceptanceBloc`, `CancellationBloc`, `RatingBloc`, `ConversationOpenBloc`) — inchangée.
- Le bottom sheet de timeline (`tracking_timeline_bottom_sheet.dart`) — réutilisé ; restyling mineur optionnel.

---

## 3. Direction retenue — « Le billet de colis »

Le colis voyage comme un passager. L'écran présente un **billet** : en-tête compagnie, corridor façon carte d'embarquement, ligne de perforation, et un **talon détachable** qui porte l'action du moment. Direction choisie parmi 6 explorées (A–F) après brainstorming visuel.

La métaphore règle directement les problèmes 1, 3, 4 et 5 : une pièce maîtresse unique remplace l'empilement de cartes, le statut s'intègre en tampon, le corridor devient lisible et valorisant, et le talon met en avant l'action clé.

**Maquettes de référence** — les 7 maquettes validées sont dans `docs/superpowers/specs/2026-05-16-bid-detail-billet-redesign-maquettes/`. Elles font foi pour le rendu visuel attendu.

| Vue expéditeur | Vue voyageur |
|----------------|--------------|
| `expediteur/1-confirme.png` — talon QR | `voyageur/1-en-attente.png` — barre Accepter / Refuser |
| `expediteur/2-en-route.png` — code de retrait + Régénérer | `voyageur/2-confirme.png` — talon « Scanner le colis » |
| `expediteur/3-livre.png` — talon terminé | `voyageur/3-en-route.png` — talon « Confirmer la livraison » |
| `expediteur/4-suivi-bottom-sheet.png` — bottom sheet de suivi | |

---

## 4. Anatomie du billet

Carte unique en tête d'écran, blanche, coins arrondis (`DonyRadius.card`), ombre douce.

| Zone | Contenu |
|------|---------|
| **En-tête** | Marque « DONY · TRANSPORT DE COLIS » à gauche ; **tampon de statut** à droite (légèrement incliné, contour coloré). Le tampon remplace la pastille flottante. |
| **Corridor** | Codes (CDG / ABJ) en gros, villes en dessous, icône de transport au centre sur une ligne pointillée. |
| **Dates** | Départ / Arrivée — date + heure. |
| **Perforation** | Ligne pointillée + deux encoches latérales (cercles couleur fond). Sépare le billet de son talon. |
| **Talon** | Zone évolutive — voir §5. Fond légèrement teinté pour le distinguer. |

Le tampon de statut réutilise les couleurs/libellés de l'actuel `_StatusBadge` :

| Statut | Libellé | Couleur |
|--------|---------|---------|
| `PENDING` | En attente / À traiter | `warning` (ambre) |
| `ACCEPTED` | Confirmé | `success` |
| `HANDED_OVER` | En route | `primary` |
| `IN_TRANSIT` | En transit | `primary` |
| `COMPLETED` / `DELIVERED` | Livré | `success` |
| `REJECTED` | Refusé | `error` |
| `CANCELLED` | Annulé | `onSurfaceVariant` |

---

## 5. Le talon évolutif — pièce centrale

Le talon est une zone qui **se transforme selon l'état et le rôle**. Il porte toujours, en bas, une **bande n° de suivi** (dès que le numéro existe), et au-dessus une **zone d'action** qui change.

### 5.1 Vue expéditeur

| État | Zone d'action du talon | Bande n° de suivi |
|------|------------------------|-------------------|
| `PENDING` | Placeholder « En attente de confirmation du voyageur » | — (pas encore de numéro) |
| `ACCEPTED` | **QR code** de prise en charge + actions Enregistrer / Partager (widget `QrCodeCard` existant). Texte : « Montrez ce QR au voyageur lors de la remise. » | Bande n° de suivi + **Copier** + Partager |
| `HANDED_OVER` / `IN_TRANSIT` | **Code de retrait** : 4 chiffres + bouton **Copier le code** + bouton **Régénérer** (logique `_ConfirmationCodeCard` conservée : max 5 régénérations / 24 h, compte à rebours quand la limite est atteinte). Texte : « À transmettre au voyageur ; il le saisit à la livraison. » | Bande n° de suivi + Copier + Partager |
| `COMPLETED` / `DELIVERED` | Coche de livraison + « Colis livré le … » | Bande n° de suivi + Copier + Partager |

### 5.2 Vue voyageur

| État | Zone d'action du talon | Bande n° de suivi |
|------|------------------------|-------------------|
| `PENDING` | Résumé de décision : poids · valeur déclarée · catégorie | — |
| `ACCEPTED` | Bouton **« Scanner le colis »** → ouvre le scanner QR (`/tracking/scan`, `QrScannerScreen`). Texte : « À la remise, scannez le QR de l'expéditeur. » | Bande n° de suivi + Copier |
| `HANDED_OVER` / `IN_TRANSIT` | Bouton **« Confirmer la livraison »** → ouvre la saisie du code de retrait (`/tracking/scan`, flux `ConfirmDeliveryRequested`). Texte : « À l'arrivée, saisissez le code de retrait. » | Bande n° de suivi + Copier |
| `COMPLETED` / `DELIVERED` | Coche de livraison + « Colis livré le … » | Bande n° de suivi + Copier |

**Symétrie :** le talon de l'expéditeur montre *ce qu'il détient* (QR, code) ; celui du voyageur montre *ce qu'il doit faire* (scanner, confirmer). Les deux actions voyageur pointent vers le `QrScannerScreen` existant — un paramètre de mode (`scan` vs `confirm-delivery`) + le `bidId` sont passés en `extra`.

**Le n° de suivi reste copiable** depuis le talon dès qu'il existe (états `ACCEPTED` → `COMPLETED`), pour les deux rôles. C'est l'élément que l'expéditeur partage avec le destinataire pour le suivi public.

---

## 6. Matrice états × rôles — corps de l'écran

Au-delà du billet, les cartes affichées sous le billet dépendent de l'état et du rôle. Synthèse (dérivée de `bid_detail_screen.dart`) :

| Bloc | Expéditeur | Voyageur |
|------|-----------|----------|
| Carte profil | **Voyageur** — `ACCEPTED`, `HANDED_OVER`, `IN_TRANSIT`, `COMPLETED` | **Expéditeur** — tous états, tapable → fiche |
| Carte Colis | tous états | tous états |
| Carte Destinataire | tous états | tous états |
| Carte Détails du trajet | tous états | — (le voyageur fait le trajet) |
| Carte Fenêtre de remise | si `handoverLocation` défini | si `handoverLocation` défini |
| Bouton « Suivi du colis » | `ACCEPTED` → `COMPLETED` | `ACCEPTED` → `COMPLETED` |
| Lien de suivi public | `ACCEPTED`/`HANDED_OVER`/`IN_TRANSIT` si `trackingToken` | idem |
| Carte paiement libéré | `COMPLETED` | `COMPLETED` |
| Notation | CTA « Noter le voyageur » à `COMPLETED` | automatique après validation du code ; carte « Évaluation envoyée » si déjà noté |
| Carte « Responsabilité légale » | tous états | tous états |
| Bandeau no-show | contestation (cash, `cancellationNoShowStatus == PENDING_CONFIRMATION`) | signalement (cash, `ACCEPTED`, fenêtre de remise dépassée) |
| Section d'annulation | — | `ACCEPTED`/`HANDED_OVER`/`IN_TRANSIT` |

### Barres d'action collantes (`bottomNavigationBar`)

| Condition | Barre |
|-----------|-------|
| Expéditeur, `PENDING` ou `ACCEPTED` | `_SenderActionBar` — paiement / options |
| Voyageur, `PENDING` | Accepter / Refuser (« Refuser » → bottom sheet avec raison optionnelle) |
| Voyageur, `REJECTED` | `_TravelerRejectedBar` |
| Voyageur, `ACCEPTED`, dans la fenêtre de remise, présence non confirmée | « Confirmer ma présence » |

---

## 7. Suivi du colis — étapes avec photos

Un **bouton « Suivi du colis »** sous le billet ouvre le bottom sheet de suivi existant (`tracking_timeline_bottom_sheet.dart` via `showTrackingTimelineSheet`), qui affiche les **scans réels avec photos et coordonnées GPS**. Le bouton affiche un aperçu de la dernière étape.

**Changement important :** la section inline « ÉTAPES » (`_StepsSection`) affiche aujourd'hui des **données statiques codées en dur** (commentaire `« Static example steps matching maquette »` — fausses heures, « Embarquement CDG »…). Elle est **supprimée** ; le bouton la remplace pour tous les états où il y a un suivi (`ACCEPTED` → `COMPLETED`). Le bottom sheet, lui, montre les vraies données.

---

## 8. Corps de l'écran — cartes restylées

Toutes les cartes sous le billet adoptent un langage unifié : fond `surface`, bordure `kBorder`, rayon `DonyRadius.card`, **titres de section homogènes** (corrige le problème 2 — une seule casse), icône de section, espacement régulier (24 pt entre sections).

- **Carte Voyageur / Expéditeur** — avatar, nom, badges (KYC, Kilo Pro), note ou nb d'envois, tapable → fiche profil.
- **Carte Colis** — catégorie, description, poids, valeur déclarée.
- **Carte Destinataire** — carte dédiée : nom + téléphone (ne plus la diluer dans la carte Colis).
- **Carte Détails du trajet** (expéditeur) — date/heure de départ, heure d'arrivée, tarif/kg.
- **Carte Fenêtre de remise** — lieu, début/fin, présence confirmée.
- **Carte paiement libéré**, **CTA notation**, **carte responsabilité légale** — restylées à l'identique fonctionnel.

---

## 9. Adaptation au mode de transport

Le billet emprunte le vocabulaire aérien (codes aéroport, icône avion). Il s'adapte au mode de transport :

| Mode | Corridor | Icône |
|------|----------|-------|
| Aérien | Codes aéroport (`cityAirportCode()`, déjà utilisé) | ✈ |
| Routier | Noms de ville | 🚗 / route |
| Maritime | Noms de ville | 🚢 |
| Mixte | Noms de ville | icône mixte |

**Point à vérifier en implémentation :** confirmer que `BidModel` expose le mode de transport. À défaut, le billet conserve le traitement aérien par défaut et l'adaptation est traitée comme une amélioration ultérieure.

---

## 10. Découpage technique

`bid_detail_screen.dart` (~3000 lignes, ~36 classes internes) est éclaté pour respecter l'architecture feature-first et faciliter les tests. Cible :

```
features/matching/presentation/
├── screens/
│   └── bid_detail_screen.dart        # scaffold + MultiBlocProvider + _BidDetailView (orchestration, listeners, polling)
└── widgets/billet/
    ├── colis_billet.dart             # la carte billet (en-tête, corridor, dates, perforation)
    ├── billet_status_stamp.dart      # le tampon de statut
    ├── billet_talon.dart             # le talon — aiguille selon (état, rôle)
    ├── talon_tracking_strip.dart     # bande n° de suivi (copier / partager)
    ├── talon_qr_view.dart            # talon expéditeur — ACCEPTED (réutilise QrCodeCard)
    ├── talon_retrait_code_view.dart  # talon expéditeur — code de retrait (logique _ConfirmationCodeCard)
    └── talon_traveler_action_view.dart # talon voyageur — bouton scan / confirmer livraison
```

Les cartes du corps (`_TravelerCard`, `_SenderCard`, `_PackageCard`, `_RecipientCard`, `_TripDetailsCard`, `_HandoverCard`, `_DisclaimerCard`, `_PaymentReleaseCard`) et les barres d'action (`_ActionBar`, `_SenderActionBar`, `_TravelerRejectedBar`, `_ConfirmPresenceBar`) sont extraites dans des fichiers dédiés sous `widgets/`. La logique (timers, polling 10 s, chargement paiement, listeners de blocs) reste dans `_BidDetailView`.

**Aucun nouveau bloc, événement ou modèle.** Réutilisation : `QrCodeCard`, `showTrackingTimelineSheet`, `QrScannerScreen` (`/tracking/scan`), flux `ConfirmDeliveryRequested`.

---

## 11. Points d'attention

- **Données statiques** — supprimer `_StepsSection` et son `_StepData` codé en dur ; ne pas perdre le vrai suivi (bottom sheet).
- **Talon voyageur** — vérifier que `/tracking/scan` accepte un paramètre de mode pour distinguer scan QR (DEPART) et saisie du code (livraison) ; sinon, prévoir cet ajout côté `QrScannerScreen`.
- **Règle bottom sheet dony** — tout bouton dans un bottom sheet va dans `stickyBottom` (cf. CLAUDE.md).
- **Polling & timers** — préserver le rafraîchissement 10 s pour `ACCEPTED`/`HANDED_OVER`/`IN_TRANSIT` et les `dispose()`.
- **Contraste** — le talon teinté et le tampon de statut doivent respecter le ratio 4,5:1 (HIG).
- **Régénération du code** — conserver à l'identique : 5 max / 24 h, compte à rebours, états d'erreur.

---

## 12. Tests

- **Widget tests par état** — billet + talon rendus correctement pour les 7 états × 2 rôles (QR à `ACCEPTED` expéditeur, code de retrait à `HANDED_OVER`/`IN_TRANSIT`, boutons voyageur, tampon de statut).
- **Tests d'action** — Copier (n° de suivi, code), bouton « Suivi du colis » ouvre le sheet, talon voyageur navigue vers `/tracking/scan`.
- **Régression** — barres d'action par rôle/état, no-show, annulation, notation.
- **Couverture ≥ 90 %** (`flutter test --coverage`), tous les tests verts avant commit.

---

## 13. Hors périmètre / suites possibles

- Restyling du bottom sheet de timeline lui-même.
- Adaptation fine du mode de transport si `BidModel` ne porte pas l'information aujourd'hui.
- Mode sombre du billet (fondations dark mode déjà amorcées dans le projet).
