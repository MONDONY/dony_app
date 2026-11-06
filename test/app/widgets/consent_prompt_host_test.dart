import 'dart:async';

import 'package:dony/app/widgets/consent_prompt_host.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/consent_prompt.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/l10n_test_helpers.dart';
import '../../helpers/mock_analytics_backend.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

class _Probe implements FirebaseSessionProbe {
  const _Probe({required this.real});
  final bool real;
  @override
  bool get hasSession => real;
  @override
  bool get isAnonymous => !real;
  @override
  bool get hasRealSession => real;
}

void main() {
  late ConsentPrompt prompt;
  const accept = Key('consent-sheet-accept');

  late Map<String, Object?> store;

  void register({required bool real}) {
    final hive = MockHiveService();
    final box = MockBox();
    store = {};
    when(() => hive.userPrefs).thenReturn(box);
    when(
      () => box.get(any<dynamic>()),
    ).thenAnswer((i) => store[i.positionalArguments.first as String]);
    when(() => box.put(any<dynamic>(), any<dynamic>())).thenAnswer((i) async {
      store[i.positionalArguments[0] as String] = i.positionalArguments[1];
    });
    getIt.registerSingleton<HiveService>(hive);
    prompt = ConsentPrompt();
    getIt.registerSingleton<ConsentPrompt>(prompt);
    getIt.registerSingleton<AnalyticsService>(_MockAnalytics());
    getIt.registerSingleton<FirebaseSessionProbe>(_Probe(real: real));
  }

  setUp(ConsentPromptHost.resetForTest);
  tearDown(() => getIt.reset());

  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    localizedApp(const ConsentPromptHost(child: Scaffold(body: SizedBox()))),
  );

  testWidgets('ouvre la feuille quand la demande est levée', (tester) async {
    register(real: true);
    await mount(tester);
    expect(find.byKey(accept), findsNothing);

    prompt.request();
    await tester.pumpAndSettle();

    expect(find.byKey(accept), findsOneWidget);
  });

  testWidgets('chaque ouverture est comptée comme une relance', (tester) async {
    register(real: true);
    await mount(tester);

    prompt.request();
    await tester.pumpAndSettle();

    expect(find.byKey(accept), findsOneWidget);
    expect(store['consent_reminder_count'], 1);
    expect(store['consent_reminder_last_at'], isA<String>());
  });

  testWidgets('session invitée : aucune relance comptée', (tester) async {
    register(real: false);
    prompt.request();
    await mount(tester);
    await tester.pumpAndSettle();

    expect(store['consent_reminder_count'], isNull);
  });

  testWidgets('demande levée avant le montage : ouvre au montage', (
    tester,
  ) async {
    register(real: true);
    prompt.request();
    await mount(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(accept), findsOneWidget);
  });

  testWidgets('session invitée : jamais de feuille', (tester) async {
    register(real: false);
    prompt.request();
    await mount(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(accept), findsNothing);
  });

  testWidgets('au plus une ouverture par lancement, même après un geste', (
    tester,
  ) async {
    register(real: true);
    prompt.request();
    await mount(tester);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 20));
    await tester.pumpAndSettle();
    expect(find.byKey(accept), findsNothing);

    prompt.request();
    await tester.pumpAndSettle();

    expect(find.byKey(accept), findsNothing);
  });

  testWidgets("n'ouvre pas par-dessus une autre route, puis ouvre au retour", (
    tester,
  ) async {
    register(real: true);
    late BuildContext ctx;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (c) {
            ctx = c;
            return const ConsentPromptHost(child: Scaffold(body: SizedBox()));
          },
        ),
      ),
    );
    unawaited(
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('autre')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    prompt.request();
    await tester.pumpAndSettle();
    expect(find.byKey(accept), findsNothing);

    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(accept), findsOneWidget);
  });
}
