import 'package:dony/features/assistant/presentation/widgets/assistant_route_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const SizedBox(),
        routes: [
          GoRoute(path: 'edit/phone', builder: (_, _) => const SizedBox()),
        ],
      ),
      GoRoute(
        path: '/support/tickets/:id',
        builder: (_, _) => const SizedBox(),
      ),
    ],
  );

  test('route connue', () {
    expect(assistantRouteExists(router, '/profile/edit/phone'), isTrue);
  });

  test('route inconnue', () {
    expect(assistantRouteExists(router, '/nulle-part'), isFalse);
  });

  test('chaîne invalide ou vide', () {
    expect(assistantRouteExists(router, 'pas une route'), isFalse);
    expect(assistantRouteExists(router, 'profile'), isFalse);
    expect(assistantRouteExists(router, ''), isFalse);
    expect(assistantRouteExists(router, '//evil.example/profile'), isFalse);
    expect(
      assistantRouteExists(router, 'https://evil.example/profile'),
      isFalse,
    );
  });

  test('segment dynamique', () {
    expect(assistantRouteExists(router, '/support/tickets/abc-123'), isTrue);
  });

  test('paramètres de requête et fragment', () {
    expect(
      assistantRouteExists(router, '/profile/edit/phone?from=bot'),
      isTrue,
    );
    expect(assistantRouteExists(router, '/profile#x'), isTrue);
    expect(assistantRouteExists(router, '/nulle-part?a=1'), isFalse);
  });

  test('chemin incomplet d’une route imbriquée', () {
    expect(assistantRouteExists(router, '/profile/edit'), isFalse);
  });

  test('une redirection n’est pas suivie : la route reste existante', () {
    final redirecting = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/ancienne',
          redirect: (_, _) => '/profile',
          builder: (_, _) => const SizedBox(),
        ),
        GoRoute(path: '/profile', builder: (_, _) => const SizedBox()),
      ],
    );
    expect(assistantRouteExists(redirecting, '/ancienne'), isTrue);
  });

  group('assistantRouteNeedsGo', () {
    final shellRouter = GoRouter(
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => shell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, _) => const SizedBox(),
                  routes: [
                    GoRoute(
                      path: 'detail',
                      builder: (_, _) => const SizedBox(),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/messages', builder: (_, _) => const SizedBox()),
              ],
            ),
          ],
        ),
        ShellRoute(
          builder: (_, _, child) => child,
          routes: [
            GoRoute(path: '/dans-shell', builder: (_, _) => const SizedBox()),
          ],
        ),
        GoRoute(path: '/assistant', builder: (_, _) => const SizedBox()),
        // Comme `/flights/alerts` : hors shell, mais redirigée vers un onglet
        // quand le flag est éteint.
        GoRoute(
          path: '/alertes',
          redirect: (_, _) => '/home',
          builder: (_, _) => const SizedBox(),
          routes: [
            GoRoute(path: ':id/vols', builder: (_, _) => const SizedBox()),
          ],
        ),
        // Comme `/flights` : redirection seule, sans écran.
        GoRoute(path: '/ancien-onglet', redirect: (_, _) => '/messages'),
      ],
    );

    test('racine d’onglet et route sous une branche', () {
      expect(assistantRouteNeedsGo(shellRouter, '/home'), isTrue);
      expect(assistantRouteNeedsGo(shellRouter, '/messages'), isTrue);
      expect(assistantRouteNeedsGo(shellRouter, '/home/detail'), isTrue);
      expect(assistantRouteNeedsGo(shellRouter, '/home?x=1'), isTrue);
    });

    test('ShellRoute simple', () {
      expect(assistantRouteNeedsGo(shellRouter, '/dans-shell'), isTrue);
    });

    test('route qui porte une redirection (elle-même ou un parent) : go, '
        'même hors shell', () {
      expect(assistantRouteNeedsGo(shellRouter, '/alertes'), isTrue);
      expect(assistantRouteNeedsGo(shellRouter, '/alertes/a1/vols'), isTrue);
      expect(assistantRouteNeedsGo(shellRouter, '/ancien-onglet'), isTrue);
    });

    test('route hors shell, inconnue ou invalide', () {
      expect(assistantRouteNeedsGo(shellRouter, '/assistant'), isFalse);
      expect(assistantRouteNeedsGo(shellRouter, '/nulle-part'), isFalse);
      expect(assistantRouteNeedsGo(shellRouter, 'home'), isFalse);
      expect(
        assistantRouteNeedsGo(shellRouter, '//evil.example/home'),
        isFalse,
      );
    });
  });
}
