import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/expediteur_contact_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConvBloc extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

BidModel _bid({
  String status = 'ACCEPTED',
  String? senderPhone = '+33600000000',
  String? senderName = 'Mariama D.',
}) =>
    BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: status,
      weightKg: 5,
      senderName: senderName,
      senderPhone: senderPhone,
      senderKycVerified: true,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );

Future<void> _pump(WidgetTester tester, BidModel bid) async {
  final conv = _MockConvBloc();
  when(() => conv.state).thenReturn(ConversationOpenInitial());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BlocProvider<ConversationOpenBloc>.value(
          value: conv,
          child: ExpediteurContactCard(bid: bid),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('affiche le nom + 💬 + 📞 quand téléphone partagé', (tester) async {
    await _pump(tester, _bid());
    expect(find.text('EXPÉDITEUR'), findsOneWidget);
    expect(find.text('Mariama D.'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.phone_rounded), findsOneWidget);
  });

  testWidgets('pas de 📞 si pas de téléphone', (tester) async {
    await _pump(tester, _bid(senderPhone: null));
    expect(find.byIcon(Icons.phone_rounded), findsNothing);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
  });

  testWidgets('pas de 📞 quand statut terminal (COMPLETED)', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'));
    expect(find.byIcon(Icons.phone_rounded), findsNothing);
  });
}
