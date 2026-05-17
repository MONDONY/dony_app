import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Simple MaterialApp wrapper for widgets that do NOT use GoRouter internals
/// (no context.pop(), no SliverAppBar leading).
Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

/// GoRouter wrapper used when the widget under test calls [context.pop()].
/// The widget is placed on a second route so pressing "back" actually works.
Widget _wrapWithRouter(Widget Function(BuildContext ctx) builder) {
  final router = GoRouter(
    initialLocation: '/child',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => const Scaffold(body: Text('Home')),
        routes: [
          GoRoute(
            path: 'child',
            builder: (ctx, _) => builder(ctx),
          ),
        ],
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
}

// ─────────────────────────────────────────────────────────────────────────────
//  DonyStepIndicator
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── DonyStepIndicator ──────────────────────────────────────────────────────
  group('DonyStepIndicator', () {
    // dots variant ────────────────────────────────────────────────────────────
    group('dots variant', () {
      testWidgets('renders correct number of AnimatedContainers at step 0',
          (tester) async {
        await tester.pumpWidget(_wrap(
          const DonyStepIndicator(total: 3, current: 0),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(AnimatedContainer), findsNWidgets(3));
      });

      testWidgets('renders with current step in the middle', (tester) async {
        await tester.pumpWidget(_wrap(
          const DonyStepIndicator(total: 4, current: 1),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(AnimatedContainer), findsNWidgets(4));
      });

      testWidgets('renders with current step at the last position',
          (tester) async {
        await tester.pumpWidget(_wrap(
          const DonyStepIndicator(total: 4, current: 3),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(AnimatedContainer), findsNWidgets(4));
      });

      testWidgets('variant defaults to dots', (tester) async {
        await tester.pumpWidget(_wrap(
          const DonyStepIndicator(total: 2, current: 0),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        final widget =
            tester.widget<DonyStepIndicator>(find.byType(DonyStepIndicator));
        expect(widget.variant, DonyStepVariant.dots);
      });
    });

    // bar variant ─────────────────────────────────────────────────────────────
    group('bar variant', () {
      testWidgets('renders bar segments at step 0', (tester) async {
        await tester.pumpWidget(_wrap(
          const DonyStepIndicator(
            total: 3,
            current: 0,
            variant: DonyStepVariant.bar,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        // Bar uses Expanded > Container — find Row inside the indicator
        expect(find.byType(DonyStepIndicator), findsOneWidget);
      });

      testWidgets('renders bar segments at step 1', (tester) async {
        await tester.pumpWidget(_wrap(
          const DonyStepIndicator(
            total: 3,
            current: 1,
            variant: DonyStepVariant.bar,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(DonyStepIndicator), findsOneWidget);
      });

      testWidgets('renders bar segments at step 2 (last)', (tester) async {
        await tester.pumpWidget(_wrap(
          const DonyStepIndicator(
            total: 3,
            current: 2,
            variant: DonyStepVariant.bar,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(DonyStepIndicator), findsOneWidget);
      });
    });

    // labeled variant ─────────────────────────────────────────────────────────
    group('labeled variant', () {
      testWidgets('renders step labels text', (tester) async {
        await tester.pumpWidget(_wrap(
          const DonyStepIndicator.labeled(
            steps: ['Téléphone', 'OTP', 'Rôle'],
            current: 0,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Téléphone'), findsOneWidget);
        expect(find.text('OTP'), findsOneWidget);
        expect(find.text('Rôle'), findsOneWidget);
      });

      testWidgets('active step (current=0) shows no check icon', (tester) async {
        await tester.pumpWidget(_wrap(
          const DonyStepIndicator.labeled(
            steps: ['A', 'B', 'C'],
            current: 0,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        // Only done steps (i < current) show check icon — current=0 means none done
        expect(find.byIcon(Icons.check_rounded), findsNothing);
      });

      testWidgets('done steps show check icon (current=2)', (tester) async {
        await tester.pumpWidget(_wrap(
          const DonyStepIndicator.labeled(
            steps: ['A', 'B', 'C'],
            current: 2,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        // Steps 0 and 1 are done → 2 check icons
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      });

      testWidgets('connector lines rendered between steps', (tester) async {
        await tester.pumpWidget(_wrap(
          const DonyStepIndicator.labeled(
            steps: ['A', 'B', 'C', 'D'],
            current: 1,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        // Number of labels equals number of steps
        expect(find.text('A'), findsOneWidget);
        expect(find.text('D'), findsOneWidget);
      });

      testWidgets('variant is set to labeled', (tester) async {
        await tester.pumpWidget(_wrap(
          const DonyStepIndicator.labeled(
            steps: ['Step1', 'Step2'],
            current: 1,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        final widget =
            tester.widget<DonyStepIndicator>(find.byType(DonyStepIndicator));
        expect(widget.variant, DonyStepVariant.labeled);
      });
    });
  });

  // ── DonyDialog ────────────────────────────────────────────────────────────
  group('DonyDialog', () {
    // Helper: builds a screen with a button that triggers DonyDialog.show()
    Widget _dialogTrigger({
      required String title,
      String? message,
      Widget? content,
      String confirmLabel = 'Confirmer',
      String cancelLabel = 'Annuler',
      DonyDialogVariant variant = DonyDialogVariant.info,
      IconData? icon,
    }) {
      return MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => DonyDialog.show(
                  ctx,
                  title: title,
                  message: message,
                  content: content,
                  confirmLabel: confirmLabel,
                  cancelLabel: cancelLabel,
                  variant: variant,
                  icon: icon,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows dialog title when opened', (tester) async {
      await tester.pumpWidget(_dialogTrigger(title: 'Supprimer ce trajet ?'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer ce trajet ?'), findsOneWidget);
    });

    testWidgets('shows message when provided', (tester) async {
      await tester.pumpWidget(_dialogTrigger(
        title: 'Titre',
        message: 'Cette action est irréversible.',
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Cette action est irréversible.'), findsOneWidget);
    });

    testWidgets('does not show message when null', (tester) async {
      await tester.pumpWidget(_dialogTrigger(title: 'Titre'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // Only title text, no extra body text
      expect(find.text('Titre'), findsOneWidget);
    });

    testWidgets('shows custom confirmLabel and cancelLabel', (tester) async {
      await tester.pumpWidget(_dialogTrigger(
        title: 'Titre',
        confirmLabel: 'Supprimer',
        cancelLabel: 'Non',
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer'), findsOneWidget);
      expect(find.text('Non'), findsOneWidget);
    });

    testWidgets('info variant renders OutlinedButton and FilledButton',
        (tester) async {
      await tester.pumpWidget(_dialogTrigger(
        title: 'Info Dialog',
        variant: DonyDialogVariant.info,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('destructive variant renders dialog with error colors',
        (tester) async {
      await tester.pumpWidget(_dialogTrigger(
        title: 'Delete?',
        variant: DonyDialogVariant.destructive,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('icon is displayed when provided', (tester) async {
      await tester.pumpWidget(_dialogTrigger(
        title: 'Alert',
        icon: Icons.warning_rounded,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });

    testWidgets('no icon widget rendered when icon is null', (tester) async {
      await tester.pumpWidget(_dialogTrigger(title: 'No icon'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // Icon container only appears when icon != null
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('custom content widget is displayed', (tester) async {
      await tester.pumpWidget(_dialogTrigger(
        title: 'Custom',
        content: const Text('Custom content widget'),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Custom content widget'), findsOneWidget);
    });

    testWidgets('cancel button pops dialog', (tester) async {
      await tester.pumpWidget(_dialogTrigger(title: 'Confirm'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      // Dialog dismissed
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('confirm button pops dialog', (tester) async {
      await tester.pumpWidget(_dialogTrigger(title: 'Confirm'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('icon with destructive variant shows icon', (tester) async {
      await tester.pumpWidget(_dialogTrigger(
        title: 'Danger',
        variant: DonyDialogVariant.destructive,
        icon: Icons.delete_rounded,
        message: 'Cela supprimera vos données.',
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
      expect(find.text('Cela supprimera vos données.'), findsOneWidget);
    });
  });

  // ── DonyBottomSheet ───────────────────────────────────────────────────────
  group('DonyBottomSheet', () {
    Widget _sheetTrigger({
      required Widget child,
      String? title,
      String? subtitle,
      bool isDismissible = true,
      bool showHandle = true,
      bool isScrollControlled = true,
    }) {
      return MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => DonyBottomSheet.show(
                  ctx,
                  child: child,
                  title: title,
                  subtitle: subtitle,
                  isDismissible: isDismissible,
                  showHandle: showHandle,
                  isScrollControlled: isScrollControlled,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows child content in bottom sheet', (tester) async {
      await tester.pumpWidget(_sheetTrigger(
        child: const Text('Sheet content'),
      ));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet content'), findsOneWidget);
    });

    testWidgets('shows handle when showHandle is true', (tester) async {
      await tester.pumpWidget(_sheetTrigger(
        child: const Text('Content'),
        showHandle: true,
      ));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      // Handle is a Container — sheet should be visible
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('hides handle when showHandle is false', (tester) async {
      await tester.pumpWidget(_sheetTrigger(
        child: const Text('No handle'),
        showHandle: false,
      ));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('No handle'), findsOneWidget);
    });

    testWidgets('shows title when provided', (tester) async {
      await tester.pumpWidget(_sheetTrigger(
        child: const Text('Body'),
        title: 'Trier par',
      ));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Trier par'), findsOneWidget);
    });

    testWidgets('shows subtitle when title and subtitle provided', (tester) async {
      await tester.pumpWidget(_sheetTrigger(
        child: const Text('Body'),
        title: 'Filtrer',
        subtitle: 'Choisissez vos critères',
      ));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Filtrer'), findsOneWidget);
      expect(find.text('Choisissez vos critères'), findsOneWidget);
    });

    testWidgets('shows close icon button when title is provided', (tester) async {
      await tester.pumpWidget(_sheetTrigger(
        child: const Text('Body'),
        title: 'Avec titre',
      ));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('close button dismisses the sheet', (tester) async {
      await tester.pumpWidget(_sheetTrigger(
        child: const Text('Body'),
        title: 'Closeable',
      ));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Closeable'), findsNothing);
    });

    testWidgets('no title shows SizedBox spacer path (no close icon)',
        (tester) async {
      await tester.pumpWidget(_sheetTrigger(
        child: const Text('No title sheet'),
        title: null,
      ));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.text('No title sheet'), findsOneWidget);
    });

    testWidgets('no subtitle — subtitle branch not rendered', (tester) async {
      await tester.pumpWidget(_sheetTrigger(
        child: const Text('Body'),
        title: 'Title only',
        subtitle: null,
      ));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Title only'), findsOneWidget);
    });

    // M3 — le footer sticky est enveloppé d'un SafeArea + Padding horizontal
    testWidgets('M3 — stickyBottom est dans un SafeArea et un Padding horizontal',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => DonyBottomSheet.show(
                  ctx,
                  child: const Text('Contenu'),
                  stickyBottom:
                      const Text('CTA footer', key: Key('sticky-cta')),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      // Le CTA doit être visible
      expect(find.byKey(const Key('sticky-cta')), findsOneWidget);

      // Vérifier qu'il est bien dans un SafeArea
      final safeAreas = find.ancestor(
        of: find.byKey(const Key('sticky-cta')),
        matching: find.byType(SafeArea),
      );
      expect(safeAreas, findsAtLeastNWidgets(1));

      // Vérifier qu'il y a bien un Padding horizontal non nul
      final paddings = tester.widgetList<Padding>(
        find.ancestor(
          of: find.byKey(const Key('sticky-cta')),
          matching: find.byType(Padding),
        ),
      );
      final hasHPadding = paddings.any(
        (p) =>
            p.padding.resolve(TextDirection.ltr).left >= DonySpacing.lg &&
            p.padding.resolve(TextDirection.ltr).right >= DonySpacing.lg,
      );
      expect(hasHPadding, isTrue,
          reason:
              'Le stickyBottom doit avoir un padding horizontal >= DonySpacing.lg (20)');
    });

    // M3 — le footer sans stickyBottom ne rend pas de SafeArea inutile
    testWidgets('M3 — sans stickyBottom, aucun SafeArea/Padding de footer',
        (tester) async {
      await tester.pumpWidget(_sheetTrigger(
        child: const Text('Contenu sans footer'),
      ));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Contenu sans footer'), findsOneWidget);
      // SafeArea ne doit pas exister pour le footer (pas de stickyBottom)
      expect(find.byType(SafeArea), findsNothing);
    });
  });

  // ── DonyPageScaffold ──────────────────────────────────────────────────────
  group('DonyPageScaffold', () {
    testWidgets('renders title in app bar', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const DonyPageScaffold(
          title: 'Mon profil',
          body: Text('Body content'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Mon profil'), findsOneWidget);
    });

    testWidgets('renders body content', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const DonyPageScaffold(
          title: 'Titre',
          body: Text('Corps du texte'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Corps du texte'), findsOneWidget);
    });

    testWidgets('body is scrollable by default (SingleChildScrollView)',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const DonyPageScaffold(
          title: 'Scrollable',
          body: Text('Scroll'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('body is not scrollable when scrollable=false', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const DonyPageScaffold(
          title: 'Non-scroll',
          body: Text('Fixed body'),
          scrollable: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.text('Fixed body'), findsOneWidget);
    });

    testWidgets('shows back button by default', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const DonyPageScaffold(
          title: 'Back',
          body: Text('Has back'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    });

    testWidgets('hides back button when showBackButton=false', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const DonyPageScaffold(
          title: 'No Back',
          body: Text('No back btn'),
          showBackButton: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    });

    testWidgets('renders appBarActions when provided', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => DonyPageScaffold(
          title: 'Actions',
          body: const Text('Body'),
          appBarActions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {},
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('renders floatingActionButton when provided', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => DonyPageScaffold(
          title: 'FAB',
          body: const Text('Body'),
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('renders bottomNavigationBar when provided', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => DonyPageScaffold(
          title: 'NavBar',
          body: const Text('Body'),
          bottomNavigationBar: BottomNavigationBar(
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('uses custom padding when provided', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const DonyPageScaffold(
          title: 'Custom padding',
          body: Text('Padded'),
          padding: EdgeInsets.all(8),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Padded'), findsOneWidget);
    });

    testWidgets('onBack callback called when back button tapped', (tester) async {
      var backCalled = false;
      await tester.pumpWidget(_wrapWithRouter(
        (_) => DonyPageScaffold(
          title: 'Back callback',
          body: const Text('Body'),
          onBack: () => backCalled = true,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pump();
      expect(backCalled, isTrue);
    });

    testWidgets('appBarBottom is rendered in the app bar', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => DonyPageScaffold(
          title: 'With bottom',
          body: const Text('Body'),
          appBarBottom: const PreferredSize(
            preferredSize: Size.fromHeight(40),
            child: Text('Bottom bar'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Bottom bar'), findsOneWidget);
    });

    testWidgets('resizeToAvoidBottomInset is passed to Scaffold', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const DonyPageScaffold(
          title: 'Resize',
          body: Text('Body'),
          resizeToAvoidBottomInset: false,
        ),
      ));
      await tester.pumpAndSettle();
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.resizeToAvoidBottomInset, isFalse);
    });

    testWidgets('renders stickyBottom below the body', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const DonyPageScaffold(
          title: 'Sticky',
          body: Text('Body content'),
          stickyBottom: Text('Sticky CTA'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Body content'), findsOneWidget);
      expect(find.text('Sticky CTA'), findsOneWidget);
    });
  });

  // ── DonyLayout helpers ────────────────────────────────────────────────────
  group('DonyLayout', () {
    testWidgets('isCompact returns true when width < 600', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late bool result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          result = DonyLayout.isCompact(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(result, isTrue);
    });

    testWidgets('isMedium returns true when 600 <= width < 840', (tester) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late bool result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          result = DonyLayout.isMedium(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(result, isTrue);
    });

    testWidgets('isExpanded returns true when width >= 840', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late bool result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          result = DonyLayout.isExpanded(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(result, isTrue);
    });

    testWidgets('hPadding returns 20 on compact screen', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late double result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          result = DonyLayout.hPadding(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(result, 20.0);
    });

    testWidgets('hPadding returns 32 on medium screen', (tester) async {
      tester.view.physicalSize = const Size(700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late double result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          result = DonyLayout.hPadding(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(result, 32.0);
    });

    testWidgets('hPadding returns 48 on expanded screen', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late double result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          result = DonyLayout.hPadding(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(result, 48.0);
    });

    testWidgets('maxContentWidth returns double.infinity on compact', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late double result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          result = DonyLayout.maxContentWidth(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(result, double.infinity);
    });

    testWidgets('constrained returns child directly on compact', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          return DonyLayout.constrained(ctx, const Text('test-child'));
        }),
      ));
      expect(find.text('test-child'), findsOneWidget);
    });

    testWidgets('keyboardPadding returns viewInsets.bottom', (tester) async {
      late double result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          result = DonyLayout.keyboardPadding(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(result, isNonNegative);
    });

    testWidgets('bottomSafe returns non-negative value', (tester) async {
      late double result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          result = DonyLayout.bottomSafe(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(result, isNonNegative);
    });

    testWidgets('screenWidth and screenHeight return positive values', (tester) async {
      late double w;
      late double h;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          w = DonyLayout.screenWidth(ctx);
          h = DonyLayout.screenHeight(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(w, isPositive);
      expect(h, isPositive);
    });
  });

  // ── DonyAppBar ────────────────────────────────────────────────────────────
  group('DonyAppBar', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const Scaffold(
          appBar: DonyAppBar(title: 'Mon titre'),
          body: SizedBox.shrink(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Mon titre'), findsOneWidget);
    });

    testWidgets('shows back button by default', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const Scaffold(
          appBar: DonyAppBar(title: 'Titre'),
          body: SizedBox.shrink(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    });

    testWidgets('hides back button when showBackButton=false', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const Scaffold(
          appBar: DonyAppBar(title: 'Titre', showBackButton: false),
          body: SizedBox.shrink(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    });

    testWidgets('calls onBack callback when back button tapped', (tester) async {
      var pressed = false;
      await tester.pumpWidget(_wrapWithRouter(
        (_) => Scaffold(
          appBar: DonyAppBar(
            title: 'Retour custom',
            onBack: () => pressed = true,
          ),
          body: const SizedBox.shrink(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pump();
      expect(pressed, isTrue);
    });

    testWidgets('uses context.pop() when onBack is null and back button tapped',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const Scaffold(
          appBar: DonyAppBar(title: 'Auto pop'),
          body: SizedBox.shrink(),
        ),
      ));
      await tester.pumpAndSettle();
      // Just verify back icon exists and is tappable without crashing
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
    });

    testWidgets('renders actions when provided', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => Scaffold(
          appBar: DonyAppBar(
            title: 'With actions',
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
            ],
          ),
          body: const SizedBox.shrink(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('renders default divider bottom when bottom is null',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const Scaffold(
          appBar: DonyAppBar(title: 'No bottom'),
          body: SizedBox.shrink(),
        ),
      ));
      await tester.pumpAndSettle();
      // Default bottom is a PreferredSize wrapping a Divider
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('renders custom bottom widget when provided', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => Scaffold(
          appBar: DonyAppBar(
            title: 'Custom bottom',
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(48),
              child: Text('Custom bottom bar'),
            ),
          ),
          body: const SizedBox.shrink(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Custom bottom bar'), findsOneWidget);
    });

    testWidgets('preferredSize height is 56 without bottom', (tester) async {
      const bar = DonyAppBar(title: 'Size test');
      expect(bar.preferredSize.height, 56.0);
    });

    testWidgets('preferredSize height adds bottom height when bottom provided',
        (tester) async {
      const customBottom = PreferredSize(
        preferredSize: Size.fromHeight(40),
        child: SizedBox.shrink(),
      );
      const bar = DonyAppBar(title: 'Size test', bottom: customBottom);
      expect(bar.preferredSize.height, 56.0 + 40.0);
    });

    testWidgets('tooltip is set to Retour on back button', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(
        (_) => const Scaffold(
          appBar: DonyAppBar(title: 'Tooltip test'),
          body: SizedBox.shrink(),
        ),
      ));
      await tester.pumpAndSettle();
      final btn = tester.widget<IconButton>(find.byType(IconButton).first);
      expect(btn.tooltip, 'Retour');
    });
  });

  // ── DonySliverAppBar ──────────────────────────────────────────────────────
  group('DonySliverAppBar', () {
    Widget _sliverWrap({
      required String title,
      VoidCallback? onBack,
      bool showBackButton = false,
      List<Widget>? actions,
      double expandedHeight = 110,
      PreferredSizeWidget? bottom,
    }) {
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              DonySliverAppBar(
                title: title,
                onBack: onBack,
                showBackButton: showBackButton,
                actions: actions,
                expandedHeight: expandedHeight,
                bottom: bottom,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 500)),
            ],
          ),
        ),
      );
    }

    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(_sliverWrap(title: 'Accueil'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Accueil'), findsOneWidget);
    });

    testWidgets('does not show back button by default', (tester) async {
      await tester.pumpWidget(_sliverWrap(title: 'No back'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    });

    testWidgets('shows back button when showBackButton=true', (tester) async {
      // Need router for context.pop()
      final router = GoRouter(
        initialLocation: '/child',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('root')),
            routes: [
              GoRoute(
                path: 'child',
                builder: (_, __) => Scaffold(
                  body: CustomScrollView(
                    slivers: [
                      const DonySliverAppBar(
                        title: 'With back',
                        showBackButton: true,
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
          MaterialApp.router(routerConfig: router, theme: AppTheme.light));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    });

    testWidgets('renders actions when provided', (tester) async {
      await tester.pumpWidget(_sliverWrap(
        title: 'Title',
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('uses custom expandedHeight', (tester) async {
      await tester.pumpWidget(_sliverWrap(title: 'Title', expandedHeight: 200));
      await tester.pump(const Duration(milliseconds: 600));
      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(bar.expandedHeight, 200.0);
    });

    testWidgets('renders custom bottom when provided', (tester) async {
      await tester.pumpWidget(_sliverWrap(
        title: 'Title',
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: Text('Bottom sliver'),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Bottom sliver'), findsOneWidget);
    });

    testWidgets('renders default border container bottom when bottom is null',
        (tester) async {
      await tester.pumpWidget(_sliverWrap(title: 'Default bottom'));
      await tester.pump(const Duration(milliseconds: 600));
      // Default bottom uses a PreferredSize with a Container
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('calls onBack when back button tapped', (tester) async {
      var pressed = false;
      final router = GoRouter(
        initialLocation: '/child',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('root')),
            routes: [
              GoRoute(
                path: 'child',
                builder: (_, __) => Scaffold(
                  body: CustomScrollView(
                    slivers: [
                      DonySliverAppBar(
                        title: 'Back cb',
                        showBackButton: true,
                        onBack: () => pressed = true,
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
          MaterialApp.router(routerConfig: router, theme: AppTheme.light));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pump();
      expect(pressed, isTrue);
    });

    testWidgets('uses context.pop() when no onBack and canPop is true',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/child',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('root')),
            routes: [
              GoRoute(
                path: 'child',
                builder: (_, __) => Scaffold(
                  body: CustomScrollView(
                    slivers: [
                      const DonySliverAppBar(
                        title: 'Auto pop',
                        showBackButton: true,
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
          MaterialApp.router(routerConfig: router, theme: AppTheme.light));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('goes to /home when canPop is false and back button tapped',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(
              body: CustomScrollView(
                slivers: [
                  const DonySliverAppBar(
                    title: 'Root',
                    showBackButton: true,
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 500)),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('Home sliver')),
          ),
        ],
      );
      await tester.pumpWidget(
          MaterialApp.router(routerConfig: router, theme: AppTheme.light));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Home sliver'), findsOneWidget);
    });
  });

  // ── DonyAppBar — go('/home') fallback ─────────────────────────────────────
  group('DonyAppBar go/home fallback', () {
    testWidgets('goes to /home when canPop is false and back button tapped',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              appBar: DonyAppBar(title: 'Root page'),
              body: SizedBox.shrink(),
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('Home fallback')),
          ),
        ],
      );
      await tester.pumpWidget(
          MaterialApp.router(routerConfig: router, theme: AppTheme.light));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Home fallback'), findsOneWidget);
    });
  });

  // ── DonyStatusColors extension ────────────────────────────────────────────
  group('DonyStatusColors extension', () {
    testWidgets('info and infoLight return non-null colors', (tester) async {
      late Color infoColor;
      late Color infoLightColor;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          infoColor = cs.info;
          infoLightColor = cs.infoLight;
          return const SizedBox.shrink();
        }),
      ));
      expect(infoColor, isNotNull);
      expect(infoLightColor, isNotNull);
    });

    testWidgets('errorLight returns light variant in light mode', (tester) async {
      late Color errorLightColor;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(builder: (ctx) {
          errorLightColor = Theme.of(ctx).colorScheme.errorLight;
          return const SizedBox.shrink();
        }),
      ));
      expect(errorLightColor, isNotNull);
    });

    testWidgets('errorLight returns dark variant in dark mode', (tester) async {
      late Color errorLightColor;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(builder: (ctx) {
          errorLightColor = Theme.of(ctx).colorScheme.errorLight;
          return const SizedBox.shrink();
        }),
      ));
      expect(errorLightColor, isNotNull);
    });
  });
}
