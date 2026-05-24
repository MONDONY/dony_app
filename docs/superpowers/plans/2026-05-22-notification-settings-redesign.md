# Notification Settings Screen — Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Réorganiser l'écran `/settings/notifications` en 3 niveaux (critiques verrouillées / activité / promos), couvrir les 20 types de notifications existants, et supprimer les faux toggles SMS.

**Architecture:** Le `NotificationPrefsBloc` voit ses 11 clés Hive remplacées par 6 clés réelles. L'écran est réécrit avec 3 sections visuellement distinctes : critiques non-désactivables (fond rouge, badge "Toujours actif"), activité toggleable, et promotions toggleables. Aucun nouveau BLoC, aucun nouveau fichier de modèle.

**Tech Stack:** Flutter · flutter_bloc · Hive · bloc_test · mocktail · flutter_animate · DonyListTile / DonyListSection (design system dony)

---

## Fichiers

| Fichier | Action |
|---------|--------|
| `lib/features/settings/bloc/notification_prefs_bloc.dart` | Modifier `_defaults` |
| `lib/features/settings/presentation/screens/notification_settings_screen.dart` | Réécriture complète |
| `test/features/settings/bloc/notification_prefs_bloc_test.dart` | Mettre à jour les tests |
| `test/features/settings/presentation/notification_settings_screen_test.dart` | Créer |

---

## Task 1 — Mettre à jour NotificationPrefsBloc

**Files:**
- Modify: `lib/features/settings/bloc/notification_prefs_bloc.dart`
- Modify: `test/features/settings/bloc/notification_prefs_bloc_test.dart`

### Contexte

`notification_prefs_bloc.dart` contient `_defaults` avec 11 clés dont 8 sont soit critiques (non-désactivables), soit des toggles SMS sans effet réel côté backend. On les remplace par 6 clés utiles. Le BLoC lui-même (`_onToggled`, `on<NotifPrefToggled>`) ne change pas.

Clés supprimées : `push_payment`, `sms_payment`, `push_delivery`, `sms_delivery`, `push_match`, `push_dispute`, `sms_dispute`, `email_dispute`

Clés conservées : `push_trip_reminder`, `push_promo`, `email_promo`

Clés ajoutées : `push_activity_bids` (true), `push_activity_negotiations` (true), `push_messages` (true)

- [ ] **Step 1 : Écrire les tests failing**

Remplace le contenu de `test/features/settings/bloc/notification_prefs_bloc_test.dart` par :

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockBox extends Mock implements Box<dynamic> {}

void main() {
  late MockBox mockBox;

  setUp(() {
    mockBox = MockBox();
    when(() => mockBox.get(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((inv) => inv.namedArguments[#defaultValue]);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
  });

  group('NotificationPrefsBloc', () {
    test('état initial utilise les 6 nouvelles defaults', () {
      final bloc = NotificationPrefsBloc(mockBox);
      expect(bloc.state.prefs['push_activity_bids'], isTrue);
      expect(bloc.state.prefs['push_activity_negotiations'], isTrue);
      expect(bloc.state.prefs['push_messages'], isTrue);
      expect(bloc.state.prefs['push_trip_reminder'], isTrue);
      expect(bloc.state.prefs['push_promo'], isFalse);
      expect(bloc.state.prefs['email_promo'], isFalse);
      // Anciennes clés supprimées
      expect(bloc.state.prefs.containsKey('push_payment'), isFalse);
      expect(bloc.state.prefs.containsKey('sms_payment'), isFalse);
      expect(bloc.state.prefs.containsKey('push_delivery'), isFalse);
      expect(bloc.state.prefs.containsKey('sms_delivery'), isFalse);
      expect(bloc.state.prefs.containsKey('push_match'), isFalse);
      expect(bloc.state.prefs.containsKey('push_dispute'), isFalse);
      expect(bloc.state.prefs.containsKey('sms_dispute'), isFalse);
      expect(bloc.state.prefs.containsKey('email_dispute'), isFalse);
      bloc.close();
    });

    test('état initial lit une valeur persistée depuis Hive', () {
      when(
        () => mockBox.get(
          'notif_push_activity_bids',
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(false);

      final bloc = NotificationPrefsBloc(mockBox);
      expect(bloc.state.prefs['push_activity_bids'], isFalse);
      bloc.close();
    });

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled inverse push_activity_bids (true → false)',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('push_activity_bids')),
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.prefs['push_activity_bids'],
          'push_activity_bids',
          isFalse,
        ),
      ],
      verify: (_) => verify(
        () => mockBox.put('notif_push_activity_bids', false),
      ).called(1),
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled inverse push_activity_negotiations (true → false)',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) =>
          bloc.add(const NotifPrefToggled('push_activity_negotiations')),
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.prefs['push_activity_negotiations'],
          'push_activity_negotiations',
          isFalse,
        ),
      ],
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled inverse push_messages (true → false)',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('push_messages')),
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.prefs['push_messages'],
          'push_messages',
          isFalse,
        ),
      ],
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled écrit la nouvelle valeur dans Hive',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('push_promo')),
      verify: (_) =>
          verify(() => mockBox.put('notif_push_promo', true)).called(1),
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'Deux toggles successifs restituent la valeur initiale',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc
        ..add(const NotifPrefToggled('push_promo'))
        ..add(const NotifPrefToggled('push_promo')),
      expect: () => [
        isA<NotificationPrefsState>()
            .having((s) => s.prefs['push_promo'], 'push_promo_on', isTrue),
        isA<NotificationPrefsState>()
            .having((s) => s.prefs['push_promo'], 'push_promo_off', isFalse),
      ],
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'Toggler une clé ne modifie pas les autres clés',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('push_promo')),
      expect: () => [
        isA<NotificationPrefsState>()
            .having((s) => s.prefs['push_promo'], 'push_promo', isTrue)
            .having((s) => s.prefs['push_activity_bids'], 'bids', isTrue)
            .having(
                (s) => s.prefs['push_activity_negotiations'], 'negs', isTrue),
      ],
    );

    test('NotifPrefToggled props contient la clé', () {
      const event = NotifPrefToggled('push_activity_bids');
      expect(event.props, contains('push_activity_bids'));
    });
  });
}
```

- [ ] **Step 2 : Vérifier que les tests échouent**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/settings/bloc/notification_prefs_bloc_test.dart --no-pub
```

Attendu : plusieurs FAIL sur `containsKey('push_payment')` etc. et `push_activity_bids` absent.

- [ ] **Step 3 : Mettre à jour `_defaults` dans le BLoC**

Dans `lib/features/settings/bloc/notification_prefs_bloc.dart`, remplace uniquement le bloc `_defaults` (lignes 12-24) :

```dart
  static const Map<String, bool> _defaults = {
    'push_activity_bids': true,
    'push_activity_negotiations': true,
    'push_messages': true,
    'push_trip_reminder': true,
    'push_promo': false,
    'email_promo': false,
  };
```

Le reste du fichier (constructeur, `_onToggled`) est inchangé.

- [ ] **Step 4 : Vérifier que les tests passent**

```bash
flutter test test/features/settings/bloc/notification_prefs_bloc_test.dart --no-pub
```

Attendu : tous PASS.

- [ ] **Step 5 : Commit**

```bash
git add lib/features/settings/bloc/notification_prefs_bloc.dart \
        test/features/settings/bloc/notification_prefs_bloc_test.dart
git commit -m "refactor(settings/notif): remplacer les 11 clés Hive par 6 clés réelles — suppression faux toggles SMS et critiques"
```

---

## Task 2 — Réécrire NotificationSettingsScreen

**Files:**
- Modify: `lib/features/settings/presentation/screens/notification_settings_screen.dart`
- Create: `test/features/settings/presentation/notification_settings_screen_test.dart`

### Contexte

L'écran actuel est une `StatelessWidget` avec `BlocBuilder<NotificationPrefsBloc>` et une `ListView` de 5 sections. On le réécrit entièrement avec 3 sections. Le design system fournit `DonyListTile`, `DonyListSection`, `DonyAppBar`. Les couleurs viennent de `lib/app/theme.dart` : `kError = Color(0xFFE53935)`.

Nouveau widget privé `_LockedTile` : tile non-interactive avec fond rouge pâle, Switch grisé, badge "Toujours actif".

`_buildTile()` reçoit un paramètre `subtitle` optionnel supplémentaire.

`_buildSection()` reçoit `titleColor` et `footer` optionnels.

- [ ] **Step 1 : Écrire les tests failing**

Crée `test/features/settings/presentation/notification_settings_screen_test.dart` :

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:dony/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationPrefsBloc
    extends MockBloc<NotificationPrefsEvent, NotificationPrefsState>
    implements NotificationPrefsBloc {}

class MockBox extends Mock implements Box<dynamic> {}

class _FakeNotifEvent extends Fake implements NotificationPrefsEvent {}

Widget _wrap({Map<String, bool>? prefs}) {
  final mockBloc = MockNotificationPrefsBloc();
  final state = NotificationPrefsState(
    prefs: prefs ??
        {
          'push_activity_bids': true,
          'push_activity_negotiations': true,
          'push_messages': true,
          'push_trip_reminder': true,
          'push_promo': false,
          'email_promo': false,
        },
  );
  when(() => mockBloc.state).thenReturn(state);
  whenListen<NotificationPrefsState>(mockBloc, const Stream.empty(),
      initialState: state);

  return MaterialApp(
    home: BlocProvider<NotificationPrefsBloc>.value(
      value: mockBloc,
      child: const NotificationSettingsScreen(),
    ),
  );
}

Widget _wrapWithBloc(MockNotificationPrefsBloc mockBloc) {
  return MaterialApp(
    home: BlocProvider<NotificationPrefsBloc>.value(
      value: mockBloc,
      child: const NotificationSettingsScreen(),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeNotifEvent());
  });

  group('NotificationSettingsScreen', () {
    testWidgets('affiche la section PROTECTIONS CRITIQUES', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('PROTECTIONS CRITIQUES'), findsOneWidget);
    });

    testWidgets('affiche les 3 tiles critiques', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Livraison confirmée'), findsOneWidget);
      expect(find.text('Paiement reçu'), findsOneWidget);
      expect(find.text('Litige ouvert'), findsOneWidget);
    });

    testWidgets('affiche le bandeau explicatif des critiques', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Ces notifications protègent vos transactions'),
        findsOneWidget,
      );
    });

    testWidgets('tap sur tile critique ne dispatche aucun event', (tester) async {
      final mockBloc = MockNotificationPrefsBloc();
      final state = NotificationPrefsState(prefs: {
        'push_activity_bids': true,
        'push_activity_negotiations': true,
        'push_messages': true,
        'push_trip_reminder': true,
        'push_promo': false,
        'email_promo': false,
      });
      when(() => mockBloc.state).thenReturn(state);
      whenListen<NotificationPrefsState>(mockBloc, const Stream.empty(),
          initialState: state);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Livraison confirmée'));
      await tester.pump();

      verifyNever(() => mockBloc.add(any()));
    });

    testWidgets('affiche la section ACTIVITÉ avec 4 tiles', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('ACTIVITÉ'), findsOneWidget);
      expect(find.text('Matchs & enchères'), findsOneWidget);
      expect(find.text('Négociations'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Rappel trajet J-1'), findsOneWidget);
    });

    testWidgets('tap Matchs & enchères dispatche NotifPrefToggled(push_activity_bids)',
        (tester) async {
      final mockBloc = MockNotificationPrefsBloc();
      final state = NotificationPrefsState(prefs: {
        'push_activity_bids': true,
        'push_activity_negotiations': true,
        'push_messages': true,
        'push_trip_reminder': true,
        'push_promo': false,
        'email_promo': false,
      });
      when(() => mockBloc.state).thenReturn(state);
      whenListen<NotificationPrefsState>(mockBloc, const Stream.empty(),
          initialState: state);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Matchs & enchères'));
      await tester.pump();

      verify(() => mockBloc.add(
            any(that: isA<NotifPrefToggled>()
                .having((e) => e.key, 'key', 'push_activity_bids')),
          )).called(1);
    });

    testWidgets('tap Négociations dispatche NotifPrefToggled(push_activity_negotiations)',
        (tester) async {
      final mockBloc = MockNotificationPrefsBloc();
      final state = NotificationPrefsState(prefs: {
        'push_activity_bids': true,
        'push_activity_negotiations': true,
        'push_messages': true,
        'push_trip_reminder': true,
        'push_promo': false,
        'email_promo': false,
      });
      when(() => mockBloc.state).thenReturn(state);
      whenListen<NotificationPrefsState>(mockBloc, const Stream.empty(),
          initialState: state);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Négociations'));
      await tester.pump();

      verify(() => mockBloc.add(
            any(that: isA<NotifPrefToggled>()
                .having((e) => e.key, 'key', 'push_activity_negotiations')),
          )).called(1);
    });

    testWidgets('tap Messages dispatche NotifPrefToggled(push_messages)',
        (tester) async {
      final mockBloc = MockNotificationPrefsBloc();
      final state = NotificationPrefsState(prefs: {
        'push_activity_bids': true,
        'push_activity_negotiations': true,
        'push_messages': true,
        'push_trip_reminder': true,
        'push_promo': false,
        'email_promo': false,
      });
      when(() => mockBloc.state).thenReturn(state);
      whenListen<NotificationPrefsState>(mockBloc, const Stream.empty(),
          initialState: state);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Messages'));
      await tester.pump();

      verify(() => mockBloc.add(
            any(that: isA<NotifPrefToggled>()
                .having((e) => e.key, 'key', 'push_messages')),
          )).called(1);
    });

    testWidgets('affiche la section ACTUS & PROMOTIONS', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('ACTUS & PROMOTIONS'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACTUS & PROMOTIONS'), findsOneWidget);
      expect(find.text('Actus dony (Push)'), findsOneWidget);
      expect(find.text('Actus dony (E-mail)'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2 : Vérifier que les tests échouent**

```bash
flutter test test/features/settings/presentation/notification_settings_screen_test.dart --no-pub
```

Attendu : FAIL (écran non réécrit, sections introuvables).

- [ ] **Step 3 : Vérifier si `DonyListTile` supporte `subtitle`**

```bash
grep -n 'subtitle' /home/a-diakite/Desktop/MyProject/my_app/dony_app/lib/core/design/design_system.dart | head -20
```

Si le résultat contient `subtitle`, le paramètre existe et tu peux l'utiliser directement. Sinon note qu'il faudra wrap le label (voir commentaire dans le code ci-dessous).

- [ ] **Step 4 : Réécrire l'écran**

Remplace le contenu entier de `lib/features/settings/presentation/screens/notification_settings_screen.dart` par :

```dart
import 'package:dony/app/theme.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DonyAppBar(title: 'Notifications'),
      body: BlocBuilder<NotificationPrefsBloc, NotificationPrefsState>(
        builder: (context, state) {
          void toggle(String key) =>
              context.read<NotificationPrefsBloc>().add(NotifPrefToggled(key));

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            children: [
              // ── Section 1 : Protections critiques ──────────────────────
              _buildSectionHeader(context,
                  title: 'PROTECTIONS CRITIQUES', titleColor: kError),
              _buildLockedTile(context,
                icon: Icons.verified_rounded,
                label: 'Livraison confirmée',
                subtitle: 'SMS automatique si push non reçu',
              ),
              _buildLockedTile(context,
                icon: Icons.payments_rounded,
                label: 'Paiement reçu',
                subtitle: 'SMS automatique si push non reçu',
              ),
              _buildLockedTile(context,
                icon: Icons.gavel_rounded,
                label: 'Litige ouvert',
                subtitle: 'SMS automatique si push non reçu',
              ),
              const SizedBox(height: DonySpacing.sm),
              _buildCriticalBanner(context),
              const SizedBox(height: DonySpacing.xl),
              // ── Section 2 : Activité ────────────────────────────────────
              _buildSectionHeader(context,
                  title: 'ACTIVITÉ',
                  titleColor: const Color(0xFFD97706)),
              DonyListSection(
                title: '',
                tiles: [
                  _buildTile(context,
                    label: 'Matchs & enchères',
                    subtitle: 'Demandes, acceptations, remise, annulation…',
                    key: 'push_activity_bids',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(context,
                    label: 'Négociations',
                    subtitle: 'Propositions, contre-offres, paiements…',
                    key: 'push_activity_negotiations',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(context,
                    label: 'Messages',
                    subtitle: 'Nouveaux messages reçus',
                    key: 'push_messages',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(context,
                    label: 'Rappel trajet J-1',
                    subtitle: 'La veille de chaque trajet',
                    key: 'push_trip_reminder',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xl),
              // ── Section 3 : Actus & promotions ─────────────────────────
              _buildSectionHeader(context,
                  title: 'ACTUS & PROMOTIONS',
                  titleColor: Theme.of(context).colorScheme.onSurfaceVariant),
              DonyListSection(
                title: '',
                tiles: [
                  _buildTile(context,
                    label: 'Actus dony (Push)',
                    key: 'push_promo',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                  _buildTile(context,
                    label: 'Actus dony (E-mail)',
                    key: 'email_promo',
                    prefs: state.prefs,
                    onToggle: toggle,
                  ),
                ],
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
              .slideY(begin: 0.04, duration: 280.ms, curve: Curves.easeOutCubic);
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    Color? titleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: titleColor ??
                  Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }

  Widget _buildLockedTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 4),
      child: DonyListTile(
        icon: icon,
        iconColor: kError,
        iconBgColor: cs.errorContainer,
        label: label,
        // Si DonyListTile n'a pas de paramètre subtitle, remplace les deux
        // lignes ci-dessous par : label: '$label\n$subtitle',
        subtitle: subtitle,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Toujours actif',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildCriticalBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.errorContainer.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: kError),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'Ces notifications protègent vos transactions. '
              'Elles ne peuvent pas être désactivées.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  DonyListTile _buildTile(
    BuildContext context, {
    required String label,
    required String key,
    required Map<String, bool> prefs,
    required void Function(String) onToggle,
    String? subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isOn = prefs[key] ?? false;

    return DonyListTile(
      icon: isOn
          ? Icons.notifications_active_rounded
          : Icons.notifications_off_outlined,
      iconColor: isOn ? cs.primary : cs.onSurfaceVariant,
      iconBgColor: isOn
          ? cs.primaryContainer
          : cs.onSurfaceVariant.withValues(alpha: 0.12),
      label: label,
      // Si DonyListTile n'a pas de paramètre subtitle, remplace les deux
      // lignes ci-dessous par : label: subtitle != null ? '$label\n$subtitle' : label,
      subtitle: subtitle,
      trailing: Switch(value: isOn, onChanged: (_) => onToggle(key)),
      onTap: () => onToggle(key),
    );
  }
}
```

- [ ] **Step 5 : Vérifier que les tests passent**

```bash
flutter test test/features/settings/presentation/notification_settings_screen_test.dart --no-pub
```

Attendu : tous PASS.

- [ ] **Step 6 : Vérifier la suite de tests complète**

```bash
flutter test --no-pub
```

Attendu : tous PASS (aucune régression).

- [ ] **Step 7 : Commit**

```bash
git add lib/features/settings/presentation/screens/notification_settings_screen.dart \
        test/features/settings/presentation/notification_settings_screen_test.dart
git commit -m "feat(settings/notif): redesign écran Notifications — 3 niveaux, critiques verrouillées, 20 types couverts"
```

---

## Checklist finale

- [ ] `flutter analyze` sans erreur : `flutter analyze lib/ test/`
- [ ] Couverture ≥ 90 % : `flutter test --coverage`
- [ ] Les 6 clés Hive nouvelles sont les seules dans `_defaults`
- [ ] Aucun toggle SMS dans l'UI
- [ ] Les 3 tiles critiques ne dispatchent aucun event au tap
- [ ] Les sous-titres descriptifs sont visibles sur les tiles d'activité
- [ ] Le bandeau "Ces notifications protègent vos transactions" est affiché
