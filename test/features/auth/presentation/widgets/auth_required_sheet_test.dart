import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/l10n_test_helpers.dart';

Widget _app({AuthRequiredReason reason = AuthRequiredReason.explore}) =>
    MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      AuthRequiredSheet.show(context, reason: reason),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/auth/method',
            builder: (_, _) => const Scaffold(body: Text('auth-method')),
          ),
        ],
      ),
    );

Future<void> _open(
  WidgetTester tester, {
  AuthRequiredReason reason = AuthRequiredReason.explore,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(reason: reason));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('AuthRequiredSheet', () {
    testWidgets('affiche le titre et les actions en français', (tester) async {
      await _open(tester);

      expect(find.text('Connexion requise'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Continuer à explorer'), findsOneWidget);
      expect(
        find.text('Connecte-toi pour utiliser cette action.'),
        findsOneWidget,
      );
    });

    testWidgets('adapte le texte au motif « signaler »', (tester) async {
      await _open(tester, reason: AuthRequiredReason.report);

      expect(
        find.text('Connecte-toi pour signaler une annonce.'),
        findsOneWidget,
      );
    });

    testWidgets('adapte le texte au motif « proposer »', (tester) async {
      await _open(tester, reason: AuthRequiredReason.offer);

      expect(
        find.text('Connecte-toi pour proposer ton trajet en toute sécurité.'),
        findsOneWidget,
      );
    });

    testWidgets('« Se connecter » mène à la connexion', (tester) async {
      await _open(tester);

      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(find.text('auth-method'), findsOneWidget);
    });

    testWidgets('affiche la fenêtre en anglais', (tester) async {
      useEnglish();
      await _open(tester);

      expect(find.text('Sign-in required'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Keep exploring'), findsOneWidget);
    });
  });
}
