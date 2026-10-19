// Constructeurs appelés à l'exécution : un appel `const` n'est jamais exécuté
// et deux instances `const` identiques court-circuitent la comparaison.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

void main() {
  group('SupportEvent — égalité de valeur', () {
    test('accueil : sans champ', () {
      expectValueEquality(() => SupportHomeRequested(), [
        SupportTicketDetailRequested('t-1'),
      ]);
      expect(SupportHomeRequested().props, isEmpty);
    });

    test('brouillon ouvert : comparé sur son origine', () {
      expectValueEquality(() => SupportDraftOpened('phone_already_used'), [
        SupportDraftOpened('team_cancelled_parcel'),
      ]);
    });

    test('création de ticket : catégorie, sujet et message', () {
      SupportTicketCreateRequested make({
        String category = 'PAYMENT',
        String message = 'Bonjour',
        String? origin,
      }) => SupportTicketCreateRequested(
        category: category,
        subject: 'Remboursement',
        message: message,
        origin: origin,
      );
      expectValueEquality(make, [
        make(category: 'DELIVERY'),
        make(message: 'Rebonjour'),
        make(origin: 'team_cancelled_parcel'),
      ]);
    });

    test('événements portant un identifiant de ticket', () {
      expectValueEquality(() => SupportTicketDetailRequested('t-1'), [
        SupportTicketDetailRequested('t-2'),
        SupportTicketHideRequested('t-1'),
      ]);
      expectValueEquality(() => SupportTicketHideRequested('t-1'), [
        SupportTicketHideRequested('t-2'),
      ]);
      expectValueEquality(() => SupportTicketLiveRefreshRequested('t-1'), [
        SupportTicketLiveRefreshRequested('t-2'),
      ]);
    });

    test('envoi de message : ticket et contenu', () {
      expectValueEquality(
        () => SupportMessageSendRequested(ticketId: 't-1', content: 'a'),
        [
          SupportMessageSendRequested(ticketId: 't-1', content: 'b'),
          SupportMessageSendRequested(ticketId: 't-2', content: 'a'),
        ],
      );
    });

    test('pièces jointes : chemin local et identifiant local', () {
      expectValueEquality(() => SupportAttachmentPickRequested('/tmp/a.jpg'), [
        SupportAttachmentPickRequested('/tmp/b.jpg'),
      ]);
      expectValueEquality(() => SupportAttachmentRemoved('l-1'), [
        SupportAttachmentRemoved('l-2'),
      ]);
    });
  });
}
