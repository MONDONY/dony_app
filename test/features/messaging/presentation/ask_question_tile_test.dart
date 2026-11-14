import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/messaging/bloc/ask_question/ask_question_cubit.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/widgets/ask_question_tile.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements ConversationRepository {}

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

class _Probe implements FirebaseSessionProbe {
  const _Probe(this.real);
  final bool real;
  @override
  bool get hasSession => real;
  @override
  bool get isAnonymous => !real;
  @override
  bool get hasRealSession => real;
}

const _conv = ConversationModel(
  id: 'conv-q',
  firestoreConversationId: 'conv_q',
  otherParticipant: ParticipantModel(id: 't1', name: 'Ibrahima Diallo'),
  kind: ConversationModel.kindInquiry,
  announcementId: 'a1',
  inquiryMessageLimit: 10,
);

AnnouncementModel _announcement({String status = 'ACTIVE'}) {
  final now = DateTime.now();
  return AnnouncementModel(
    id: 'a1',
    travelerId: 't1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: now.add(const Duration(days: 20)),
    availableKg: 10,
    totalKg: 20,
    pricePerKg: 8,
    status: status,
    pricingMode: 'PER_KG',
    acceptedPaymentMethods: const {},
    traveler: const TravelerProfile(id: 't1', displayName: 'Ibrahima Diallo'),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late _MockRepo repo;
  late _MockKycBloc kyc;

  setUpAll(() {
    registerFallbackValue(const KycReset());
  });

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockRepo();
    when(() => repo.inquiryUnsupported).thenReturn(false);
    kyc = _MockKycBloc();
    when(() => kyc.state).thenReturn(const KycInitial());
    when(() => kyc.stream).thenAnswer((_) => const Stream.empty());
    if (getIt.isRegistered<FirebaseSessionProbe>()) {
      getIt.unregister<FirebaseSessionProbe>();
    }
    getIt.registerSingleton<FirebaseSessionProbe>(const _Probe(true));
  });

  tearDown(() async {
    if (getIt.isRegistered<FirebaseSessionProbe>()) {
      await getIt.unregister<FirebaseSessionProbe>();
    }
  });

  String? pushed;
  final navKey = GlobalKey<NavigatorState>();

  Widget harness({
    AnnouncementModel? announcement,
    String? viewerId = 'u1',
    String? kycStatus = 'VERIFIED',
  }) {
    pushed = null;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: AskQuestionTile(
              announcement: announcement ?? _announcement(),
              viewerId: viewerId,
              viewerKycStatus: kycStatus,
              cubit: AskQuestionCubit(
                repo,
                makeDisabledAnalytics(MockAnalyticsBackend()),
                hasRealSession: () =>
                    getIt<FirebaseSessionProbe>().hasRealSession,
              ),
              onOpenChat: (c) => pushed = '/conversations/${c.id}',
              onFollowUp: (run) => run(navKey.currentContext!),
            ),
          ),
        ),
      ],
      navigatorKey: navKey,
    );
    return BlocProvider<KycBloc>.value(
      value: kyc,
      child: MaterialApp.router(
        routerConfig: router,
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  Future<void> pump(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  testWidgets('visible pour un non-propriétaire vérifié', (t) async {
    await t.pumpWidget(harness());
    await pump(t);
    expect(find.text('Poser une question'), findsOneWidget);
    expect(find.text('Écrivez à Ibrahima avant de réserver'), findsOneWidget);
    expect(find.text('10 messages'), findsOneWidget);
  });

  testWidgets('masquée sur son propre trajet', (t) async {
    await t.pumpWidget(harness(viewerId: 't1'));
    await pump(t);
    expect(find.text('Poser une question'), findsNothing);
  });

  testWidgets('masquée si le trajet est complet ou non actif', (t) async {
    for (final s in ['FULL', 'COMPLETED', 'CANCELLED', 'DRAFT']) {
      await t.pumpWidget(harness(announcement: _announcement(status: s)));
      await pump(t);
      expect(find.text('Poser une question'), findsNothing, reason: s);
    }
  });

  testWidgets('invité : feuille de connexion, aucun appel', (t) async {
    await getIt.unregister<FirebaseSessionProbe>();
    getIt.registerSingleton<FirebaseSessionProbe>(const _Probe(false));
    await t.pumpWidget(harness(viewerId: null, kycStatus: null));
    await pump(t);
    await t.tap(find.text('Poser une question'));
    await pump(t);
    expect(find.text('Se connecter'), findsWidgets);
    verifyNever(() => repo.openInquiry(any()));
  });

  testWidgets('non vérifié : feuille KYC sans appel API', (t) async {
    await t.pumpWidget(harness(kycStatus: 'PENDING'));
    await pump(t);
    await t.tap(find.text('Poser une question'));
    await pump(t);
    expect(find.text('Vérifier mon identité'), findsOneWidget);
    verifyNever(() => repo.openInquiry(any()));
  });

  testWidgets('vérifié : openInquiry une fois puis navigation', (t) async {
    when(() => repo.openInquiry('a1')).thenAnswer((_) async => _conv);
    await t.pumpWidget(harness());
    await pump(t);
    await t.tap(find.text('Poser une question'));
    await pump(t);
    verify(() => repo.openInquiry('a1')).called(1);
    expect(pushed, '/conversations/conv-q');
  });

  testWidgets('double appui : un seul appel', (t) async {
    final c = Completer<ConversationModel>();
    when(() => repo.openInquiry('a1')).thenAnswer((_) => c.future);
    await t.pumpWidget(harness());
    await pump(t);
    await t.tap(find.text('Poser une question'));
    await t.pump();
    await t.tap(find.text('Poser une question'), warnIfMissed: false);
    await t.pump();
    verify(() => repo.openInquiry('a1')).called(1);
    c.complete(_conv);
    await pump(t);
    expect(pushed, '/conversations/conv-q');
  });

  testWidgets('InquiryKycRequired : feuille KYC', (t) async {
    when(
      () => repo.openInquiry('a1'),
    ).thenAnswer((_) async => throw const InquiryKycRequiredException());
    await t.pumpWidget(harness());
    await pump(t);
    await t.tap(find.text('Poser une question'));
    await pump(t);
    expect(find.text('Vérifier mon identité'), findsOneWidget);
    expect(pushed, isNull);
  });

  testWidgets('InquiryUnavailable : snackbar et tuile retirée', (t) async {
    when(() => repo.openInquiry('a1')).thenAnswer(
      (_) async =>
          throw const InquiryUnavailableException(kAnnouncementNotFound),
    );
    await t.pumpWidget(harness());
    await pump(t);
    await t.tap(find.text('Poser une question'));
    await pump(t);
    expect(
      find.text('Les questions ne sont plus possibles sur ce trajet.'),
      findsOneWidget,
    );
    expect(find.text('Poser une question'), findsNothing);
  });

  testWidgets('autre erreur : tuile gardée, pas de navigation', (t) async {
    when(
      () => repo.openInquiry('a1'),
    ).thenAnswer((_) async => throw Exception('x'));
    await t.pumpWidget(harness());
    await pump(t);
    await t.tap(find.text('Poser une question'));
    await pump(t);
    expect(find.text('Poser une question'), findsOneWidget);
    expect(pushed, isNull);
  });

  group('back sans les questions (I1)', () {
    const neutral = "Poser une question n'est pas encore disponible.";
    const closed = 'Les questions ne sont plus possibles sur ce trajet.';

    testWidgets('405 : message neutre, tuile retirée, puis masquée sans '
        'message à la réouverture', (t) async {
      var unsupported = false;
      when(() => repo.inquiryUnsupported).thenAnswer((_) => unsupported);
      when(() => repo.openInquiry('a1')).thenAnswer((_) async {
        unsupported = true;
        throw const InquiryUnsupportedException();
      });
      await t.pumpWidget(harness());
      await pump(t);
      await t.tap(find.text('Poser une question'));
      await pump(t);
      expect(find.text(neutral), findsOneWidget);
      expect(find.text(closed), findsNothing);
      expect(find.text('Poser une question'), findsNothing);

      // Nouvelle ouverture de la feuille : nouvelle tuile, même dépôt.
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 5));
      DonySnackbar.clearDedup();
      await t.pumpWidget(harness());
      await pump(t);
      expect(find.text('Poser une question'), findsNothing);
      expect(find.text(neutral), findsNothing);
      verify(() => repo.openInquiry('a1')).called(1);
    });

    testWidgets('404 announcement-not-found : message du trajet', (t) async {
      when(() => repo.openInquiry('a1')).thenAnswer(
        (_) async =>
            throw const InquiryUnavailableException(kAnnouncementNotFound),
      );
      await t.pumpWidget(harness());
      await pump(t);
      await t.tap(find.text('Poser une question'));
      await pump(t);
      expect(find.text(closed), findsOneWidget);
      expect(find.text(neutral), findsNothing);
    });
  });
}
