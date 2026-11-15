import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/contact_links.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:dony/features/support/bloc/support_contact_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/recording_url_launcher.dart';

class _MockConfig extends Mock implements IConfigRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockConfig config;
  late _MockAnalytics analytics;
  late RecordingUrlLauncher platform;

  setUp(() {
    config = _MockConfig();
    analytics = _MockAnalytics();
    platform = RecordingUrlLauncher();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  SupportContactCubit build() => SupportContactCubit(
    config,
    analytics,
    launcher: ContactLinkLauncher(launcher: platform),
  );

  group('load', () {
    blocTest<SupportContactCubit, SupportContactState>(
      'numéro réglé : prête, carte affichée tracée',
      build: build,
      setUp: () => when(
        () => config.getSupportWhatsappNumber(),
      ).thenAnswer((_) async => '+33612345678'),
      act: (c) => c.load(source: 'support'),
      expect: () => const [
        SupportContactState(
          status: SupportContactStatus.ready,
          whatsappNumber: '+33612345678',
        ),
      ],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.supportWhatsappCardShown,
          properties: {'source': 'support'},
        ),
      ).called(1),
    );

    blocTest<SupportContactCubit, SupportContactState>(
      'aucun numéro : masquée, rien de tracé',
      build: build,
      setUp: () => when(
        () => config.getSupportWhatsappNumber(),
      ).thenAnswer((_) async => null),
      act: (c) => c.load(source: 'faq'),
      expect: () => const [
        SupportContactState(status: SupportContactStatus.hidden),
      ],
      verify: (_) => verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ),
    );

    blocTest<SupportContactCubit, SupportContactState>(
      'lecture en échec : masquée, jamais d\'erreur',
      build: build,
      setUp: () => when(
        () => config.getSupportWhatsappNumber(),
      ).thenThrow(Exception('réseau')),
      act: (c) => c.load(source: 'support'),
      expect: () => const [
        SupportContactState(status: SupportContactStatus.hidden),
      ],
    );

    test('cubit fermé pendant la lecture : aucun état émis', () async {
      when(() => config.getSupportWhatsappNumber()).thenAnswer((_) async {
        return '+33612345678';
      });
      final cubit = build();
      final pending = cubit.load(source: 'support');
      await cubit.close();
      await pending;
      expect(cubit.state.status, SupportContactStatus.initial);
    });
  });

  group('openWhatsApp', () {
    SupportContactCubit ready() {
      final cubit = build();
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      cubit.emit(
        const SupportContactState(
          status: SupportContactStatus.ready,
          whatsappNumber: '+33 6 12 34 56 78',
        ),
      );
      return cubit;
    }

    test('ouvre wa.me avec le message, en application externe', () async {
      final cubit = ready();

      final opened = await cubit.openWhatsApp(
        message: 'Bonjour Yadony',
        source: 'support',
      );

      expect(opened, isTrue);
      expect(platform.urls.single, startsWith('https://wa.me/33612345678'));
      expect(platform.urls.single, contains('text=Bonjour'));
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.supportWhatsappOpened,
          properties: {'source': 'support', 'outcome': 'whatsapp'},
        ),
      ).called(1);
    });

    test('WhatsApp ne s\'ouvre pas : false et outcome fallback', () async {
      platform.result = false;
      final cubit = ready();

      final opened = await cubit.openWhatsApp(
        message: 'Bonjour',
        source: 'faq',
      );

      expect(opened, isFalse);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.supportWhatsappOpened,
          properties: {'source': 'faq', 'outcome': 'fallback'},
        ),
      ).called(1);
    });

    test('numéro sans indicatif : aucun lien, repli', () async {
      final cubit = build();
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      cubit.emit(
        const SupportContactState(
          status: SupportContactStatus.ready,
          whatsappNumber: '0612345678',
        ),
      );

      expect(
        await cubit.openWhatsApp(message: 'x', source: 'support'),
        isFalse,
      );
      expect(platform.urls, isEmpty);
    });
  });

  group('repli sans WhatsApp', () {
    SupportContactCubit ready() {
      final cubit = build();
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      cubit.emit(
        const SupportContactState(
          status: SupportContactStatus.ready,
          whatsappNumber: '+33612345678',
        ),
      );
      return cubit;
    }

    test('SMS : ouvre sms: avec le corps, trace l\'action', () async {
      final cubit = ready();

      expect(await cubit.sendSms('Bonjour'), isTrue);

      expect(platform.urls.single, startsWith('sms:+33612345678'));
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.supportContactFallbackAction,
          properties: {'action': 'sms', 'opened': true},
        ),
      ).called(1);
    });

    test('SMS qui ne s\'ouvre pas : false, tracé opened false', () async {
      platform.result = false;
      final cubit = ready();

      expect(await cubit.sendSms('Bonjour'), isFalse);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.supportContactFallbackAction,
          properties: {'action': 'sms', 'opened': false},
        ),
      ).called(1);
    });

    test('appel et copie : tracés', () {
      final cubit = ready()
        ..trackCall()
        ..trackCopy();

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.supportContactFallbackAction,
          properties: {'action': 'call', 'opened': true},
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.supportContactFallbackAction,
          properties: {'action': 'copy', 'opened': true},
        ),
      ).called(1);
      expect(cubit.state.whatsappNumber, '+33612345678');
    });
  });
}
