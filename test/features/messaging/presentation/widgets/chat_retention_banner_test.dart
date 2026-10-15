import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/widgets/chat_retention_banner.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/l10n_test_helpers.dart';

const _participant = ParticipantModel(id: 'uid-1', name: 'Modibo Coulibaly');

ConversationModel _conv({DateTime? purgeAt, bool purged = false}) =>
    ConversationModel(
      id: 'conv-1',
      bidId: 'bid-1',
      firestoreConversationId: 'conv_bid-1',
      otherParticipant: _participant,
      messagesPurgeAt: purgeAt,
      messagesPurged: purged,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  testWidgets('colis pas encore livré : la règle des 3 jours, sans date', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(ChatRetentionBanner(conversation: _conv())),
    );
    expect(
      find.text(
        'Les messages et les photos de cette conversation seront supprimés '
        '3 jours après la livraison du colis.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('colis livré : la date d’effacement', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        ChatRetentionBanner(
          conversation: _conv(purgeAt: DateTime.utc(2026, 10, 18, 10)),
        ),
      ),
    );
    expect(
      find.text(
        'Colis livré : les messages et les photos de cette conversation '
        'seront supprimés le 18 octobre.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('fil déjà vidé : le constat', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        ChatRetentionBanner(
          conversation: _conv(
            purgeAt: DateTime.utc(2026, 10, 18, 10),
            purged: true,
          ),
        ),
      ),
    );
    expect(
      find.text(
        'Les messages et les photos de cette conversation ont été supprimés '
        '3 jours après la livraison du colis.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('en anglais', (tester) async {
    enableEnglish();
    await tester.pumpWidget(
      localizedApp(
        ChatRetentionBanner(
          conversation: _conv(purgeAt: DateTime.utc(2026, 10, 18, 10)),
        ),
        locale: AppL10n.en,
      ),
    );
    expect(
      find.text(
        'Parcel delivered: messages and photos in this conversation will be '
        'deleted on October 18.',
      ),
      findsOneWidget,
    );
  });
}
