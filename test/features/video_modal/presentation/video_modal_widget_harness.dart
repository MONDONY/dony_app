import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/profile/presentation/screens/help_tutorial_player.dart';
import 'package:dony/features/video_modal/presentation/video_modal_host.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Écran de 360 dp de large, le plus étroit visé.
void usePhone360(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Chaque libellé de [DonyButton] tient sur une ligne à sa taille normale :
/// le `FittedBox(scaleDown)` du bouton ne doit jamais le rapetisser.
void expectButtonLabelsFit(WidgetTester tester) {
  final buttons = find.byType(DonyButton);
  expect(buttons, findsWidgets);
  for (var i = 0; i < buttons.evaluate().length; i++) {
    final label = find
        .descendant(
          of: buttons.at(i),
          matching: find.byWidgetPredicate((w) => w is Text && w.maxLines == 1),
        )
        .first;
    // Le FittedBox du libellé (pas celui d'une icône SVG).
    final fitted = find
        .ancestor(of: label, matching: find.byType(FittedBox))
        .first;
    final textWidth = tester.getSize(label).width;
    final room = tester.getSize(fitted).width;
    expect(
      textWidth,
      lessThanOrEqualTo(room + 0.5),
      reason: '« ${tester.widget<Text>(label).data} » rapetissé',
    );
  }
  expect(tester.takeException(), isNull);
}

/// Laisse passer les transitions sans attendre la fin d'une animation
/// infinie (indicateur de chargement du lecteur).
Future<void> settleTransitions(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Attend le délai d'ouverture d'un modal du shell (2 s), puis les
/// transitions.
Future<void> settleAfterOpenDelay(WidgetTester tester) async {
  // Le chargement et l'évaluation des déclencheurs d'abord, puis le délai.
  await settleTransitions(tester);
  await tester.pump(kVideoModalOpenDelay);
  await settleTransitions(tester);
}

ThemeData get testTheme => AppTheme.light();

MaterialApp appWith({required Widget home, Locale locale = AppL10n.fr}) =>
    MaterialApp(
      theme: testTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

/// Session de lecteur factice : les événements se poussent à la main.
class FakePlayerSession implements HelpTutorialPlayerSession {
  final controller = StreamController<HelpTutorialPlayerEvent>.broadcast(
    sync: true,
  );
  bool closed = false;

  void emit(HelpTutorialPlayerEvent e) => controller.add(e);

  @override
  Stream<HelpTutorialPlayerEvent> get events => controller.stream;

  @override
  Widget buildScaffold({required Widget Function(Widget player) pageBuilder}) =>
      pageBuilder(const SizedBox(key: Key('fake-player')));

  @override
  Future<void> close() async {
    closed = true;
    await controller.close();
  }
}
