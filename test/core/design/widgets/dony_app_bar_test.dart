import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/widgets/dony_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// GoRouter wrapper — widget sits on a child route so context.canPop() == true.
Widget wrapWithRouter(Widget Function(BuildContext ctx) builder) {
  final router = GoRouter(
    initialLocation: '/child',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => const Scaffold(body: Text('Root')),
        routes: [
          GoRoute(
            path: 'child',
            builder: (ctx, _) => Scaffold(
              appBar: builder(ctx) as PreferredSizeWidget?,
              body: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
}

Widget wrapAppBar(DonyAppBar appBar) => wrapWithRouter((_) => appBar);

Widget wrapSliver({bool showBack = true}) {
  final router = GoRouter(
    initialLocation: '/child',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => const Scaffold(body: Text('Root')),
        routes: [
          GoRoute(
            path: 'child',
            builder: (ctx, _) => Scaffold(
              body: CustomScrollView(
                slivers: [
                  DonySliverAppBar(
                    title: 'Sliver Title',
                    showBackButton: showBack,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
}

// ─── Matcher helper ────────────────────────────────────────────────────────────

Iterable<Container> styledContainers(WidgetTester tester) =>
    tester.widgetList<Container>(find.byType(Container)).where((c) {
      final decoration = c.decoration;
      if (decoration is BoxDecoration) {
        return decoration.borderRadius == BorderRadius.circular(DonyRadius.iconBtn);
      }
      return false;
    });

// ─────────────────────────────────────────────────────────────────────────────
//  DonyAppBar
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('DonyAppBar', () {
    // ── Container with BorderRadius(10) ───────────────────────────────────────

    testWidgets('renders a Container with BorderRadius(10) when showBackButton',
        (tester) async {
      await tester.pumpWidget(
        wrapAppBar(const DonyAppBar(title: 'Test')),
      );
      await tester.pump();

      expect(styledContainers(tester), isNotEmpty,
          reason: 'Expected a Container with BorderRadius.circular(10)');
    });

    // ── Default icon: chevron_left_rounded ────────────────────────────────────

    testWidgets('uses Icons.chevron_left_rounded by default', (tester) async {
      await tester.pumpWidget(
        wrapAppBar(const DonyAppBar(title: 'Test')),
      );
      await tester.pump();

      final chevrons = tester
          .widgetList<Icon>(find.byType(Icon))
          .where((i) => i.icon == Icons.chevron_left_rounded);
      expect(chevrons, isNotEmpty,
          reason: 'chevron_left_rounded icon not found in DonyAppBar');
    });

    // ── leadingIcon: Icons.close_rounded ─────────────────────────────────────

    testWidgets('uses Icons.close_rounded when leadingIcon is close_rounded',
        (tester) async {
      await tester.pumpWidget(
        wrapAppBar(const DonyAppBar(
          title: 'Modal',
          leadingIcon: Icons.close_rounded,
        )),
      );
      await tester.pump();

      final closeIcons = tester
          .widgetList<Icon>(find.byType(Icon))
          .where((i) => i.icon == Icons.close_rounded);
      expect(closeIcons, isNotEmpty,
          reason: 'close_rounded icon not found in DonyAppBar leading');

      // Styled container still present
      expect(styledContainers(tester), isNotEmpty,
          reason: 'Styled container must be present for close icon too');
    });

    // ── showBackButton: false ─────────────────────────────────────────────────

    testWidgets('renders no chevron when showBackButton: false', (tester) async {
      await tester.pumpWidget(
        wrapAppBar(const DonyAppBar(title: 'NoBack', showBackButton: false)),
      );
      await tester.pump();

      expect(
        tester
            .widgetList<Icon>(find.byType(Icon))
            .where((i) => i.icon == Icons.chevron_left_rounded),
        isEmpty,
      );
    });

    // ── Tooltip logic ─────────────────────────────────────────────────────────

    testWidgets("tooltip is 'Retour' by default", (tester) async {
      await tester.pumpWidget(
        wrapAppBar(const DonyAppBar(title: 'Test')),
      );
      await tester.pump();

      final iconButton = tester.widget<IconButton>(find.byType(IconButton).first);
      expect(iconButton.tooltip, 'Retour');
    });

    testWidgets("tooltip is 'Fermer' when leadingIcon is provided", (tester) async {
      await tester.pumpWidget(
        wrapAppBar(const DonyAppBar(
          title: 'Modal',
          leadingIcon: Icons.close_rounded,
        )),
      );
      await tester.pump();

      final iconButton = tester.widget<IconButton>(find.byType(IconButton).first);
      expect(iconButton.tooltip, 'Fermer');
    });

    // ── Title rendered ────────────────────────────────────────────────────────

    testWidgets('renders the title text', (tester) async {
      await tester.pumpWidget(
        wrapAppBar(const DonyAppBar(title: 'Mon titre', showBackButton: false)),
      );
      await tester.pump();

      expect(find.text('Mon titre'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  //  DonySliverAppBar
  // ─────────────────────────────────────────────────────────────────────────────

  group('DonySliverAppBar', () {
    testWidgets('renders Container with BorderRadius(10) when showBackButton',
        (tester) async {
      await tester.pumpWidget(wrapSliver());
      await tester.pump();

      expect(styledContainers(tester), isNotEmpty,
          reason: 'DonySliverAppBar should have a Container with radius 10');
    });

    testWidgets('uses chevron_left_rounded icon', (tester) async {
      await tester.pumpWidget(wrapSliver());
      await tester.pump();

      final chevrons = tester
          .widgetList<Icon>(find.byType(Icon))
          .where((i) => i.icon == Icons.chevron_left_rounded);
      expect(chevrons, isNotEmpty);
    });

    testWidgets('renders no leading when showBackButton: false', (tester) async {
      await tester.pumpWidget(wrapSliver(showBack: false));
      await tester.pump();

      expect(
        tester
            .widgetList<Icon>(find.byType(Icon))
            .where((i) => i.icon == Icons.chevron_left_rounded),
        isEmpty,
      );
    });
  });
}
