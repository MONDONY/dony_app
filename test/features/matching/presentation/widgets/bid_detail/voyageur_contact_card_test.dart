import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/voyageur_contact_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockConvBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _MockRevealBloc extends MockBloc<ContactRevealEvent, ContactRevealState>
    implements ContactRevealBloc {}

class _FakeConversationOpenEvent extends Fake
    implements ConversationOpenEvent {}

BidModel _bid({
  required String status,
  bool? contactWindowOpen,
  DateTime? returnDeadline,
  DateTime? returnedAt,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  weightKg: 5,
  travelerId: 't1',
  travelerName: 'Moussa K.',
  travelerPhoneAvailable: true,
  contactWindowOpen: contactWindowOpen,
  returnDeadline: returnDeadline,
  returnedAt: returnedAt,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

Finder get _phoneIcon =>
    find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone');
Finder get _chatIcon =>
    find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'message-circle');

Future<_MockConvBloc> _pump(WidgetTester tester, BidModel bid) async {
  final conv = _MockConvBloc();
  when(() => conv.state).thenReturn(const ConversationOpenInitial());
  final reveal = _MockRevealBloc();
  when(() => reveal.state).thenReturn(const ContactRevealInitial());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<ConversationOpenBloc>.value(value: conv),
            BlocProvider<ContactRevealBloc>.value(value: reveal),
          ],
          child: VoyageurContactCard(bid: bid),
        ),
      ),
    ),
  );
  return conv;
}

void main() {
  setUpAll(() => registerFallbackValue(_FakeConversationOpenEvent()));
  setUp(() => setSmsAuthEnabled(true));
  tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));

  testWidgets('commande acceptée : 💬 + 📞, sans indication de retour', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'ACCEPTED', contactWindowOpen: true));
    expect(_chatIcon, findsOneWidget);
    expect(_phoneIcon, findsOneWidget);
    expect(
      find.byKey(const Key('contact-return-in-progress-hint')),
      findsNothing,
    );
  });

  // FLUTTER-FM : après l'annulation, l'expéditeur doit pouvoir joindre le
  // voyageur qui a encore son colis.
  testWidgets('colis annulé, retour en cours : 💬 + 📞 et indication', (
    tester,
  ) async {
    final conv = await _pump(
      tester,
      _bid(
        status: 'CANCELLED',
        contactWindowOpen: true,
        returnDeadline: DateTime.now().add(const Duration(days: 2)),
      ),
    );
    expect(_chatIcon, findsOneWidget);
    expect(_phoneIcon, findsOneWidget);
    expect(
      find.text(
        'Retour en cours : contactez le voyageur pour récupérer votre colis.',
      ),
      findsOneWidget,
    );

    await tester.tap(_chatIcon);
    verify(
      () => conv.add(any(that: isA<ConversationOpenRequested>())),
    ).called(1);
  });

  testWidgets('retour en cours, en anglais', (tester) async {
    useEnglish();
    await _pump(
      tester,
      _bid(
        status: 'CANCELLED',
        contactWindowOpen: true,
        returnDeadline: DateTime.now().add(const Duration(days: 2)),
      ),
    );
    expect(
      find.text(
        'Return in progress: contact the traveler to get your parcel back.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('colis restitué : plus aucun bouton', (tester) async {
    await _pump(
      tester,
      _bid(
        status: 'CANCELLED',
        contactWindowOpen: false,
        returnDeadline: DateTime.now().add(const Duration(days: 2)),
        returnedAt: DateTime.now(),
      ),
    );
    expect(_chatIcon, findsNothing);
    expect(_phoneIcon, findsNothing);
  });

  testWidgets('délai de retour écoulé (serveur) : plus aucun bouton', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(
        status: 'CANCELLED',
        contactWindowOpen: false,
        returnDeadline: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    expect(_chatIcon, findsNothing);
    expect(_phoneIcon, findsNothing);
  });
}
