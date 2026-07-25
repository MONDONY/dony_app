import 'dart:async';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final original = Animate.defaultDuration;
  tearDown(() => Animate.defaultDuration = original);
  await testMain();
}
