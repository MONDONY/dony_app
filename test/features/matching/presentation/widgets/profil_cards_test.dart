import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/expediteur_card.dart';
import 'package:dony/features/matching/presentation/widgets/profil_card_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/voyageur_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

// ── Fixture ───────────────────────────────────────────────────────────────────

BidModel _bid() => BidModel(
  id: 'b-1',
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: 5,
  status: 'ACCEPTED',
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  travelerName: 'Abou D.',
  senderName: 'Mariam K.',
);

void main() {
  testWidgets('VoyageurCard montre le nom du voyageur', (tester) async {
    final mockBloc = _MockConversationOpenBloc();
    when(() => mockBloc.state).thenReturn(const ConversationOpenInitial());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider<ConversationOpenBloc>.value(
            value: mockBloc,
            child: VoyageurCard(bid: _bid()),
          ),
        ),
      ),
    );
    expect(find.text('Abou D.'), findsOneWidget);
  });

  testWidgets('ExpediteurCard montre le nom de l\'expéditeur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ExpediteurCard(bid: _bid())),
      ),
    );
    expect(find.textContaining('Mariam K.'), findsOneWidget);
  });

  testWidgets('MiniChip affiche le label avec la bonne couleur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MiniChip(
            label: 'KYC',
            color: Colors.green,
            bg: Colors.green.shade50,
          ),
        ),
      ),
    );
    expect(find.text('KYC'), findsOneWidget);
    expect(find.byType(MiniChip), findsOneWidget);
  });
}
