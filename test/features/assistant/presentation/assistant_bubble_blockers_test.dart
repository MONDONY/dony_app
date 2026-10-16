import 'package:dony/app/router.dart';
import 'package:dony/features/assistant/presentation/assistant_bubble_blockers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PopupRoute<void> _popup() =>
    RawDialogRoute<void>(pageBuilder: (_, _, _) => const SizedBox());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AssistantBubbleBlockers blockers;
  late AssistantModalObserver observer;
  final page = MaterialPageRoute<void>(builder: (_) => const SizedBox());

  setUp(() {
    blockers = AssistantBubbleBlockers();
    observer = AssistantModalObserver(blockers);
  });

  test('inactif au départ', () {
    expect(blockers.active.value, isFalse);
  });

  test('une feuille ou un dialogue (PopupRoute) bloque, la page non', () {
    observer.didPush(page, null);
    expect(blockers.active.value, isFalse);
    final dialog = _popup();
    observer.didPush(dialog, page);
    expect(blockers.active.value, isTrue);
    observer.didPop(dialog, page);
    expect(blockers.active.value, isFalse);
  });

  test('plusieurs modales : actif jusqu’à la dernière fermée', () {
    final a = _popup();
    final b = _popup();
    observer
      ..didPush(a, page)
      ..didPush(b, a);
    observer.didPop(b, a);
    expect(blockers.active.value, isTrue);
    observer.didPop(a, page);
    expect(blockers.active.value, isFalse);
  });

  test('retrait sans pop (didRemove) libère aussi', () {
    final a = _popup();
    observer.didPush(a, page);
    observer.didRemove(a, page);
    expect(blockers.active.value, isFalse);
  });

  test('remplacement : l’ancienne libère, la nouvelle bloque', () {
    final a = _popup();
    observer.didPush(a, page);
    observer.didReplace(newRoute: page, oldRoute: a);
    expect(blockers.active.value, isFalse);
    observer.didReplace(newRoute: a, oldRoute: page);
    expect(blockers.active.value, isTrue);
  });

  test('un relâchement en trop ne rend pas le compteur négatif', () {
    blockers.release();
    blockers.acquire();
    expect(blockers.active.value, isTrue);
    blockers.release();
    expect(blockers.active.value, isFalse);
  });

  test('l’observateur de l’app est branché sur appRouter', () {
    expect(
      appRouter.routerDelegate.builder.observers,
      contains(assistantModalObserver),
    );
  });

  group('HideAssistantBubble dans un onglet du shell', () {
    // Comme `StatefulShellRoute.indexedStack` : toutes les branches restent
    // montées, chacune sous un `TickerMode` qui ne l'active que si elle est
    // affichée.
    Future<ValueNotifier<int>> pumpTabs(
      WidgetTester tester,
      AssistantBubbleBlockers blockers,
    ) async {
      final index = ValueNotifier<int>(0);
      addTearDown(index.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<int>(
            valueListenable: index,
            builder: (_, current, _) => IndexedStack(
              index: current,
              children: [
                for (var i = 0; i < 2; i++)
                  TickerMode(
                    enabled: i == current,
                    child: i == 1
                        ? HideAssistantBubble(
                            blockers: blockers,
                            child: const Text('camera'),
                          )
                        : const Text('accueil'),
                  ),
              ],
            ),
          ),
        ),
      );
      return index;
    }

    testWidgets('l’onglet caméra bloque seulement tant qu’il est affiché', (
      tester,
    ) async {
      final index = await pumpTabs(tester, blockers);
      await tester.pump();
      expect(blockers.active.value, isFalse, reason: 'onglet caméra caché');
      index.value = 1;
      await tester.pump();
      await tester.pump();
      expect(blockers.active.value, isTrue);
      index.value = 0;
      await tester.pump();
      await tester.pump();
      expect(
        blockers.active.value,
        isFalse,
        reason: 'la branche reste montée hors écran, sans bloquer la bulle',
      );
      index.value = 1;
      await tester.pump();
      await tester.pump();
      expect(blockers.active.value, isTrue);
    });

    testWidgets('démonté pendant qu’il bloque : relâche une seule fois', (
      tester,
    ) async {
      final index = await pumpTabs(tester, blockers);
      index.value = 1;
      await tester.pump();
      await tester.pump();
      expect(blockers.active.value, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(blockers.active.value, isFalse);
      // Un compteur resté trop bas serait ici négatif puis faussé.
      blockers.acquire();
      expect(blockers.active.value, isTrue);
      blockers.release();
      expect(blockers.active.value, isFalse);
    });
  });
}
