import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/notify_recipients_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../../helpers/recording_url_launcher.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

BidModel _bid(
  String id,
  String status, {
  String? recipientName,
  String? recipientPhone = '+221700000000',
  String? recipientAppStatus,
}) => BidModel(
  id: id,
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  recipientName: recipientName ?? 'Destinataire $id',
  recipientPhone: recipientPhone,
  recipientAppStatus: recipientAppStatus,
  senderName: 'Moussa',
  travelerName: 'Ibrahima',
  arrivalCity: 'Dakar',
);

final _bids = [
  _bid('a', 'ACCEPTED'),
  _bid('b', 'HANDED_OVER', recipientAppStatus: 'CONFIRMED'),
  _bid('c', 'ARRIVED', recipientAppStatus: 'CONFIRMED'),
  _bid('d', 'IN_TRANSIT', recipientPhone: null),
  _bid('e', 'ARRIVED'),
  _bid('f', 'COMPLETED'),
];

void main() {
  late _MockAnalytics analytics;

  setUp(() {
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(analytics);
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  test('recipientsToNotify garde remis, en transit et arrivés', () {
    expect(recipientsToNotify(_bids).map((b) => b.id), ['b', 'c', 'd', 'e']);
    expect(recipientsToNotify(const []), isEmpty);
  });

  Future<void> openSheet(
    WidgetTester tester,
    List<BidModel> bids, {
    NotifyRecipientsSource source = NotifyRecipientsSource.manual,
    String? instructions,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => NotifyRecipientsSheet.show(
                context,
                bids: bids,
                source: source,
                instructions: instructions,
              ),
              child: const Text('OUVRIR'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OUVRIR'));
    await tester.pumpAndSettle();
  }

  testWidgets('liste filtrée par statut, puce Dans Yadony et boutons', (
    tester,
  ) async {
    await openSheet(tester, _bids);

    expect(find.text('Prévenir les destinataires'), findsOneWidget);
    for (final id in ['b', 'c', 'd', 'e']) {
      expect(find.byKey(Key('notify-recipient-$id')), findsOneWidget);
    }
    expect(find.byKey(const Key('notify-recipient-a')), findsNothing);
    expect(find.byKey(const Key('notify-recipient-f')), findsNothing);

    // Puce seulement pour les destinataires CONFIRMED.
    expect(find.text('Dans Yadony'), findsNWidgets(2));
    expect(find.byKey(const Key('notify-recipient-in-app-b')), findsOneWidget);
    expect(find.byKey(const Key('notify-recipient-in-app-e')), findsNothing);
    // « Notifié dans l'app » : CONFIRMED et arrivé uniquement.
    expect(find.text("Notifié dans l'app"), findsOneWidget);

    // Sans numéro : pas de boutons, mention dédiée.
    expect(find.text('En transit · Numéro indisponible'), findsOneWidget);
    expect(find.text('Remis · +221700000000'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNWidgets(3));
    expect(find.text('SMS'), findsNWidgets(3));
    expect(find.text('Appeler'), findsNWidgets(3));

    verify(
      () => analytics.logEvent(
        AnalyticsEvents.recipientsNotifyOpened,
        properties: {'count': 4, 'source': 'manual'},
      ),
    ).called(1);
  });

  testWidgets('ancien back (recipientAppStatus null) : aucune puce', (
    tester,
  ) async {
    await openSheet(tester, [_bid('x', 'ARRIVED')]);
    expect(find.text('Dans Yadony'), findsNothing);
    expect(find.text("Notifié dans l'app"), findsNothing);
    expect(find.text('Arrivé · +221700000000'), findsOneWidget);
  });

  testWidgets('destinataire sans nom : libellé de repli', (tester) async {
    await openSheet(tester, [_bid('x', 'ARRIVED', recipientName: ' ')]);
    expect(find.text('Destinataire'), findsOneWidget);
  });

  testWidgets('aucun colis concerné : rien ne s’ouvre, aucun event', (
    tester,
  ) async {
    await openSheet(tester, [_bid('a', 'ACCEPTED')]);
    expect(find.text('Prévenir les destinataires'), findsNothing);
    verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    );
  });

  testWidgets('WhatsApp d’une ligne : message arrivé avec instructions', (
    tester,
  ) async {
    final platform = RecordingUrlLauncher();
    installUrlLauncher(platform, addTearDown);
    await openSheet(
      tester,
      [_bid('c', 'ARRIVED', recipientAppStatus: 'CONFIRMED')],
      source: NotifyRecipientsSource.afterArrival,
      instructions: 'Gare de Pikine',
    );

    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();

    final text = Uri.parse(platform.urls.single).queryParameters['text'];
    expect(text, contains('est arrivé à Dakar'));
    expect(text, contains('Retrait : Gare de Pikine.'));
    expect(platform.modes.single, PreferredLaunchMode.externalApplication);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.recipientsNotifyOpened,
        properties: {'count': 1, 'source': 'after_arrival'},
      ),
    ).called(1);
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

  testWidgets('Fermer (stickyBottom) referme la feuille', (tester) async {
    await openSheet(tester, [_bid('b', 'HANDED_OVER')]);
    expect(find.text('Prévenir les destinataires'), findsOneWidget);

    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    expect(find.text('Prévenir les destinataires'), findsNothing);
  });
}
