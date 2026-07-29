# Yadony Public Brand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harmoniser la marque publique, le mot-logo, les mascottes et le nom affiché de l'application entre `dony_app`, `dony-pro` et `dony-admin`.

**Architecture:** `dony_app` reste la source des assets Yadony. Chaque front web reçoit une copie locale du mot-logo et de sa mascotte contextuelle, puis ses composants et contenus publics sont corrigés sans renommer les identifiants techniques existants. Chaque dépôt est modifié et validé indépendamment sur une branche dédiée.

**Tech Stack:** Flutter/Dart, Android, iOS, Nuxt 4, Vue 3, TypeScript, Tailwind CSS, Vitest, Playwright.

## Global Constraints

- Le nom public exact est `Yadony`, avec les déclinaisons `Yadony PRO` et `Yadony ADMIN`.
- Les dépôts, packages, classes `Dony*`, clés `dony-*`, schémas, identifiants Firebase et contrats externes restent inchangés.
- Le mot-logo source est `dony_app/assets/logos/logo-yadony.png`.
- La mascotte Yadony PRO est `dony_app/assets/mascotte/travel.png`.
- La mascotte Yadony ADMIN est `dony-admin/public/mascots/securise.png`.
- Les changements existants et sans rapport dans chaque dépôt doivent être préservés.
- Aucun commit ne doit être créé directement sur `main`.
- Les seuils de couverture existants ne doivent pas être abaissés.

---

### Task 1: Auditer le nom public de l'application mobile

**Files:**
- Verify: `android/app/src/main/AndroidManifest.xml`
- Verify: `ios/Runner/Info.plist`
- Verify: `web/index.html`
- Verify: `lib/app/app.dart`
- Verify: `assets/logos/logo-yadony.png`
- Verify: `assets/mascotte/travel.png`

**Interfaces:**
- Consumes: nom public `Yadony` et assets canoniques de `dony_app`
- Produces: preuve que les plateformes mobiles et web Flutter affichent déjà `Yadony`

- [ ] **Step 1: Ajouter un contrôle automatisé de la marque native**

Créer `test/branding/public_brand_test.dart` avec le contenu suivant :

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les manifestes exposent Yadony comme nom public', () {
    final android = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    final web = File('web/index.html').readAsStringSync();

    expect(android, contains('android:label="Yadony"'));
    expect(ios, contains('<string>Yadony</string>'));
    expect(web, contains('<title>Yadony</title>'));
  });

  test('les assets canoniques de marque existent', () {
    expect(File('assets/logos/logo-yadony.png').existsSync(), isTrue);
    expect(File('assets/mascotte/travel.png').existsSync(), isTrue);
  });
}
```

- [ ] **Step 2: Exécuter le contrôle ciblé**

Run:

```bash
flutter test test/branding/public_brand_test.dart
```

Expected: PASS, car Android, iOS, Flutter web et les assets sont déjà configurés avec Yadony.

- [ ] **Step 3: Contrôler les copies publiques résiduelles**

Run:

```bash
rg -n -i '"dony"|\bDony (app|application|équipe|support|admin|pro)\b' \
  lib android/app/src/main ios/Runner web \
  --glob '!**/*.g.dart'
```

Expected: aucune ancienne marque publique ; les occurrences restantes sont exclusivement des identifiants techniques documentés.

- [ ] **Step 4: Exécuter la validation Flutter**

Run:

```bash
flutter analyze
flutter test --coverage
```

Expected: analyse et tests réussis ; couverture globale au moins égale à 90 %.

- [ ] **Step 5: Commit**

```bash
git add test/branding/public_brand_test.dart
git commit -m "test: verrouille la marque publique Yadony"
```

### Task 2: Installer les assets et la marque Yadony PRO

**Files:**
- Create: `public/logos/logo-yadony.png`
- Create: `public/mascots/travel.png`
- Modify: `app/features/auth/components/LoginLeftPanel.vue`
- Modify: `tests/components/LoginLeftPanel.spec.ts`
- Modify: `app/features/landing/components/LandingNav.vue`
- Modify: `app/features/landing/components/LandingFooter.vue`
- Modify: `app/components/layout/AppSidebar.vue`
- Modify: `nuxt.config.ts`

**Interfaces:**
- Consumes: `../dony_app/assets/logos/logo-yadony.png` et `../dony_app/assets/mascotte/travel.png`
- Produces: `/logos/logo-yadony.png`, `/mascots/travel.png` et les en-têtes publics `Yadony PRO`

- [ ] **Step 1: Créer une branche dédiée sans inclure les changements locaux existants**

Run:

```bash
git switch -c chore/yadony-public-brand
git status --short
```

Expected: la nouvelle branche est active ; `pnpm-lock.yaml` et `pnpm-workspace.yaml` restent intacts et ne seront pas ajoutés aux commits de cette tâche.

- [ ] **Step 2: Mettre à jour le test du panneau de connexion pour exiger le logo et la mascotte**

Remplacer les assertions de marque dans `tests/components/LoginLeftPanel.spec.ts` par :

```ts
it('renders the Yadony PRO logo', () => {
  const wrapper = mount(LoginLeftPanel)
  expect(wrapper.find('img[alt="Yadony"]').attributes('src')).toBe('/logos/logo-yadony.png')
  expect(wrapper.text()).toContain('PRO')
})

it('renders the travel mascot', () => {
  const wrapper = mount(LoginLeftPanel)
  const mascot = wrapper.find('img[alt="Mascotte Yadony prête à voyager"]')
  expect(mascot.exists()).toBe(true)
  expect(mascot.attributes('src')).toBe('/mascots/travel.png')
})
```

- [ ] **Step 3: Exécuter le test ciblé pour vérifier qu'il échoue**

Run:

```bash
pnpm test -- tests/components/LoginLeftPanel.spec.ts
```

Expected: FAIL, car le panneau affiche encore le texte `dony` et aucune mascotte.

- [ ] **Step 4: Copier les assets canoniques**

Run:

```bash
cp ../dony_app/assets/logos/logo-yadony.png public/logos/logo-yadony.png
mkdir -p public/mascots
cp ../dony_app/assets/mascotte/travel.png public/mascots/travel.png
```

- [ ] **Step 5: Intégrer le logo et la mascotte au panneau de connexion**

Dans `app/features/auth/components/LoginLeftPanel.vue`, remplacer le logo textuel par :

```vue
<div class="flex items-center gap-2">
  <img src="/logos/logo-yadony.png" alt="Yadony" class="h-7 w-auto" />
  <span class="rounded-full bg-primary/10 px-2.5 py-0.5 text-xs font-semibold text-primary">PRO</span>
</div>
```

Ajouter dans la zone éditoriale, avant le titre :

```vue
<img
  src="/mascots/travel.png"
  alt="Mascotte Yadony prête à voyager"
  class="mb-5 h-36 w-36 object-contain outline outline-1 -outline-offset-1 outline-black/10 dark:outline-white/10"
/>
```

Conserver le titre, la description et les éléments de réassurance existants.

- [ ] **Step 6: Remplacer les anciens assets dans la landing page**

Dans `LandingNav.vue` et `LandingFooter.vue`, utiliser :

```vue
<img src="/logos/logo-yadony.png" alt="Yadony" class="h-7 w-auto" />
```

Utiliser `h-6` dans le footer. Supprimer uniquement la sélection des anciens
logos clair/sombre devenue inutile, sans modifier la gestion globale du thème.

- [ ] **Step 7: Harmoniser le shell authentifié**

Dans `app/components/layout/AppSidebar.vue`, remplacer le mot textuel `dony` par
le même `<img src="/logos/logo-yadony.png" alt="Yadony" ...>` et conserver le
badge `PRO`.

Dans `nuxt.config.ts`, remplacer les valeurs publiques :

```ts
title: 'Yadony PRO'
```

Ne pas modifier la clé technique `dony-theme`.

- [ ] **Step 8: Exécuter le test ciblé**

Run:

```bash
pnpm test -- tests/components/LoginLeftPanel.spec.ts
```

Expected: PASS.

- [ ] **Step 9: Commit des assets et composants de marque**

```bash
git add public/logos/logo-yadony.png public/mascots/travel.png \
  app/features/auth/components/LoginLeftPanel.vue \
  app/features/landing/components/LandingNav.vue \
  app/features/landing/components/LandingFooter.vue \
  app/components/layout/AppSidebar.vue tests/components/LoginLeftPanel.spec.ts \
  nuxt.config.ts
git commit -m "feat: installe l identité visuelle Yadony PRO"
```

### Task 3: Corriger toutes les copies publiques de Yadony PRO

**Files:**
- Modify: `app/features/cash/components/CashCommissionCard.vue`
- Modify: `app/features/colis/components/BidDetailPanel.vue`
- Modify: `app/features/landing/components/LandingAppBridge.vue`
- Modify: `app/features/landing/components/LandingCta.vue`
- Modify: `app/features/landing/components/LandingFaq.vue`
- Modify: `app/features/landing/components/LandingFeatures.vue`
- Modify: `app/features/landing/components/LandingHero.vue`
- Modify: `app/features/landing/components/LandingTestimonials.vue`
- Modify: `app/features/payout/types/index.ts`
- Modify: `app/features/trajets/components/NewAnnouncementForm.vue`
- Modify: `app/features/trajets/components/TripDetailRevenue.vue`
- Modify: `app/layouts/default.vue`
- Modify: `app/pages/design.vue`
- Modify: `app/pages/index.vue`
- Modify: `app/pages/litiges/index.vue`
- Modify: `app/pages/login.vue`
- Modify: `app/pages/upgrade.vue`

**Interfaces:**
- Consumes: règle de casse publique `Yadony` / `Yadony PRO`
- Produces: contenu éditorial sans ancienne marque visible

- [ ] **Step 1: Ajouter un test statique de copie publique**

Créer `tests/branding/publicBrand.spec.ts` :

```ts
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

describe('public Yadony brand', () => {
  it('does not expose the former brand in active UI copy', () => {
    const files = [
      'app/components/layout/AppSidebar.vue',
      'app/features/auth/components/LoginLeftPanel.vue',
      'app/features/cash/components/CashCommissionCard.vue',
      'app/features/colis/components/BidDetailPanel.vue',
      'app/features/landing/components/LandingAppBridge.vue',
      'app/features/landing/components/LandingCta.vue',
      'app/features/landing/components/LandingFaq.vue',
      'app/features/landing/components/LandingFeatures.vue',
      'app/features/landing/components/LandingFooter.vue',
      'app/features/landing/components/LandingHero.vue',
      'app/features/landing/components/LandingNav.vue',
      'app/features/landing/components/LandingTestimonials.vue',
      'app/features/payout/types/index.ts',
      'app/features/trajets/components/NewAnnouncementForm.vue',
      'app/features/trajets/components/TripDetailRevenue.vue',
      'app/layouts/default.vue',
      'app/pages/design.vue',
      'app/pages/index.vue',
      'app/pages/litiges/index.vue',
      'app/pages/login.vue',
      'app/pages/upgrade.vue',
      'nuxt.config.ts',
    ]
    const offenders = files.filter((file) => {
      const source = readFileSync(file, 'utf8')
        .replaceAll(/dony-theme|dony-table|__donyAuth(?:Seed)?|dony_device_id|admin\.dony\.invalid/gi, '')
      return /\bdony\b/i.test(source)
    })
    expect(offenders).toEqual([])
  })
})
```

- [ ] **Step 2: Exécuter le test statique pour vérifier qu'il échoue**

Run:

```bash
pnpm test -- tests/branding/publicBrand.spec.ts
```

Expected: FAIL avec la liste des composants contenant encore l'ancienne marque.

- [ ] **Step 3: Corriger les textes et métadonnées publics**

Dans chaque fichier listé par le test, appliquer exactement :

```text
dony PRO -> Yadony PRO
Dony PRO -> Yadony PRO
dony     -> Yadony
Dony     -> Yadony
```

Limiter le remplacement aux chaînes affichées, titres, descriptions,
commentaires éditoriaux et textes alternatifs. Ne pas renommer les symboles,
classes CSS, clés de stockage, URLs, codes de parrainage ni contrats techniques.

- [ ] **Step 4: Exécuter le test statique et les tests unitaires**

Run:

```bash
pnpm test -- tests/branding/publicBrand.spec.ts
pnpm test
```

Expected: PASS.

- [ ] **Step 5: Commit des copies publiques**

```bash
git add app tests/branding/publicBrand.spec.ts
git commit -m "fix: harmonise les textes publics Yadony PRO"
```

- [ ] **Step 6: Validation complète de Yadony PRO**

Run:

```bash
pnpm lint
pnpm test:coverage
pnpm build
```

Expected: toutes les commandes réussissent et les seuils de couverture configurés restent satisfaits.

### Task 4: Installer le logo et harmoniser Yadony ADMIN

**Files:**
- Create: `public/logos/logo-yadony.png`
- Modify: `app/features/auth/components/LoginLeftPanel.vue`
- Modify: `tests/components/LoginLeftPanel.spec.ts`
- Modify: `app/components/layout/AppSidebar.vue`
- Modify: `app/layouts/default.vue`
- Modify: `app/pages/change-password.vue`
- Modify: `app/pages/denied.vue`
- Modify: `app/pages/login.vue`
- Modify: `nuxt.config.ts`
- Create: `tests/branding/publicBrand.spec.ts`

**Interfaces:**
- Consumes: `../dony_app/assets/logos/logo-yadony.png` et `/mascots/securise.png`
- Produces: logo public Yadony, marque `Yadony ADMIN` et mascotte sécurisée accessible

- [ ] **Step 1: Créer une branche dédiée en préservant le commit local existant**

Run:

```bash
git switch -c chore/yadony-public-brand
git status --short --branch
```

Expected: la branche part de l'état actuel `chore/codex-agent-config` et conserve son commit sans le modifier.

- [ ] **Step 2: Mettre à jour le test du panneau de connexion**

Dans `tests/components/LoginLeftPanel.spec.ts`, remplacer le test du logo par :

```ts
it('renders the Yadony ADMIN logo', () => {
  const wrapper = mount(LoginLeftPanel)
  expect(wrapper.find('img[alt="Yadony"]').attributes('src')).toBe('/logos/logo-yadony.png')
  expect(wrapper.text()).toContain('ADMIN')
})
```

Mettre à jour le test de mascotte pour exiger :

```ts
expect(img.attributes('alt')).toBe('Mascotte Yadony avec bouclier de sécurité vérifié')
```

- [ ] **Step 3: Exécuter le test ciblé pour vérifier qu'il échoue**

Run:

```bash
pnpm test -- tests/components/LoginLeftPanel.spec.ts
```

Expected: FAIL, car le logo est encore rendu comme texte et l'ancien nom reste dans le texte alternatif.

- [ ] **Step 4: Copier le mot-logo officiel**

Run:

```bash
mkdir -p public/logos
cp ../dony_app/assets/logos/logo-yadony.png public/logos/logo-yadony.png
```

- [ ] **Step 5: Intégrer le logo au panneau et au shell**

Dans `LoginLeftPanel.vue` et `AppSidebar.vue`, remplacer le mot textuel par :

```vue
<img src="/logos/logo-yadony.png" alt="Yadony" class="h-7 w-auto" />
```

Conserver le badge `ADMIN`. Dans le panneau de connexion, mettre le texte
alternatif de la mascotte à :

```text
Mascotte Yadony avec bouclier de sécurité vérifié
```

- [ ] **Step 6: Corriger les noms publics**

Appliquer les valeurs suivantes uniquement aux textes visibles et métadonnées :

```text
dony ADMIN -> Yadony ADMIN
Dony Admin -> Yadony ADMIN
dony       -> Yadony
Dony       -> Yadony
```

Modifier `default.vue`, `change-password.vue`, `denied.vue`, `login.vue` et
`nuxt.config.ts`. Ne pas modifier `dony-theme`, `dony-admin-session` ni
`admin.dony.invalid`.

- [ ] **Step 7: Ajouter le contrôle statique ADMIN**

Créer `tests/branding/publicBrand.spec.ts` :

```ts
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

describe('public Yadony ADMIN brand', () => {
  it('does not expose the former brand in active UI copy', () => {
    const files = [
      'app/components/layout/AppSidebar.vue',
      'app/features/auth/components/LoginLeftPanel.vue',
      'app/layouts/default.vue',
      'app/pages/change-password.vue',
      'app/pages/denied.vue',
      'app/pages/login.vue',
      'nuxt.config.ts',
    ]
    const offenders = files.filter((file) => {
      const source = readFileSync(file, 'utf8')
        .replaceAll(/dony-theme|dony-admin-session|admin\.dony\.invalid/gi, '')
      return /\bdony\b/i.test(source)
    })
    expect(offenders).toEqual([])
  })
})
```

- [ ] **Step 8: Exécuter les tests ciblés et unitaires**

Run:

```bash
pnpm test -- tests/components/LoginLeftPanel.spec.ts
pnpm test -- tests/branding/publicBrand.spec.ts
pnpm test
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add public/logos/logo-yadony.png app tests/components/LoginLeftPanel.spec.ts \
  tests/branding/publicBrand.spec.ts nuxt.config.ts
git commit -m "feat: harmonise l identité visuelle Yadony ADMIN"
```

- [ ] **Step 10: Validation complète de Yadony ADMIN**

Run:

```bash
pnpm lint
pnpm test:coverage
pnpm build
```

Expected: toutes les commandes réussissent et les seuils de couverture configurés restent satisfaits.

### Task 5: Vérification croisée finale

**Files:**
- Verify: `dony_app/`
- Verify: `dony-pro/`
- Verify: `dony-admin/`

**Interfaces:**
- Consumes: livrables validés des tâches 1 à 4
- Produces: bilan des occurrences publiques corrigées et des identifiants techniques conservés

- [ ] **Step 1: Vérifier les assets**

Run depuis le répertoire parent :

```bash
shasum -a 256 \
  dony_app/assets/logos/logo-yadony.png \
  dony-pro/public/logos/logo-yadony.png \
  dony-admin/public/logos/logo-yadony.png
```

Expected: les trois empreintes sont identiques.

- [ ] **Step 2: Inventorier les occurrences restantes**

Run:

```bash
rg -n -i '\bdony\b' \
  dony_app/lib dony_app/android/app/src/main dony_app/ios/Runner dony_app/web \
  dony-pro/app dony-pro/nuxt.config.ts \
  dony-admin/app dony-admin/nuxt.config.ts
```

Expected: chaque occurrence restante appartient à un identifiant technique
explicitement préservé par les contraintes globales ; aucune chaîne rendue ne
présente Dony comme marque.

- [ ] **Step 3: Vérifier les états Git**

Run:

```bash
git -C dony_app status --short --branch
git -C dony-pro status --short --branch
git -C dony-admin status --short --branch
```

Expected: les trois dépôts sont sur des branches dédiées ; les changements
locaux antérieurs de `dony-pro` restent présents et non commités.
