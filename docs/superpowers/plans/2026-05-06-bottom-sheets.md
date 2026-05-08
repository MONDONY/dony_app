# Bottom Sheets — Remplacement d'écrans Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir 12 écrans secondaires en bottom sheets pour réduire la pile de navigation et améliorer le flux utilisateur.

**Architecture:** Chaque conversion crée un widget `*BottomSheet` dans `features/<feature>/presentation/widgets/`, expose une méthode statique `show()`, et est appelé depuis l'écran parent. La route GoRouter correspondante est supprimée après conversion.

**Tech Stack:** Flutter BLoC, `showModalBottomSheet`, `DonyBottomSheet` (existant dans `lib/core/design/widgets/`), `flutter_test`

---

## Fichiers créés / modifiés

| Action | Fichier |
|--------|---------|
| Modify | `lib/core/design/widgets/dony_bottom_sheet.dart` |
| Create | `lib/features/ratings/presentation/widgets/rating_bottom_sheet.dart` |
| Create | `lib/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart` |
| Create | `lib/features/payments/presentation/widgets/escrow_explainer_bottom_sheet.dart` |
| Create | `lib/features/auth/presentation/widgets/role_selection_bottom_sheet.dart` |
| Create | `lib/features/tracking/presentation/screens/tracking_hub_screen.dart` |
| Create | `lib/features/tracking/presentation/widgets/offline_queue_bottom_sheet.dart` |
| Create | `lib/features/tracking/presentation/widgets/tracking_search_bottom_sheet.dart` |
| Create | `lib/features/matching/presentation/widgets/handover_bottom_sheet.dart` |
| Create | `lib/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart` |
| Create | `lib/features/connect_onboarding/presentation/widgets/connect_pending_bottom_sheet.dart` |
| Create | `lib/features/settings/presentation/widgets/delete_account_bottom_sheet.dart` |
| Create | `lib/features/profile/presentation/widgets/upgrade_pro_bottom_sheet.dart` |
| Create | `lib/features/cancellation/presentation/widgets/rematch_bottom_sheet.dart` |
| Modify | `lib/app/router.dart` |
| Modify | `lib/features/matching/presentation/screens/bid_detail_screen.dart` |
| Modify | `lib/features/matching/presentation/screens/announcement_detail_screen.dart` |
| Modify | `lib/features/payments/presentation/screens/payment_screen.dart` |
| Modify | `lib/features/auth/presentation/screens/otp_verification_screen.dart` |
| Modify | `lib/features/profile/presentation/profile_screen.dart` |
| Modify | `lib/features/connect_onboarding/presentation/screens/connect_onboarding_intro_screen.dart` |
| Modify | `lib/features/settings/presentation/settings_screen.dart` |
| Modify | `lib/features/cancellation/presentation/screens/cancellation_screen.dart` |
| Create | `test/features/ratings/presentation/widgets/rating_bottom_sheet_test.dart` |
| Create | `test/features/cancellation/presentation/widgets/cancellation_bottom_sheet_test.dart` |
| Create | `test/features/payments/presentation/widgets/escrow_explainer_bottom_sheet_test.dart` |
| Create | `test/features/tracking/presentation/widgets/offline_queue_bottom_sheet_test.dart` |
| Create | `test/features/tracking/presentation/widgets/tracking_search_bottom_sheet_test.dart` |
| Create | `test/features/matching/presentation/widgets/handover_bottom_sheet_test.dart` |
| Create | `test/features/settings/presentation/widgets/delete_account_bottom_sheet_test.dart` |

---

## Task 1 — Mettre à jour DonyBottomSheet (cap 90 % + isDanger)

**Files:**
- Modify: `lib/core/design/widgets/dony_bottom_sheet.dart`

Le `margin: EdgeInsets.only(top: DonySpacing.huge)` actuel (48 px) laisse ~94 % de hauteur libre sur un iPhone 14. On le remplace par un calcul dynamique pour garantir le plafond à 90 %.

- [ ] **Step 1 — Modifier `DonyBottomSheet.show()` pour accepter `isDanger`**

Remplacer le contenu de `lib/core/design/widgets/dony_bottom_sheet.dart` par :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

abstract final class DonyBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    String? subtitle,
    bool isDismissible = true,
    bool showHandle = true,
    bool isScrollControlled = true,
    bool isDanger = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DonyBottomSheetContent(
        title: title,
        subtitle: subtitle,
        showHandle: showHandle,
        isDanger: isDanger,
        child: child,
      ),
    );
  }
}

class _DonyBottomSheetContent extends StatelessWidget {
  const _DonyBottomSheetContent({
    required this.child,
    this.title,
    this.subtitle,
    this.showHandle = true,
    this.isDanger = false,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showHandle;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom + mq.viewPadding.bottom;
    // Garantit que la BS ne dépasse jamais 90 % de la hauteur d'écran
    final topMargin = mq.size.height * 0.1;

    final bgColor = isDanger ? cs.errorContainer : cs.surface;
    final handleColor = isDanger
        ? cs.error.withValues(alpha: 0.35)
        : DonyColors.neutral300;

    return Container(
      margin: EdgeInsets.only(top: topMargin),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
        boxShadow: DonyShadow.sheet,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHandle)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: DonySpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
              ),
            ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg, DonySpacing.base, DonySpacing.base, 0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: tt.headlineSmall?.copyWith(
                            color: isDanger ? cs.error : null,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: DonySpacing.xs),
                          Text(
                            subtitle!,
                            style: tt.bodySmall?.copyWith(
                              color: DonyColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    style: IconButton.styleFrom(
                      foregroundColor: DonyColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: DonySpacing.base),
          ] else
            const SizedBox(height: DonySpacing.sm),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                title != null ? 0 : DonySpacing.sm,
                DonySpacing.lg,
                DonySpacing.xl + bottomInset,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2 — Vérifier la compilation**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter analyze lib/core/design/widgets/dony_bottom_sheet.dart
```
Attendu : aucune erreur.

- [ ] **Step 3 — Commit**

```bash
git add lib/core/design/widgets/dony_bottom_sheet.dart
git commit -m "feat(design): enforce 90% height cap + isDanger on DonyBottomSheet"
```

---

## Task 2 — Rating Bottom Sheet

**Files:**
- Create: `lib/features/ratings/presentation/widgets/rating_bottom_sheet.dart`
- Modify: `lib/features/matching/presentation/screens/bid_detail_screen.dart`
- Create: `test/features/ratings/presentation/widgets/rating_bottom_sheet_test.dart`
- Modify (cleanup): `lib/app/router.dart` — supprimer la route `/ratings/:bidId`

- [ ] **Step 1 — Écrire le test en échec**

Créer `test/features/ratings/presentation/widgets/rating_bottom_sheet_test.dart` :

```dart
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRatingBloc extends Mock implements RatingBloc {}

Widget _wrap(Widget child, RatingBloc bloc) => MaterialApp(
      home: BlocProvider<RatingBloc>.value(value: bloc, child: child),
    );

void main() {
  late RatingBloc bloc;

  setUp(() {
    bloc = _MockRatingBloc();
    when(() => bloc.state).thenReturn(const RatingInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('affiche le sélecteur d\'étoiles et le champ commentaire', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) => TextButton(
        onPressed: () => RatingBottomSheet.show(ctx, bidId: 'bid-1', travelerName: 'Amadou'),
        child: const Text('Ouvrir'),
      )),
      bloc,
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Évaluer Amadou'), findsOneWidget);
    expect(find.byIcon(Icons.star_outline_rounded), findsWidgets);
    expect(find.text('Commentaire (facultatif)'), findsOneWidget);
  });

  testWidgets('le bouton Envoyer est désactivé si 0 étoile', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) => TextButton(
        onPressed: () => RatingBottomSheet.show(ctx, bidId: 'bid-1', travelerName: 'Amadou'),
        child: const Text('Ouvrir'),
      )),
      bloc,
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    final btn = tester.widget<ElevatedButton>(
      find.ancestor(of: find.text('Envoyer l\'évaluation'), matching: find.byType(ElevatedButton)),
    );
    expect(btn.onPressed, isNull);
  });
}
```

- [ ] **Step 2 — Lancer le test pour vérifier l'échec**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/ratings/presentation/widgets/rating_bottom_sheet_test.dart
```
Attendu : FAIL — `RatingBottomSheet` non trouvé.

- [ ] **Step 3 — Créer `rating_bottom_sheet.dart`**

Créer `lib/features/ratings/presentation/widgets/rating_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RatingBottomSheet extends StatefulWidget {
  const RatingBottomSheet({
    super.key,
    required this.bidId,
    required this.travelerName,
  });

  final String bidId;
  final String travelerName;

  static Future<void> show(
    BuildContext context, {
    required String bidId,
    required String travelerName,
  }) {
    return DonyBottomSheet.show(
      context,
      title: 'Évaluer $travelerName',
      subtitle: 'Votre avis aide la communauté dony',
      child: BlocProvider(
        create: (ctx) => ctx.read<RatingBloc>(),
        child: RatingBottomSheet(bidId: bidId, travelerName: travelerName),
      ),
    );
  }

  @override
  State<RatingBottomSheet> createState() => _RatingBottomSheetState();
}

class _RatingBottomSheetState extends State<RatingBottomSheet> {
  int _stars = 0;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_stars == 0) return;
    context.read<RatingBloc>().add(RatingSubmitRequested(
      bidId: widget.bidId,
      stars: _stars,
      comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return BlocConsumer<RatingBloc, RatingState>(
      listener: (context, state) {
        if (state is RatingSuccess) {
          Navigator.of(context).pop();
          DonySnackbar.show(context, message: 'Merci pour votre évaluation !', type: DonySnackbarType.success);
        } else if (state is RatingError) {
          DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
        }
      },
      builder: (context, state) {
        final isLoading = state is RatingLoading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StarSelector(
              selected: _stars,
              onSelect: (s) => setState(() => _stars = s),
            ),
            if (_stars > 0)
              Center(
                child: Text(
                  _starLabel(_stars),
                  style: tt.labelLarge?.copyWith(
                    color: DonyColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms),
            const SizedBox(height: DonySpacing.base),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              maxLength: 200,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Commentaire (facultatif)',
                hintText: 'Partagez votre expérience…',
                filled: true,
                fillColor: DonyColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  borderSide: const BorderSide(color: DonyColors.neutral200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  borderSide: const BorderSide(color: DonyColors.neutral200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  borderSide: const BorderSide(color: DonyColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.base),
            DonyButton(
              label: 'Envoyer l\'évaluation',
              icon: Icons.star_rounded,
              isLoading: isLoading,
              onPressed: (_stars > 0 && !isLoading) ? () => _submit(context) : null,
            ),
          ],
        );
      },
    );
  }

  String _starLabel(int s) => switch (s) {
    1 => 'Très décevant',
    2 => 'Décevant',
    3 => 'Correct',
    4 => 'Bien',
    5 => 'Excellent !',
    _ => '',
  };
}

class _StarSelector extends StatelessWidget {
  const _StarSelector({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final idx = i + 1;
            final filled = idx <= selected;
            return GestureDetector(
              onTap: () => onSelect(idx),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    key: ValueKey(filled),
                    size: 44,
                    color: filled ? const Color(0xFFF59E0B) : DonyColors.neutral200,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4 — Lancer le test pour vérifier qu'il passe**

```bash
flutter test test/features/ratings/presentation/widgets/rating_bottom_sheet_test.dart
```
Attendu : PASS.

- [ ] **Step 5 — Mettre à jour `BidDetailScreen` pour appeler la BS**

Dans `lib/features/matching/presentation/screens/bid_detail_screen.dart`, trouver l'endroit qui navigue vers `/ratings/:bidId` (chercher `context.push('/ratings'`) et remplacer par :

```dart
// Avant :
// context.push('/ratings/${bid.id}', extra: {'travelerName': bid.travelerName});

// Après :
RatingBottomSheet.show(
  context,
  bidId: bid.id,
  travelerName: bid.travelerName,
);
```

Ajouter l'import en haut du fichier :
```dart
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
```

S'assurer que `BidDetailScreen` a un `BlocProvider<RatingBloc>` disponible dans son arbre. Si ce n'est pas le cas, wrapper le call site dans un `BlocProvider` :

```dart
BlocProvider(
  create: (_) => getIt<RatingBloc>(),
  child: BidDetailScreen(bid: bid, fromPayment: fromPayment),
)
```

(dans `router.dart`, route `/bids/:bidId`)

- [ ] **Step 6 — Supprimer la route `/ratings/:bidId` dans `router.dart`**

Dans `lib/app/router.dart`, supprimer le bloc GoRoute correspondant à `/ratings/:bidId`. Chercher `path: '/ratings/:bidId'` et retirer l'entrée complète ainsi que son import `rating_screen.dart` en haut du fichier si plus utilisé ailleurs.

- [ ] **Step 7 — Vérifier que tout compile**

```bash
flutter analyze
```
Attendu : 0 erreurs.

- [ ] **Step 8 — Commit**

```bash
git add lib/features/ratings/presentation/widgets/rating_bottom_sheet.dart \
        test/features/ratings/presentation/widgets/rating_bottom_sheet_test.dart \
        lib/features/matching/presentation/screens/bid_detail_screen.dart \
        lib/app/router.dart
git commit -m "feat(ratings): convert RatingScreen to bottom sheet"
```

---

## Task 3 — Cancellation Bottom Sheet

**Files:**
- Create: `lib/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart`
- Modify: `lib/features/matching/presentation/screens/announcement_detail_screen.dart`
- Create: `test/features/cancellation/presentation/widgets/cancellation_bottom_sheet_test.dart`
- Modify: `lib/app/router.dart` — supprimer `/announcements/:id/cancel`

- [ ] **Step 1 — Écrire le test en échec**

Créer `test/features/cancellation/presentation/widgets/cancellation_bottom_sheet_test.dart` :

```dart
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCancellationBloc extends Mock implements CancellationBloc {}

Widget _wrap(Widget child, CancellationBloc bloc) => MaterialApp(
      home: BlocProvider<CancellationBloc>.value(value: bloc, child: child),
    );

void main() {
  late CancellationBloc bloc;

  setUp(() {
    bloc = _MockCancellationBloc();
    when(() => bloc.state).thenReturn(const CancellationInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('affiche les 5 options de raison', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) => TextButton(
        onPressed: () => CancellationBottomSheet.show(ctx, announcementId: 'ann-1'),
        child: const Text('Ouvrir'),
      )),
      bloc,
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Vol annulé'), findsOneWidget);
    expect(find.text('Urgence personnelle'), findsOneWidget);
    expect(find.text('Autre'), findsOneWidget);
  });

  testWidgets('le bouton Confirmer est présent', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) => TextButton(
        onPressed: () => CancellationBottomSheet.show(ctx, announcementId: 'ann-1'),
        child: const Text('Ouvrir'),
      )),
      bloc,
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmer l\'annulation'), findsOneWidget);
  });
}
```

- [ ] **Step 2 — Lancer le test pour vérifier l'échec**

```bash
flutter test test/features/cancellation/presentation/widgets/cancellation_bottom_sheet_test.dart
```
Attendu : FAIL.

- [ ] **Step 3 — Créer `cancellation_bottom_sheet.dart`**

Créer `lib/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

const _reasons = [
  'Vol annulé',
  'Urgence personnelle',
  'Problème de santé',
  'Changement d\'itinéraire',
  'Autre',
];

class CancellationBottomSheet extends StatefulWidget {
  const CancellationBottomSheet({super.key, required this.announcementId});

  final String announcementId;

  static Future<void> show(BuildContext context, {required String announcementId}) {
    return DonyBottomSheet.show(
      context,
      isDanger: true,
      title: 'Annuler ce trajet ?',
      subtitle: 'Cette action est irréversible',
      child: BlocProvider.value(
        value: context.read<CancellationBloc>(),
        child: CancellationBottomSheet(announcementId: announcementId),
      ),
    );
  }

  @override
  State<CancellationBottomSheet> createState() => _CancellationBottomSheetState();
}

class _CancellationBottomSheetState extends State<CancellationBottomSheet> {
  String? _selectedReason;
  final _otherCtrl = TextEditingController();

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  String? get _finalReason {
    if (_selectedReason == null) return null;
    if (_selectedReason == 'Autre' && _otherCtrl.text.trim().isNotEmpty) {
      return _otherCtrl.text.trim();
    }
    return _selectedReason;
  }

  void _confirm(BuildContext context) {
    final reason = _finalReason;
    if (reason == null) {
      DonySnackbar.show(context, message: 'Veuillez sélectionner une raison', type: DonySnackbarType.error);
      return;
    }
    final bloc = context.read<CancellationBloc>();
    Navigator.of(context).pop(); // ferme la BS avant le dialog
    DonyDialog.show(
      context,
      title: 'Confirmer l\'annulation',
      message: 'Cette action annulera votre trajet et remboursera automatiquement tous les expéditeurs concernés.',
      variant: DonyDialogVariant.destructive,
      icon: Icons.warning_amber_rounded,
    ).then((confirmed) {
      if (confirmed == true) {
        bloc.add(CancellationTripRequested(
          announcementId: widget.announcementId,
          reason: reason,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocListener<CancellationBloc, CancellationState>(
      listener: (context, state) {
        if (state is CancellationSuccess) {
          final n = state.cancellation.affectedBidsCount;
          DonySnackbar.show(
            context,
            message: n > 0
                ? 'Trajet annulé · $n expéditeur${n > 1 ? 's' : ''} remboursé${n > 1 ? 's' : ''}'
                : 'Trajet annulé',
            type: DonySnackbarType.success,
          );
          context.go('/announcements');
        } else if (state is CancellationError) {
          DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(color: cs.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: cs.error, size: 18),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    'Tous les expéditeurs liés seront remboursés automatiquement.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.base),
          Text('Raison', style: tt.titleSmall),
          const SizedBox(height: DonySpacing.sm),
          DonyRadioGroup<String>(
            value: _selectedReason,
            onChanged: (v) => setState(() => _selectedReason = v),
            options: _reasons.map((r) => DonyRadioOption(value: r, label: r)).toList(),
          ),
          if (_selectedReason == 'Autre') ...[
            const SizedBox(height: DonySpacing.md),
            DonyTextField(controller: _otherCtrl, label: 'Précisez...', hint: 'Décrivez votre raison'),
          ],
          const SizedBox(height: DonySpacing.xl),
          BlocBuilder<CancellationBloc, CancellationState>(
            builder: (context, state) => DonyButton(
              label: 'Confirmer l\'annulation',
              variant: DonyButtonVariant.destructive,
              isLoading: state is CancellationLoading,
              onPressed: state is CancellationLoading ? null : () => _confirm(context),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4 — Mettre à jour `AnnouncementDetailScreen`**

Dans `lib/features/matching/presentation/screens/announcement_detail_screen.dart`, trouver la navigation vers `/announcements/:id/cancel` et remplacer par :

```dart
// Avant :
// context.push('/announcements/${announcement.id}/cancel');

// Après :
CancellationBottomSheet.show(context, announcementId: announcement.id);
```

Ajouter l'import :
```dart
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
```

- [ ] **Step 5 — Supprimer la route dans `router.dart`**

Supprimer la route GoRoute `path: 'cancel'` imbriquée sous `/announcements/:id`.

- [ ] **Step 6 — Lancer les tests**

```bash
flutter test test/features/cancellation/presentation/widgets/cancellation_bottom_sheet_test.dart
flutter analyze
```
Attendu : PASS, 0 erreurs.

- [ ] **Step 7 — Commit**

```bash
git add lib/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart \
        test/features/cancellation/presentation/widgets/cancellation_bottom_sheet_test.dart \
        lib/features/matching/presentation/screens/announcement_detail_screen.dart \
        lib/app/router.dart
git commit -m "feat(cancellation): convert CancellationScreen to bottom sheet"
```

---

## Task 4 — Escrow Explainer Bottom Sheet

**Files:**
- Create: `lib/features/payments/presentation/widgets/escrow_explainer_bottom_sheet.dart`
- Modify: `lib/features/payments/presentation/screens/payment_screen.dart`
- Create: `test/features/payments/presentation/widgets/escrow_explainer_bottom_sheet_test.dart`
- Modify: `lib/app/router.dart` — supprimer `/payments/escrow`

- [ ] **Step 1 — Écrire le test en échec**

Créer `test/features/payments/presentation/widgets/escrow_explainer_bottom_sheet_test.dart` :

```dart
import 'package:dony/features/payments/presentation/widgets/escrow_explainer_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche le montant et le nom du voyageur', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => TextButton(
        onPressed: () => EscrowExplainerBottomSheet.show(
          ctx,
          amount: 150.0,
          travelerName: 'Amadou Diallo',
        ),
        child: const Text('Ouvrir'),
      )),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('150,00 €'), findsOneWidget);
    expect(find.text('Amadou Diallo'), findsOneWidget);
    expect(find.text('J\'ai compris'), findsOneWidget);
  });
}
```

- [ ] **Step 2 — Lancer le test pour vérifier l'échec**

```bash
flutter test test/features/payments/presentation/widgets/escrow_explainer_bottom_sheet_test.dart
```
Attendu : FAIL.

- [ ] **Step 3 — Créer `escrow_explainer_bottom_sheet.dart`**

Créer `lib/features/payments/presentation/widgets/escrow_explainer_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EscrowExplainerBottomSheet extends StatelessWidget {
  const EscrowExplainerBottomSheet({
    super.key,
    required this.amount,
    required this.travelerName,
  });

  final double amount;
  final String travelerName;

  static Future<void> show(
    BuildContext context, {
    required double amount,
    required String travelerName,
  }) {
    return DonyBottomSheet.show(
      context,
      title: '🔒 Paiement sécurisé',
      subtitle: travelerName,
      child: EscrowExplainerBottomSheet(amount: amount, travelerName: travelerName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          fmt.format(amount),
          style: tt.displaySmall?.copyWith(
            color: DonyColors.primary,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          'Retenu jusqu\'à la livraison',
          style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.xl),
        _InfoTile(
          icon: Icons.lock_rounded,
          text: 'Votre paiement est bloqué en séquestre jusqu\'à confirmation de livraison par le destinataire.',
          cs: cs,
          tt: tt,
        ),
        const SizedBox(height: DonySpacing.sm),
        _InfoTile(
          icon: Icons.schedule_rounded,
          text: 'Libération automatique 48h après la date de livraison prévue si aucune confirmation.',
          cs: cs,
          tt: tt,
        ),
        const SizedBox(height: DonySpacing.sm),
        _InfoTile(
          icon: Icons.shield_rounded,
          text: 'En cas de litige, dony intervient pour arbitrer et protéger les deux parties.',
          cs: cs,
          tt: tt,
        ),
        const SizedBox(height: DonySpacing.xl),
        DonyButton(
          label: 'J\'ai compris',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.text, required this.cs, required this.tt});

  final IconData icon;
  final String text;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: DonyColors.primary),
          const SizedBox(width: DonySpacing.sm),
          Expanded(child: Text(text, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4 — Mettre à jour `PaymentScreen`**

Dans `lib/features/payments/presentation/screens/payment_screen.dart`, trouver la navigation vers `/payments/escrow` et remplacer :

```dart
// Avant :
// context.push('/payments/escrow', extra: {'amount': amount, 'travelerName': name, 'bidId': bid.id});

// Après :
EscrowExplainerBottomSheet.show(context, amount: amount, travelerName: name);
```

Ajouter l'import :
```dart
import 'package:dony/features/payments/presentation/widgets/escrow_explainer_bottom_sheet.dart';
```

- [ ] **Step 5 — Supprimer la route `/payments/escrow` dans `router.dart`**

Supprimer le GoRoute `path: '/payments/escrow'` et son import `escrow_explainer_screen.dart` si plus utilisé.

- [ ] **Step 6 — Lancer les tests**

```bash
flutter test test/features/payments/presentation/widgets/escrow_explainer_bottom_sheet_test.dart
flutter analyze
```
Attendu : PASS, 0 erreurs.

- [ ] **Step 7 — Commit**

```bash
git add lib/features/payments/presentation/widgets/escrow_explainer_bottom_sheet.dart \
        test/features/payments/presentation/widgets/escrow_explainer_bottom_sheet_test.dart \
        lib/features/payments/presentation/screens/payment_screen.dart \
        lib/app/router.dart
git commit -m "feat(payments): convert EscrowExplainerScreen to bottom sheet"
```

---

## Task 5 — Role Selection Bottom Sheet

**Files:**
- Create: `lib/features/auth/presentation/widgets/role_selection_bottom_sheet.dart`
- Modify: `lib/features/auth/presentation/screens/otp_verification_screen.dart` (ou là où `RoleSelectionScreen` est actuellement instancié)

> Note : `RoleSelectionScreen` n'a pas de route GoRouter — il est instancié directement. Chercher `RoleSelectionScreen()` dans le codebase pour trouver le call site exact.

- [ ] **Step 1 — Localiser le call site**

```bash
grep -rn "RoleSelectionScreen" /home/a-diakite/Desktop/MyProject/my_app/dony_app/lib/ --include="*.dart"
```

- [ ] **Step 2 — Créer `role_selection_bottom_sheet.dart`**

Créer `lib/features/auth/presentation/widgets/role_selection_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RoleSelectionBottomSheet extends StatefulWidget {
  const RoleSelectionBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return DonyBottomSheet.show(
      context,
      isDismissible: false,
      title: 'Comment utiliser dony ?',
      subtitle: 'Vous pouvez cumuler les deux rôles',
      child: BlocProvider.value(
        value: context.read<AuthBloc>(),
        child: const RoleSelectionBottomSheet(),
      ),
    );
  }

  @override
  State<RoleSelectionBottomSheet> createState() => _RoleSelectionBottomSheetState();
}

class _RoleSelectionBottomSheetState extends State<RoleSelectionBottomSheet> {
  bool _isSender = false;
  bool _isTraveler = false;

  bool get _canContinue => _isSender || _isTraveler;

  void _submit(BuildContext context) {
    if (!_canContinue) return;
    context.read<AuthBloc>().add(AuthRoleSelected(
      isSender: _isSender,
      isTraveler: _isTraveler,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthRoleSetupComplete) {
          Navigator.of(context).pop();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RoleCard(
            icon: Icons.inventory_2_rounded,
            title: 'Expéditeur',
            subtitle: 'J\'envoie des colis vers l\'Afrique',
            selected: _isSender,
            cs: cs,
            tt: tt,
            onTap: () => setState(() => _isSender = !_isSender),
          ),
          const SizedBox(height: DonySpacing.sm),
          _RoleCard(
            icon: Icons.flight_rounded,
            title: 'Voyageur',
            subtitle: 'Je transporte des colis lors de mes voyages',
            selected: _isTraveler,
            cs: cs,
            tt: tt,
            onTap: () => setState(() => _isTraveler = !_isTraveler),
          ),
          const SizedBox(height: DonySpacing.xl),
          DonyButton(
            label: 'Continuer',
            onPressed: _canContinue ? () => _submit(context) : null,
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.cs,
    required this.tt,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant, size: 22),
            const SizedBox(width: DonySpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tt.titleSmall?.copyWith(color: selected ? cs.primary : cs.onSurface)),
                  Text(subtitle, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3 — Remplacer l'appel à `RoleSelectionScreen` dans le call site trouvé à l'étape 1**

Remplacer l'instanciation/navigation vers `RoleSelectionScreen` par :

```dart
RoleSelectionBottomSheet.show(context);
```

Ajouter l'import :
```dart
import 'package:dony/features/auth/presentation/widgets/role_selection_bottom_sheet.dart';
```

- [ ] **Step 4 — Vérifier la compilation**

```bash
flutter analyze
```
Attendu : 0 erreurs.

- [ ] **Step 5 — Commit**

```bash
git add lib/features/auth/presentation/widgets/role_selection_bottom_sheet.dart
git commit -m "feat(auth): convert RoleSelectionScreen to bottom sheet"
```

---

## Task 6 — Tracking Hub Screen + Offline Queue Bottom Sheet

**Files:**
- Create: `lib/features/tracking/presentation/screens/tracking_hub_screen.dart`
- Create: `lib/features/tracking/presentation/widgets/offline_queue_bottom_sheet.dart`
- Modify: `lib/app/router.dart` — remplacer `_TrackingHubScreen` inline + supprimer `/tracking/offline-queue`
- Create: `test/features/tracking/presentation/widgets/offline_queue_bottom_sheet_test.dart`

- [ ] **Step 1 — Écrire le test en échec**

Créer `test/features/tracking/presentation/widgets/offline_queue_bottom_sheet_test.dart` :

```dart
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/presentation/widgets/offline_queue_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrackingBloc extends Mock implements TrackingBloc {}

void main() {
  late TrackingBloc bloc;

  setUp(() {
    bloc = _MockTrackingBloc();
    when(() => bloc.state).thenReturn(const TrackingInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('affiche la liste des scans en attente', (tester) async {
    final items = [
      OfflineScanItem(donNumber: 'DON-4821', eventType: 'Prise en charge', timestamp: DateTime.now()),
      OfflineScanItem(donNumber: 'DON-4819', eventType: 'En transit', timestamp: DateTime.now()),
    ];

    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<TrackingBloc>.value(
        value: bloc,
        child: Builder(builder: (ctx) => TextButton(
          onPressed: () => OfflineQueueBottomSheet.show(ctx, items: items),
          child: const Text('Ouvrir'),
        )),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('DON-4821'), findsOneWidget);
    expect(find.text('DON-4819'), findsOneWidget);
    expect(find.text('Synchroniser'), findsOneWidget);
  });
}
```

- [ ] **Step 2 — Lancer le test pour vérifier l'échec**

```bash
flutter test test/features/tracking/presentation/widgets/offline_queue_bottom_sheet_test.dart
```
Attendu : FAIL.

- [ ] **Step 3 — Créer `offline_queue_bottom_sheet.dart`**

Créer `lib/features/tracking/presentation/widgets/offline_queue_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeago/timeago.dart' as timeago;

class OfflineScanItem {
  const OfflineScanItem({
    required this.donNumber,
    required this.eventType,
    required this.timestamp,
  });
  final String donNumber;
  final String eventType;
  final DateTime timestamp;
}

class OfflineQueueBottomSheet extends StatelessWidget {
  const OfflineQueueBottomSheet({super.key, required this.items});

  final List<OfflineScanItem> items;

  static Future<void> show(BuildContext context, {required List<OfflineScanItem> items}) {
    return DonyBottomSheet.show(
      context,
      title: '${items.length} scan${items.length > 1 ? 's' : ''} hors-ligne',
      subtitle: 'En attente de synchronisation',
      child: BlocProvider.value(
        value: context.read<TrackingBloc>(),
        child: OfflineQueueBottomSheet(items: items),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.sm),
          child: DonyListTile(
            leading: _eventIcon(item.eventType, cs),
            title: item.donNumber,
            subtitle: timeago.format(item.timestamp, locale: 'fr'),
          ),
        )),
        const SizedBox(height: DonySpacing.base),
        DonyButton(
          label: 'Synchroniser',
          icon: Icons.sync_rounded,
          onPressed: () {
            context.read<TrackingBloc>().add(const TrackingOfflineSyncRequested());
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _eventIcon(String eventType, ColorScheme cs) {
    final (icon, bg) = switch (eventType) {
      'Prise en charge' => (Icons.inventory_2_rounded, const Color(0xFFFEF9C3)),
      'En transit' => (Icons.local_shipping_rounded, const Color(0xFFEDE9FE)),
      'Livré' => (Icons.check_circle_rounded, const Color(0xFFDCFCE7)),
      _ => (Icons.qr_code_rounded, cs.surfaceContainerLow),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(DonyRadius.sm)),
      child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
    );
  }
}
```

- [ ] **Step 4 — Créer `tracking_hub_screen.dart`** (extrait de `router.dart`)

Créer `lib/features/tracking/presentation/screens/tracking_hub_screen.dart` en déplaçant la classe `_TrackingHubScreen` depuis `router.dart` (et la rendre publique `TrackingHubScreen`), en ajoutant la bannière offline et en convertissant le tap "Suivre un colis" en BS :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/tracking/presentation/widgets/offline_queue_bottom_sheet.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_search_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';

class TrackingHubScreen extends StatelessWidget {
  const TrackingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Suivi des colis',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0D1B2A)),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE9ECEF)),
        ),
      ),
      body: BlocBuilder<TrackingBloc, TrackingState>(
        buildWhen: (prev, curr) => curr is TrackingOfflineQueueLoaded,
        builder: (context, state) {
          final offlineItems = state is TrackingOfflineQueueLoaded ? state.items : <OfflineScanItem>[];

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Bannière hors-ligne ───────────────────────────────
                if (offlineItems.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => OfflineQueueBottomSheet.show(context, items: offlineItems),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.base,
                        vertical: DonySpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFB45309)),
                          const SizedBox(width: DonySpacing.sm),
                          Expanded(
                            child: Text(
                              '${offlineItems.length} scan${offlineItems.length > 1 ? 's' : ''} hors-ligne en attente',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFB45309)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xl),
                ],

                // ── Section voyageur ──────────────────────────────────
                const _HubSectionTitle(icon: Icons.qr_code_scanner_rounded, label: 'Je suis voyageur'),
                const SizedBox(height: 12),
                _HubCard(
                  icon: Icons.qr_code_scanner_rounded,
                  iconBg: const Color(0xFFE3F2FD),
                  iconColor: const Color(0xFF1E88E5),
                  title: 'Scanner le QR code d\'un colis',
                  subtitle: 'À la remise, en transit ou à la livraison',
                  onTap: () => context.push('/tracking/scan'),
                ),
                const SizedBox(height: 32),

                // ── Section expéditeur ────────────────────────────────
                const _HubSectionTitle(icon: Icons.search_rounded, label: 'Je suis expéditeur ou destinataire'),
                const SizedBox(height: 12),
                _HubCard(
                  icon: Icons.search_rounded,
                  iconBg: const Color(0xFFE8F5E9),
                  iconColor: const Color(0xFF16A34A),
                  title: 'Suivre un colis par numéro',
                  subtitle: 'Entrez votre numéro DON-XXXXXX',
                  // Ouvre la BS au lieu de naviguer vers /tracking/search
                  onTap: () => TrackingSearchBottomSheet.show(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Les widgets privés _HubSectionTitle et _HubCard sont copiés depuis router.dart
class _HubSectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HubSectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF6B7A8D)),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7A8D), letterSpacing: 0.8),
        ),
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _HubCard({required this.icon, required this.iconBg, required this.iconColor, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE9ECEF)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D1B2A))),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A8D))),
              ],
            )),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0BAC6), size: 20),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5 — Mettre à jour `router.dart`**

Dans `router.dart` :
1. Remplacer `builder: (context, state) => const _TrackingHubScreen()` par `builder: (context, state) => BlocProvider(create: (_) => getIt<TrackingBloc>()..add(const TrackingOfflineQueueLoaded()), child: const TrackingHubScreen())`
2. Supprimer les classes `_TrackingHubScreen`, `_HubSectionTitle`, `_HubCard` en bas du fichier
3. Supprimer la route GoRoute `path: '/tracking/offline-queue'`
4. Ajouter l'import : `import 'package:dony/features/tracking/presentation/screens/tracking_hub_screen.dart';`

- [ ] **Step 6 — Lancer les tests**

```bash
flutter test test/features/tracking/presentation/widgets/offline_queue_bottom_sheet_test.dart
flutter analyze
```
Attendu : PASS, 0 erreurs.

- [ ] **Step 7 — Commit**

```bash
git add lib/features/tracking/presentation/screens/tracking_hub_screen.dart \
        lib/features/tracking/presentation/widgets/offline_queue_bottom_sheet.dart \
        test/features/tracking/presentation/widgets/offline_queue_bottom_sheet_test.dart \
        lib/app/router.dart
git commit -m "feat(tracking): extract TrackingHubScreen + offline queue bottom sheet"
```

---

## Task 7 — Tracking Search Bottom Sheet

**Files:**
- Create: `lib/features/tracking/presentation/widgets/tracking_search_bottom_sheet.dart`
- Modify: `lib/app/router.dart` — supprimer `/tracking/search`
- Create: `test/features/tracking/presentation/widgets/tracking_search_bottom_sheet_test.dart`

- [ ] **Step 1 — Écrire le test en échec**

Créer `test/features/tracking/presentation/widgets/tracking_search_bottom_sheet_test.dart` :

```dart
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_search_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrackingBloc extends Mock implements TrackingBloc {}

void main() {
  late TrackingBloc bloc;

  setUp(() {
    bloc = _MockTrackingBloc();
    when(() => bloc.state).thenReturn(const TrackingInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('affiche le champ de recherche DON', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<TrackingBloc>.value(
        value: bloc,
        child: Builder(builder: (ctx) => TextButton(
          onPressed: () => TrackingSearchBottomSheet.show(ctx),
          child: const Text('Ouvrir'),
        )),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Numéro de suivi'), findsOneWidget);
    expect(find.text('Rechercher'), findsOneWidget);
  });
}
```

- [ ] **Step 2 — Lancer le test pour vérifier l'échec**

```bash
flutter test test/features/tracking/presentation/widgets/tracking_search_bottom_sheet_test.dart
```
Attendu : FAIL.

- [ ] **Step 3 — Créer `tracking_search_bottom_sheet.dart`**

Créer `lib/features/tracking/presentation/widgets/tracking_search_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TrackingSearchBottomSheet extends StatefulWidget {
  const TrackingSearchBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return DonyBottomSheet.show(
      context,
      title: 'Rechercher un colis',
      subtitle: 'Format : DON-XXXXXX',
      child: BlocProvider.value(
        value: context.read<TrackingBloc>(),
        child: const TrackingSearchBottomSheet(),
      ),
    );
  }

  @override
  State<TrackingSearchBottomSheet> createState() => _TrackingSearchBottomSheetState();
}

class _TrackingSearchBottomSheetState extends State<TrackingSearchBottomSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _search(BuildContext context) {
    final raw = _ctrl.text.trim().toUpperCase();
    if (raw.isEmpty) return;
    // Normalise : accepte "4821234" → "DON-4821234"
    final normalized = raw.startsWith('DON-') ? raw : 'DON-$raw';
    context.read<TrackingBloc>().add(TrackingSearchRequested(donNumber: normalized));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TrackingBloc, TrackingState>(
      listener: (context, state) {
        if (state is TrackingSearchSuccess) {
          Navigator.of(context).pop();
          // La navigation vers la timeline est gérée par le parent
        } else if (state is TrackingError) {
          DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
        }
      },
      child: BlocBuilder<TrackingBloc, TrackingState>(
        builder: (context, state) {
          final isLoading = state is TrackingLoading;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DonyTextField(
                controller: _ctrl,
                label: 'Numéro de suivi',
                hint: 'DON-481234',
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _search(context),
              ),
              const SizedBox(height: DonySpacing.base),
              DonyButton(
                label: 'Rechercher',
                icon: Icons.search_rounded,
                isLoading: isLoading,
                onPressed: isLoading ? null : () => _search(context),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4 — Supprimer la route `/tracking/search` dans `router.dart`**

Supprimer le GoRoute `path: '/tracking/search'` et son import `tracking_search_screen.dart` si plus utilisé ailleurs.

- [ ] **Step 5 — Lancer les tests**

```bash
flutter test test/features/tracking/presentation/widgets/tracking_search_bottom_sheet_test.dart
flutter analyze
```
Attendu : PASS, 0 erreurs.

- [ ] **Step 6 — Commit**

```bash
git add lib/features/tracking/presentation/widgets/tracking_search_bottom_sheet.dart \
        test/features/tracking/presentation/widgets/tracking_search_bottom_sheet_test.dart \
        lib/app/router.dart
git commit -m "feat(tracking): convert TrackingSearchScreen to bottom sheet"
```

---

## Task 8 — Handover Bottom Sheet

**Files:**
- Create: `lib/features/matching/presentation/widgets/handover_bottom_sheet.dart`
- Modify: `lib/features/matching/presentation/screens/bid_detail_screen.dart`
- Create: `test/features/matching/presentation/widgets/handover_bottom_sheet_test.dart`
- Modify: `lib/app/router.dart` — supprimer la route `handover` imbriquée sous `/bids/:bidId`

- [ ] **Step 1 — Écrire le test en échec**

Créer `test/features/matching/presentation/widgets/handover_bottom_sheet_test.dart` :

```dart
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/handover_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends Mock implements BidBloc {}

void main() {
  late BidBloc bloc;

  setUp(() {
    bloc = _MockBidBloc();
    when(() => bloc.state).thenReturn(const BidInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('affiche les champs adresse et heures', (tester) async {
    final bid = BidModel.skeleton('bid-1');
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<BidBloc>.value(
        value: bloc,
        child: Builder(builder: (ctx) => TextButton(
          onPressed: () => HandoverBottomSheet.show(ctx, bid: bid),
          child: const Text('Ouvrir'),
        )),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Adresse de remise'), findsOneWidget);
    expect(find.text('Heure de début'), findsOneWidget);
    expect(find.text('Heure de fin'), findsOneWidget);
    expect(find.text('Confirmer la remise'), findsOneWidget);
  });
}
```

- [ ] **Step 2 — Lancer le test pour vérifier l'échec**

```bash
flutter test test/features/matching/presentation/widgets/handover_bottom_sheet_test.dart
```
Attendu : FAIL.

- [ ] **Step 3 — Créer `handover_bottom_sheet.dart`**

Créer `lib/features/matching/presentation/widgets/handover_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HandoverBottomSheet extends StatefulWidget {
  const HandoverBottomSheet({super.key, required this.bid});

  final BidModel bid;

  static Future<void> show(BuildContext context, {required BidModel bid}) {
    return DonyBottomSheet.show(
      context,
      title: 'Lieu de remise',
      subtitle: '${bid.donNumber} · ${bid.weightKg} kg',
      child: BlocProvider.value(
        value: context.read<BidBloc>(),
        child: HandoverBottomSheet(bid: bid),
      ),
    );
  }

  @override
  State<HandoverBottomSheet> createState() => _HandoverBottomSheetState();
}

class _HandoverBottomSheetState extends State<HandoverBottomSheet> {
  final _addressCtrl = TextEditingController();
  TimeOfDay _start = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _end   = const TimeOfDay(hour: 16, minute: 0);

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(BuildContext context, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  void _submit(BuildContext context) {
    if (_addressCtrl.text.trim().isEmpty) {
      DonySnackbar.show(context, message: 'Veuillez saisir une adresse', type: DonySnackbarType.error);
      return;
    }
    context.read<BidBloc>().add(BidHandoverSubmitted(
      bidId: widget.bid.id,
      address: _addressCtrl.text.trim(),
      startTime: _start,
      endTime: _end,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return BlocConsumer<BidBloc, BidState>(
      listener: (context, state) {
        if (state is BidHandoverSuccess) {
          Navigator.of(context).pop();
          DonySnackbar.show(context, message: 'Point de remise enregistré', type: DonySnackbarType.success);
        } else if (state is BidError) {
          DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
        }
      },
      builder: (context, state) {
        final isLoading = state is BidLoading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyTextField(
              controller: _addressCtrl,
              label: 'Adresse de remise',
              hint: '12 rue de Rivoli, Paris',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: DonySpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: 'Heure de début',
                    time: _start,
                    tt: tt,
                    onTap: () => _pickTime(context, isStart: true),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: _TimeTile(
                    label: 'Heure de fin',
                    time: _end,
                    tt: tt,
                    onTap: () => _pickTime(context, isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: 'Confirmer la remise',
              isLoading: isLoading,
              onPressed: isLoading ? null : () => _submit(context),
            ),
          ],
        );
      },
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.label, required this.time, required this.tt, required this.onTap});
  final String label;
  final TimeOfDay time;
  final TextTheme tt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: DonyColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: tt.labelSmall?.copyWith(color: DonyColors.textMuted)),
            const SizedBox(height: DonySpacing.xs),
            Text(time.format(context), style: tt.titleSmall),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4 — Mettre à jour `BidDetailScreen`**

Dans `lib/features/matching/presentation/screens/bid_detail_screen.dart`, remplacer la navigation vers `/bids/:bidId/handover` :

```dart
// Avant :
// context.push('/bids/${bid.id}/handover', extra: bid);

// Après :
HandoverBottomSheet.show(context, bid: bid);
```

Ajouter l'import :
```dart
import 'package:dony/features/matching/presentation/widgets/handover_bottom_sheet.dart';
```

- [ ] **Step 5 — Supprimer la route `handover` dans `router.dart`**

Supprimer la GoRoute imbriquée `path: 'handover'` sous `/bids/:bidId`.

- [ ] **Step 6 — Lancer les tests**

```bash
flutter test test/features/matching/presentation/widgets/handover_bottom_sheet_test.dart
flutter analyze
```
Attendu : PASS, 0 erreurs.

- [ ] **Step 7 — Commit**

```bash
git add lib/features/matching/presentation/widgets/handover_bottom_sheet.dart \
        test/features/matching/presentation/widgets/handover_bottom_sheet_test.dart \
        lib/features/matching/presentation/screens/bid_detail_screen.dart \
        lib/app/router.dart
git commit -m "feat(matching): convert HandoverScreen to bottom sheet"
```

---

## Task 9 — KYC Onboarding Bottom Sheet

**Files:**
- Create: `lib/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Modify: `lib/app/router.dart` — supprimer `/kyc`

- [ ] **Step 1 — Créer `kyc_onboarding_bottom_sheet.dart`**

Créer `lib/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class KycOnboardingBottomSheet extends StatelessWidget {
  const KycOnboardingBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return DonyBottomSheet.show(
      context,
      child: BlocProvider.value(
        value: context.read<KycBloc>(),
        child: const KycOnboardingBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<KycBloc, KycState>(
      listener: (context, state) {
        if (state is KycSessionCreated) {
          Navigator.of(context).pop();
          // Le KycWebViewScreen est ouvert via GoRouter depuis l'écran parent
        } else if (state is KycError) {
          DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
        }
      },
      builder: (context, state) {
        final isLoading = state is KycLoading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.badge_rounded, size: 48, color: DonyColors.primary),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Vérifiez votre identité',
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Requis pour publier des annonces sur dony',
              style: tt.bodyMedium?.copyWith(color: DonyColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            _InfoRow(icon: Icons.verified_user_rounded, text: 'Processus Stripe Identity sécurisé', cs: cs, tt: tt),
            const SizedBox(height: DonySpacing.sm),
            _InfoRow(icon: Icons.photo_camera_rounded, text: 'Pièce d\'identité + selfie requis', cs: cs, tt: tt),
            const SizedBox(height: DonySpacing.sm),
            _InfoRow(icon: Icons.schedule_rounded, text: 'Vérification en 2 à 5 minutes', cs: cs, tt: tt),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: 'Démarrer la vérification',
              isLoading: isLoading,
              onPressed: isLoading ? null : () => context.read<KycBloc>().add(const KycSessionRequested()),
            ),
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              label: 'Plus tard',
              variant: DonyButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, required this.cs, required this.tt});
  final IconData icon;
  final String text;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: DonyColors.primary),
        const SizedBox(width: DonySpacing.sm),
        Expanded(child: Text(text, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
      ],
    );
  }
}
```

- [ ] **Step 2 — Mettre à jour `ProfileScreen`**

Dans `lib/features/profile/presentation/profile_screen.dart`, trouver la navigation vers `/kyc` et remplacer par :

```dart
// Avant :
// context.push('/kyc');

// Après :
KycOnboardingBottomSheet.show(context);
```

Ajouter l'import :
```dart
import 'package:dony/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart';
```

- [ ] **Step 3 — Supprimer la route `/kyc` dans `router.dart`**

Supprimer le GoRoute `path: '/kyc'` (garder `/kyc/verify` et `/kyc/status` qui restent plein écran).

- [ ] **Step 4 — Vérifier la compilation**

```bash
flutter analyze
```
Attendu : 0 erreurs.

- [ ] **Step 5 — Commit**

```bash
git add lib/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart \
        lib/features/profile/presentation/profile_screen.dart \
        lib/app/router.dart
git commit -m "feat(kyc): convert KycOnboardingScreen to bottom sheet"
```

---

## Task 10 — Connect Onboarding Pending Bottom Sheet

**Files:**
- Create: `lib/features/connect_onboarding/presentation/widgets/connect_pending_bottom_sheet.dart`
- Modify: `lib/features/connect_onboarding/presentation/screens/connect_onboarding_intro_screen.dart`
- Modify: `lib/app/router.dart` — supprimer `/connect/onboarding/pending`

- [ ] **Step 1 — Créer `connect_pending_bottom_sheet.dart`**

Créer `lib/features/connect_onboarding/presentation/widgets/connect_pending_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_event.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ConnectPendingBottomSheet extends StatelessWidget {
  const ConnectPendingBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return DonyBottomSheet.show(
      context,
      isDismissible: false,
      child: BlocProvider.value(
        value: context.read<ConnectOnboardingBloc>(),
        child: const ConnectPendingBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return BlocListener<ConnectOnboardingBloc, ConnectOnboardingState>(
      listener: (context, state) {
        if (state is ConnectOnboardingComplete) {
          Navigator.of(context).pop();
          DonySnackbar.show(context, message: 'Compte bancaire configuré !', type: DonySnackbarType.success);
          context.go('/profile');
        } else if (state is ConnectOnboardingError) {
          DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.hourglass_top_rounded, size: 40, color: DonyColors.primary),
          const SizedBox(height: DonySpacing.base),
          Text('En attente de Stripe', style: tt.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Revenez ici après avoir complété le formulaire Stripe dans votre navigateur.',
            style: tt.bodyMedium?.copyWith(color: DonyColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xl),
          BlocBuilder<ConnectOnboardingBloc, ConnectOnboardingState>(
            builder: (context, state) => DonyButton(
              label: 'J\'ai complété le formulaire',
              isLoading: state is ConnectOnboardingLoading,
              onPressed: state is ConnectOnboardingLoading
                  ? null
                  : () => context.read<ConnectOnboardingBloc>().add(const ConnectOnboardingStatusChecked()),
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            label: 'Revenir plus tard',
            variant: DonyButtonVariant.ghost,
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/profile');
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2 — Mettre à jour `ConnectOnboardingIntroScreen`**

Dans `lib/features/connect_onboarding/presentation/screens/connect_onboarding_intro_screen.dart`, remplacer la navigation vers `/connect/onboarding/pending` par :

```dart
// Avant :
// context.push('/connect/onboarding/pending');

// Après :
ConnectPendingBottomSheet.show(context);
```

Ajouter l'import :
```dart
import 'package:dony/features/connect_onboarding/presentation/widgets/connect_pending_bottom_sheet.dart';
```

- [ ] **Step 3 — Supprimer `/connect/onboarding/pending` dans `router.dart`**

Supprimer le GoRoute `path: '/connect/onboarding/pending'`.

Vérifier que le deep link `/stripe/onboarding/complete` qui redirige vers `/connect/onboarding/pending` est également mis à jour. Remplacer :
```dart
// Avant :
redirect: (context, state) => '/connect/onboarding/pending',

// Après — rediriger vers l'intro screen qui ouvrira la BS pending
redirect: (context, state) => '/connect/onboarding/intro?from=stripe',
```

Et dans `ConnectOnboardingIntroScreen`, détecter le paramètre `from=stripe` pour ouvrir automatiquement la BS :
```dart
// Dans initState ou dans le build, après le premier frame :
WidgetsBinding.instance.addPostFrameCallback((_) {
  final fromStripe = GoRouterState.of(context).uri.queryParameters['from'] == 'stripe';
  if (fromStripe && mounted) {
    ConnectPendingBottomSheet.show(context);
  }
});
```

- [ ] **Step 4 — Vérifier la compilation**

```bash
flutter analyze
```
Attendu : 0 erreurs.

- [ ] **Step 5 — Commit**

```bash
git add lib/features/connect_onboarding/presentation/widgets/connect_pending_bottom_sheet.dart \
        lib/features/connect_onboarding/presentation/screens/connect_onboarding_intro_screen.dart \
        lib/app/router.dart
git commit -m "feat(connect): convert ConnectOnboardingPendingScreen to bottom sheet"
```

---

## Task 11 — Delete Account Bottom Sheet

**Files:**
- Create: `lib/features/settings/presentation/widgets/delete_account_bottom_sheet.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart`
- Create: `test/features/settings/presentation/widgets/delete_account_bottom_sheet_test.dart`
- Modify: `lib/app/router.dart` — supprimer `/settings/delete-account`

- [ ] **Step 1 — Écrire le test en échec**

Créer `test/features/settings/presentation/widgets/delete_account_bottom_sheet_test.dart` :

```dart
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/delete_account_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAccountDeletionBloc extends Mock implements AccountDeletionBloc {}

void main() {
  late AccountDeletionBloc bloc;

  setUp(() {
    bloc = _MockAccountDeletionBloc();
    when(() => bloc.state).thenReturn(const AccountDeletionInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('affiche l\'avertissement et les boutons', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<AccountDeletionBloc>.value(
        value: bloc,
        child: Builder(builder: (ctx) => TextButton(
          onPressed: () => DeleteAccountBottomSheet.show(ctx),
          child: const Text('Ouvrir'),
        )),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer définitivement'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
  });
}
```

- [ ] **Step 2 — Lancer le test pour vérifier l'échec**

```bash
flutter test test/features/settings/presentation/widgets/delete_account_bottom_sheet_test.dart
```
Attendu : FAIL.

- [ ] **Step 3 — Créer `delete_account_bottom_sheet.dart`**

Créer `lib/features/settings/presentation/widgets/delete_account_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/bloc/account_deletion_event.dart';
import 'package:dony/features/settings/bloc/account_deletion_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

const _reasons = [
  'Je n\'utilise plus le service',
  'Problème de confidentialité',
  'Trop de notifications',
  'Autre raison',
];

class DeleteAccountBottomSheet extends StatefulWidget {
  const DeleteAccountBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return DonyBottomSheet.show(
      context,
      isDanger: true,
      title: 'Supprimer le compte ?',
      subtitle: 'Action irréversible — toutes vos données seront effacées',
      child: BlocProvider.value(
        value: context.read<AccountDeletionBloc>(),
        child: const DeleteAccountBottomSheet(),
      ),
    );
  }

  @override
  State<DeleteAccountBottomSheet> createState() => _DeleteAccountBottomSheetState();
}

class _DeleteAccountBottomSheetState extends State<DeleteAccountBottomSheet> {
  String? _reason;

  void _confirm(BuildContext context) {
    final bloc = context.read<AccountDeletionBloc>();
    Navigator.of(context).pop();
    DonyDialog.show(
      context,
      title: 'Dernière confirmation',
      message: 'Cette action supprimera définitivement votre compte et toutes vos données. Êtes-vous certain ?',
      variant: DonyDialogVariant.destructive,
      icon: Icons.delete_forever_rounded,
    ).then((confirmed) {
      if (confirmed == true) {
        bloc.add(AccountDeletionRequested(reason: _reason));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocListener<AccountDeletionBloc, AccountDeletionState>(
      listener: (context, state) {
        if (state is AccountDeletionSuccess) {
          context.go('/auth/phone');
        } else if (state is AccountDeletionError) {
          DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Raison (optionnel)', style: tt.titleSmall),
          const SizedBox(height: DonySpacing.sm),
          DonyRadioGroup<String>(
            value: _reason,
            onChanged: (v) => setState(() => _reason = v),
            options: _reasons.map((r) => DonyRadioOption(value: r, label: r)).toList(),
          ),
          const SizedBox(height: DonySpacing.xl),
          Row(
            children: [
              Expanded(
                child: DonyButton(
                  label: 'Annuler',
                  variant: DonyButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                flex: 2,
                child: BlocBuilder<AccountDeletionBloc, AccountDeletionState>(
                  builder: (context, state) => DonyButton(
                    label: 'Supprimer définitivement',
                    variant: DonyButtonVariant.destructive,
                    isLoading: state is AccountDeletionLoading,
                    onPressed: state is AccountDeletionLoading ? null : () => _confirm(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4 — Mettre à jour `SettingsScreen`**

Dans `lib/features/settings/presentation/settings_screen.dart`, remplacer la navigation vers `/settings/delete-account` :

```dart
// Avant :
// context.push('/settings/delete-account');

// Après :
DeleteAccountBottomSheet.show(context);
```

Ajouter l'import :
```dart
import 'package:dony/features/settings/presentation/widgets/delete_account_bottom_sheet.dart';
```

- [ ] **Step 5 — Supprimer la route `/settings/delete-account` dans `router.dart`**

Supprimer le GoRoute `path: '/settings/delete-account'`.

- [ ] **Step 6 — Lancer les tests**

```bash
flutter test test/features/settings/presentation/widgets/delete_account_bottom_sheet_test.dart
flutter analyze
```
Attendu : PASS, 0 erreurs.

- [ ] **Step 7 — Commit**

```bash
git add lib/features/settings/presentation/widgets/delete_account_bottom_sheet.dart \
        test/features/settings/presentation/widgets/delete_account_bottom_sheet_test.dart \
        lib/features/settings/presentation/settings_screen.dart \
        lib/app/router.dart
git commit -m "feat(settings): convert DeleteAccountScreen to bottom sheet"
```

---

## Task 12 — Upgrade Pro Bottom Sheet

**Files:**
- Create: `lib/features/profile/presentation/widgets/upgrade_pro_bottom_sheet.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Modify: `lib/app/router.dart` — supprimer `/profile/upgrade-pro`

- [ ] **Step 1 — Créer `upgrade_pro_bottom_sheet.dart`**

Créer `lib/features/profile/presentation/widgets/upgrade_pro_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/profile/bloc/profile_bloc.dart';
import 'package:dony/features/profile/bloc/profile_event.dart';
import 'package:dony/features/profile/bloc/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UpgradeProBottomSheet extends StatefulWidget {
  const UpgradeProBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return DonyBottomSheet.show(
      context,
      title: '⭐ Passer en Professionnel',
      subtitle: 'Badge Pro · Volume + · Priorité de matching',
      child: BlocProvider.value(
        value: context.read<ProfileBloc>(),
        child: const UpgradeProBottomSheet(),
      ),
    );
  }

  @override
  State<UpgradeProBottomSheet> createState() => _UpgradeProBottomSheetState();
}

class _UpgradeProBottomSheetState extends State<UpgradeProBottomSheet> {
  final _companyCtrl = TextEditingController();
  final _siretCtrl   = TextEditingController();

  @override
  void dispose() {
    _companyCtrl.dispose();
    _siretCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final company = _companyCtrl.text.trim();
    final siret   = _siretCtrl.text.trim().replaceAll(' ', '');
    if (company.isEmpty || siret.length != 14) {
      DonySnackbar.show(
        context,
        message: siret.length != 14 ? 'Le SIRET doit comporter 14 chiffres' : 'Veuillez remplir tous les champs',
        type: DonySnackbarType.error,
      );
      return;
    }
    context.read<ProfileBloc>().add(ProfileUpgradeToProRequested(
      companyName: company,
      siret: siret,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileUpgradeProSuccess) {
          Navigator.of(context).pop();
          DonySnackbar.show(context, message: 'Compte Pro activé !', type: DonySnackbarType.success);
        } else if (state is ProfileError) {
          DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
        }
      },
      builder: (context, state) {
        final isLoading = state is ProfileLoading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avantages
            Container(
              padding: const EdgeInsets.all(DonySpacing.base),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.xs,
                children: const [
                  _ProChip(label: '✓ Badge Pro'),
                  _ProChip(label: '✓ Volume illimité'),
                  _ProChip(label: '✓ Priorité matching'),
                  _ProChip(label: '✓ Support dédié'),
                ],
              ),
            ),
            const SizedBox(height: DonySpacing.xl),
            DonyTextField(controller: _companyCtrl, label: 'Nom de l\'entreprise', hint: 'SARL Diallo Transport'),
            const SizedBox(height: DonySpacing.sm),
            DonyTextField(controller: _siretCtrl, label: 'SIRET', hint: '123 456 789 00010', keyboardType: TextInputType.number),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: 'Activer le compte Pro',
              isLoading: isLoading,
              onPressed: isLoading ? null : () => _submit(context),
            ),
          ],
        );
      },
    );
  }
}

class _ProChip extends StatelessWidget {
  const _ProChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
    );
  }
}
```

- [ ] **Step 2 — Mettre à jour `ProfileScreen`**

Dans `lib/features/profile/presentation/profile_screen.dart`, remplacer la navigation vers `/profile/upgrade-pro` :

```dart
// Avant :
// context.push('/profile/upgrade-pro');

// Après :
UpgradeProBottomSheet.show(context);
```

Ajouter l'import :
```dart
import 'package:dony/features/profile/presentation/widgets/upgrade_pro_bottom_sheet.dart';
```

- [ ] **Step 3 — Supprimer `/profile/upgrade-pro` dans `router.dart`**

Supprimer le GoRoute `path: '/profile/upgrade-pro'`.

- [ ] **Step 4 — Vérifier la compilation**

```bash
flutter analyze
```
Attendu : 0 erreurs.

- [ ] **Step 5 — Commit**

```bash
git add lib/features/profile/presentation/widgets/upgrade_pro_bottom_sheet.dart \
        lib/features/profile/presentation/profile_screen.dart \
        lib/app/router.dart
git commit -m "feat(profile): convert UpgradeToProScreen to bottom sheet"
```

---

## Task 13 — Rematch Search Bottom Sheet

**Files:**
- Create: `lib/features/cancellation/presentation/widgets/rematch_bottom_sheet.dart`
- Modify: `lib/features/cancellation/presentation/screens/cancellation_screen.dart`
- Modify: `lib/app/router.dart` — supprimer `/cancellations/rematch`

> Règle conditionnelle : si `cancellation.affectedBidsCount <= 4`, ouvrir la BS. Sinon, naviguer vers `RematchSearchScreen` (plein écran).

- [ ] **Step 1 — Créer `rematch_bottom_sheet.dart`**

Créer `lib/features/cancellation/presentation/widgets/rematch_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RematchBottomSheet extends StatelessWidget {
  const RematchBottomSheet({super.key, required this.cancellation});

  final CancellationModel cancellation;

  /// Ouvre la BS si ≤ 4 suggestions, sinon navigue vers le plein écran.
  static void showOrNavigate(BuildContext context, CancellationModel cancellation) {
    if (cancellation.suggestions.length <= 4) {
      DonyBottomSheet.show(
        context,
        title: '${cancellation.suggestions.length} alternative${cancellation.suggestions.length > 1 ? 's' : ''} trouvée${cancellation.suggestions.length > 1 ? 's' : ''}',
        subtitle: 'Colis affectés · ${cancellation.corridor}',
        child: RematchBottomSheet(cancellation: cancellation),
      );
    } else {
      context.push('/cancellations/rematch', extra: cancellation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...cancellation.suggestions.map((suggestion) => Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.sm),
          child: DonyUserCard(
            name: suggestion.travelerName,
            subtitle: '${suggestion.departureDate} · ${suggestion.availableWeightKg} kg dispo · ${suggestion.rating}★',
            trailing: DonyButton(
              label: 'Voir',
              variant: DonyButtonVariant.outlined,
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/traveler/${suggestion.announcementId}');
              },
            ),
          ),
        )),
        if (cancellation.suggestions.length >= 4) ...[
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            label: 'Voir toutes les alternatives',
            variant: DonyButtonVariant.ghost,
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/cancellations/rematch', extra: cancellation);
            },
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 2 — Mettre à jour `CancellationScreen`**

Dans `lib/features/cancellation/presentation/screens/cancellation_screen.dart`, dans le `BlocListener`, trouver où `CancellationSuccess` navigue vers `/cancellations/rematch` et remplacer :

```dart
// Avant (dans le listener CancellationSuccess) :
// if (state.cancellation.suggestions.isNotEmpty) {
//   context.push('/cancellations/rematch', extra: state.cancellation);
// }

// Après :
if (state.cancellation.suggestions.isNotEmpty) {
  RematchBottomSheet.showOrNavigate(context, state.cancellation);
}
```

Ajouter l'import :
```dart
import 'package:dony/features/cancellation/presentation/widgets/rematch_bottom_sheet.dart';
```

- [ ] **Step 3 — Garder la route `/cancellations/rematch` dans `router.dart`**

Cette route est conservée pour le cas > 4 résultats. Ne pas la supprimer.

- [ ] **Step 4 — Vérifier la compilation**

```bash
flutter analyze
```
Attendu : 0 erreurs.

- [ ] **Step 5 — Lancer tous les tests**

```bash
flutter test
```
Attendu : tous les tests passent.

- [ ] **Step 6 — Commit**

```bash
git add lib/features/cancellation/presentation/widgets/rematch_bottom_sheet.dart \
        lib/features/cancellation/presentation/screens/cancellation_screen.dart
git commit -m "feat(cancellation): convert RematchSearchScreen to conditional bottom sheet"
```

---

## Task 14 — Vérification finale

- [ ] **Step 1 — Lancer tous les tests**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test
```
Attendu : 0 rouge.

- [ ] **Step 2 — Analyse statique complète**

```bash
flutter analyze
```
Attendu : 0 erreurs, 0 warnings.

- [ ] **Step 3 — Vérifier que les routes supprimées ne sont plus référencées**

```bash
grep -rn "'/ratings/\|'/announcements/.*cancel\|'/payments/escrow\|'/tracking/offline-queue\|'/tracking/search\|'/settings/delete-account\|'/profile/upgrade-pro\|'/connect/onboarding/pending\|'/bids/.*/handover\|'/kyc'" \
  lib/ --include="*.dart" | grep -v "router.dart" | grep "context.push\|context.go"
```
Attendu : 0 résultats.

- [ ] **Step 4 — Commit de clôture si nécessaire**

```bash
git add .
git commit -m "chore: bottom sheets migration complete — 11 routes removed"
```