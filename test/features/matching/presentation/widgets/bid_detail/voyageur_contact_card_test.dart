import 'dart:ui' show SemanticsAction, Tristate;

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
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

/// Un seul bouton « Contacter » : il ouvre la discussion. L'appel se lance
/// depuis la messagerie, plus depuis cette carte.
Finder get _contactIcon =>
    find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'messages-square');
Finder get _oldIcons => find.byWidgetPredicate(
  (w) => w is DonyIcon && (w.name == 'phone' || w.name == 'message-circle'),
);

Future<_MockConvBloc> _pump(
  WidgetTester tester,
  BidModel bid, {
  ConversationOpenState state = const ConversationOpenInitial(),
}) async {
  final conv = _MockConvBloc();
  when(() => conv.state).thenReturn(state);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [BlocProvider<ConversationOpenBloc>.value(value: conv)],
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
    expect(_contactIcon, findsOneWidget);
    expect(_oldIcons, findsNothing);
    expect(
      find.byKey(const Key('contact-return-in-progress-hint')),
      findsNothing,
    );
  });

  // FLUTTER-FM : après l'annulation, l'expéditeur doit pouvoir joindre le
  // voyageur qui a encore son colis.
  // FLUTTER-P1 : contact gardé 48 h après l'annulation, sur décision serveur.
  // `Semantics(excludeSemantics: true)` autour d'un `GestureDetector` sans
  // `onTap` sur le nœud retirait l'action d'activation : un lecteur d'écran
  // annonçait « bouton » sans pouvoir l'activer.
  testWidgets('lecteur d\'écran : le bouton expose l\'action « toucher »', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final conv = await _pump(
      tester,
      _bid(status: 'ACCEPTED', contactWindowOpen: true),
    );
    final node = tester.getSemantics(
      find.bySemanticsLabel('Contacter le voyageur'),
    );
    expect(node.label, 'Contacter le voyageur');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isTrue);
    tester.semantics.tap(find.semantics.byLabel('Contacter le voyageur'));
    await tester.pump();
    final captured = verify(() => conv.add(captureAny())).captured;
    expect(captured.single, isA<ConversationOpenRequested>());
    handle.dispose();
  });

  testWidgets('lecteur d\'écran, ouverture en cours : bouton désactivé, '
      'sans action « toucher »', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      _bid(status: 'ACCEPTED', contactWindowOpen: true),
      state: const ConversationOpenLoading(),
    );
    final node = tester.getSemantics(
      find.bySemanticsLabel('Contacter le voyageur'),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('annulé, fenêtre de 48 h ouverte : 💬 + 📞 et indication', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'CANCELLED', contactWindowOpen: true));
    expect(_contactIcon, findsOneWidget);
    expect(_oldIcons, findsNothing);
    expect(
      find.byKey(const Key('contact-cancelled-window-hint')),
      findsOneWidget,
    );
  });

  testWidgets('annulé, fenêtre refermée : fermé, sans indication', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'CANCELLED', contactWindowOpen: false));
    expect(_contactIcon, findsNothing);
    expect(
      find.byKey(const Key('contact-cancelled-window-hint')),
      findsNothing,
    );
  });

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
    expect(_contactIcon, findsOneWidget);
    expect(_oldIcons, findsNothing);
    expect(
      find.text(
        'Retour en cours : contactez le voyageur pour récupérer votre colis.',
      ),
      findsOneWidget,
    );

    await tester.tap(_contactIcon);
    await tester.pumpAndSettle();
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
    expect(_contactIcon, findsNothing);
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
    expect(_contactIcon, findsNothing);
  });
}
