import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/chat_labels.dart';
import 'package:dony/features/messaging/presentation/widgets/conversation_tile.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../../../helpers/l10n_test_helpers.dart';

ConversationModel _conversation({
  String participantName = '',
  String? lastMessagePreview,
  DateTime? lastMessageAt,
}) => ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: ParticipantModel(id: 'uid-1', name: participantName),
  lastMessagePreview: lastMessagePreview,
  lastMessageAt: lastMessageAt,
);

Widget _wrap(ConversationModel conversation) => MaterialApp(
  home: Scaffold(body: ConversationTile(conversation: conversation)),
);

void main() {
  group('replis fr', () {
    testWidgets('nom vide -> conversationUserFallback', (tester) async {
      await tester.pumpWidget(_wrap(_conversation()));

      expect(find.text('Utilisateur'), findsOneWidget);
    });

    testWidgets('aperçu vide -> conversationStartedFallback', (tester) async {
      await tester.pumpWidget(_wrap(_conversation(participantName: 'Awa')));

      expect(find.text('Conversation démarrée'), findsOneWidget);
    });

    testWidgets('aperçu localisation traduit', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _conversation(
            participantName: 'Awa',
            lastMessagePreview: kChatPreviewLocation,
          ),
        ),
      );

      expect(find.text('📍 Localisation partagée'), findsOneWidget);
    });
  });

  group('replis en', () {
    testWidgets('empty name -> conversationUserFallback', (tester) async {
      useEnglish();
      await tester.pumpWidget(_wrap(_conversation()));

      expect(find.text('User'), findsOneWidget);
    });

    testWidgets('empty preview -> conversationStartedFallback', (tester) async {
      useEnglish();
      await tester.pumpWidget(_wrap(_conversation(participantName: 'Awa')));

      expect(find.text('Conversation started'), findsOneWidget);
    });

    testWidgets('location preview translated', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(
          _conversation(
            participantName: 'Awa',
            lastMessagePreview: kChatPreviewLocation,
          ),
        ),
      );

      expect(find.text('📍 Shared location'), findsOneWidget);
    });
  });

  // Régression finale F : 'HH:mm' / 'EEE' / 'd MMM' fixes (AppL10n.localeName)
  // → DateFormat.jm/.E/.MMMd(l.localeName). formatConversationTime dépend de
  // l'heure d'exécution (aujourd'hui / cette semaine / plus ancien) : on
  // compare donc à des décalages relatifs, jamais à une date absolue fixe.
  group('formatConversationTime', () {
    test('aujourd\'hui -> heure (fr)', () {
      // 2 minutes : reste le même jour, sauf juste après minuit (un recul
      // de 2 h tombait la veille quand la CI tournait avant 2 h du matin).
      final date = DateTime.now().subtract(const Duration(minutes: 2));
      expect(
        formatConversationTime(AppL10n.current, date),
        DateFormat.jm('fr').format(date),
      );
    });

    test('aujourd\'hui -> heure (en)', () {
      useEnglish();
      // 2 minutes : reste le même jour, sauf juste après minuit (un recul
      // de 2 h tombait la veille quand la CI tournait avant 2 h du matin).
      final date = DateTime.now().subtract(const Duration(minutes: 2));
      expect(
        formatConversationTime(AppL10n.current, date),
        DateFormat.jm('en').format(date),
      );
    });

    test('il y a 3 jours -> jour abrégé (fr)', () {
      final date = DateTime.now().subtract(const Duration(days: 3));
      expect(
        formatConversationTime(AppL10n.current, date),
        DateFormat.E('fr').format(date),
      );
    });

    test('il y a 3 jours -> jour abrégé (en)', () {
      useEnglish();
      final date = DateTime.now().subtract(const Duration(days: 3));
      expect(
        formatConversationTime(AppL10n.current, date),
        DateFormat.E('en').format(date),
      );
    });

    test('il y a 20 jours -> date courte (fr)', () {
      final date = DateTime.now().subtract(const Duration(days: 20));
      expect(
        formatConversationTime(AppL10n.current, date),
        DateFormat.MMMd('fr').format(date),
      );
    });

    test('il y a 20 jours -> date courte (en)', () {
      useEnglish();
      final date = DateTime.now().subtract(const Duration(days: 20));
      expect(
        formatConversationTime(AppL10n.current, date),
        DateFormat.MMMd('en').format(date),
      );
    });
  });

  group('conversation voyageur ↔ destinataire (lot 3C)', () {
    ConversationModel recipientConversation({
      String? role,
      bool trip = true,
      String? viewerRole,
    }) => ConversationModel(
      id: 'conv-r',
      bidId: 'bid-1',
      firestoreConversationId: 'rconv_bid-1',
      otherParticipant: ParticipantModel(id: 'uid-2', name: 'Awa', role: role),
      tripOrigin: trip ? 'Paris' : null,
      tripDestination: trip ? 'Dakar' : null,
      kind: ConversationModel.kindRecipientTraveler,
      viewerRole: viewerRole,
    );

    testWidgets('rôle absent, viewerRole TRAVELER -> Destinataire', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(recipientConversation(viewerRole: 'TRAVELER')),
      );

      expect(find.text('Destinataire · Paris → Dakar'), findsOneWidget);
    });

    testWidgets('préfixe le trajet du rôle servi', (tester) async {
      await tester.pumpWidget(
        _wrap(recipientConversation(role: 'Destinataire')),
      );

      expect(find.text('Destinataire · Paris → Dakar'), findsOneWidget);
    });

    testWidgets('rôle absent vu par le destinataire -> Voyageur', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(recipientConversation()));

      expect(find.text('Voyageur · Paris → Dakar'), findsOneWidget);
    });

    testWidgets('sans trajet, le rôle seul', (tester) async {
      await tester.pumpWidget(
        _wrap(recipientConversation(role: 'Destinataire', trip: false)),
      );

      expect(find.text('Destinataire'), findsOneWidget);
    });

    testWidgets('rôle vide vu par le voyageur -> repli traduit', (
      tester,
    ) async {
      useEnglish();
      await tester.pumpWidget(_wrap(recipientConversation(role: ' ')));

      // Rôle vide : rien ne dit que l'on est le voyageur, le repli est
      // celui du destinataire qui regarde.
      expect(find.text('Traveler · Paris → Dakar'), findsOneWidget);
    });

    testWidgets('fil expéditeur ↔ voyageur : trajet seul', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConversationModel(
            id: 'conv-s',
            bidId: 'bid-1',
            firestoreConversationId: 'conv_bid-1',
            otherParticipant: ParticipantModel(
              id: 'uid-2',
              name: 'Awa',
              role: 'Voyageur',
            ),
            tripOrigin: 'Paris',
            tripDestination: 'Dakar',
          ),
        ),
      );

      expect(find.text('Paris → Dakar'), findsOneWidget);
    });
  });
}
