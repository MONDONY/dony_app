import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({
  String status = 'IN_TRANSIT',
  String? name,
  String? phone,
  String? appStatus,
  bool byUsername = false,
  String? username,
  bool declined = false,
  bool phoneHidden = false,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  recipientName: name,
  recipientPhone: phone,
  recipientAppStatus: appStatus,
  recipientDesignatedByUsername: byUsername,
  recipientUsername: username,
  recipientDeclined: declined,
  recipientPhoneHidden: phoneHidden,
);

Future<void> _pump(
  WidgetTester tester,
  BidModel bid, {
  bool isSender = true,
  Locale locale = const Locale('fr'),
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ColisDestinataireCard(bid: bid, isSender: isSender),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('désigné par identifiant (expéditeur)', () {
    for (final loc in const [Locale('fr'), Locale('en')]) {
      final fr = loc.languageCode == 'fr';
      testWidgets(
        'lien en attente : @identifiant + pastille (${loc.languageCode})',
        (tester) async {
          await _pump(
            tester,
            _bid(
              name: '@awa.diallo',
              appStatus: 'PENDING',
              byUsername: true,
              username: 'awa.diallo',
            ),
            locale: loc,
          );
          expect(find.text('@awa.diallo'), findsOneWidget);
          expect(
            find.text(
              fr ? 'En attente de confirmation' : 'Awaiting confirmation',
            ),
            findsOneWidget,
          );
          expect(find.text(fr ? 'Téléphone' : 'Phone'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('lien absent : même rendu que en attente', (tester) async {
      await _pump(
        tester,
        _bid(name: '@awa.diallo', byUsername: true, username: 'awa.diallo'),
      );
      expect(find.text('@awa.diallo'), findsOneWidget);
      expect(find.text('En attente de confirmation'), findsOneWidget);
    });

    testWidgets('confirmé avec numéro : nom public et numéro', (tester) async {
      await _pump(
        tester,
        _bid(
          name: 'Awa Diallo',
          phone: '+221770000000',
          appStatus: 'CONFIRMED',
          byUsername: true,
        ),
      );
      expect(find.text('Awa Diallo'), findsOneWidget);
      expect(find.text('+221770000000'), findsOneWidget);
      expect(find.text('En attente de confirmation'), findsNothing);
    });

    testWidgets('confirmé sans numéro : nom seul, pas de ligne vide', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(name: 'Awa Diallo', appStatus: 'CONFIRMED', byUsername: true),
      );
      expect(find.text('Awa Diallo'), findsOneWidget);
      expect(find.text('Téléphone'), findsNothing);
    });
  });

  group('vue voyageur', () {
    for (final loc in const [Locale('fr'), Locale('en')]) {
      final fr = loc.languageCode == 'fr';
      testWidgets(
        'lien en attente : destinataire non confirmé (${loc.languageCode})',
        (tester) async {
          await _pump(tester, _bid(), isSender: false, locale: loc);
          expect(
            find.text(
              fr ? 'Destinataire non confirmé' : 'Recipient not confirmed',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('destinataire connu : nom et numéro inchangés', (tester) async {
      await _pump(
        tester,
        _bid(name: 'Awa Diallo', phone: '+221770000000'),
        isSender: false,
      );
      expect(find.text('Awa Diallo'), findsOneWidget);
      expect(find.text('Destinataire non confirmé'), findsNothing);
    });
  });
}
