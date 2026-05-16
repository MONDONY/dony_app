# Modifier un trajet lié — Plan d'implémentation

> **Pour les workers agentiques :** SOUS-COMPÉTENCE REQUISE : utiliser superpowers:subagent-driven-development (recommandé) ou superpowers:executing-plans pour implémenter ce plan tâche par tâche. Les étapes utilisent la syntaxe case à cocher (`- [ ]`).

**Objectif :** Permettre au voyageur de modifier un trajet existant (capacité disponible + paiement en liquide) depuis l'écran de liaison de trajet, via un bottom sheet.

**Architecture :** Nouveau bottom sheet `ModifyTripSheet` (design A : bloc verrouillé en lecture seule + bloc modifiable) qui réutilise `AnnouncementBloc` (remplacement complet de l'annonce via `AnnouncementUpdateRequested`) et `CommissionMethodBloc`. Point d'entrée : pied de carte ajouté sur `TripTile` (widget extrait de `link_trip_screen.dart`). Aucun nouveau bloc, événement ni modèle.

**Stack technique :** Flutter, flutter_bloc, GoRouter, design system dony (`DonyBottomSheet`, `DonyButton`), tests `flutter_test` + `bloc_test` + `mocktail`.

---

## Prérequis

Le worktree `.worktrees/modifier-trajet-lie` est un checkout neuf — installer les dépendances avant de commencer :

```bash
flutter pub get
```

Toutes les commandes du plan s'exécutent depuis la racine du worktree (`.worktrees/modifier-trajet-lie`).

---

## Structure des fichiers

| Fichier | Action | Responsabilité |
|---------|--------|----------------|
| `lib/features/package_request/presentation/widgets/thread/modify_trip_sheet.dart` | Créer | Bottom sheet `ModifyTripSheet` : affichage verrouillé, capacité, toggle liquide, sauvegarde |
| `lib/features/package_request/presentation/widgets/traveler/trip_tile.dart` | Créer | Widget public `TripTile` (extrait de `link_trip_screen.dart`), avec pied « Modifier » + pastille liquide |
| `lib/features/package_request/presentation/screens/traveler/link_trip_screen.dart` | Modifier | Utiliser `TripTile`, ouvrir `ModifyTripSheet`, rafraîchir après modification |
| `test/features/package_request/presentation/widgets/thread/modify_trip_sheet_test.dart` | Créer | Widget tests du sheet |
| `test/features/package_request/presentation/widgets/traveler/trip_tile_test.dart` | Créer | Widget tests de `TripTile` |

---

## Précisions techniques (verrouillées par lecture du code)

L'implémenteur doit connaître ces faits — ils sont déjà vérifiés, ne pas les redécouvrir :

1. **`AnnouncementUpdateRequested`** (`lib/features/matching/bloc/announcement_event.dart`) est un **remplacement complet** : il porte `id, departureCity, arrivalCity, departureDate, departureTime?, arrivalTime?, pickupAddress, deliveryAddress, availableKg, pricePerKg, transportMode, description?, acceptedContentTypes, refusedTypes, acceptedPaymentMethods`. `pickupAddress`/`deliveryAddress` sont `AddressData` **non-null requis** ; `transportMode` est `TransportMode` **non-null requis**. `acceptedPaymentMethods` est un `List<String>` de codes wire (`'STRIPE'`, `'CASH'`).
2. **`AnnouncementModel`** : `acceptedPaymentMethods` est un `Set<BidPaymentMethod>` ; `pickupAddress`/`deliveryAddress`/`transportMode` sont **nullables** ; `bidsCount` est `int?` ; `availableKg`/`totalKg` sont `double`.
3. **`BidPaymentMethod`** (`lib/features/matching/data/models/bid_model.dart`) : `enum { stripe (@JsonValue 'STRIPE'), cash (@JsonValue 'CASH') }`.
4. **`AnnouncementBloc._onUpdateRequested`** émet `AnnouncementLoading` puis `AnnouncementUpdated(announcement)` en succès, ou `AnnouncementError(error)` en échec (le HTTP 409 « colis acceptés » est déjà traduit en `ConflictException` lisible par le bloc).
5. **`DonyBottomSheet.show<T>(context, {required Widget child, String? title, Widget? stickyBottom, Widget Function(Widget)? wrapper, ...})`** → `Future<T?>`. `useRootNavigator: true` est déjà forcé. Le `child` est automatiquement enveloppé dans un `SingleChildScrollView`. Le `wrapper` enveloppe l'ensemble `child` + `stickyBottom`.
6. **`DonyButton({required String label, required VoidCallback? onPressed, bool isLoading, Key? key, ...})`** : `onPressed: null` désactive ; `isLoading: true` affiche un spinner.
7. **`CommissionMethodBloc`** : événement `CommissionMethodLoadRequested()` (sans argument) ; états `CommissionMethodInitial/Loading/Loaded(CommissionMethod card)/NotConfigured/SetupInProgress/Error`. Une carte est exploitable si l'état est `CommissionMethodLoaded` **et** `card.expirationStatus != ExpirationStatus.expired` (`ExpirationStatus { valid, expiresSoon, expired }`).
8. **DI** (`lib/core/di/injection.dart`) : `AnnouncementBloc` et `CommissionMethodBloc` sont enregistrés en `registerFactory` → résolus via `getIt<...>()`.
9. **Bornes capacité** : le formulaire de création de trajet borne la capacité à **min 1 kg / max 23 kg** (slider de `create_announcement_bottom_sheet.dart`). On reprend ces bornes.
10. **Référence vivante** : `lib/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart` montre le pattern `wrapper` + `MultiBlocProvider` + `onSubmitReady`/`submit` + toggle liquide. À consulter en cas de doute.
11. **Règle HIG** : `fontSize` < 12 interdit (`labelSmall`=10, `labelMedium`=11 sont sous le plancher → utiliser `bodySmall`=12). Cibles tactiles ≥ 44×44.

---

## Task 1 : `ModifyTripSheet` — affichage + bloc modifiable (sans sauvegarde)

Crée le bottom sheet complet côté UI : bloc verrouillé, bannière d'offres, stepper de capacité, toggle liquide avec détour carte commission. Le bouton « Enregistrer » est présent mais sa logique de sauvegarde est un **stub vide** — elle sera implémentée en Task 2.

**Files:**
- Create: `lib/features/package_request/presentation/widgets/thread/modify_trip_sheet.dart`
- Test: `test/features/package_request/presentation/widgets/thread/modify_trip_sheet_test.dart`

- [ ] **Step 1 : Écrire le fichier `modify_trip_sheet.dart`**

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const double _kMinKg = 1;
const double _kMaxKg = 23;

/// Bottom sheet permettant au voyageur de modifier un trajet existant
/// (capacité + paiement liquide) depuis l'écran de liaison de trajet.
///
/// Précondition : [announcement] doit avoir `pickupAddress`, `deliveryAddress`
/// et `transportMode` non-null (garanti par le point d'entrée `TripTile`).
abstract final class ModifyTripSheet {
  /// Retourne `true` si l'annonce a été mise à jour, sinon `null`/`false`.
  static Future<bool?> show(
    BuildContext context, {
    required AnnouncementModel announcement,
  }) {
    VoidCallback? submit;
    return DonyBottomSheet.show<bool>(
      context,
      title: 'Modifier le trajet',
      wrapper: (child) => MultiBlocProvider(
        providers: [
          BlocProvider<AnnouncementBloc>(
              create: (_) => getIt<AnnouncementBloc>()),
          BlocProvider<CommissionMethodBloc>(
              create: (_) => getIt<CommissionMethodBloc>()),
        ],
        child: child,
      ),
      stickyBottom: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (ctx, state) {
          final isLoading = state is AnnouncementLoading;
          return DonyButton(
            key: const Key('modify-trip-submit'),
            label: 'Enregistrer les modifications',
            isLoading: isLoading,
            onPressed: isLoading ? null : () => submit?.call(),
          );
        },
      ),
      child: _ModifyTripContent(
        announcement: announcement,
        onSubmitReady: (fn) => submit = fn,
      ),
    );
  }
}

class _ModifyTripContent extends StatefulWidget {
  const _ModifyTripContent({
    required this.announcement,
    required this.onSubmitReady,
  });

  final AnnouncementModel announcement;
  final void Function(VoidCallback) onSubmitReady;

  @override
  State<_ModifyTripContent> createState() => _ModifyTripContentState();
}

class _ModifyTripContentState extends State<_ModifyTripContent> {
  late final ValueNotifier<double> _capacity;
  late final ValueNotifier<bool> _cashEnabled;
  bool _awaitingCardSetup = false;

  AnnouncementModel get _a => widget.announcement;

  @override
  void initState() {
    super.initState();
    _capacity = ValueNotifier<double>(
      _a.availableKg.clamp(_kMinKg, _kMaxKg).toDouble(),
    );
    _cashEnabled = ValueNotifier<bool>(
      _a.acceptedPaymentMethods.contains(BidPaymentMethod.cash),
    );
    widget.onSubmitReady(_submit);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<CommissionMethodBloc>()
            .add(CommissionMethodLoadRequested());
      }
    });
  }

  @override
  void dispose() {
    _capacity.dispose();
    _cashEnabled.dispose();
    super.dispose();
  }

  // Implémenté en Task 2.
  void _submit() {}

  bool _hasValidCard(CommissionMethodState st) =>
      st is CommissionMethodLoaded &&
      st.card.expirationStatus != ExpirationStatus.expired;

  Future<void> _onCashToggled(bool want) async {
    if (!want) {
      _cashEnabled.value = false;
      return;
    }
    final st = context.read<CommissionMethodBloc>().state;
    if (_hasValidCard(st)) {
      _cashEnabled.value = true;
      return;
    }
    // Pas de carte commission → détour vers la configuration.
    // Le sheet reste monté ; au retour on recharge l'état de la carte.
    _awaitingCardSetup = true;
    await context.push('/payments/commission-method');
    if (!mounted) return;
    context.read<CommissionMethodBloc>().add(CommissionMethodLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CommissionMethodBloc, CommissionMethodState>(
      listener: (ctx, st) {
        // Retour du détour : si une carte valide est désormais configurée,
        // on honore l'intention d'activer le liquide.
        if (_awaitingCardSetup && _hasValidCard(st)) {
          _awaitingCardSetup = false;
          _cashEnabled.value = true;
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LockedInfoBlock(announcement: _a),
          const SizedBox(height: DonySpacing.lg),
          if ((_a.bidsCount ?? 0) > 0) ...[
            const _OffersWarningBanner(),
            const SizedBox(height: DonySpacing.lg),
          ],
          _ModifiableBlock(
            capacity: _capacity,
            cashEnabled: _cashEnabled,
            onCashToggled: _onCashToggled,
          ),
        ],
      ),
    );
  }
}

// ── Bloc verrouillé (lecture seule) ──────────────────────────────────────────

class _LockedInfoBlock extends StatelessWidget {
  const _LockedInfoBlock({required this.announcement});
  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat('EEE d MMM yyyy', 'fr')
        .format(announcement.departureDate);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_rounded, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: DonySpacing.xs),
              Text('NON MODIFIABLE',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  )),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          _LockedRow(
            icon: Icons.swap_horiz_rounded,
            label: 'Corridor',
            value:
                '${announcement.departureCity} → ${announcement.arrivalCity}',
          ),
          const SizedBox(height: DonySpacing.sm),
          _LockedRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date de voyage',
            value: date,
          ),
          const SizedBox(height: DonySpacing.sm),
          _LockedRow(
            icon: Icons.flight_takeoff_rounded,
            label: 'Lieu de remise',
            value: announcement.pickupAddress?.label ?? '—',
          ),
          const SizedBox(height: DonySpacing.sm),
          _LockedRow(
            icon: Icons.flight_land_rounded,
            label: 'Lieu de récupération',
            value: announcement.deliveryAddress?.label ?? '—',
          ),
        ],
      ),
    );
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              Text(value,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Bannière d'information « offres existantes » ─────────────────────────────

class _OffersWarningBanner extends StatelessWidget {
  const _OffersWarningBanner();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const Key('modify-trip-offers-warning'),
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.warningLight,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: cs.warning),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'Ce trajet a déjà reçu des offres. Si un colis y est déjà '
              'accepté, la modification sera refusée.',
              style: tt.bodySmall?.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bloc modifiable ──────────────────────────────────────────────────────────

class _ModifiableBlock extends StatelessWidget {
  const _ModifiableBlock({
    required this.capacity,
    required this.cashEnabled,
    required this.onCashToggled,
  });
  final ValueNotifier<double> capacity;
  final ValueNotifier<bool> cashEnabled;
  final ValueChanged<bool> onCashToggled;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.success.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MODIFIABLE',
              style: tt.bodySmall?.copyWith(
                color: cs.success,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: DonySpacing.md),
          Text('Capacité disponible',
              style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface, fontWeight: FontWeight.w600)),
          const SizedBox(height: DonySpacing.sm),
          _CapacityStepper(capacity: capacity),
          const SizedBox(height: DonySpacing.base),
          Divider(color: cs.success.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: DonySpacing.sm),
          _CashToggleRow(cashEnabled: cashEnabled, onChanged: onCashToggled),
        ],
      ),
    );
  }
}

class _CapacityStepper extends StatelessWidget {
  const _CapacityStepper({required this.capacity});
  final ValueNotifier<double> capacity;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: capacity,
      builder: (context, kg, _) {
        return Row(
          children: [
            _StepperButton(
              key: const Key('capacity-decrement'),
              icon: Icons.remove_rounded,
              onPressed: kg > _kMinKg
                  ? () => capacity.value =
                      (kg - 1).clamp(_kMinKg, _kMaxKg).toDouble()
                  : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${kg.toStringAsFixed(0)} kg',
                  key: const Key('capacity-value'),
                  style: tt.headlineMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            _StepperButton(
              key: const Key('capacity-increment'),
              icon: Icons.add_rounded,
              onPressed: kg < _kMaxKg
                  ? () => capacity.value =
                      (kg + 1).clamp(_kMinKg, _kMaxKg).toDouble()
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Material(
      color: enabled ? cs.surface : cs.surface.withValues(alpha: 0.5),
      shape: CircleBorder(side: BorderSide(color: cs.outline)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          // padding 12 + icône 22 ≈ 46 → cible tactile ≥ 44 (HIG).
          padding: const EdgeInsets.all(DonySpacing.md),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CashToggleRow extends StatelessWidget {
  const _CashToggleRow({required this.cashEnabled, required this.onChanged});
  final ValueNotifier<bool> cashEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: cashEnabled,
      builder: (context, enabled, _) {
        return Row(
          children: [
            Icon(Icons.payments_rounded, size: 20, color: cs.onSurface),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paiement en liquide',
                      style: tt.bodyMedium?.copyWith(
                          color: cs.onSurface, fontWeight: FontWeight.w600)),
                  Text(
                    "L'expéditeur peut payer en espèces à la remise",
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Switch(
              key: const Key('modify-trip-cash-switch'),
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: cs.primary,
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 2 : Vérifier l'analyse statique**

Run: `flutter analyze lib/features/package_request/presentation/widgets/thread/modify_trip_sheet.dart`
Expected: `No issues found!`

- [ ] **Step 3 : Écrire le fichier de test avec le harness et les tests d'affichage**

Créer `test/features/package_request/presentation/widgets/thread/modify_trip_sheet_test.dart` :

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/modify_trip_sheet.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

const _validCard = CommissionMethod(
  brand: 'visa',
  last4: '4242',
  expMonth: 12,
  expYear: 2030,
  expirationStatus: ExpirationStatus.valid,
);
const _expiredCard = CommissionMethod(
  brand: 'visa',
  last4: '1234',
  expMonth: 1,
  expYear: 2020,
  expirationStatus: ExpirationStatus.expired,
);

AnnouncementModel _trip({
  double availableKg = 10,
  int? bidsCount,
  Set<BidPaymentMethod> payments = const {BidPaymentMethod.stripe},
  AddressData? pickup,
  AddressData? delivery,
}) {
  return AnnouncementModel(
    id: 'ann-1',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2026, 8, 15),
    availableKg: availableKg,
    totalKg: 23,
    pricePerKg: 7,
    status: 'ACTIVE',
    transportMode: TransportMode.plane,
    pickupAddress:
        pickup ?? AddressData(label: '10 rue de Rivoli, Paris', lat: 48.86, lng: 2.35),
    deliveryAddress:
        delivery ?? AddressData(label: 'Aéroport de Dakar', lat: 14.74, lng: -17.49),
    bidsCount: bidsCount,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    acceptedPaymentMethods: payments,
  );
}

late MockAnnouncementBloc announcementBloc;
late MockCommissionMethodBloc commissionBloc;

Widget _harness(AnnouncementModel trip) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () => ModifyTripSheet.show(ctx, announcement: trip),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/payments/commission-method',
        builder: (ctx, _) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('retour-stub'),
              onPressed: () => ctx.pop(),
              child: const Text('Commission stub'),
            ),
          ),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
}

Future<void> _open(WidgetTester tester, AnnouncementModel trip) async {
  await tester.pumpWidget(_harness(trip));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(CommissionMethodLoadRequested());
    registerFallbackValue(AnnouncementUpdateRequested(
      id: '',
      departureCity: '',
      arrivalCity: '',
      departureDate: DateTime(2026),
      pickupAddress: AddressData(label: '', lat: 0, lng: 0),
      deliveryAddress: AddressData(label: '', lat: 0, lng: 0),
      availableKg: 0,
      pricePerKg: 0,
      transportMode: TransportMode.plane,
    ));
  });

  setUp(() {
    announcementBloc = MockAnnouncementBloc();
    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    when(() => announcementBloc.stream)
        .thenAnswer((_) => const Stream.empty());
    commissionBloc = MockCommissionMethodBloc();
    when(() => commissionBloc.state)
        .thenReturn(CommissionMethodNotConfigured());
    when(() => commissionBloc.stream)
        .thenAnswer((_) => const Stream.empty());

    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<CommissionMethodBloc>()) {
      getIt.unregister<CommissionMethodBloc>();
    }
    getIt.registerFactory<AnnouncementBloc>(() => announcementBloc);
    getIt.registerFactory<CommissionMethodBloc>(() => commissionBloc);
  });

  tearDown(() {
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<CommissionMethodBloc>()) {
      getIt.unregister<CommissionMethodBloc>();
    }
  });

  testWidgets('affiche le titre et le bloc verrouillé en lecture seule',
      (tester) async {
    await _open(tester, _trip());
    expect(find.text('Modifier le trajet'), findsOneWidget);
    expect(find.text('NON MODIFIABLE'), findsOneWidget);
    expect(find.text('Paris → Dakar'), findsOneWidget);
    expect(find.text('10 rue de Rivoli, Paris'), findsOneWidget);
  });

  testWidgets('affiche la bannière quand le trajet a déjà des offres',
      (tester) async {
    await _open(tester, _trip(bidsCount: 2));
    expect(find.byKey(const Key('modify-trip-offers-warning')),
        findsOneWidget);
  });

  testWidgets('masque la bannière quand bidsCount vaut 0', (tester) async {
    await _open(tester, _trip(bidsCount: 0));
    expect(find.byKey(const Key('modify-trip-offers-warning')), findsNothing);
  });
}
```

- [ ] **Step 4 : Lancer les tests d'affichage**

Run: `flutter test test/features/package_request/presentation/widgets/thread/modify_trip_sheet_test.dart`
Expected: 3 tests PASS.

- [ ] **Step 5 : Ajouter les tests du stepper de capacité**

Ajouter dans `void main()`, après les tests précédents :

```dart
  testWidgets('le stepper incrémente et décrémente la capacité',
      (tester) async {
    await _open(tester, _trip(availableKg: 10));
    expect(find.text('10 kg'), findsOneWidget);
    await tester.tap(find.byKey(const Key('capacity-increment')));
    await tester.pump();
    expect(find.text('11 kg'), findsOneWidget);
    await tester.tap(find.byKey(const Key('capacity-decrement')));
    await tester.pump();
    expect(find.text('10 kg'), findsOneWidget);
  });

  testWidgets('le stepper est borné à 1 kg minimum', (tester) async {
    await _open(tester, _trip(availableKg: 1));
    await tester.tap(find.byKey(const Key('capacity-decrement')));
    await tester.pump();
    expect(find.text('1 kg'), findsOneWidget);
  });

  testWidgets('le stepper est borné à 23 kg maximum', (tester) async {
    await _open(tester, _trip(availableKg: 23));
    await tester.tap(find.byKey(const Key('capacity-increment')));
    await tester.pump();
    expect(find.text('23 kg'), findsOneWidget);
  });
```

- [ ] **Step 6 : Ajouter les tests du toggle liquide**

Ajouter dans `void main()` :

```dart
  testWidgets('le toggle liquide est ON quand l\'annonce accepte le cash',
      (tester) async {
    when(() => commissionBloc.state)
        .thenReturn(CommissionMethodLoaded(_validCard));
    await _open(tester, _trip(
      payments: const {BidPaymentMethod.stripe, BidPaymentMethod.cash},
    ));
    final sw = tester.widget<Switch>(
        find.byKey(const Key('modify-trip-cash-switch')));
    expect(sw.value, isTrue);
  });

  testWidgets('le toggle liquide est OFF par défaut', (tester) async {
    await _open(tester, _trip());
    final sw = tester.widget<Switch>(
        find.byKey(const Key('modify-trip-cash-switch')));
    expect(sw.value, isFalse);
  });

  testWidgets('activer le liquide avec une carte valide passe le toggle ON',
      (tester) async {
    when(() => commissionBloc.state)
        .thenReturn(CommissionMethodLoaded(_validCard));
    await _open(tester, _trip());
    await tester.tap(find.byKey(const Key('modify-trip-cash-switch')));
    await tester.pump();
    final sw = tester.widget<Switch>(
        find.byKey(const Key('modify-trip-cash-switch')));
    expect(sw.value, isTrue);
  });

  testWidgets('activer le liquide sans carte ouvre la configuration',
      (tester) async {
    when(() => commissionBloc.state)
        .thenReturn(CommissionMethodNotConfigured());
    await _open(tester, _trip());
    await tester.tap(find.byKey(const Key('modify-trip-cash-switch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('retour-stub')), findsOneWidget);
  });

  testWidgets('activer le liquide avec une carte expirée ouvre la config',
      (tester) async {
    when(() => commissionBloc.state)
        .thenReturn(CommissionMethodLoaded(_expiredCard));
    await _open(tester, _trip());
    await tester.tap(find.byKey(const Key('modify-trip-cash-switch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('retour-stub')), findsOneWidget);
  });
```

- [ ] **Step 7 : Lancer tous les tests du fichier**

Run: `flutter test test/features/package_request/presentation/widgets/thread/modify_trip_sheet_test.dart`
Expected: 11 tests PASS.

- [ ] **Step 8 : Commit**

```bash
git add lib/features/package_request/presentation/widgets/thread/modify_trip_sheet.dart test/features/package_request/presentation/widgets/thread/modify_trip_sheet_test.dart
git commit -m "feat(package_request): bottom sheet ModifyTripSheet — affichage et bloc modifiable"
```

---

## Task 2 : `ModifyTripSheet` — sauvegarde

Implémente la sauvegarde : `_submit()` construit et dispatche `AnnouncementUpdateRequested`, et un `BlocListener<AnnouncementBloc>` ferme le sheet en succès ou affiche l'erreur.

**Files:**
- Modify: `lib/features/package_request/presentation/widgets/thread/modify_trip_sheet.dart`
- Test: `test/features/package_request/presentation/widgets/thread/modify_trip_sheet_test.dart`

- [ ] **Step 1 : Ajouter les imports nécessaires à la sauvegarde**

Dans `modify_trip_sheet.dart`, ajouter aux imports existants :

```dart
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
```

- [ ] **Step 2 : Remplacer le stub `_submit()` par l'implémentation**

Remplacer dans `_ModifyTripContentState` :

```dart
  // Implémenté en Task 2.
  void _submit() {}
```

par :

```dart
  void _submit() {
    final a = _a;
    final paymentMethods = ['STRIPE', if (_cashEnabled.value) 'CASH'];
    context.read<AnnouncementBloc>().add(AnnouncementUpdateRequested(
          id: a.id,
          departureCity: a.departureCity,
          arrivalCity: a.arrivalCity,
          departureDate: a.departureDate,
          departureTime: a.departureTime,
          arrivalTime: a.arrivalTime,
          // Précondition garantie par TripTile : adresses non-null.
          pickupAddress: a.pickupAddress!,
          deliveryAddress: a.deliveryAddress!,
          availableKg: _capacity.value,
          pricePerKg: a.pricePerKg,
          transportMode: a.transportMode ?? TransportMode.plane,
          description: a.description,
          acceptedContentTypes: a.acceptedContentTypes ?? const [],
          refusedTypes: a.refusedTypes ?? const [],
          acceptedPaymentMethods: paymentMethods,
        ));
  }
```

- [ ] **Step 3 : Envelopper `build()` dans un `BlocListener<AnnouncementBloc>`**

Dans `_ModifyTripContentState.build()`, envelopper le `BlocListener<CommissionMethodBloc>` existant par un `BlocListener<AnnouncementBloc>`. Remplacer le `return BlocListener<CommissionMethodBloc, CommissionMethodState>(` initial par :

```dart
    return BlocListener<AnnouncementBloc, AnnouncementState>(
      listener: (ctx, state) {
        if (state is AnnouncementUpdated) {
          Navigator.of(ctx, rootNavigator: true).pop(true);
        } else if (state is AnnouncementError) {
          ErrorPresenter.show(ctx, state.error);
        }
      },
      child: BlocListener<CommissionMethodBloc, CommissionMethodState>(
```

et fermer la parenthèse correspondante : après le `child: Column(...)` du `BlocListener<CommissionMethodBloc>`, il faut désormais **deux** `)` de fermeture (un pour chaque `BlocListener`). La structure finale de `build()` :

```dart
  @override
  Widget build(BuildContext context) {
    return BlocListener<AnnouncementBloc, AnnouncementState>(
      listener: (ctx, state) {
        if (state is AnnouncementUpdated) {
          Navigator.of(ctx, rootNavigator: true).pop(true);
        } else if (state is AnnouncementError) {
          ErrorPresenter.show(ctx, state.error);
        }
      },
      child: BlocListener<CommissionMethodBloc, CommissionMethodState>(
        listener: (ctx, st) {
          if (_awaitingCardSetup && _hasValidCard(st)) {
            _awaitingCardSetup = false;
            _cashEnabled.value = true;
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LockedInfoBlock(announcement: _a),
            const SizedBox(height: DonySpacing.lg),
            if ((_a.bidsCount ?? 0) > 0) ...[
              const _OffersWarningBanner(),
              const SizedBox(height: DonySpacing.lg),
            ],
            _ModifiableBlock(
              capacity: _capacity,
              cashEnabled: _cashEnabled,
              onCashToggled: _onCashToggled,
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4 : Vérifier l'analyse statique**

Run: `flutter analyze lib/features/package_request/presentation/widgets/thread/modify_trip_sheet.dart`
Expected: `No issues found!`

- [ ] **Step 5 : Ajouter les imports de test**

Dans `modify_trip_sheet_test.dart`, ajouter aux imports :

```dart
import 'package:dony/core/error/app_exception.dart';
```

(`AnnouncementEvent`/`AnnouncementUpdateRequested` et les états sont déjà importés.)

- [ ] **Step 6 : Ajouter le test de dispatch de la sauvegarde**

Ajouter dans `void main()` :

```dart
  testWidgets(
      'Enregistrer dispatche AnnouncementUpdateRequested avec capacité et '
      'méthodes de paiement', (tester) async {
    when(() => commissionBloc.state)
        .thenReturn(CommissionMethodLoaded(_validCard));
    when(() => announcementBloc.add(any())).thenReturn(null);
    await _open(tester, _trip(availableKg: 10));

    // Capacité 10 → 12
    await tester.tap(find.byKey(const Key('capacity-increment')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('capacity-increment')));
    await tester.pump();
    // Activer le liquide
    await tester.tap(find.byKey(const Key('modify-trip-cash-switch')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('modify-trip-submit')));
    await tester.pump();

    verify(() => announcementBloc.add(any(
          that: predicate<AnnouncementEvent>(
            (e) =>
                e is AnnouncementUpdateRequested &&
                e.id == 'ann-1' &&
                e.availableKg == 12 &&
                e.acceptedPaymentMethods.contains('STRIPE') &&
                e.acceptedPaymentMethods.contains('CASH'),
            'AnnouncementUpdateRequested capacité=12 STRIPE+CASH',
          ),
        ))).called(1);
  });

  testWidgets('AnnouncementUpdated ferme le sheet', (tester) async {
    whenListen(
      announcementBloc,
      Stream<AnnouncementState>.fromIterable([
        AnnouncementLoading(),
        AnnouncementUpdated(_trip()),
      ]),
      initialState: AnnouncementInitial(),
    );
    when(() => announcementBloc.add(any())).thenReturn(null);
    await _open(tester, _trip());
    expect(find.text('Modifier le trajet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('modify-trip-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Modifier le trajet'), findsNothing);
  });

  testWidgets('AnnouncementError garde le sheet ouvert', (tester) async {
    whenListen(
      announcementBloc,
      Stream<AnnouncementState>.fromIterable([
        AnnouncementLoading(),
        AnnouncementError(const ConflictException(
          'Modification impossible : des colis sont déjà acceptés',
          code: 'announcement-update-blocked',
        )),
      ]),
      initialState: AnnouncementInitial(),
    );
    when(() => announcementBloc.add(any())).thenReturn(null);
    await _open(tester, _trip());

    await tester.tap(find.byKey(const Key('modify-trip-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Modifier le trajet'), findsOneWidget);
  });
```

> Note : si la signature exacte de `AnnouncementError` ou `ConflictException` diffère (vérifier `lib/features/matching/bloc/announcement_state.dart` et `lib/core/error/app_exception.dart`), adapter l'instanciation — le bloc utilise `AnnouncementError(const ConflictException('...', code: '...'))` dans `announcement_bloc.dart`, c'est la référence.

- [ ] **Step 7 : Lancer tous les tests du fichier**

Run: `flutter test test/features/package_request/presentation/widgets/thread/modify_trip_sheet_test.dart`
Expected: 14 tests PASS.

- [ ] **Step 8 : Vérifier la couverture du fichier**

Run: `flutter test --coverage test/features/package_request/presentation/widgets/thread/modify_trip_sheet_test.dart`
Vérifier que `modify_trip_sheet.dart` est couvert ≥ 90 % dans `coverage/lcov.info`. Si une branche (ex. retour du détour carte commission) n'est pas couverte, ajouter un test ciblé avec un `StreamController<CommissionMethodState>` :

```dart
  testWidgets('retour du détour avec carte valide active le toggle',
      (tester) async {
    final controller = StreamController<CommissionMethodState>();
    addTearDown(controller.close);
    whenListen(commissionBloc, controller.stream,
        initialState: CommissionMethodNotConfigured());
    await _open(tester, _trip());

    await tester.tap(find.byKey(const Key('modify-trip-cash-switch')));
    await tester.pumpAndSettle(); // navigue vers le stub
    await tester.tap(find.byKey(const Key('retour-stub')));
    await tester.pumpAndSettle(); // revient au sheet
    controller.add(CommissionMethodLoaded(_validCard));
    await tester.pumpAndSettle();

    final sw = tester.widget<Switch>(
        find.byKey(const Key('modify-trip-cash-switch')));
    expect(sw.value, isTrue);
  });
```

(Ajouter `import 'dart:async';` en tête du fichier de test si ce test est inclus.)

- [ ] **Step 9 : Commit**

```bash
git add lib/features/package_request/presentation/widgets/thread/modify_trip_sheet.dart test/features/package_request/presentation/widgets/thread/modify_trip_sheet_test.dart
git commit -m "feat(package_request): sauvegarde dans ModifyTripSheet via AnnouncementUpdateRequested"
```

---

## Task 3 : Extraire `TripTile` dans son propre fichier

Refactor pur, sans changement de comportement : la classe privée `_TripTile` de `link_trip_screen.dart` devient un widget public `TripTile` dans son propre fichier. Cela rend le widget testable et prépare l'ajout du pied de carte (Task 4).

**Files:**
- Create: `lib/features/package_request/presentation/widgets/traveler/trip_tile.dart`
- Modify: `lib/features/package_request/presentation/screens/traveler/link_trip_screen.dart`

- [ ] **Step 1 : Créer `trip_tile.dart` avec le contenu de `_TripTile`**

Créer `lib/features/package_request/presentation/widgets/traveler/trip_tile.dart` — c'est le code actuel de `_TripTile` (lignes 306-393 de `link_trip_screen.dart`), renommé `TripTile` public, avec `super.key` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

/// Carte d'un trajet compatible dans l'écran de liaison de trajet.
class TripTile extends StatelessWidget {
  const TripTile({
    required this.announcement,
    required this.index,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final AnnouncementModel announcement;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? cs.primaryContainer : cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(
                color: isSelected ? cs.primary : cs.outline,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.primary : cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.check_rounded
                        : Icons.flight_takeoff_rounded,
                    color: isSelected ? cs.onPrimary : cs.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEE d MMM', 'fr')
                            .format(announcement.departureDate),
                        style:
                            Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      Text(
                        '${announcement.availableKg} kg dispo · ${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
                        style:
                            Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  fontSize: 12,
                                  color: kTextSecondary,
                                ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? cs.primary : kTextHint,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 220.ms, delay: (40 * index).ms)
        .slideY(begin: 0.04);
  }
}
```

- [ ] **Step 2 : Supprimer `_TripTile` de `link_trip_screen.dart`**

Dans `link_trip_screen.dart`, supprimer entièrement la classe `class _TripTile extends StatelessWidget { ... }` (la classe `_ErrorView` reste).

- [ ] **Step 3 : Importer `TripTile` et mettre à jour son usage**

Ajouter l'import dans `link_trip_screen.dart` :

```dart
import 'package:dony/features/package_request/presentation/widgets/traveler/trip_tile.dart';
```

Dans `_buildBody`, remplacer `_TripTile(` par `TripTile(` (l'appel `.map((e) => _TripTile(announcement: e.value, index: e.key, isSelected: ..., onTap: ...))` devient `.map((e) => TripTile(...))`, mêmes arguments).

- [ ] **Step 4 : Vérifier l'analyse statique**

Run: `flutter analyze lib/features/package_request/`
Expected: `No issues found!` (aucune nouvelle erreur ; en particulier, vérifier qu'aucun import de `link_trip_screen.dart` n'est devenu inutilisé — supprimer `intl`/`flutter_animate` de `link_trip_screen.dart` uniquement s'ils ne sont plus référencés ailleurs dans le fichier).

- [ ] **Step 5 : Lancer la suite de tests matching/package_request (non-régression)**

Run: `flutter test test/features/package_request/ test/features/matching/`
Expected: tous les tests existants PASS (aucune régression).

- [ ] **Step 6 : Commit**

```bash
git add lib/features/package_request/presentation/widgets/traveler/trip_tile.dart lib/features/package_request/presentation/screens/traveler/link_trip_screen.dart
git commit -m "refactor(package_request): extraire TripTile de link_trip_screen"
```

---

## Task 4 : Point d'entrée — pied de `TripTile` + branchement `link_trip_screen`

Ajoute le pied de carte (bouton « Modifier » + pastille liquide) à `TripTile`, et branche l'ouverture du sheet + le rafraîchissement dans `link_trip_screen`.

**Files:**
- Modify: `lib/features/package_request/presentation/widgets/traveler/trip_tile.dart`
- Modify: `lib/features/package_request/presentation/screens/traveler/link_trip_screen.dart`
- Test: `test/features/package_request/presentation/widgets/traveler/trip_tile_test.dart`

- [ ] **Step 1 : Ajouter l'import `bid_model.dart` dans `trip_tile.dart`**

```dart
import 'package:dony/features/matching/data/models/bid_model.dart';
```

- [ ] **Step 2 : Ajouter le callback `onModify` à `TripTile`**

Dans `TripTile`, ajouter le champ et le paramètre de constructeur :

```dart
class TripTile extends StatelessWidget {
  const TripTile({
    required this.announcement,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onModify,
    super.key,
  });

  final AnnouncementModel announcement;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  /// `null` quand le trajet ne peut pas être modifié en sécurité
  /// (adresses incomplètes) — le bouton « Modifier » est alors désactivé.
  final VoidCallback? onModify;
```

- [ ] **Step 3 : Remplacer le `build()` de `TripTile` par la version avec pied de carte**

Le `Container` à bordure contient désormais un `Column` : la rangée de sélection (dans un `InkWell` qui ne couvre QUE cette rangée) puis le pied de carte. Remplacer la méthode `build()` :

```dart
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cashOn =
        announcement.acceptedPaymentMethods.contains(BidPaymentMethod.cash);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? cs.primaryContainer : cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary
                              : cs.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected
                              ? Icons.check_rounded
                              : Icons.flight_takeoff_rounded,
                          color: isSelected ? cs.onPrimary : cs.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: DonySpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEE d MMM', 'fr')
                                  .format(announcement.departureDate),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              '${announcement.availableKg} kg dispo · ${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(
                                    fontSize: 12,
                                    color: kTextSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? cs.primary : kTextHint,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  children: [
                    Divider(height: 1, color: cs.outline),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ModifyButton(onTap: onModify),
                        const Spacer(),
                        _CashChip(enabled: cashOn),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 220.ms, delay: (40 * index).ms)
        .slideY(begin: 0.04);
  }
}
```

- [ ] **Step 4 : Ajouter les widgets privés `_ModifyButton` et `_CashChip` à la fin de `trip_tile.dart`**

```dart
class _ModifyButton extends StatelessWidget {
  const _ModifyButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Material(
      color: enabled ? cs.primaryContainer : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(DonyRadius.sm),
      child: InkWell(
        key: const Key('trip-tile-modify-button'),
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        onTap: onTap,
        child: Padding(
          // vertical 12 → cible tactile ≥ 44 (HIG).
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_rounded,
                  size: 14,
                  color: enabled ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: DonySpacing.xs),
              Text(
                'Modifier le trajet',
                style: tt.bodySmall?.copyWith(
                  color: enabled ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashChip extends StatelessWidget {
  const _CashChip({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const Key('trip-tile-cash-chip'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: enabled ? cs.successLight : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.payments_rounded : Icons.payments_outlined,
            size: 13,
            color: enabled ? cs.success : cs.onSurfaceVariant,
          ),
          const SizedBox(width: DonySpacing.xs),
          Text(
            enabled ? 'Liquide activé' : 'Liquide désactivé',
            style: tt.bodySmall?.copyWith(
              color: enabled ? cs.success : cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5 : Brancher l'ouverture du sheet dans `link_trip_screen.dart`**

Ajouter l'import :

```dart
import 'package:dony/features/package_request/presentation/widgets/thread/modify_trip_sheet.dart';
```

Ajouter ces deux méthodes dans `_LinkTripScreenState` (à côté de `_createNewTrip`) :

```dart
  /// Un trajet n'est modifiable que si ses adresses sont complètes
  /// (requises par AnnouncementUpdateRequested, remplacement complet).
  bool _canModify(AnnouncementModel ann) =>
      ann.pickupAddress != null && ann.deliveryAddress != null;

  Future<void> _openModifySheet(AnnouncementModel ann) async {
    final changed = await ModifyTripSheet.show(context, announcement: ann);
    if (changed == true && mounted) {
      await _load();
    }
  }
```

- [ ] **Step 6 : Passer `onModify` à `TripTile` dans `_buildBody`**

Dans `_buildBody`, le `.map` qui construit les `TripTile` devient :

```dart
            ..._matchingTrips
                .asMap()
                .entries
                .map((e) => TripTile(
                      announcement: e.value,
                      index: e.key,
                      isSelected: _selectedTrip?.id == e.value.id,
                      onTap: () => _selectTrip(e.value),
                      onModify: _canModify(e.value)
                          ? () => _openModifySheet(e.value)
                          : null,
                    )),
```

- [ ] **Step 7 : Vérifier l'analyse statique**

Run: `flutter analyze lib/features/package_request/`
Expected: `No issues found!`

- [ ] **Step 8 : Écrire les tests de `TripTile`**

Créer `test/features/package_request/presentation/widgets/traveler/trip_tile_test.dart` :

```dart
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/presentation/widgets/traveler/trip_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _trip({
  Set<BidPaymentMethod> payments = const {BidPaymentMethod.stripe},
}) {
  return AnnouncementModel(
    id: 'ann-1',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2026, 8, 15),
    availableKg: 12,
    totalKg: 23,
    pricePerKg: 7,
    status: 'ACTIVE',
    transportMode: TransportMode.plane,
    pickupAddress: AddressData(label: 'Paris', lat: 48.86, lng: 2.35),
    deliveryAddress: AddressData(label: 'Dakar', lat: 14.74, lng: -17.49),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    acceptedPaymentMethods: payments,
  );
}

Widget _harness(TripTile tile) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: tile));

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('affiche le bouton Modifier et la pastille liquide',
      (tester) async {
    await tester.pumpWidget(_harness(TripTile(
      announcement: _trip(),
      index: 0,
      isSelected: false,
      onTap: () {},
      onModify: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-tile-modify-button')), findsOneWidget);
    expect(find.text('Modifier le trajet'), findsOneWidget);
    expect(find.text('Liquide désactivé'), findsOneWidget);
  });

  testWidgets('la pastille indique « Liquide activé » quand le cash est accepté',
      (tester) async {
    await tester.pumpWidget(_harness(TripTile(
      announcement:
          _trip(payments: const {BidPaymentMethod.stripe, BidPaymentMethod.cash}),
      index: 0,
      isSelected: false,
      onTap: () {},
      onModify: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Liquide activé'), findsOneWidget);
  });

  testWidgets('tap sur Modifier déclenche onModify', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_harness(TripTile(
      announcement: _trip(),
      index: 0,
      isSelected: false,
      onTap: () {},
      onModify: () => tapped = true,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trip-tile-modify-button')));
    expect(tapped, isTrue);
  });

  testWidgets('tap sur le corps de la carte déclenche onTap, pas onModify',
      (tester) async {
    var selected = false;
    var modified = false;
    await tester.pumpWidget(_harness(TripTile(
      announcement: _trip(),
      index: 0,
      isSelected: false,
      onTap: () => selected = true,
      onModify: () => modified = true,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paris → Dakar').first);
    expect(selected, isTrue);
    expect(modified, isFalse);
  });

  testWidgets('le bouton Modifier est désactivé quand onModify est null',
      (tester) async {
    await tester.pumpWidget(_harness(TripTile(
      announcement: _trip(),
      index: 0,
      isSelected: false,
      onTap: () {},
      onModify: null,
    )));
    await tester.pumpAndSettle();
    final inkWell = tester.widget<InkWell>(
        find.byKey(const Key('trip-tile-modify-button')));
    expect(inkWell.onTap, isNull);
  });
}
```

> Note : `find.text('Paris → Dakar')` n'existe pas dans `TripTile` (la tuile affiche la date et « X kg dispo »). Pour le test « tap sur le corps », viser plutôt `find.textContaining('kg dispo')` ou `find.byIcon(Icons.flight_takeoff_rounded)` — utiliser un finder qui pointe la rangée de sélection, pas le pied.

- [ ] **Step 9 : Lancer les tests de `TripTile`**

Run: `flutter test test/features/package_request/presentation/widgets/traveler/trip_tile_test.dart`
Expected: 5 tests PASS.

- [ ] **Step 10 : Vérifier la couverture globale**

Run: `flutter test --coverage`
Vérifier la couverture globale dans `coverage/lcov.info` (`genhtml coverage/lcov.info -o coverage/html` pour le rapport HTML). Cible : **≥ 90 %**. Si les lignes ajoutées dans `link_trip_screen.dart` (`_canModify`, `_openModifySheet`, passage de `onModify`) font passer sous le seuil, ajouter `test/features/package_request/presentation/screens/traveler/link_trip_screen_test.dart` : mock `PackageRequestRepository` + `AnnouncementRepository` enregistrés via `getIt`, pump `LinkTripScreen` dans un `MaterialApp` avec un `NegotiationBloc` fourni, et vérifier qu'une `TripTile` avec bouton « Modifier » apparaît pour un trajet retourné par `getMyAnnouncements()`.

- [ ] **Step 11 : Commit**

```bash
git add lib/features/package_request/ test/features/package_request/presentation/widgets/traveler/trip_tile_test.dart
git commit -m "feat(package_request): point d'entrée modifier-trajet dans link_trip_screen"
```

---

## Auto-revue du plan

**1. Couverture de la spec** (`docs/superpowers/specs/2026-05-16-modifier-trajet-lie-design.md`) :
- §3 Point d'entrée (bouton « Modifier » + pastille liquide sur chaque trajet) → Task 4. ✓
- §4 Bottom sheet design A (bloc verrouillé + bloc modifiable, `stickyBottom`) → Task 1. ✓
- §5 Toggle liquide + carte commission + détour → Task 1 (`_onCashToggled`, `BlocListener<CommissionMethodBloc>`). ✓
- §6 Garde-fous (champs verrouillés, bannière `bidsCount > 0`, capacité bornée 1-23) → Task 1 (`_LockedInfoBlock`, `_OffersWarningBanner`, `_CapacityStepper`). ✓
- §7 Enregistrement (`AnnouncementUpdateRequested` remplacement complet, conversion `Set<BidPaymentMethod>` → `List<String>`) → Task 2. ✓
- §8 États & erreurs (`AnnouncementLoading`/`Updated`/`Error`, `ErrorPresenter`) → Task 2. ✓
- §9 Découpage (créer `modify_trip_sheet.dart`, modifier `link_trip_screen.dart`) → Tasks 1-4. ✓
- §10 Tests ≥ 90 % → Tasks 1, 2, 4 (étapes de couverture). ✓

**2. Placeholders** : aucun « TBD »/« TODO ». Le stub `_submit() {}` de Task 1 est explicitement marqué « implémenté en Task 2 » et l'est en Task 2 Step 2. Toutes les étapes de code contiennent du code complet.

**3. Cohérence des types** : `ModifyTripSheet.show` → `Future<bool?>` ; le sheet `pop(true)` en succès ; `link_trip_screen._openModifySheet` teste `changed == true`. `_capacity` est `ValueNotifier<double>`, `_cashEnabled` est `ValueNotifier<bool>` — cohérent entre Tasks 1 et 2. `TripTile` gagne `onModify` (Task 4) après extraction (Task 3) — l'ordre est respecté. `acceptedPaymentMethods` : `Set<BidPaymentMethod>` lu du modèle, `List<String>` (`'STRIPE'`/`'CASH'`) envoyé dans l'événement — conversion en Task 2 Step 2.
