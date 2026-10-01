import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/contact_links.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/recipient_contact.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../../helpers/recording_url_launcher.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

BidModel _bid({
  String status = 'ARRIVED',
  String? recipientName = 'Awa Diallo',
  String? recipientPhone = '+221 70 000 00 00',
  String? senderName = 'Moussa K.',
  String? travelerName = 'Ibrahima S.',
  String? arrivalCity = 'Dakar',
  String? arrivalInstructions,
  String? recipientAppStatus,
}) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  recipientName: recipientName,
  recipientPhone: recipientPhone,
  senderName: senderName,
  travelerName: travelerName,
  arrivalCity: arrivalCity,
  arrivalInstructions: arrivalInstructions,
  recipientAppStatus: recipientAppStatus,
);

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('travelerRecipientMessage', () {
    test('FR arrivé avec instructions', () {
      expect(
        travelerRecipientMessage(
          fr,
          _bid(),
          instructions: 'Gare routière de Pikine, 18 h.',
        ),
        'Bonjour Awa Diallo, je suis Ibrahima, voyageur Yadony. '
        'Votre colis envoyé par Moussa est arrivé à Dakar. '
        'Retrait : Gare routière de Pikine, 18 h. '
        'Pensez à votre code de retrait à 6 chiffres.',
      );
    });

    test('FR arrivé sans instructions : pas de phrase Retrait', () {
      expect(
        travelerRecipientMessage(fr, _bid()),
        'Bonjour Awa Diallo, je suis Ibrahima, voyageur Yadony. '
        'Votre colis envoyé par Moussa est arrivé à Dakar. '
        'Pensez à votre code de retrait à 6 chiffres.',
      );
    });

    test('instructions du bid en repli de celles du trajet', () {
      expect(
        travelerRecipientMessage(
          fr,
          _bid(arrivalInstructions: 'Marché Sandaga'),
        ),
        contains('Retrait : Marché Sandaga.'),
      );
      expect(
        travelerRecipientMessage(
          fr,
          _bid(arrivalInstructions: 'Marché Sandaga'),
          instructions: '   ',
        ),
        isNot(contains('Retrait')),
      );
    });

    for (final status in ['HANDED_OVER', 'IN_TRANSIT']) {
      test('FR en route ($status)', () {
        expect(
          travelerRecipientMessage(
            fr,
            _bid(status: status),
            instructions: 'Gare',
          ),
          'Bonjour Awa Diallo, je suis Ibrahima, voyageur Yadony. '
          'Votre colis envoyé par Moussa est en route vers Dakar. '
          'Je vous recontacte à mon arrivée.',
        );
      });
    }

    test('autre statut : simple présentation', () {
      expect(
        travelerRecipientMessage(fr, _bid(status: 'ACCEPTED')),
        'Bonjour Awa Diallo, je suis Ibrahima, voyageur Yadony.',
      );
    });

    test('noms et ville inconnus : formulations neutres', () {
      expect(
        travelerRecipientMessage(
          fr,
          _bid(
            status: 'IN_TRANSIT',
            recipientName: ' ',
            travelerName: null,
            senderName: '',
            arrivalCity: null,
          ),
        ),
        'Bonjour, je suis votre voyageur Yadony. '
        'Votre colis est en route vers sa destination. '
        'Je vous recontacte à mon arrivée.',
      );
    });

    test('EN arrivé', () {
      expect(
        travelerRecipientMessage(en, _bid(), instructions: 'Main station'),
        'Hi Awa Diallo, I\'m Ibrahima, your Yadony traveler. '
        'Your parcel sent by Moussa has arrived in Dakar. '
        'Pickup: Main station. Remember your 6-digit pickup code.',
      );
    });
  });

  group('TravelerRecipientContactCard.shouldShow', () {
    test('statut de contact et téléphone requis', () {
      expect(TravelerRecipientContactCard.shouldShow(_bid()), isTrue);
      expect(
        TravelerRecipientContactCard.shouldShow(_bid(status: 'ACCEPTED')),
        isTrue,
      );
      expect(
        TravelerRecipientContactCard.shouldShow(_bid(status: 'PENDING')),
        isFalse,
      );
      expect(
        TravelerRecipientContactCard.shouldShow(_bid(recipientPhone: ' ')),
        isFalse,
      );
      expect(
        TravelerRecipientContactCard.shouldShow(_bid(recipientPhone: null)),
        isFalse,
      );
    });
  });

  group('contactRecipient', () {
    late _MockAnalytics analytics;
    late RecordingUrlLauncher platform;
    String? clipboard;

    setUp(() {
      analytics = _MockAnalytics();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      if (getIt.isRegistered<AnalyticsService>()) {
        getIt.unregister<AnalyticsService>();
      }
      getIt.registerSingleton<AnalyticsService>(analytics);
      platform = RecordingUrlLauncher();
      clipboard = null;
      DonySnackbar.clearDedup();
    });

    tearDown(() {
      if (getIt.isRegistered<AnalyticsService>()) {
        getIt.unregister<AnalyticsService>();
      }
    });

    Future<void> pumpCard(WidgetTester tester, BidModel bid) async {
      installUrlLauncher(platform, addTearDown);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
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
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: TravelerRecipientContactCard(bid: bid),
            ),
          ),
        ),
      );
    }

    testWidgets('carte : titre et trois boutons', (tester) async {
      await pumpCard(tester, _bid());
      expect(find.text('Contacter le destinataire'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('Appeler'), findsOneWidget);
    });

    testWidgets('WhatsApp : wa.me pré-rempli en externalApplication', (
      tester,
    ) async {
      await pumpCard(tester, _bid(recipientAppStatus: 'CONFIRMED'));
      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();

      expect(platform.urls, hasLength(1));
      final uri = Uri.parse(platform.urls.single);
      expect(uri.host, 'wa.me');
      expect(uri.path, '/221700000000');
      expect(uri.queryParameters['text'], startsWith('Bonjour Awa Diallo,'));
      expect(platform.modes.single, PreferredLaunchMode.externalApplication);
      expect(clipboard, isNull);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.recipientContacted,
          properties: {
            'channel': 'whatsapp',
            'status': 'ARRIVED',
            'in_app': true,
          },
        ),
      ).called(1);
    });

    testWidgets('SMS : lien sms en externalApplication', (tester) async {
      await pumpCard(tester, _bid(status: 'IN_TRANSIT'));
      await tester.tap(find.text('SMS'));
      await tester.pumpAndSettle();

      expect(platform.urls.single, startsWith('sms:+221700000000'));
      expect(platform.urls.single, contains('body=Bonjour%20Awa'));
      expect(platform.modes.single, PreferredLaunchMode.externalApplication);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.recipientContacted,
          properties: {
            'channel': 'sms',
            'status': 'IN_TRANSIT',
            'in_app': false,
          },
        ),
      ).called(1);
    });

    testWidgets('WhatsApp sans indicatif : message copié + snackbar', (
      tester,
    ) async {
      await pumpCard(tester, _bid(recipientPhone: '0612345678'));
      await tester.tap(find.text('WhatsApp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(platform.urls, isEmpty);
      expect(clipboard, startsWith('Bonjour Awa Diallo,'));
      expect(
        find.text('Message copié. Collez-le dans votre messagerie.'),
        findsOneWidget,
      );
    });

    testWidgets('messagerie absente : message copié + snackbar', (
      tester,
    ) async {
      platform.result = false;
      await pumpCard(tester, _bid());
      await tester.tap(find.text('SMS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(platform.urls, hasLength(1));
      expect(clipboard, contains('est arrivé à Dakar'));
      expect(
        find.text('Message copié. Collez-le dans votre messagerie.'),
        findsOneWidget,
      );
    });

    testWidgets('Appeler : composeur tel: en externalApplication', (
      tester,
    ) async {
      await pumpCard(tester, _bid());
      await tester.tap(find.text('Appeler'));
      await tester.pumpAndSettle();

      expect(platform.urls.single, 'tel:+221%2070%20000%2000%2000');
      expect(platform.modes.single, PreferredLaunchMode.externalApplication);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.recipientContacted,
          properties: {'channel': 'call', 'status': 'ARRIVED', 'in_app': false},
        ),
      ).called(1);
    });

    testWidgets('lanceur injecté prioritaire sur celui de la plateforme', (
      tester,
    ) async {
      final injected = RecordingUrlLauncher();
      installUrlLauncher(platform, addTearDown);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TravelerRecipientContactCard(
              bid: _bid(),
              launcher: ContactLinkLauncher(launcher: injected),
            ),
          ),
        ),
      );
      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();
      expect(injected.urls, hasLength(1));
      expect(platform.urls, isEmpty);
    });
  });
}
