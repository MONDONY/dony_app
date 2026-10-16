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

  group('assistantRouteInShell', () {
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
      ],
    );

    test('racine d’onglet et route sous une branche', () {
      expect(assistantRouteInShell(shellRouter, '/home'), isTrue);
      expect(assistantRouteInShell(shellRouter, '/messages'), isTrue);
      expect(assistantRouteInShell(shellRouter, '/home/detail'), isTrue);
      expect(assistantRouteInShell(shellRouter, '/home?x=1'), isTrue);
    });

    test('ShellRoute simple', () {
      expect(assistantRouteInShell(shellRouter, '/dans-shell'), isTrue);
    });

    test('route hors shell, inconnue ou invalide', () {
      expect(assistantRouteInShell(shellRouter, '/assistant'), isFalse);
      expect(assistantRouteInShell(shellRouter, '/nulle-part'), isFalse);
      expect(assistantRouteInShell(shellRouter, 'home'), isFalse);
      expect(
        assistantRouteInShell(shellRouter, '//evil.example/home'),
        isFalse,
      );
    });
  });
}
