import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/contact_links.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:dony/features/support/bloc/support_contact_cubit.dart';
import 'package:dony/features/support/presentation/widgets/support_whatsapp_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/recording_url_launcher.dart';

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
    // `dialPhoneNumber` passe par le lanceur global de la plateforme.
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

  Future<void> pumpCard(
    WidgetTester tester, {
    String? number,
    bool faq = false,
    Size size = const Size(360, 800),
  }) async {
    when(
      () => config.getSupportWhatsappNumber(),
    ).thenAnswer((_) async => number);
    await cubit.load(source: faq ? 'faq' : 'support');
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SupportWhatsAppCard(
                source: faq ? 'faq' : 'support',
                faqVariant: faq,
                cubit: cubit,
              ),
              const Text('Reste de l\'écran'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('sans numéro : aucune carte, rien ne prend de place', (
    tester,
  ) async {
    await pumpCard(tester);

    expect(find.byKey(const ValueKey('support-whatsapp-cta')), findsNothing);
    expect(find.text('Reste de l\'écran'), findsOneWidget);
  });

  testWidgets('avec numéro : titre du Support, bouton, numéro en clair', (
    tester,
  ) async {
    await pumpCard(tester, number: '+33612345678');

    expect(find.text('Une question ? Écrivez-nous'), findsOneWidget);
    expect(find.text('Écrire sur WhatsApp'), findsOneWidget);
    expect(find.text('+33612345678'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Centre d\'aide : titre « Besoin d\'un humain ? »', (
    tester,
  ) async {
    await pumpCard(tester, number: '+33612345678', faq: true);

    expect(find.text('Besoin d\'un humain ?'), findsOneWidget);
    expect(find.text('Une question ? Écrivez-nous'), findsNothing);
  });

  testWidgets('le bouton tient sur une ligne à 320 dp, en français', (
    tester,
  ) async {
    await pumpCard(tester, number: '+33612345678', size: const Size(320, 700));

    final label = tester.getSize(find.text('Écrire sur WhatsApp'));
    final button = tester.getSize(
      find.byKey(const ValueKey('support-whatsapp-cta')),
    );
    expect(button.height, 50);
    expect(label.height, lessThan(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('toucher le bouton ouvre WhatsApp, sans feuille de repli', (
    tester,
  ) async {
    await pumpCard(tester, number: '+33612345678');

    await tester.tap(find.byKey(const ValueKey('support-whatsapp-cta')));
    await tester.pumpAndSettle();

    expect(platform.urls.single, startsWith('https://wa.me/33612345678'));
    expect(find.text('Contacter Yadony'), findsNothing);
  });

  group('WhatsApp indisponible : feuille de repli', () {
    Future<void> openFallback(WidgetTester tester) async {
      platform.result = false;
      await pumpCard(tester, number: '+33612345678');
      await tester.tap(find.byKey(const ValueKey('support-whatsapp-cta')));
      await tester.pumpAndSettle();
    }

    testWidgets('montre le numéro et les trois actions empilées', (
      tester,
    ) async {
      await openFallback(tester);

      expect(find.text('Contacter Yadony'), findsOneWidget);
      expect(find.text('Appeler'), findsOneWidget);
      expect(find.text('Envoyer un SMS'), findsOneWidget);
      expect(find.text('Copier'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Envoyer un SMS » ouvre la messagerie au numéro', (
      tester,
    ) async {
      await openFallback(tester);
      platform
        ..result = true
        ..urls.clear();

      await tester.tap(find.text('Envoyer un SMS'));
      await tester.pumpAndSettle();

      expect(platform.urls.single, startsWith('sms:+33612345678'));
    });

    testWidgets('SMS impossible : message d\'erreur, feuille gardée', (
      tester,
    ) async {
      await openFallback(tester);

      await tester.tap(find.text('Envoyer un SMS'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Impossible d\'ouvrir'), findsOneWidget);
      expect(find.text('Contacter Yadony'), findsOneWidget);
    });

    testWidgets('« Copier » met le numéro dans le presse-papiers', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openFallback(tester);

      await tester.tap(find.text('Copier'));
      await tester.pumpAndSettle();

      expect(copied, '+33612345678');
      expect(find.text('Numéro copié'), findsOneWidget);
    });

    testWidgets('« Appeler » ouvre le composeur', (tester) async {
      await openFallback(tester);
      platform
        ..result = true
        ..urls.clear();

      await tester.tap(find.text('Appeler'));
      await tester.pumpAndSettle();

      expect(platform.urls.single, 'tel:+33612345678');
    });
  });
}
