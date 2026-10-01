import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/recipients/bloc/incoming_invitations_cubit.dart';
import 'package:dony/features/recipients/bloc/invite_recipient_cubit.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/bloc/sent_invitations_cubit.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:dony/features/recipients/presentation/screens/recipient_invitations_screen.dart';
import 'package:dony/features/recipients/presentation/screens/recipients_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class _MockRepo extends Mock implements RecipientInvitationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

const _helpJson = '{"schemaVersion": 1, "socialLinks": [], "tutorials": []}';

class _StaticHelpSource implements HelpCenterConfigSource {
  const _StaticHelpSource();

  @override
  String get activatedJson => _helpJson;

  @override
  Future<String?> fetchAndActivate() async => _helpJson;
}

DioException _dio(AppException e) => DioException(
  requestOptions: RequestOptions(path: '/recipient-invitations'),
  error: e,
);

const _linked = Recipient(
  id: 'r-1',
  fullName: 'Awa Diop',
  phoneE164: '+221771234567',
  country: 'SN',
  linkedOnYadony: true,
);

const _plain = Recipient(
  id: 'r-2',
  fullName: 'Moussa Traoré',
  phoneE164: '+22370001122',
  country: 'ML',
);

const _sent = [
  SentRecipientInvitation(
    id: 's1',
    channel: 'PHONE',
    maskedTarget: '+221 •• •• •• 12',
    status: 'PENDING',
  ),
  SentRecipientInvitation(
    id: 's2',
    channel: 'EMAIL',
    maskedTarget: 'a••••@gmail.com',
    status: 'ACCEPTED',
  ),
];

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  late List<String> visited;

  setUpAll(() => registerFallbackValue(const RecipientLoaded()));

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockRepo();
    analytics = _MockAnalytics();
    visited = [];
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  group('carnet', () {
    late _MockRecipientBloc bloc;

    setUp(() {
      bloc = _MockRecipientBloc();
      if (getIt.isRegistered<InviteRecipientCubit>()) {
        getIt.unregister<InviteRecipientCubit>();
      }
      getIt.registerFactory<InviteRecipientCubit>(
        () => InviteRecipientCubit(repo, analytics),
      );
    });

    tearDown(() => getIt.unregister<InviteRecipientCubit>());

    Future<void> pumpCarnet(
      WidgetTester tester, {
      List<Recipient> recipients = const [],
    }) async {
      when(() => bloc.state).thenReturn(
        RecipientState(status: RecipientStatus.success, recipients: recipients),
      );
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => HelpCenterBloc(
                HelpCenterRepository(
                  const _StaticHelpSource(),
                  fallbackJsonLoader: () async => _helpJson,
                ),
                analytics,
              ),
            ),
            BlocProvider<RecipientBloc>.value(value: bloc),
            BlocProvider(
              create: (_) => SentInvitationsCubit(repo, analytics)..load(),
            ),
          ],
          child: MaterialApp.router(
            locale: AppL10n.fr,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const RecipientsScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('puce « Dans Yadony » sur les entrées liées seulement', (
      tester,
    ) async {
      when(() => repo.getSent()).thenAnswer((_) async => []);
      await pumpCarnet(tester, recipients: [_linked, _plain]);

      expect(find.byKey(const Key('recipient-linked-r-1')), findsOneWidget);
      expect(find.byKey(const Key('recipient-linked-r-2')), findsNothing);
      // DonyBadge affiche son libellé en capitales.
      expect(find.text('DANS YADONY'), findsOneWidget);
      expect(find.byKey(const Key('invite-yadony-recipient')), findsOneWidget);
      expect(find.byKey(const Key('sent-invitations-section')), findsNothing);
    });

    testWidgets('ancien back (404) : action et section masquées', (
      tester,
    ) async {
      when(() => repo.getSent()).thenThrow(_dio(const NotFoundException()));
      await pumpCarnet(tester, recipients: [_plain]);

      expect(find.byKey(const Key('invite-yadony-recipient')), findsNothing);
      expect(find.text('Moussa Traoré'), findsOneWidget);
    });

    testWidgets('invitations envoyées : cible masquée et statuts', (
      tester,
    ) async {
      when(() => repo.getSent()).thenAnswer((_) async => _sent);
      await pumpCarnet(tester, recipients: [_plain]);

      expect(find.text('Invitations envoyées'), findsOneWidget);
      expect(find.text('+221 •• •• •• 12'), findsOneWidget);
      expect(find.text('a••••@gmail.com'), findsOneWidget);
      expect(find.text('EN ATTENTE'), findsOneWidget);
      expect(find.text('ACCEPTÉE'), findsOneWidget);
    });

    testWidgets('carnet vide : les invitations restent visibles', (
      tester,
    ) async {
      when(() => repo.getSent()).thenAnswer((_) async => _sent);
      await pumpCarnet(tester);

      expect(find.byKey(const Key('sent-invitations-section')), findsOneWidget);
      expect(find.textContaining('Aucun destinataire'), findsNothing);
    });

    testWidgets('annuler : confirmation puis DELETE, ligne retirée', (
      tester,
    ) async {
      when(() => repo.getSent()).thenAnswer((_) async => _sent);
      when(() => repo.revoke(any())).thenAnswer((_) async {});
      await pumpCarnet(tester);

      await tester.tap(find.byKey(const Key('sent-invitation-cancel-s1')));
      await tester.pumpAndSettle();
      expect(find.text("Annuler l'invitation ?"), findsOneWidget);
      await tester.tap(find.text("Annuler l'invitation"));
      await tester.pumpAndSettle();

      verify(() => repo.revoke('s1')).called(1);
      expect(find.byKey(const Key('sent-invitation-s1')), findsNothing);
      expect(find.byKey(const Key('sent-invitation-s2')), findsOneWidget);
    });

    testWidgets('annulation ratée : erreur affichée', (tester) async {
      when(() => repo.getSent()).thenAnswer((_) async => _sent);
      when(() => repo.revoke(any())).thenThrow(_dio(const ServerException()));
      await pumpCarnet(tester);

      await tester.tap(find.byKey(const Key('sent-invitation-cancel-s1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Annuler l'invitation"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('sent-invitation-s1')), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('inviter : feuille, envoi, message identique et rechargement', (
      tester,
    ) async {
      when(() => repo.getSent()).thenAnswer((_) async => []);
      when(() => repo.sendToPhone(any())).thenAnswer((_) async {});
      await pumpCarnet(tester, recipients: [_plain]);

      await tester.tap(find.byKey(const Key('invite-yadony-recipient')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('invite-recipient-phone')),
        '+221771234567',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('invite-recipient-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Invitation envoyée. Si cette personne a Yadony, '
          'elle pourra accepter.',
        ),
        findsOneWidget,
      );
      // Premier chargement + rechargement après l'envoi.
      verify(() => repo.getSent()).called(2);
    });
  });

  group('écran invité', () {
    const pendingInv = IncomingRecipientInvitation(
      id: 'p1',
      inviterFirstName: 'Awa',
      status: 'PENDING',
    );
    const acceptedInv = IncomingRecipientInvitation(
      id: 'a1',
      inviterFirstName: 'Moussa',
      status: 'ACCEPTED',
    );

    Future<void> pumpScreen(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider(
              create: (_) => IncomingInvitationsCubit(repo, analytics)..load(),
              child: const RecipientInvitationsScreen(),
            ),
          ),
          GoRoute(
            path: kAddProfilePhoneRoute,
            builder: (_, _) {
              visited.add(kAddProfilePhoneRoute);
              return const Scaffold(body: Text('ajout numéro'));
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          locale: AppL10n.fr,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('demande en attente : texte d\'accord, autorisés séparés', (
      tester,
    ) async {
      when(
        () => repo.getIncoming(),
      ).thenAnswer((_) async => [pendingInv, acceptedInv]);
      await pumpScreen(tester);

      expect(find.text('Demandes reçues'), findsOneWidget);
      expect(
        find.text('Awa veut vous ajouter à ses destinataires'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Awa verra votre nom et votre numéro, et ses colis vous seront '
          'rattachés directement.',
        ),
        findsOneWidget,
      );
      expect(find.text('Expéditeurs autorisés'), findsOneWidget);
      expect(find.text('Moussa'), findsOneWidget);
    });

    testWidgets('accepter : passe dans les autorisés, message', (tester) async {
      when(() => repo.getIncoming()).thenAnswer((_) async => [pendingInv]);
      when(() => repo.accept(any())).thenAnswer((_) async {});
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('incoming-invitation-accept-p1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => repo.accept('p1')).called(1);
      expect(find.text('Demandes reçues'), findsNothing);
      expect(find.byKey(const Key('authorized-sender-p1')), findsOneWidget);
      expect(
        find.text('Awa peut maintenant vous rattacher ses colis.'),
        findsOneWidget,
      );
    });

    testWidgets('refuser : la demande disparaît', (tester) async {
      when(() => repo.getIncoming()).thenAnswer((_) async => [pendingInv]);
      when(() => repo.decline(any())).thenAnswer((_) async {});
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('incoming-invitation-decline-p1')));
      await tester.pumpAndSettle();

      verify(() => repo.decline('p1')).called(1);
      expect(find.text('Aucune demande'), findsOneWidget);
    });

    testWidgets('retirer : confirmation puis retrait', (tester) async {
      when(() => repo.getIncoming()).thenAnswer((_) async => [acceptedInv]);
      when(() => repo.revoke(any())).thenAnswer((_) async {});
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('authorized-sender-remove-a1')));
      await tester.pumpAndSettle();
      expect(find.text('Retirer Moussa ?'), findsOneWidget);
      await tester.tap(find.text('Retirer').last);
      await tester.pumpAndSettle();

      verify(() => repo.revoke('a1')).called(1);
      expect(find.text('Aucune demande'), findsOneWidget);
    });

    testWidgets('409 sans numéro : dialogue puis écran d\'ajout de numéro', (
      tester,
    ) async {
      when(() => repo.getIncoming()).thenAnswer((_) async => [pendingInv]);
      when(() => repo.accept(any())).thenThrow(
        _dio(
          const ConflictException('phone', code: kInvitationPhoneRequiredCode),
        ),
      );
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('incoming-invitation-accept-p1')));
      await tester.pumpAndSettle();
      expect(find.text('Ajoutez votre numéro'), findsOneWidget);

      await tester.tap(find.text('Ajouter un numéro'));
      await tester.pumpAndSettle();
      expect(visited, [kAddProfilePhoneRoute]);
    });

    testWidgets('échec d\'une réponse : erreur et rechargement', (
      tester,
    ) async {
      when(() => repo.getIncoming()).thenAnswer((_) async => [pendingInv]);
      when(() => repo.decline(any())).thenThrow(_dio(const ServerException()));
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('incoming-invitation-decline-p1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SnackBar), findsOneWidget);
      verify(() => repo.getIncoming()).called(2);
    });

    testWidgets('vide et erreur de chargement', (tester) async {
      when(() => repo.getIncoming()).thenThrow(_dio(const ServerException()));
      await pumpScreen(tester);
      expect(find.text('Erreur de chargement'), findsOneWidget);

      when(() => repo.getIncoming()).thenAnswer((_) async => []);
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Aucune demande'), findsOneWidget);
    });
  });
}
