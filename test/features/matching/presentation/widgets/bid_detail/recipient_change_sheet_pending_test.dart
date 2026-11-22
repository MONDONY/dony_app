import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/recipient_change/recipient_change_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/recipient_change_sheet.dart';
import 'package:dony/features/recipients/bloc/designate_yadony_user_cubit.dart';
import 'package:dony/features/recipients/data/datasources/recipient_invitation_datasource.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBids extends Mock implements BidRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

class _MockDatasource extends Mock implements RecipientInvitationDatasource {}

/// Colis déjà désigné par identifiant, lien en attente.
BidModel _pending({String appStatus = 'PENDING'}) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'IN_TRANSIT',
  recipientName: '@awa.diallo',
  recipientAppStatus: appStatus,
  recipientDesignatedByUsername: true,
  recipientUsername: 'awa.diallo',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

void main() {
  late _MockBids bids;
  late _MockDatasource datasource;
  late RecipientInvitationRepository invitations;
  late _MockAnalytics analytics;
  late _MockBidBloc bidBloc;

  setUpAll(() => registerFallbackValue(_FakeBidEvent()));

  setUp(() {
    bids = _MockBids();
    datasource = _MockDatasource();
    // Vrai dépôt : les drapeaux de session sont posés par la feuille.
    invitations = RecipientInvitationRepository(datasource);
    analytics = _MockAnalytics();
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerSingleton<RecipientInvitationRepository>(invitations)
      ..registerFactory<RecipientChangeCubit>(
        () => RecipientChangeCubit(bids, analytics),
      )
      ..registerFactory<DesignateYadonyUserCubit>(
        () => DesignateYadonyUserCubit(invitations, analytics),
      );
  });

  tearDown(() async => getIt.reset());

  void lookupReturns({required bool designation}) {
    when(() => datasource.lookupUsername(any())).thenAnswer(
      (_) async => UsernameLookup(
        username: 'awa.diallo',
        initial: 'A',
        parcelDesignation: designation,
      ),
    );
  }

  Future<void> open(WidgetTester tester, BidModel bid) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: AppL10n.fr,
        home: BlocProvider<BidBloc>.value(
          value: bidBloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openRecipientChangeSheet(context, bid),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('recipient-change-yadony-user')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('designate-yadony-user-field')),
      'awa.diallo',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets('colis déjà désigné : repasser en nom + numéro n\'envoie jamais '
      'un nom en @', (tester) async {
    when(
      () => bids.changeRecipient(
        any(),
        recipientName: any(named: 'recipientName'),
        recipientPhone: any(named: 'recipientPhone'),
        recipientUsername: any(named: 'recipientUsername'),
      ),
    ).thenAnswer((_) async => _pending());
    await open(tester, _pending());

    // Le nom n'est pas prérempli avec « @identifiant ».
    expect(find.text('@awa.diallo'), findsNothing);
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), 'Fatou Sow');
    await tester.enterText(fields.at(1), '+221771234567');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DonyButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    final captured = verify(
      () => bids.changeRecipient(
        'bid-1',
        recipientName: captureAny(named: 'recipientName'),
        recipientPhone: captureAny(named: 'recipientPhone'),
        recipientUsername: any(named: 'recipientUsername'),
      ),
    ).captured;
    expect(captured[0], 'Fatou Sow');
    expect((captured[0] as String).startsWith('@'), isFalse);
  });

  testWidgets('colis déjà désigné : sans saisie, Enregistrer est inactif', (
    tester,
  ) async {
    await open(tester, _pending());
    final button = tester.widget<DonyButton>(
      find.widgetWithText(DonyButton, 'Enregistrer'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'même compte que le destinataire désigné : message, pas de choix',
    (tester) async {
      lookupReturns(designation: true);
      await open(tester, _pending());
      await search(tester);

      expect(
        find.text('C\'est déjà le destinataire de ce colis.'),
        findsOneWidget,
      );
      final choose = tester.widget<DonyButton>(
        find.byKey(const Key('designate-yadony-user-choose')),
      );
      expect(choose.onPressed, isNull);
    },
  );

  testWidgets('lien refusé, même compte : même blocage', (tester) async {
    lookupReturns(designation: true);
    await open(tester, _pending(appStatus: 'DECLINED'));
    await search(tester);
    expect(
      find.text('C\'est déjà le destinataire de ce colis.'),
      findsOneWidget,
    );
  });

  testWidgets('autre compte : avertissement de renouvellement affiché', (
    tester,
  ) async {
    when(() => datasource.lookupUsername(any())).thenAnswer(
      (_) async => const UsernameLookup(
        username: 'moussa',
        initial: 'M',
        parcelDesignation: true,
      ),
    );
    await open(tester, _pending());
    await tester.tap(find.byKey(const Key('recipient-change-yadony-user')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('designate-yadony-user-field')),
      'moussa',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('designate-yadony-user-choose')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('recipient-change-username-warning')),
      findsOneWidget,
    );
  });

  testWidgets('back sans désignation de colis : la feuille posée, le choix '
      'disparaît (vrai dépôt)', (tester) async {
    lookupReturns(designation: false);
    await open(tester, _pending());
    await search(tester);
    expect(
      find.text('Cette désignation n\'est pas encore disponible.'),
      findsOneWidget,
    );
    // Fermeture de la feuille sans choisir.
    Navigator.of(
      tester.element(find.byKey(const Key('designate-yadony-user-field'))),
    ).pop();
    await tester.pumpAndSettle();

    expect(invitations.parcelDesignationOffered, isFalse);
    expect(find.byKey(const Key('recipient-change-yadony-user')), findsNothing);
  });
}
