import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/expediteur_contact_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConvBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _MockRevealBloc extends MockBloc<ContactRevealEvent, ContactRevealState>
    implements ContactRevealBloc {}

class _FakeConversationOpenEvent extends Fake
    implements ConversationOpenEvent {}

class _FakeContactRevealEvent extends Fake implements ContactRevealEvent {}

/// Le numéro n'est plus porté par le bid : seul un booléen dit si l'expéditeur est
/// joignable. Le numéro est demandé au serveur au tap sur 📞.
BidModel _bid({
  String status = 'ACCEPTED',
  bool senderPhoneAvailable = true,
  String? senderName = 'Mariama D.',
  String senderId = 's1',
  int? senderTotalShipments,
  bool senderKycVerified = true,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: senderId,
  status: status,
  weightKg: 5,
  senderName: senderName,
  senderPhoneAvailable: senderPhoneAvailable,
  senderTotalShipments: senderTotalShipments,
  senderKycVerified: senderKycVerified,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

Future<void> _pump(
  WidgetTester tester,
  BidModel bid, {
  ContactRevealBloc? reveal,
}) async {
  final conv = _MockConvBloc();
  when(() => conv.state).thenReturn(const ConversationOpenInitial());
  final revealBloc = reveal ?? _MockRevealBloc();
  if (reveal == null) {
    when(() => revealBloc.state).thenReturn(const ContactRevealInitial());
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<ConversationOpenBloc>.value(value: conv),
            BlocProvider<ContactRevealBloc>.value(value: revealBloc),
          ],
          child: ExpediteurContactCard(bid: bid),
        ),
      ),
    ),
  );
}

/// Un bloc de révélation qui part de Initial puis émet [state] : le listener de la
/// carte réagit comme en production, sans dépendre d'un vrai repository.
_MockRevealBloc _revealEmitting(ContactRevealState state) {
  final bloc = _MockRevealBloc();
  whenListen(
    bloc,
    Stream<ContactRevealState>.fromIterable([state]),
    initialState: const ContactRevealInitial(),
  );
  return bloc;
}

void _mockUrlLauncher({required bool canLaunch}) {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'canLaunch') return canLaunch;
        if (call.method == 'launch') return canLaunch;
        return null;
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}

Finder get _phoneIcon =>
    find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone');
Finder get _chatIcon =>
    find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'message-circle');

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeConversationOpenEvent());
    registerFallbackValue(_FakeContactRevealEvent());
  });

  // Ce fichier teste exclusivement la fonctionnalité d'appel révélé par le
  // serveur — indépendante du canal SMS OTP (auth). Le flag est donc activé
  // par défaut ici pour isoler ces tests de sa valeur par défaut (false).
  setUp(() => setSmsAuthEnabled(true));
  tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));

  testWidgets(
    'pas de 📞 tant que le SMS OTP backend n\'est pas confirmé, même joignable',
    (tester) async {
      setSmsAuthEnabled(false);
      await _pump(tester, _bid());
      expect(_phoneIcon, findsNothing);
      expect(_chatIcon, findsOneWidget);
    },
  );

  testWidgets('affiche le nom + 💬 + 📞 quand l\'expéditeur est joignable', (
    tester,
  ) async {
    await _pump(tester, _bid());
    expect(find.text('EXPÉDITEUR'), findsOneWidget);
    expect(find.text('Mariama D.'), findsOneWidget);
    expect(_chatIcon, findsOneWidget);
    expect(_phoneIcon, findsOneWidget);
  });

  testWidgets('pas de 📞 si le serveur ne le déclare pas joignable', (
    tester,
  ) async {
    await _pump(tester, _bid(senderPhoneAvailable: false));
    expect(_phoneIcon, findsNothing);
    expect(_chatIcon, findsOneWidget);
  });

  testWidgets('pas de 📞 quand statut terminal (COMPLETED)', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'));
    expect(_phoneIcon, findsNothing);
  });

  testWidgets('pas de 📞 quand statut terminal (DELIVERED)', (tester) async {
    await _pump(tester, _bid(status: 'DELIVERED'));
    expect(_phoneIcon, findsNothing);
  });

  testWidgets('chip KYC affiché si senderKycVerified=true', (tester) async {
    await _pump(tester, _bid());
    expect(find.text('Identité'), findsOneWidget);
  });

  testWidgets('chip KYC absent si senderKycVerified=false', (tester) async {
    await _pump(tester, _bid(senderKycVerified: false));
    expect(find.text('Identité'), findsNothing);
  });

  testWidgets('envoi pluriel — senderTotalShipments=3', (tester) async {
    await _pump(tester, _bid(senderTotalShipments: 3));
    expect(find.textContaining('3 envois'), findsOneWidget);
  });

  testWidgets('envoi singulier — senderTotalShipments=1', (tester) async {
    await _pump(tester, _bid(senderTotalShipments: 1));
    expect(find.textContaining('1 envoi'), findsOneWidget);
  });

  testWidgets('senderTotalShipments null → pas de texte envois', (
    tester,
  ) async {
    await _pump(tester, _bid());
    expect(find.textContaining('envoi'), findsNothing);
  });

  testWidgets('sans nom → « Expéditeur » (le numéro ne sert plus de repli)', (
    tester,
  ) async {
    await _pump(tester, _bid(senderName: null));
    expect(find.text('Expéditeur'), findsOneWidget);
  });

  testWidgets('senderId vide → pas de chevron (canOpenProfile=false)', (
    tester,
  ) async {
    await _pump(tester, _bid(senderId: ''));
    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'chevron-right'),
      findsNothing,
    );
  });

  testWidgets('tap 💬 → ConversationOpenRequested émis', (tester) async {
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
            child: ExpediteurContactCard(bid: _bid()),
          ),
        ),
      ),
    );
    await tester.tap(_chatIcon);
    await tester.pumpAndSettle();
    verify(
      () => conv.add(any(that: isA<ConversationOpenRequested>())),
    ).called(1);
  });

  // ── Révélation du numéro : le tap demande, il n'appelle pas directement ─────

  testWidgets('tap 📞 → demande le numéro au serveur, sans composer', (
    tester,
  ) async {
    final reveal = _MockRevealBloc();
    when(() => reveal.state).thenReturn(const ContactRevealInitial());
    await _pump(tester, _bid(), reveal: reveal);

    await tester.tap(_phoneIcon);
    await tester.pump();

    verify(
      () => reveal.add(any(that: isA<ContactRevealRequested>())),
    ).called(1);
  });

  testWidgets('numéro reçu → composeur ouvert, aucun message d\'erreur', (
    tester,
  ) async {
    _mockUrlLauncher(canLaunch: true);
    await _pump(
      tester,
      _bid(),
      reveal: _revealEmitting(const ContactRevealSuccess('+33600000000')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Le composeur s'est ouvert : aucun repli ne doit s'afficher.
    expect(find.text('Copier'), findsNothing);
    expect(find.textContaining('Aucun numéro disponible'), findsNothing);
  });

  testWidgets(
    'pas d\'app téléphone → le numéro est affiché et proposé à la copie',
    (tester) async {
      _mockUrlLauncher(canLaunch: false);
      await _pump(
        tester,
        _bid(),
        reveal: _revealEmitting(const ContactRevealSuccess('+33600000000')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Le numéro vient d'être obtenu du serveur : le perdre sur une simple erreur
      // serait dommage (émulateurs et tablettes n'ont pas de composeur).
      expect(find.textContaining('+33600000000'), findsOneWidget);
      expect(find.text('Copier'), findsOneWidget);
    },
  );

  testWidgets('compte sans numéro → message dédié, pas de composeur vide', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(),
      reveal: _revealEmitting(const ContactRevealSuccess(null)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Aucun numéro disponible'), findsOneWidget);
  });

  testWidgets('échec serveur → message d\'erreur remonté', (tester) async {
    await _pump(
      tester,
      _bid(),
      reveal: _revealEmitting(
        const ContactRevealError(ForbiddenException('Numéro indisponible')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Numéro indisponible'), findsOneWidget);
  });
}
