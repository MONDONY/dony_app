import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/expediteur_contact_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConvBloc extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _FakeConversationOpenEvent extends Fake implements ConversationOpenEvent {}

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
  setUpAll(() {
    registerFallbackValue(_FakeConversationOpenEvent());
  });

  testWidgets('affiche le nom + 💬 + 📞 quand téléphone partagé', (tester) async {
    await _pump(tester, _bid());
    expect(find.text('EXPÉDITEUR'), findsOneWidget);
    expect(find.text('Mariama D.'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'message-circle'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone'), findsOneWidget);
  });

  testWidgets('pas de 📞 si pas de téléphone', (tester) async {
    await _pump(tester, _bid(senderPhone: null));
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'message-circle'), findsOneWidget);
  });

  testWidgets('pas de 📞 quand statut terminal (COMPLETED)', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'));
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone'), findsNothing);
  });

  testWidgets('pas de 📞 quand statut terminal (DELIVERED)', (tester) async {
    await _pump(tester, _bid(status: 'DELIVERED'));
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone'), findsNothing);
  });

  testWidgets('pas de 📞 si téléphone vide (chaîne vide)', (tester) async {
    await _pump(tester, _bid(senderPhone: ''));
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone'), findsNothing);
  });

  testWidgets('chip KYC affiché si senderKycVerified=true', (tester) async {
    await _pump(tester, _bid());
    expect(find.text('KYC'), findsOneWidget);
  });

  testWidgets('chip KYC absent si senderKycVerified=false', (tester) async {
    final conv = _MockConvBloc();
    when(() => conv.state).thenReturn(ConversationOpenInitial());
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      weightKg: 5,
      senderName: 'Mariama D.',
      senderPhone: '+33600000000',
      senderKycVerified: false,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
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
    expect(find.text('KYC'), findsNothing);
  });

  testWidgets('chip Kilo Pro affiché si senderKiloPro=true', (tester) async {
    final conv = _MockConvBloc();
    when(() => conv.state).thenReturn(ConversationOpenInitial());
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      weightKg: 5,
      senderName: 'Mariama D.',
      senderPhone: '+33600000000',
      senderKiloPro: true,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
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
    expect(find.text('Kilo Pro'), findsOneWidget);
  });

  testWidgets('état chargement conversation → spinner dans bouton 💬',
      (tester) async {
    final conv = _MockConvBloc();
    when(() => conv.state).thenReturn(const ConversationOpenLoading());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: BlocProvider<ConversationOpenBloc>.value(
            value: conv,
            child: ExpediteurContactCard(bid: _bid()),
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('envois pluriel — senderTotalShipments=3', (tester) async {
    final conv = _MockConvBloc();
    when(() => conv.state).thenReturn(ConversationOpenInitial());
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      weightKg: 5,
      senderName: 'Mariama D.',
      senderPhone: '+33600000000',
      senderTotalShipments: 3,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
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
    expect(find.textContaining('3 envois'), findsOneWidget);
  });

  testWidgets('envoi singulier — senderTotalShipments=1', (tester) async {
    final conv = _MockConvBloc();
    when(() => conv.state).thenReturn(ConversationOpenInitial());
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      weightKg: 5,
      senderName: 'Mariama D.',
      senderPhone: '+33600000000',
      senderTotalShipments: 1,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
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
    expect(find.textContaining('1 envoi'), findsOneWidget);
  });

  testWidgets('resolvedSenderName utilise le téléphone si pas de nom',
      (tester) async {
    await _pump(tester, _bid(senderName: null, senderPhone: '+33611223344'));
    expect(find.text('+33611223344'), findsWidgets);
  });

  testWidgets('resolvedSenderName = Expéditeur si ni nom ni téléphone',
      (tester) async {
    await _pump(tester, _bid(senderName: null, senderPhone: null));
    expect(find.text('Expéditeur'), findsOneWidget);
  });

  testWidgets('tap 💬 → ConversationOpenRequested émis', (tester) async {
    final conv = _MockConvBloc();
    when(() => conv.state).thenReturn(ConversationOpenInitial());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: BlocProvider<ConversationOpenBloc>.value(
            value: conv,
            child: ExpediteurContactCard(bid: _bid()),
          ),
        ),
      ),
    );
    await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'message-circle'));
    await tester.pumpAndSettle();
    verify(() => conv.add(any(that: isA<ConversationOpenRequested>()))).called(1);
  });

  testWidgets(
      'senderId vide → pas de chevron (canOpenProfile=false)',
      (tester) async {
    final conv = _MockConvBloc();
    when(() => conv.state).thenReturn(ConversationOpenInitial());
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: '',
      status: 'ACCEPTED',
      weightKg: 5,
      senderName: 'Mariama D.',
      senderPhone: '+33600000000',
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
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
    // When senderId is empty, there's no chevron and no tap target for profile
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'chevron-right'), findsNothing);
  });

  testWidgets('senderTotalShipments null → pas de texte envois',
      (tester) async {
    final conv = _MockConvBloc();
    when(() => conv.state).thenReturn(ConversationOpenInitial());
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      weightKg: 5,
      senderName: 'Mariama D.',
      senderPhone: '+33600000000',
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );
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
    expect(find.textContaining('envoi'), findsNothing);
  });

  testWidgets('tap 📞 canLaunchUrl=true → aucun snackbar erreur', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'canLaunch') return true;
      if (call.method == 'launch') return true;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await _pump(tester, _bid());
    await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining("Impossible d'ouvrir le composeur"), findsNothing);
  });

  testWidgets('tap 📞 canLaunchUrl=false → snackbar erreur', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'canLaunch') return false;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await _pump(tester, _bid());
    await tester.tap(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'phone'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining("Impossible d'ouvrir le composeur"), findsOneWidget);
  });
}
