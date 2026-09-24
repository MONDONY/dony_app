import 'dart:async';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Symboles de date de toutes les locales : les formats suivent désormais la
  // langue de l'app (AppL10n.localeName), plus seulement 'fr'.
  await initializeDateFormatting();
  final original = Animate.defaultDuration;
  tearDown(() => Animate.defaultDuration = original);
  await testMain();
}
