# Refonte « Billet de colis » — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refondre `bid_detail_screen.dart` (« Mon colis ») autour d'une métaphore de billet — en-tête, corridor, perforation, talon évolutif — adaptative expéditeur/voyageur sur 7 états.

**Architecture:** Construction ascendante. On crée d'abord les widgets feuilles du billet (testés isolément, app inchangée), puis on les assemble, puis on intègre dans l'écran en remplaçant zone par zone. Le fichier de 3000 lignes est éclaté en widgets dédiés sous `widgets/billet/` et `widgets/`. Aucun changement backend, bloc, événement ou modèle.

**Tech Stack:** Flutter · flutter_bloc · GoRouter · flutter_animate · design system dony (`DonySpacing`, `DonyRadius`, `DonyColors`, `DonyCard`…) · tests `flutter_test` + `bloc_test` + `mocktail`.

**Spec :** `docs/superpowers/specs/2026-05-16-bid-detail-billet-redesign-design.md`
**Maquettes :** `docs/superpowers/specs/2026-05-16-bid-detail-billet-redesign-maquettes/`

---

## Règles transverses

- **Filet de sécurité :** `test/features/matching/presentation/screens/bid_detail_screen_cash_test.dart` doit rester vert à chaque tâche. Le lancer après toute tâche touchant l'écran.
- **Design :** importer `package:dony/core/design/design_system.dart`. Couleurs via `Theme.of(context).colorScheme`, typo via `textTheme`. Jamais de couleur en dur hors `DonyColors`.
- **Pas de `setState`** hors logique d'animation locale d'un widget feuille ; **GoRouter** pour toute navigation.
- **Bottom sheet :** tout `DonyButton` dans un bottom sheet va dans `stickyBottom` (cf. CLAUDE.md).
- Chaque tâche finit par `flutter analyze` (0 erreur) puis un commit.

## Baseline — avant de commencer

- [ ] Lancer `flutter test test/features/matching/` — confirmer que tout est vert.
- [ ] Lancer `flutter analyze` — confirmer 0 erreur.

---

## Structure de fichiers cible

```
lib/features/matching/presentation/
├── screens/
│   └── bid_detail_screen.dart              # MODIFIÉ — scaffold + _BidDetailView (orchestration)
└── widgets/
    ├── billet/
    │   ├── colis_billet.dart               # CRÉÉ — carte billet (en-tête, corridor, dates, perforation, talon)
    │   ├── billet_status_stamp.dart        # CRÉÉ — tampon de statut
    │   ├── billet_talon.dart               # CRÉÉ — aiguillage (état, rôle) → contenu du talon
    │   ├── talon_tracking_strip.dart       # CRÉÉ — bande n° de suivi (copier / partager)
    │   ├── talon_retrait_code_view.dart    # CRÉÉ — code de retrait (extraction _ConfirmationCodeCard)
    │   └── talon_traveler_action_view.dart # CRÉÉ — boutons scan / confirmer livraison (voyageur)
    ├── billet_perforation.dart             # CRÉÉ — séparateur perforé réutilisable
    ├── voyageur_card.dart                  # CRÉÉ — extraction _TravelerCard
    ├── expediteur_card.dart                # CRÉÉ — extraction _SenderCard
    ├── colis_card.dart                     # CRÉÉ — extraction _PackageCard
    ├── destinataire_card.dart              # CRÉÉ — extraction _RecipientCard
    ├── trajet_card.dart                    # CRÉÉ — extraction _TripDetailsCard
    ├── handover_card.dart                  # CRÉÉ — extraction _HandoverCard
    ├── suivi_button.dart                   # CRÉÉ — bouton « Suivi du colis »
    └── action_bars/
        └── bid_detail_action_bars.dart     # CRÉÉ — extraction des 4 barres d'action
```

Le QR à l'état Confirmé réutilise le widget existant `QrCodeCard` (`features/tracking/presentation/widgets/qr_code_card.dart`) — pas de nouveau fichier (DRY).

---

## Task 1 : `BilletStatusStamp` — le tampon de statut

Tampon incliné affiché dans l'en-tête du billet. Mappe `bid.status` → libellé + couleur (reprend la logique de l'actuel `_StatusBadge`, `bid_detail_screen.dart:569-629`).

**Files:**
- Create: `lib/features/matching/presentation/widgets/billet/billet_status_stamp.dart`
- Test: `test/features/matching/presentation/widgets/billet/billet_status_stamp_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

```dart
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_status_stamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, String status) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: BilletStatusStamp(status: status))),
  ));
}

void main() {
  testWidgets('ACCEPTED → libellé "Confirmé"', (tester) async {
    await _pump(tester, 'ACCEPTED');
    expect(find.text('Confirmé'), findsOneWidget);
  });

  testWidgets('HANDED_OVER → libellé "En route"', (tester) async {
    await _pump(tester, 'HANDED_OVER');
    expect(find.text('En route'), findsOneWidget);
  });

  testWidgets('COMPLETED → libellé "Livré"', (tester) async {
    await _pump(tester, 'COMPLETED');
    expect(find.text('Livré'), findsOneWidget);
  });

  testWidgets('PENDING → libellé "En attente"', (tester) async {
    await _pump(tester, 'PENDING');
    expect(find.text('En attente'), findsOneWidget);
  });

  testWidgets('statut inconnu → libellé brut', (tester) async {
    await _pump(tester, 'WEIRD');
    expect(find.text('WEIRD'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer le test — il échoue**

Run: `flutter test test/features/matching/presentation/widgets/billet/billet_status_stamp_test.dart`
Expected: FAIL — `Target of URI doesn't exist` (le fichier widget n'existe pas).

- [ ] **Step 3 : Implémenter le widget**

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Tampon de statut incliné affiché dans l'en-tête du billet.
class BilletStatusStamp extends StatelessWidget {
  final String status;
  const BilletStatusStamp({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (Color color, String label) = switch (status) {
      'ACCEPTED' => (cs.success, 'Confirmé'),
      'HANDED_OVER' => (cs.primary, 'En route'),
      'IN_TRANSIT' => (cs.primary, 'En transit'),
      'COMPLETED' || 'DELIVERED' => (cs.success, 'Livré'),
      'REJECTED' => (cs.error, 'Refusé'),
      'CANCELLED' => (cs.onSurfaceVariant, 'Annulé'),
      'PENDING' => (cs.warning, 'En attente'),
      _ => (cs.onSurfaceVariant, status),
    };

    return Transform.rotate(
      angle: -0.087, // ~ -5°
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm,
          vertical: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DonyRadius.sm),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          label.toUpperCase(),
          style: tt.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4 : Lancer le test — il passe**

Run: `flutter test test/features/matching/presentation/widgets/billet/billet_status_stamp_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5 : `flutter analyze` puis commit**

```bash
flutter analyze lib/features/matching/presentation/widgets/billet/billet_status_stamp.dart
git add lib/features/matching/presentation/widgets/billet/billet_status_stamp.dart test/features/matching/presentation/widgets/billet/billet_status_stamp_test.dart
git commit -m "feat(billet): tampon de statut du billet de colis"
```

---

## Task 2 : `TalonTrackingStrip` — bande n° de suivi

Bande en bas du talon : visuel code-barres + libellé + numéro + bouton **Copier** (presse-papier + snackbar) + bouton **Partager**. Reprend le comportement copie de l'actuel `_TrackingNumberCard` (`bid_detail_screen.dart:2110-2187`) et le partage de l'actuelle action AppBar (`Share.share`).

**Files:**
- Create: `lib/features/matching/presentation/widgets/billet/talon_tracking_strip.dart`
- Test: `test/features/matching/presentation/widgets/billet/talon_tracking_strip_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

```dart
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_tracking_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(body: TalonTrackingStrip(trackingNumber: 'DON-3TSTR9VH')),
  ));
}

void main() {
  testWidgets('affiche le numéro de suivi', (tester) async {
    await _pump(tester);
    expect(find.text('DON-3TSTR9VH'), findsOneWidget);
  });

  testWidgets('le bouton Copier place le numéro dans le presse-papier',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await _pump(tester);
    await tester.tap(find.byKey(const Key('talon-copy-button')));
    await tester.pump();
    expect(copied, 'DON-3TSTR9VH');
  });
}
```

- [ ] **Step 2 : Lancer le test — il échoue**

Run: `flutter test test/features/matching/presentation/widgets/billet/talon_tracking_strip_test.dart`
Expected: FAIL — fichier widget absent.

- [ ] **Step 3 : Implémenter le widget**

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Bande « n° de suivi » en pied de talon : code-barres décoratif,
/// numéro, et actions Copier / Partager.
class TalonTrackingStrip extends StatelessWidget {
  final String trackingNumber;
  const TalonTrackingStrip({super.key, required this.trackingNumber});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.only(top: DonySpacing.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: Row(
        children: [
          // Code-barres décoratif (CustomPaint simple ou Container hachuré)
          const _BarcodeGlyph(),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('N° DE SUIVI',
                    style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant, letterSpacing: 0.6)),
                Text(trackingNumber,
                    style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ],
            ),
          ),
          IconButton(
            key: const Key('talon-copy-button'),
            icon: Icon(Icons.copy_rounded, color: cs.primary, size: 20),
            tooltip: 'Copier',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: trackingNumber));
              DonySnackbar.show(context,
                  message: 'Numéro copié', type: DonySnackbarType.success);
            },
          ),
          IconButton(
            key: const Key('talon-share-button'),
            icon: Icon(Icons.ios_share_rounded, color: cs.primary, size: 20),
            tooltip: 'Partager',
            onPressed: () => Share.share(
                'Suivez mon colis dony #$trackingNumber'),
          ),
        ],
      ),
    );
  }
}

class _BarcodeGlyph extends StatelessWidget {
  const _BarcodeGlyph();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        border: Border.all(color: cs.outline),
      ),
      child: CustomPaint(painter: _BarcodePainter(cs.onSurface)),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final Color color;
  _BarcodePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const widths = [2.0, 1.0, 3.0, 1.0, 2.0, 1.0, 1.0, 3.0, 2.0, 1.0];
    double x = 4;
    for (final w in widths) {
      canvas.drawRect(Rect.fromLTWH(x, 6, w, size.height - 12), p);
      x += w + 2;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.color != color;
}
```

Visuel : voir `maquettes/.../expediteur/1-confirme.png` (bande en bas du talon).

- [ ] **Step 4 : Lancer le test — il passe**

Run: `flutter test test/features/matching/presentation/widgets/billet/talon_tracking_strip_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5 : `flutter analyze` puis commit**

```bash
flutter analyze lib/features/matching/presentation/widgets/billet/talon_tracking_strip.dart
git add lib/features/matching/presentation/widgets/billet/talon_tracking_strip.dart test/features/matching/presentation/widgets/billet/talon_tracking_strip_test.dart
git commit -m "feat(billet): bande n° de suivi avec copier/partager"
```

---

## Task 3 : `TalonRetraitCodeView` — code de retrait (extraction)

Extraire l'actuel `_ConfirmationCodeCard` (`bid_detail_screen.dart:2463-2751`, classe `StatefulWidget` + son `State`) dans un fichier dédié, **en préservant TOUTE la logique** : régénération (max 5 / 24 h via `_maxRefreshes`/`_window`), compte à rebours (`_initCountdown`, `_formatRemaining`, `Timer`), copie, états `TrackingRefreshCodeLoading`/`TrackingConfirmCodeLoaded`/`TrackingRefreshCodeError`. Restyler le bloc en 4 cases de chiffres (cf. `maquettes/.../expediteur/2-en-route.png`).

**Files:**
- Create: `lib/features/matching/presentation/widgets/billet/talon_retrait_code_view.dart`
- Modify: `lib/features/matching/presentation/screens/bid_detail_screen.dart` — supprimer la classe `_ConfirmationCodeCard` et `_ConfirmationCodeCardState` (lignes 2463-2751), importer le nouveau fichier, remplacer l'usage `_ConfirmationCodeCard(...)` par `TalonRetraitCodeView(...)`.
- Test: `test/features/matching/presentation/widgets/billet/talon_retrait_code_view_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_retrait_code_view.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}
class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

Future<void> _pump(WidgetTester tester, _MockTrackingBloc t, _MockBidBloc b) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<TrackingBloc>.value(value: t),
          BlocProvider<BidBloc>.value(value: b),
        ],
        child: const TalonRetraitCodeView(
          bidId: 'bid-1', initialCode: '4729', refreshCount: 0),
      ),
    ),
  ));
}

void main() {
  testWidgets('affiche le code de retrait initial', (tester) async {
    final t = _MockTrackingBloc();
    final b = _MockBidBloc();
    when(() => t.state).thenReturn(TrackingInitial());
    when(() => b.state).thenReturn(BidInitial());
    await _pump(tester, t, b);
    expect(find.text('4729'), findsOneWidget);
    expect(find.text('Copier le code'), findsOneWidget);
    expect(find.textContaining('Régénérer'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer le test — il échoue**

Run: `flutter test test/features/matching/presentation/widgets/billet/talon_retrait_code_view_test.dart`
Expected: FAIL — fichier widget absent.

- [ ] **Step 3 : Créer le fichier**

Copier intégralement `_ConfirmationCodeCard` + `_ConfirmationCodeCardState` depuis `bid_detail_screen.dart:2463-2751` dans le nouveau fichier. Renommer la classe publique en `TalonRetraitCodeView` (et `_TalonRetraitCodeViewState`). Conserver `bidId`, `initialCode`, `refreshCount`, `refreshWindowStart`, et toute la logique de `Timer`/countdown/régénération. Ajouter les imports nécessaires (`design_system.dart`, `tracking_bloc/event/state`, `bid_bloc/event`, `error_presenter`, `dart:async`, `flutter/services`). Restyler l'affichage du code en 4 cases sombres (une par chiffre) au lieu du grand texte unique — voir maquette `expediteur/2-en-route.png`. Le libellé de section devient « Code de retrait ». Conserver les boutons « Copier le code » et « Régénérer » et le bloc d'avertissement / rate-limit.

- [ ] **Step 4 : Brancher dans l'écran**

Dans `bid_detail_screen.dart` : supprimer les lignes 2463-2751 (`_ConfirmationCodeCard`/`_ConfirmationCodeCardState`), ajouter `import '../widgets/billet/talon_retrait_code_view.dart';`, et remplacer `_ConfirmationCodeCard(` par `TalonRetraitCodeView(` à son site d'usage (~ligne 402).

- [ ] **Step 5 : Lancer les tests**

Run: `flutter test test/features/matching/presentation/widgets/billet/talon_retrait_code_view_test.dart test/features/matching/presentation/screens/bid_detail_screen_cash_test.dart`
Expected: PASS (les deux fichiers).

- [ ] **Step 6 : `flutter analyze` puis commit**

```bash
flutter analyze lib/features/matching/
git add lib/features/matching/presentation/widgets/billet/talon_retrait_code_view.dart lib/features/matching/presentation/screens/bid_detail_screen.dart test/features/matching/presentation/widgets/billet/talon_retrait_code_view_test.dart
git commit -m "refactor(billet): extraction du code de retrait dans TalonRetraitCodeView"
```

---

## Task 4 : `TalonTravelerActionView` — actions voyageur (scan / livraison)

Nouveau widget : selon le mode, affiche un bouton **« Scanner le colis »** ou **« Confirmer la livraison »**. Les deux naviguent vers le scanner existant via `context.push('/tracking/scan', extra: {...})`. Le `QrScannerScreen` gère déjà le scan QR (DEPART) et la confirmation de livraison (`ConfirmDeliveryRequested`).

**Files:**
- Create: `lib/features/matching/presentation/widgets/billet/talon_traveler_action_view.dart`
- Test: `test/features/matching/presentation/widgets/billet/talon_traveler_action_view_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

```dart
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_traveler_action_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> _pump(WidgetTester tester, TalonTravelerAction action) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => Scaffold(
      body: TalonTravelerActionView(bidId: 'bid-1', action: action))),
    GoRoute(path: '/tracking/scan',
      builder: (_, __) => const Scaffold(body: Text('SCANNER'))),
  ]);
  await tester.pumpWidget(MaterialApp.router(
      routerConfig: router, theme: AppTheme.light));
  return router;
}

void main() {
  testWidgets('mode scan → bouton "Scanner le colis"', (tester) async {
    await _pump(tester, TalonTravelerAction.scan);
    expect(find.text('Scanner le colis'), findsOneWidget);
  });

  testWidgets('mode confirmDelivery → bouton "Confirmer la livraison"',
      (tester) async {
    await _pump(tester, TalonTravelerAction.confirmDelivery);
    expect(find.text('Confirmer la livraison'), findsOneWidget);
  });

  testWidgets('tap → navigue vers /tracking/scan', (tester) async {
    await _pump(tester, TalonTravelerAction.scan);
    await tester.tap(find.text('Scanner le colis'));
    await tester.pumpAndSettle();
    expect(find.text('SCANNER'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer le test — il échoue**

Run: `flutter test test/features/matching/presentation/widgets/billet/talon_traveler_action_view_test.dart`
Expected: FAIL — fichier widget absent.

- [ ] **Step 3 : Implémenter le widget**

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum TalonTravelerAction { scan, confirmDelivery }

/// Talon voyageur actionnable : scan de prise en charge / confirmation
/// de livraison. Navigue vers le scanner QR existant (`/tracking/scan`).
class TalonTravelerActionView extends StatelessWidget {
  final String bidId;
  final TalonTravelerAction action;
  const TalonTravelerActionView({
    super.key,
    required this.bidId,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (String label, String hint, IconData icon, Color color) =
        switch (action) {
      TalonTravelerAction.scan => (
        'Scanner le colis',
        'À la remise, scannez le QR de l\'expéditeur.',
        Icons.qr_code_scanner_rounded,
        cs.primary,
      ),
      TalonTravelerAction.confirmDelivery => (
        'Confirmer la livraison',
        'À l\'arrivée, saisissez le code de retrait de l\'expéditeur.',
        Icons.verified_rounded,
        cs.success,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(hint,
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          label: label,
          icon: icon,
          onPressed: () => context.push(
            '/tracking/scan',
            extra: {'bidId': bidId, 'mode': action.name},
          ),
        ),
      ],
    );
  }
}
```

> **Note d'intégration :** vérifier que `QrScannerScreen` (route `/tracking/scan`, `lib/app/router.dart:198`) lit le `extra` `{bidId, mode}`. Si la route n'accepte pas de paramètre aujourd'hui, ajouter la lecture de `state.extra` dans le `builder` de la route et la transmettre à `QrScannerScreen` (paramètre optionnel). Ne pas changer la logique de scan elle-même.

- [ ] **Step 4 : Lancer le test — il passe**

Run: `flutter test test/features/matching/presentation/widgets/billet/talon_traveler_action_view_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5 : `flutter analyze` puis commit**

```bash
flutter analyze lib/features/matching/presentation/widgets/billet/talon_traveler_action_view.dart
git add lib/features/matching/presentation/widgets/billet/talon_traveler_action_view.dart test/features/matching/presentation/widgets/billet/talon_traveler_action_view_test.dart
git commit -m "feat(billet): talon voyageur actionnable — scan et confirmation livraison"
```

---

## Task 5 : `BilletPerforation` + `BilletTalon` — l'aiguillage du talon

`BilletPerforation` : séparateur perforé réutilisable (ligne pointillée + deux encoches latérales). `BilletTalon` : aiguille, selon `(bid.status, isSender)`, vers le bon contenu, et ajoute `TalonTrackingStrip` quand `bid.trackingNumber != null`.

**Files:**
- Create: `lib/features/matching/presentation/widgets/billet_perforation.dart`
- Create: `lib/features/matching/presentation/widgets/billet/billet_talon.dart`
- Test: `test/features/matching/presentation/widgets/billet/billet_talon_test.dart`

Logique d'aiguillage (zone d'action) :

| `(isSender, status)` | Contenu |
|----------------------|---------|
| sender, `PENDING` | placeholder « En attente de confirmation du voyageur » |
| sender, `ACCEPTED` | `QrCodeCard(bidId)` |
| sender, `HANDED_OVER`/`IN_TRANSIT` (+ `confirmationCode != null`) | `TalonRetraitCodeView(...)` |
| sender, `COMPLETED`/`DELIVERED` | bloc « terminé » (coche + date) |
| traveler, `PENDING` | résumé décision (poids · valeur · catégorie) |
| traveler, `ACCEPTED` | `TalonTravelerActionView(action: scan)` |
| traveler, `HANDED_OVER`/`IN_TRANSIT` | `TalonTravelerActionView(action: confirmDelivery)` |
| traveler, `COMPLETED`/`DELIVERED` | bloc « terminé » |
| toute, `REJECTED`/`CANCELLED` | bloc neutre (statut terminal, pas d'action) |

`TalonTrackingStrip(bid.trackingNumber!)` est ajouté sous la zone d'action dès que `bid.trackingNumber != null`.

- [ ] **Step 1 : Écrire le test qui échoue**

```dart
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_traveler_action_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({required String status, String? trackingNumber}) => BidModel(
      id: 'bid-1', announcementId: 'a-1', senderId: 's-1', weightKg: 5,
      status: status, createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1), trackingNumber: trackingNumber,
    );

Future<void> _pump(WidgetTester tester, BidModel bid, bool isSender) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: BilletTalon(bid: bid, isSender: isSender)),
  ));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('voyageur + ACCEPTED → action de scan', (tester) async {
    await _pump(tester, _bid(status: 'ACCEPTED', trackingNumber: 'DON-1'),
        false);
    expect(find.byType(TalonTravelerActionView), findsOneWidget);
    expect(find.text('Scanner le colis'), findsOneWidget);
  });

  testWidgets('sender + PENDING → placeholder, pas de bande de suivi',
      (tester) async {
    await _pump(tester, _bid(status: 'PENDING'), true);
    expect(find.textContaining('En attente de confirmation'), findsOneWidget);
    expect(find.text('N° DE SUIVI'), findsNothing);
  });

  testWidgets('trackingNumber présent → bande de suivi affichée',
      (tester) async {
    await _pump(tester, _bid(status: 'ACCEPTED', trackingNumber: 'DON-1'),
        false);
    expect(find.text('N° DE SUIVI'), findsOneWidget);
    expect(find.text('DON-1'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer le test — il échoue**

Run: `flutter test test/features/matching/presentation/widgets/billet/billet_talon_test.dart`
Expected: FAIL — fichiers absents.

- [ ] **Step 3 : Implémenter `BilletPerforation`**

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Ligne de perforation d'un billet : pointillés + deux encoches latérales.
/// [notchColor] doit être la couleur du fond derrière le billet.
class BilletPerforation extends StatelessWidget {
  final Color notchColor;
  const BilletPerforation({super.key, required this.notchColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // pointillés
          Row(children: List.generate(40, (i) => Expanded(
            child: Container(
              height: 1.5,
              color: i.isEven ? cs.outline : Colors.transparent),
          ))),
          // encoches
          Align(alignment: Alignment.centerLeft,
            child: Transform.translate(offset: const Offset(-8, 0),
              child: _notch(notchColor))),
          Align(alignment: Alignment.centerRight,
            child: Transform.translate(offset: const Offset(8, 0),
              child: _notch(notchColor))),
        ],
      ),
    );
  }

  Widget _notch(Color c) => Container(
      width: 16, height: 16,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}
```

- [ ] **Step 4 : Implémenter `BilletTalon`**

Créer `BilletTalon` (StatelessWidget, params `BidModel bid`, `bool isSender`). Fond légèrement teinté (`DonyColors`/`cs.surfaceContainer` clair), coins bas arrondis. Construire la zone d'action via un `switch` sur `(isSender, bid.status)` selon le tableau ci-dessus :
- placeholder PENDING sender : icône `Icons.hourglass_empty_rounded` + texte centré.
- QR : `QrCodeCard(bidId: bid.id)` (import `features/tracking/presentation/widgets/qr_code_card.dart`).
- retrait code : `TalonRetraitCodeView(bidId: bid.id, initialCode: bid.confirmationCode!, refreshCount: bid.confirmationCodeRefreshCount, refreshWindowStart: bid.confirmationCodeRefreshWindowStart)`.
- traveler scan / confirmDelivery : `TalonTravelerActionView(bidId: bid.id, action: ...)`.
- résumé décision (traveler PENDING) : 3 mini-stats poids/valeur/catégorie.
- terminé : coche verte + « Colis livré ».
Puis, si `bid.trackingNumber != null`, ajouter sous la zone : `TalonTrackingStrip(trackingNumber: bid.trackingNumber!)`.

- [ ] **Step 5 : Lancer le test — il passe**

Run: `flutter test test/features/matching/presentation/widgets/billet/billet_talon_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6 : `flutter analyze` puis commit**

```bash
flutter analyze lib/features/matching/
git add lib/features/matching/presentation/widgets/billet_perforation.dart lib/features/matching/presentation/widgets/billet/billet_talon.dart test/features/matching/presentation/widgets/billet/billet_talon_test.dart
git commit -m "feat(billet): talon évolutif aiguillé par état et rôle"
```

---

## Task 6 : `ColisBillet` — la carte billet complète

Assemble l'en-tête (marque + `BilletStatusStamp`), le corridor (codes via `cityAirportCode()`, icône de transport), les dates, `BilletPerforation` et `BilletTalon`.

**Files:**
- Create: `lib/features/matching/presentation/widgets/billet/colis_billet.dart`
- Test: `test/features/matching/presentation/widgets/billet/colis_billet_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

```dart
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_status_stamp.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid() => BidModel(
      id: 'bid-1', announcementId: 'a-1', senderId: 's-1', weightKg: 5,
      status: 'ACCEPTED', createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1), trackingNumber: 'DON-3TSTR9VH',
      departureCity: 'Paris', arrivalCity: 'Abidjan',
    );

void main() {
  testWidgets('le billet montre le tampon de statut et le talon',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ColisBillet(bid: _bid(), isSender: true)),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BilletStatusStamp), findsOneWidget);
    expect(find.byType(BilletTalon), findsOneWidget);
    expect(find.text('Confirmé'), findsOneWidget);
    expect(find.textContaining('Paris'), findsWidgets);
  });
}
```

- [ ] **Step 2 : Lancer le test — il échoue**

Run: `flutter test test/features/matching/presentation/widgets/billet/colis_billet_test.dart`
Expected: FAIL — fichier absent.

- [ ] **Step 3 : Implémenter `ColisBillet`**

`StatelessWidget`, params `BidModel bid`, `bool isSender`. Structure (`Container` blanc, `DonyRadius.card`, ombre douce) :
1. **En-tête** : `Row` — texte « DONY · TRANSPORT DE COLIS » (`tt.labelSmall`, `cs.primary`) à gauche, `BilletStatusStamp(status: bid.status)` à droite.
2. **Corridor** : `Row` — code départ + ville, icône de transport centrée sur ligne pointillée, code arrivée + ville. Codes via `cityAirportCode(bid.departureCity ?? 'Paris', departure: true)` et `cityAirportCode(bid.arrivalCity ?? 'Dakar', departure: false)` (import `core/constants/city_airport_codes.dart`). Icône : `Icons.flight_rounded` par défaut.
3. **Dates** : `Row` — « Départ » + date/heure (`bid.departureDate`, `bid.departureTime`), « Arrivée » + heure (`bid.arrivalTime`). Format via `DateFormat('d MMM', 'fr')`.
4. `BilletPerforation(notchColor: Theme.of(context).scaffoldBackgroundColor)`.
5. `BilletTalon(bid: bid, isSender: isSender)`.

Détails visuels (espacements, tailles) : voir maquettes `expediteur/1-confirme.png` et `voyageur/1-en-attente.png`. Animation d'entrée : `.animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic)`.

- [ ] **Step 4 : Lancer le test — il passe**

Run: `flutter test test/features/matching/presentation/widgets/billet/colis_billet_test.dart`
Expected: PASS.

- [ ] **Step 5 : `flutter analyze` puis commit**

```bash
flutter analyze lib/features/matching/presentation/widgets/billet/colis_billet.dart
git add lib/features/matching/presentation/widgets/billet/colis_billet.dart test/features/matching/presentation/widgets/billet/colis_billet_test.dart
git commit -m "feat(billet): carte billet de colis complète"
```

---

## Task 7 : Intégrer `ColisBillet` dans l'écran

Remplacer, dans le `Column` du corps de `bid_detail_screen.dart` (`_buildContent`, ~lignes 307-345), le bloc statut + `RouteMapCard` + `_TravelerCard`/`_SenderCard` initial + `_TrackingNumberCard` + `QrCodeCard` + `_ConfirmationCodeCard` (zone talon) par un seul `ColisBillet(bid: _bid, isSender: isSender)`. Le QR, le code de retrait et le n° de suivi vivent désormais **dans le talon** — retirer leurs insertions séparées.

**Files:**
- Modify: `lib/features/matching/presentation/screens/bid_detail_screen.dart`
- Test: `test/features/matching/presentation/screens/bid_detail_screen_cash_test.dart` (existant — doit rester vert)

- [ ] **Step 1 : Modifier le `Column` du corps**

Dans `_BidDetailViewState.build` → `builder` → `Column(children: [...])` : retirer le `Row` du `_StatusBadge` (lignes ~311-319), le `RouteMapCard` (~323-328), l'insertion conditionnelle de `_TrackingNumberCard` (~342-345), de `QrCodeCard` (~380-385) et de `_ConfirmationCodeCard`/`TalonRetraitCodeView` (~397-409). Les remplacer en tête de `Column` par :

```dart
ColisBillet(bid: _bid, isSender: isSender),
const SizedBox(height: DonySpacing.base),
```

Ajouter `import '../widgets/billet/colis_billet.dart';`. Conserver `_CashBadge` : l'afficher dans le billet ou juste sous lui (au choix, garder visible si `paymentMethod == cash`).

- [ ] **Step 2 : Lancer le filet de sécurité**

Run: `flutter test test/features/matching/presentation/screens/bid_detail_screen_cash_test.dart`
Expected: PASS — adapter les `find.text('CASH')` si le badge a bougé, mais ne pas dégrader la couverture.

- [ ] **Step 3 : Ajouter un test d'intégration du billet**

Dans `bid_detail_screen_cash_test.dart`, ajouter un groupe :

```dart
group('Billet de colis', () {
  testWidgets('ACCEPTED → ColisBillet affiché', (tester) async {
    final authBloc = _MockAuthBloc();
    when(() => authBloc.state)
        .thenReturn(AuthAuthenticated(_user(_kSenderId)));
    when(() => authBloc.stream).thenAnswer((_) => Stream<AuthState>.empty());
    await _pump(tester, bid: _makeBid(status: 'ACCEPTED'), authBloc: authBloc);
    expect(find.byType(ColisBillet), findsOneWidget);
  });
});
```

(ajouter l'import de `ColisBillet`).

- [ ] **Step 4 : Lancer tous les tests de l'écran**

Run: `flutter test test/features/matching/presentation/`
Expected: PASS.

- [ ] **Step 5 : Vérification manuelle**

`flutter run --dart-define-from-file=env.dev.json` — ouvrir un colis dans chaque état (PENDING, ACCEPTED, HANDED_OVER, IN_TRANSIT, COMPLETED) côté expéditeur ET voyageur. Vérifier que le billet s'affiche, que le talon montre le bon contenu, que Copier fonctionne.

- [ ] **Step 6 : `flutter analyze` puis commit**

```bash
flutter analyze lib/features/matching/
git add lib/features/matching/presentation/screens/bid_detail_screen.dart test/features/matching/presentation/screens/bid_detail_screen_cash_test.dart
git commit -m "feat(billet): intégration du billet de colis dans l'écran de détail"
```

---

## Task 8 : `SuiviButton` + suppression de la section « ÉTAPES » statique

Restyler `_TimelineButton` (`bid_detail_screen.dart:2191-2248`) en `SuiviButton` dans un fichier dédié, étendre sa condition d'affichage à `COMPLETED`/`DELIVERED`, et **supprimer** `_StepsSection`/`_StepData`/`_StepItem` (`bid_detail_screen.dart:841-990`) qui affichent des données statiques codées en dur.

**Files:**
- Create: `lib/features/matching/presentation/widgets/suivi_button.dart`
- Modify: `lib/features/matching/presentation/screens/bid_detail_screen.dart`
- Test: `test/features/matching/presentation/widgets/suivi_button_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

```dart
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/suivi_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid() => BidModel(
      id: 'bid-1', announcementId: 'a-1', senderId: 's-1', weightKg: 5,
      status: 'COMPLETED', createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      departureCity: 'Paris', arrivalCity: 'Abidjan');

void main() {
  testWidgets('affiche le libellé Suivi du colis', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SuiviButton(bid: _bid())),
    ));
    expect(find.text('Suivi du colis'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer le test — il échoue**

Run: `flutter test test/features/matching/presentation/widgets/suivi_button_test.dart`
Expected: FAIL — fichier absent.

- [ ] **Step 3 : Créer `SuiviButton`**

Copier la structure de `_TimelineButton` (`bid_detail_screen.dart:2191-2248`) dans `suivi_button.dart`, classe publique `SuiviButton`. Conserver `onTap: () => showTrackingTimelineSheet(context, bidId: bid.id, corridor: _corridor)`. Restyler (icône, libellé « Suivi du colis », sous-titre « Voir le détail et les photos », chevron). Imports : `design_system.dart`, `tracking_timeline_bottom_sheet.dart`, `bid_model.dart`.

- [ ] **Step 4 : Brancher dans l'écran + supprimer le statique**

Dans `bid_detail_screen.dart` :
- Supprimer `_StepsSection`, `_StepData`, `_StepItem` (lignes 841-990).
- Supprimer le bloc d'insertion de `_StepsSection` dans le `Column` (~lignes 412-416).
- Remplacer l'usage de `_TimelineButton` par `SuiviButton`, et **étendre sa condition** d'affichage à `COMPLETED`/`DELIVERED` (en plus de `ACCEPTED`/`HANDED_OVER`/`IN_TRANSIT`).
- Ajouter `import '../widgets/suivi_button.dart';`.

- [ ] **Step 5 : Lancer les tests**

Run: `flutter test test/features/matching/presentation/`
Expected: PASS.

- [ ] **Step 6 : `flutter analyze` puis commit**

```bash
flutter analyze lib/features/matching/
git add lib/features/matching/presentation/widgets/suivi_button.dart lib/features/matching/presentation/screens/bid_detail_screen.dart test/features/matching/presentation/widgets/suivi_button_test.dart
git commit -m "feat(billet): bouton Suivi du colis + suppression de la timeline statique"
```

---

## Task 9 : Cartes profil — `VoyageurCard` & `ExpediteurCard`

Extraire `_TravelerCard` (`bid_detail_screen.dart:633-772`) → `voyageur_card.dart` et `_SenderCard` (`bid_detail_screen.dart:1067-1168`) → `expediteur_card.dart`, en préservant le comportement (ouverture des fiches profil via `showTravelerProfileSheet` / `showSenderProfileSheet`, badges KYC/Kilo Pro). Restyler en cohérence avec le billet (titres de section homogènes).

**Files:**
- Create: `lib/features/matching/presentation/widgets/voyageur_card.dart`
- Create: `lib/features/matching/presentation/widgets/expediteur_card.dart`
- Modify: `lib/features/matching/presentation/screens/bid_detail_screen.dart`
- Test: `test/features/matching/presentation/widgets/profil_cards_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

```dart
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/voyageur_card.dart';
import 'package:dony/features/matching/presentation/widgets/expediteur_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid() => BidModel(
      id: 'b-1', announcementId: 'a-1', senderId: 's-1', weightKg: 5,
      status: 'ACCEPTED', createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      travelerName: 'Abou D.', senderName: 'Mariam K.');

void main() {
  testWidgets('VoyageurCard montre le nom du voyageur', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
      home: Scaffold(body: VoyageurCard(bid: _bid()))));
    expect(find.text('Abou D.'), findsOneWidget);
  });

  testWidgets('ExpediteurCard montre le nom de l\'expéditeur', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
      home: Scaffold(body: ExpediteurCard(bid: _bid()))));
    expect(find.textContaining('Mariam K.'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer le test — il échoue**

Run: `flutter test test/features/matching/presentation/widgets/profil_cards_test.dart`
Expected: FAIL — fichiers absents.

- [ ] **Step 3 : Extraire les widgets**

Déplacer `_TravelerCard` → `VoyageurCard` dans `voyageur_card.dart` (avec ses dépendances privées `_MiniChip`, `_IconActionButton` si elles ne servent qu'à elle — sinon les laisser et importer). Idem `_SenderCard` → `ExpediteurCard`. Préserver `onTap`/`showXProfileSheet`. Ajouter les imports nécessaires.

- [ ] **Step 4 : Brancher dans l'écran**

Remplacer les usages de `_TravelerCard`/`_SenderCard` par `VoyageurCard`/`ExpediteurCard`, supprimer les classes de `bid_detail_screen.dart`, ajouter les imports.

- [ ] **Step 5 : Lancer les tests**

Run: `flutter test test/features/matching/presentation/`
Expected: PASS.

- [ ] **Step 6 : `flutter analyze` puis commit**

```bash
flutter analyze lib/features/matching/
git add lib/features/matching/presentation/widgets/voyageur_card.dart lib/features/matching/presentation/widgets/expediteur_card.dart lib/features/matching/presentation/screens/bid_detail_screen.dart test/features/matching/presentation/widgets/profil_cards_test.dart
git commit -m "refactor(billet): extraction des cartes profil voyageur/expéditeur"
```

---

## Task 10 : `ColisCard` & `DestinataireCard`

Extraire `_PackageCard` (`bid_detail_screen.dart:1170-1195`) → `colis_card.dart` et `_RecipientCard` (`bid_detail_screen.dart:1197-1214`) → `destinataire_card.dart`. La carte destinataire reste **dédiée** (Nom + Téléphone) — ne pas la fusionner. Restyler en cohérence.

**Files:**
- Create: `lib/features/matching/presentation/widgets/colis_card.dart`
- Create: `lib/features/matching/presentation/widgets/destinataire_card.dart`
- Modify: `lib/features/matching/presentation/screens/bid_detail_screen.dart`
- Test: `test/features/matching/presentation/widgets/colis_destinataire_cards_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

```dart
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/colis_card.dart';
import 'package:dony/features/matching/presentation/widgets/destinataire_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid() => BidModel(
      id: 'b-1', announcementId: 'a-1', senderId: 's-1', weightKg: 5,
      status: 'ACCEPTED', createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      recipientName: 'Awa N.', recipientPhone: '+225070000000');

void main() {
  testWidgets('ColisCard montre le poids', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
      home: Scaffold(body: ColisCard(bid: _bid()))));
    expect(find.textContaining('5'), findsWidgets);
  });

  testWidgets('DestinataireCard montre nom et téléphone', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
      home: Scaffold(body: DestinataireCard(bid: _bid()))));
    expect(find.text('Awa N.'), findsOneWidget);
    expect(find.text('+225070000000'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer le test — il échoue**

Run: `flutter test test/features/matching/presentation/widgets/colis_destinataire_cards_test.dart`
Expected: FAIL — fichiers absents.

- [ ] **Step 3 : Extraire les widgets**

Déplacer `_PackageCard` → `ColisCard`, `_RecipientCard` → `DestinataireCard`. Elles dépendent de `_Card` et `_InfoRow` (`bid_detail_screen.dart:1333-1400`) : extraire aussi `_Card` et `_InfoRow` dans un fichier partagé `lib/features/matching/presentation/widgets/detail_card.dart` (classes publiques `DetailCard`, `InfoRow`) et les utiliser. Mettre à jour tous les usages restants de `_Card`/`_InfoRow` dans l'écran.

- [ ] **Step 4 : Brancher dans l'écran**

Remplacer les usages, supprimer les classes déplacées, ajouter les imports.

- [ ] **Step 5 : Lancer les tests**

Run: `flutter test test/features/matching/presentation/`
Expected: PASS.

- [ ] **Step 6 : `flutter analyze` puis commit**

```bash
flutter analyze lib/features/matching/
git add lib/features/matching/presentation/widgets/colis_card.dart lib/features/matching/presentation/widgets/destinataire_card.dart lib/features/matching/presentation/widgets/detail_card.dart lib/features/matching/presentation/screens/bid_detail_screen.dart test/features/matching/presentation/widgets/colis_destinataire_cards_test.dart
git commit -m "refactor(billet): extraction des cartes colis et destinataire"
```

---

## Task 11 : `TrajetCard`, `HandoverCard`, `DisclaimerCard`, `PaymentReleaseCard`

Extraire les cartes secondaires restantes dans des fichiers dédiés, en préservant le comportement : `_TripDetailsCard` (`:1282-1331`) → `trajet_card.dart`, `_HandoverCard` (`:1244-1280`) → `handover_card.dart`, `_DisclaimerCard` (`:1216-1242`) → `disclaimer_card.dart`, `_PaymentReleaseCard` (`:994-1065`) → `payment_release_card.dart`. Toutes utilisent `DetailCard`/`InfoRow` (Task 10).

**Files:**
- Create: `trajet_card.dart`, `handover_card.dart`, `disclaimer_card.dart`, `payment_release_card.dart` (sous `widgets/`)
- Modify: `bid_detail_screen.dart`
- Test: `test/features/matching/presentation/widgets/cartes_secondaires_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

```dart
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trajet_card.dart';
import 'package:dony/features/matching/presentation/widgets/disclaimer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid() => BidModel(
      id: 'b-1', announcementId: 'a-1', senderId: 's-1', weightKg: 5,
      status: 'ACCEPTED', createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1), departureDate: DateTime(2026, 5, 11));

void main() {
  testWidgets('TrajetCard a un titre', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
      home: Scaffold(body: TrajetCard(bid: _bid()))));
    expect(find.text('Détails du trajet'), findsOneWidget);
  });

  testWidgets('DisclaimerCard a un titre', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
      home: Scaffold(body: DisclaimerCard(bid: _bid()))));
    expect(find.text('Responsabilité légale'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer le test — il échoue**

Run: `flutter test test/features/matching/presentation/widgets/cartes_secondaires_test.dart`
Expected: FAIL — fichiers absents.

- [ ] **Step 3 : Extraire les 4 widgets**

Déplacer chaque classe dans son fichier (classes publiques `TrajetCard`, `HandoverCard`, `DisclaimerCard`, `PaymentReleaseCard`), en préservant la logique. Ajouter les imports (`detail_card.dart`, `design_system.dart`, `intl`).

- [ ] **Step 4 : Brancher dans l'écran**

Remplacer les usages, supprimer les classes de `bid_detail_screen.dart`, ajouter les imports.

- [ ] **Step 5 : Lancer les tests**

Run: `flutter test test/features/matching/presentation/`
Expected: PASS.

- [ ] **Step 6 : `flutter analyze` puis commit**

```bash
flutter analyze lib/features/matching/
git add lib/features/matching/presentation/widgets/trajet_card.dart lib/features/matching/presentation/widgets/handover_card.dart lib/features/matching/presentation/widgets/disclaimer_card.dart lib/features/matching/presentation/widgets/payment_release_card.dart lib/features/matching/presentation/screens/bid_detail_screen.dart test/features/matching/presentation/widgets/cartes_secondaires_test.dart
git commit -m "refactor(billet): extraction des cartes trajet, remise, disclaimer, paiement"
```

---

## Task 12 : Extraction des barres d'action

Extraire les 4 barres d'action — `_ActionBar` (`:1402-1572`), `_ConfirmPresenceBar` (`:1574-1603`), `_SenderActionBar` (`:1677-…`), `_TravelerRejectedBar` (`:2044-…`) — et leurs dépendances privées exclusives (`_EscrowBadge`, `_SenderOptionsSheet`, `_OptionTile`) dans `widgets/action_bars/bid_detail_action_bars.dart`. Classes publiques : `TravelerPendingBar`, `ConfirmPresenceBar`, `SenderActionBar`, `TravelerRejectedBar`. Préserver tout le comportement (dialogues de refus, paiement, options).

**Files:**
- Create: `lib/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart`
- Modify: `lib/features/matching/presentation/screens/bid_detail_screen.dart`
- Test: `test/features/matching/presentation/screens/bid_detail_screen_cash_test.dart` (existant)

- [ ] **Step 1 : Extraire le fichier**

Déplacer les classes listées dans le nouveau fichier (renommées en public), ajouter les imports. Mettre à jour `bid_detail_screen.dart` : importer le fichier, remplacer les usages dans la sélection du `bottomNavigationBar`, supprimer les classes déplacées.

- [ ] **Step 2 : Lancer le filet de sécurité**

Run: `flutter test test/features/matching/presentation/screens/bid_detail_screen_cash_test.dart`
Expected: PASS — les barres se comportent à l'identique.

- [ ] **Step 3 : Ajouter un test de barre voyageur PENDING**

```dart
group('Barre d\'action voyageur', () {
  testWidgets('voyageur + PENDING → Accepter / Refuser', (tester) async {
    final authBloc = _MockAuthBloc();
    when(() => authBloc.state)
        .thenReturn(AuthAuthenticated(_user(_kTravelerId)));
    when(() => authBloc.stream).thenAnswer((_) => Stream<AuthState>.empty());
    await _pump(tester, bid: _makeBid(status: 'PENDING'), authBloc: authBloc);
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
  });
});
```

- [ ] **Step 4 : Lancer les tests**

Run: `flutter test test/features/matching/presentation/`
Expected: PASS.

- [ ] **Step 5 : `flutter analyze` puis commit**

```bash
flutter analyze lib/features/matching/
git add lib/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart lib/features/matching/presentation/screens/bid_detail_screen.dart test/features/matching/presentation/screens/bid_detail_screen_cash_test.dart
git commit -m "refactor(billet): extraction des barres d'action de l'écran de détail"
```

---

## Task 13 : Nettoyage final + couverture

Supprimer le code mort restant, vérifier l'écran sur tous les états × rôles, garantir la couverture ≥ 90 %.

**Files:**
- Modify: `lib/features/matching/presentation/screens/bid_detail_screen.dart`
- Test: tous les tests du dossier `matching`

- [ ] **Step 1 : Chasser le code mort**

Dans `bid_detail_screen.dart`, supprimer toute classe privée devenue inutilisée (`_StatusBadge` si plus référencé, anciens `_Card`/`_InfoRow` si tout est passé à `DetailCard`/`InfoRow`, imports orphelins). Vérifier : `flutter analyze` ne signale aucun import/élément inutilisé.

- [ ] **Step 2 : Vérifier la taille du fichier**

`wc -l lib/features/matching/presentation/screens/bid_detail_screen.dart` — l'écran ne doit plus contenir que le scaffold + `_BidDetailView` (orchestration, listeners, polling). Cible : < 600 lignes.

- [ ] **Step 3 : Lancer toute la suite avec couverture**

Run: `flutter test --coverage`
Expected: tous les tests PASS.

- [ ] **Step 4 : Vérifier la couverture**

Run: `genhtml coverage/lcov.info -o coverage/html` puis ouvrir `coverage/html/index.html`.
Expected: couverture globale ≥ 90 %. Si un nouveau widget est sous 90 %, ajouter les tests manquants (états non couverts du `BilletTalon`, branches du `TalonRetraitCodeView`).

- [ ] **Step 5 : Vérification manuelle complète**

`flutter run --dart-define-from-file=env.dev.json` — parcourir les 7 états × 2 rôles. Comparer aux maquettes. Vérifier : copie du n° de suivi, copie du code de retrait, régénération + compte à rebours, bouton Suivi → bottom sheet avec photos, navigation talon voyageur → scanner.

- [ ] **Step 6 : `flutter analyze` puis commit final**

```bash
flutter analyze
git add -A lib/features/matching/ test/features/matching/
git commit -m "refactor(billet): nettoyage final de l'écran de détail du colis"
```

---

## Self-review (rempli par l'auteur du plan)

**Couverture de la spec :**
- §4 Anatomie du billet → Tasks 1, 5, 6 ✓
- §5 Talon évolutif (expéditeur) → Tasks 2, 3, 5 ✓ ; (voyageur) → Tasks 4, 5 ✓
- §6 Matrice états × rôles → l'aiguillage du talon (Task 5) + barres d'action (Task 12) ✓
- §7 Suivi + suppression section statique → Task 8 ✓
- §8 Cartes du corps + carte destinataire dédiée → Tasks 9, 10, 11 ✓
- §9 Adaptation mode de transport → Task 6, Step 3 (icône `flight_rounded` par défaut ; l'adaptation route/mer/mixte est notée hors périmètre dans la spec §13 si `BidModel` ne porte pas l'info — à confirmer en Task 6) ✓
- §10 Découpage technique → toutes les tasks d'extraction + Task 13 ✓
- §11 Points d'attention → filet de sécurité (règle transverse), `/tracking/scan` param (Task 4 note), polling conservé (Task 7 préserve `_BidDetailView`) ✓
- §12 Tests ≥ 90 % → Task 13 ✓

**Placeholders :** aucun « TBD/TODO ». Les extractions pointent des plages de lignes exactes ; les widgets neufs ont leur code.

**Cohérence des types :** `BilletStatusStamp(status:)`, `TalonTrackingStrip(trackingNumber:)`, `TalonRetraitCodeView(bidId:, initialCode:, refreshCount:, refreshWindowStart:)`, `TalonTravelerActionView(bidId:, action:)`, `BilletTalon(bid:, isSender:)`, `ColisBillet(bid:, isSender:)`, `SuiviButton(bid:)` — signatures cohérentes entre tâches de création et d'usage.

**Point ouvert à lever en implémentation :** Task 4 — confirmer la lecture du `extra` `{bidId, mode}` par la route `/tracking/scan` ; si absente, l'ajouter sans toucher la logique de scan.
