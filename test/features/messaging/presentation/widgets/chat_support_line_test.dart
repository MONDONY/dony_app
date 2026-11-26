import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/contact_links.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:dony/features/messaging/presentation/widgets/chat_support_line.dart';
import 'package:dony/features/support/bloc/support_contact_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/recording_url_launcher.dart';
import '../../../../helpers/support_contact_test_helpers.dart';

class _MockConfig extends Mock implements IConfigRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockConfig config;
  late _MockAnalytics analytics;
  late RecordingUrlLauncher platform;
  late SupportContactCubit cubit;

  setUp(() {
    config = _MockConfig();
    analytics = _MockAnalytics();
    platform = RecordingUrlLauncher();
    installUrlLauncher(platform, addTearDown);
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    cubit = SupportContactCubit(
      config,
      analytics,
      launcher: ContactLinkLauncher(launcher: platform),
    );
    addTearDown(cubit.close);
  });

  Future<void> pumpLine(
    WidgetTester tester, {
    String? number,
    String? tripLabel = 'Paris → Abidjan · 12 déc. · 15 kg',
    Locale locale = AppL10n.fr,
    Size size = const Size(360, 800),
  }) async {
    when(
      () => config.getSupportWhatsappNumber(),
    ).thenAnswer((_) async => number);
    await cubit.load(source: 'chat');
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: Column(
            children: [
              ChatSupportLine(tripLabel: tripLabel, cubit: cubit),
              const Text('Fil de la discussion'),
            ],
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pump();
  }

  testWidgets('sans numéro : aucune ligne, rien ne prend de place', (
    tester,
  ) async {
    await pumpLine(tester);

    expect(find.byKey(const Key('chat-support-line')), findsNothing);
    expect(find.text('Écrire au support Yadony'), findsNothing);
    expect(find.text('Fil de la discussion'), findsOneWidget);
  });

  testWidgets('avec numéro : une ligne fine, texte sur une seule ligne', (
    tester,
  ) async {
    await pumpLine(tester, number: '+33612345678');

    expect(find.text('Écrire au support Yadony'), findsOneWidget);
    final line = tester.getSize(find.byKey(const Key('chat-support-line')));
    expect(line.height, lessThan(52));
    final label = tester.getSize(find.text('Écrire au support Yadony'));
    expect(label.height, lessThan(24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tient à 320 dp en français sans débordement', (tester) async {
    await pumpLine(tester, number: '+33612345678', size: const Size(320, 700));

    final label = tester.getSize(find.text('Écrire au support Yadony'));
    expect(label.height, lessThan(24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tient à 320 dp en anglais sans débordement', (tester) async {
    enableEnglish();
    await pumpLine(
      tester,
      number: '+33612345678',
      locale: AppL10n.en,
      size: const Size(320, 700),
    );

    final label = tester.getSize(find.text('Message Yadony support'));
    expect(label.height, lessThan(24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('un appui ouvre WhatsApp avec le trajet dans le message', (
    tester,
  ) async {
    await pumpLine(tester, number: '+33612345678');

    await tester.tap(find.byKey(const Key('chat-support-line')));
    await tester.pumpAndSettle();

    final uri = Uri.parse(platform.urls.single);
    expect(uri.host, 'wa.me');
    expect(uri.path, '/33612345678');
    expect(uri.queryParameters['text'], contains('Paris → Abidjan'));
    expect(uri.queryParameters['text'], startsWith('Bonjour Yadony'));
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.supportWhatsappOpened,
        properties: {'source': 'chat', 'outcome': 'whatsapp'},
      ),
    ).called(1);
    expect(find.text('Contacter Yadony'), findsNothing);
  });

  testWidgets('sans trajet : message générique du support', (tester) async {
    await pumpLine(tester, number: '+33612345678', tripLabel: null);

    await tester.tap(find.byKey(const Key('chat-support-line')));
    await tester.pumpAndSettle();

    final uri = Uri.parse(platform.urls.single);
    expect(uri.queryParameters['text'], "Bonjour Yadony, j'ai besoin d'aide.");
  });

  testWidgets('WhatsApp indisponible : feuille de repli du support', (
    tester,
  ) async {
    platform.result = false;
    await pumpLine(tester, number: '+33612345678');

    await tester.tap(find.byKey(const Key('chat-support-line')));
    await tester.pumpAndSettle();

    expect(find.text('Contacter Yadony'), findsOneWidget);
    expect(find.text('Appeler'), findsOneWidget);
  });

  testWidgets('cubit non enregistré : la ligne disparaît sans planter', (
    tester,
  ) async {
    expect(getIt.isRegistered<SupportContactCubit>(), isFalse);
    await tester.pumpWidget(
      localizedApp(const Scaffold(body: ChatSupportLine())),
    );
    await tester.pump();

    expect(find.byKey(const Key('chat-support-line')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cubit enregistré : la ligne le charge elle-même', (
    tester,
  ) async {
    registerSupportContactCubit(number: '+33612345678');
    await tester.pumpWidget(
      localizedApp(const Scaffold(body: ChatSupportLine())),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('chat-support-line')), findsOneWidget);
  });
}
