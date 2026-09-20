import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le scarabée de signalement ([DonyFeedbackButton]) est présent par défaut
/// dans les deux barres du design system : c'est ce qui le met sur chaque
/// écran sans que chaque écran ait à y penser.
void main() {
  Widget compact({bool? showFeedback, List<Widget>? actions}) {
    return MaterialApp(
      home: Scaffold(
        appBar: DonyAppBar(
          title: 'Titre',
          showFeedback: showFeedback ?? true,
          actions: actions,
        ),
        body: const SizedBox(),
      ),
    );
  }

  Widget sliver({bool? showFeedback, List<Widget>? actions}) {
    return MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            DonySliverAppBar(
              title: 'Titre',
              showFeedback: showFeedback ?? true,
              actions: actions,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
          ],
        ),
      ),
    );
  }

  group('DonyAppBar', () {
    testWidgets('affiche le scarabée par défaut, en dernière action', (
      tester,
    ) async {
      await tester.pumpWidget(
        compact(actions: [const Icon(Icons.share, key: Key('share'))]),
      );
      expect(find.byType(DonyFeedbackButton), findsOneWidget);
      // Le partage reste à gauche du scarabée.
      final share = tester.getCenter(find.byKey(const Key('share')));
      final bug = tester.getCenter(find.byType(DonyFeedbackButton));
      expect(share.dx, lessThan(bug.dx));
    });

    testWidgets('showFeedback: false le retire', (tester) async {
      await tester.pumpWidget(compact(showFeedback: false));
      expect(find.byType(DonyFeedbackButton), findsNothing);
    });

    testWidgets('pas de doublon quand l\'écran le place lui-même', (
      tester,
    ) async {
      await tester.pumpWidget(
        compact(
          actions: [
            const DonyFeedbackButton(),
            const Icon(Icons.share, key: Key('share')),
          ],
        ),
      );
      expect(find.byType(DonyFeedbackButton), findsOneWidget);
    });
  });

  group('DonySliverAppBar', () {
    testWidgets('affiche le scarabée par défaut', (tester) async {
      await tester.pumpWidget(sliver());
      expect(find.byType(DonyFeedbackButton), findsOneWidget);
    });

    testWidgets('showFeedback: false le retire', (tester) async {
      await tester.pumpWidget(sliver(showFeedback: false));
      expect(find.byType(DonyFeedbackButton), findsNothing);
    });
  });

  test('withFeedbackButton garde la liste telle quelle sans le drapeau', () {
    final actions = <Widget>[const SizedBox()];
    expect(withFeedbackButton(actions, false), same(actions));
    expect(withFeedbackButton(null, false), isNull);
    expect(withFeedbackButton(null, true), hasLength(1));
  });
}
