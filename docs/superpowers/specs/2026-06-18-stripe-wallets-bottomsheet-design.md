# Spec — Sélecteur de paiement : logos wallets (phase 2)

**Date:** 2026-06-18 | **Status:** 🟡 Validée (design) — implémentation à planifier
**Repo:** `dony_app` (Flutter)
**Phase 2 de 2** — phase 1 = activation Stripe (PR `dony_app#104` / `dony-back#70`). Cette phase = UI du sélecteur de moyen de paiement.
**Dépendance :** la tuile annonce Apple Pay / Google Pay / PayPal — véridique seulement une fois la phase 1 mergée + wallets activés au dashboard Stripe.

---

## 1. Objectif

Redessiner la tuile « Stripe » du sélecteur de moyen de paiement pour signaler à l'expéditeur que ce rail couvre désormais **Carte + Apple Pay + Google Pay + PayPal** (les instruments réels étant choisis dans la PaymentSheet Stripe native).

## 2. Décision de design — Option C-logos, plateforme-aware, logos officiels

Retenu après mockups (companion visuel) :
- **C** : on conserve le cadenas + « Paiement sécurisé / Via Stripe » (réassurance actuelle) et on ajoute une rangée de **logos de marque**.
- **plateforme-aware** : Apple Pay seulement sur iOS, Google Pay seulement sur Android, carte + PayPal partout.
- **logos officiels** (option b) : marks Apple Pay / Google Pay / PayPal / Visa / Mastercard depuis leurs brand resources, pour la conformité store (Apple refuse les marks Apple Pay non conformes).

**Rejeté :** A (logos « Carte & wallets » sans cadenas) — perd la réassurance. B (texte seul) — moins premium, l'utilisateur l'a écarté.

### Conséquence
Aucun changement de logique/enum/BLoC. Le rail reste `STRIPE`. C'est purement présentationnel : la tuile annonce, la PaymentSheet Stripe gère le choix réel.

## 3. Architecture

### 3.1 Assets (logos officiels)
Nouveau dossier `assets/logos/payment/` (déclaré dans `pubspec.yaml`), SVG :
- `card.svg` — réseaux carte (Visa + Mastercard combinés en **un seul** mark)
- `apple-pay.svg` — mark officiel Apple Pay
- `google-pay.svg` — mark officiel Google Pay
- `paypal.svg` — mark officiel PayPal

Source : brand resources officiels (Apple « Apple Pay Marks », Google « Google Pay brand guidelines », PayPal Logo Center, Visa/Mastercard brand centers). Respect clear space + taille minimale. Rendu via `flutter_svg` (déjà utilisé pour `assets/icons/*.svg`).

### 3.2 Widget `PaymentBrandMarks` (nouveau)
`lib/features/payments/presentation/widgets/payment_brand_marks.dart`

```dart
class PaymentBrandMarks extends StatelessWidget {
  const PaymentBrandMarks({super.key});

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final marks = <String>[
      'assets/logos/payment/card.svg',
      if (isIOS) 'assets/logos/payment/apple-pay.svg'
      else 'assets/logos/payment/google-pay.svg',
      'assets/logos/payment/paypal.svg',
    ];
    return Wrap(
      spacing: DonySpacing.xs,
      runSpacing: DonySpacing.xs,
      children: [
        for (final a in marks)
          SvgPicture.asset(a, height: 16, semanticsLabel: _labelFor(a)),
      ],
    );
  }
}
```
- Plateforme-aware via `defaultTargetPlatform` (testable avec `debugDefaultTargetPlatformOverride`).
- `Wrap` pour ne pas déborder sur une tuile demi-largeur.
- `semanticsLabel` sur chaque mark (accessibilité — info pas portée par la couleur seule).

### 3.3 `_MethodTile` — slot `marks` optionnel
`create_bid_bottom_sheet.dart` (`_MethodTile`, ~L1790) gagne un paramètre `Widget? marks` rendu entre `label` et `sublabel`. La tuile STRIPE (`_PaymentMethodSelector`, ~L1721) passe :
- `iconAsset: 'lock'`, `label: 'Paiement sécurisé'`, `marks: const PaymentBrandMarks()`, `sublabel: 'Via Stripe'`.

Les tuiles Cash/Wave/Orange passent `marks: null` → rendu inchangé (le slot ne s'affiche que si non null).

## 4. Hors scope

- `PaymentMethodsChips` (lecture seule, vue voyageur sur une demande) : **inchangé**. Les wallets sont implicites sous le rail carte ; ce composant liste les moyens acceptés, pas les instruments.
- Flux négociation : pas de sélecteur interactif (le moyen est résolu depuis le thread) → rien à redessiner.
- L'UI interne de la PaymentSheet Stripe : gérée par Stripe.
- Aucun changement backend, BLoC, enum, repository.

## 5. Tests

- **`PaymentBrandMarks`** : avec `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` → 3 SVG dont `apple-pay.svg`, pas `google-pay.svg`. Avec Android → `google-pay.svg`, pas `apple-pay.svg`. `card.svg` + `paypal.svg` dans les deux cas.
- **Tuile STRIPE** : `_PaymentMethodSelector` rend `PaymentBrandMarks` ; une tuile non-STRIPE (ex. Cash) ne rend pas de marks.
- Couverture ≥ 90 % sur le nouveau code.

## 6. Edge cases

- **Asset manquant** : `SvgPicture.asset` lève si le fichier est absent. Les 4 SVG doivent exister + être déclarés dans `pubspec.yaml` avant le merge (sinon crash au build/runtime de la tuile). Le plan inclut des assets placeholder conformes au pire, à remplacer par les officiels.
- **Web/desktop** : `defaultTargetPlatform` renvoie autre chose qu'iOS/Android → la branche `else` (Google Pay) s'applique. Acceptable (dony est mobile-only ; pas de cible web/desktop).
- **Accessibilité** : `semanticsLabel` obligatoire sur chaque mark.

## 6bis. Mise à jour — marks réels en place

Les 4 placeholders ont été remplacés par de vrais marks d'acceptation : Visa/Mastercard/PayPal pleine couleur (aaronfagan, MIT) + Apple Pay/Google Pay mark monochrome officiel (simple-icons, CC0). Le widget rend désormais **4 marks** : `visa`, `mastercard`, wallet plateforme, `paypal`. Provenance : `assets/logos/payment/SOURCES.md`. Pour conformité stricte des chartes, substituer les téléchargements officiels.

## 7. Critères d'acceptation

- [ ] La tuile « Stripe » du sélecteur de bid affiche cadenas + « Paiement sécurisé » + logos (carte + wallet plateforme + PayPal) + « Via Stripe ».
- [ ] Sur iOS : Apple Pay visible, Google Pay absent. Sur Android : l'inverse. Carte + PayPal dans les deux cas.
- [ ] Les tuiles Cash/Wave/Orange restent inchangées (pas de marks).
- [ ] Logos officiels conformes (clear space, taille mini) déposés dans `assets/logos/payment/` + déclarés dans `pubspec.yaml`.
- [ ] `semanticsLabel` sur chaque logo.
- [ ] Aucun changement d'enum / BLoC / backend.
- [ ] Tests `PaymentBrandMarks` (iOS/Android) + tuile, couverture ≥ 90 %.
