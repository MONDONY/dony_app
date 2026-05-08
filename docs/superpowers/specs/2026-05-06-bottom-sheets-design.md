# Design — Remplacement d'écrans par des Bottom Sheets

**Date :** 2026-05-06  
**Statut :** ✅ Approuvé  
**Périmètre :** Flutter app dony (`dony_app/`)

---

## Contexte

L'app dony comporte 43 écrans. Plusieurs d'entre eux sont des écrans "secondaires" — des actions courtes, des formulaires courts, ou des contenus informatifs — qui méritent d'être présentés en bottom sheet plutôt qu'en navigation push complète.

**Règle de hauteur :** chaque bottom sheet enveloppe son contenu (`intrinsicHeight`). Si le contenu dépasse 90 % de la hauteur d'écran, la BS se bloque à 90 % et son contenu devient scrollable.

---

## Écrans à convertir

### Groupe 1 — Conversions idéales (5 écrans)

| Écran | Route actuelle | Hauteur estimée | Déclencheur |
|---|---|---|---|
| Rating Screen | `/ratings/:bidId` | ~38% | Bouton sur BidDetailScreen après livraison |
| Cancellation Screen | `/announcements/:id/cancel` | ~52% | Bouton "Annuler" sur AnnouncementDetailScreen |
| Escrow Explainer Screen | `/payments/escrow` | ~55% | Badge 🔒 sur PaymentScreen |
| Role Selection Screen | flow interne auth | ~50% | Transition après OTP/PIN dans le flow auth |
| Offline Scan Queue Screen | `/tracking/offline-queue` | ~48% (3 items) → 90%+ scroll | Bannière d'alerte sur TrackingHubScreen |

### Groupe 2 — Bonnes candidates (5 écrans)

| Écran | Route actuelle | Hauteur estimée | Déclencheur |
|---|---|---|---|
| Handover Screen | `/bids/:bidId/handover` | ~50% | Bouton "Définir point de remise" sur BidDetailScreen |
| Tracking Search Screen | `/tracking/search` | ~30% | Carte "Rechercher" sur TrackingHubScreen |
| KYC Onboarding Screen | `/kyc` | ~55% | Bannière KYC sur ProfileScreen |
| Connect Onboarding Pending | `/connect/onboarding/pending` | ~35% | Retour depuis l'app Stripe externe |
| Delete Account Screen | `/settings/delete-account` | ~55% | Item "Supprimer le compte" sur SettingsScreen |

### Groupe 3 — Compromis (2 écrans)

| Écran | Route actuelle | Hauteur estimée | Arbitrage |
|---|---|---|---|
| Upgrade to Pro Screen | `/profile/upgrade-pro` | ~80% | Fonctionne en BS 80 % height mais légère perte de confiance perçue vs plein écran |
| Rematch Search Screen | `/cancellations/rematch` | 40 %–90 % selon résultats | BS si ≤ 4 résultats, link "Voir toutes les alternatives" ouvre plein écran si > 4 |

---

## Architecture Flutter

### Widget réutilisable : `DonyBottomSheet`

Créer un widget utilitaire dans `lib/common/widgets/dony_bottom_sheet.dart` :

```dart
// Ouverture depuis n'importe quel contexte
showDonyBottomSheet(
  context: context,
  builder: (context) => RatingBottomSheet(bidId: bid.id),
);
```

**Comportement :**
- `showModalBottomSheet` avec `isScrollControlled: true`
- `constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9)`
- `SingleChildScrollView` wrappant le contenu pour le scroll si dépassement
- Handle en haut (32 × 3 px, couleur `#D1D5DB`)
- `backgroundColor: Colors.white`, `borderRadius: BorderRadius.vertical(top: Radius.circular(16))`
- `useSafeArea: true` pour éviter le chevauchement avec la barre de navigation système

### Variante danger : `DonyDangerBottomSheet`

Pour Cancellation et Delete Account :
- `backgroundColor: Color(0xFFFFF5F5)`
- `borderTop: Border(top: BorderSide(color: Color(0xFFFECACA)))`
- Handle couleur `Color(0xFFFCA5A5)`

### Gestion du clavier (Handover, Tracking Search)

Ajouter `resizeToAvoidBottomInset: true` au `Scaffold` parent et `padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom)` dans la BS pour remonter avec le clavier.

---

## Routes GoRouter — suppressions

Les routes suivantes **n'ont plus besoin d'exister** dans le router après conversion :

```
/ratings/:bidId                    → BS depuis BidDetailScreen
/announcements/:id/cancel          → BS depuis AnnouncementDetailScreen
/payments/escrow                   → BS depuis PaymentScreen
/tracking/offline-queue            → BS depuis TrackingHubScreen
/tracking/search                   → BS depuis TrackingHubScreen
/bids/:bidId/handover              → BS depuis BidDetailScreen
/kyc                               → BS depuis ProfileScreen (bannière)
/connect/onboarding/pending        → BS depuis ConnectOnboardingIntroScreen
/settings/delete-account           → BS depuis SettingsScreen
/profile/upgrade-pro               → BS depuis ProfileScreen
/cancellations/rematch             → BS depuis CancellationScreen (si ≤ 4 résultats)
```

> **Note :** supprimer ces routes de GoRouter uniquement après avoir créé les BS correspondantes et vérifié qu'aucun deep link externe ne les cible.

---

## Thème visuel

- **Fond BS :** `Colors.white`
- **Fond BS danger :** `Color(0xFFFFF5F5)`
- **Handle :** `Color(0xFFD1D5DB)`, 32 × 3 px, centré, `borderRadius: 100`
- **Titre BS :** `fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111111)`
- **Sous-titre BS :** `fontSize: 12, color: Color(0xFFAAAAAA)`
- **Bouton primaire :** fond `Color(0xFF16A34A)`, texte blanc, `borderRadius: 8`
- **Bouton danger :** fond `Color(0xFFDC2626)`, texte blanc
- **Bouton ghost :** fond `Color(0xFFF3F4F6)`, texte `Color(0xFF555555)`, bordure `Color(0xFFE5E7EB)`

---

## Ordre d'implémentation recommandé

1. Créer `DonyBottomSheet` + `DonyDangerBottomSheet` (utilitaires communs)
2. **Rating** — impact UX le plus immédiat, le plus simple
3. **Cancellation** — idem, très court
4. **Escrow Explainer** — zéro logique, pur affichage
5. **Role Selection** — flow auth
6. **Offline Scan Queue** — avec logique bannière
7. **Handover** — gestion clavier
8. **Tracking Search** — le plus simple du groupe 2
9. **KYC Onboarding** — bannière profil
10. **Connect Pending** — retour Stripe
11. **Delete Account** — variante danger
12. **Upgrade Pro** — BS 80 %
13. **Rematch Search** — logique conditionnelle ≤ 4 résultats

---

## Tests à ajouter

Pour chaque BS convertie :
- Widget test : BS s'ouvre et affiche le bon contenu
- Widget test : BS se ferme après action principale
- Widget test : hauteur ne dépasse pas 90 % (golden test ou contrainte vérifiée)
- Widget test BS danger : couleur de fond correcte

---

## Écrans à ne PAS convertir

| Écran | Raison |
|---|---|
| QR Scanner | Flux caméra — plein écran obligatoire |
| Payment Screen | Transaction financière — confiance utilisateur |
| KYC WebView | Contrôlé par Stripe |
| Tracking Timeline | Interface riche et longue |
| Chat Screen | Interface de messagerie |
| Create/Edit Announcement | Formulaire complexe multi-champs |
| Search Announcement | Filtres + carte + résultats |
| Bid Detail | Contenu riche, QR code, actions multiples |
