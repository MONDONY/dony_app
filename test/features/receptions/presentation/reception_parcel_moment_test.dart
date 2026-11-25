import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/receptions/bloc/reception_detail_cubit.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/receptions/presentation/screens/reception_detail_screen.dart';
import 'package:dony/features/video_modal/data/models/parcel_role.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../video_modal/moment_test_support.dart';

class _MockCubit extends MockCubit<ReceptionDetailState>
    implements ReceptionDetailCubit {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

const _id = 'b1';

Reception _reception({
  String linkStatus = 'CONFIRMED',
  String bidStatus = 'ARRIVED',
}) => Reception(
  bidId: _id,
  linkStatus: linkStatus,
  bidStatus: bidStatus,
  senderFirstName: 'Awa',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  recipientName: 'Moussa Diop',
  travelerFirstName: 'Ibrahima',
  trackingNumber: 'DON-AB12CD',
  confirmationCode: '482913',
);

/// Écran de réception : le destinataire dont le lien est confirmé reçoit le
/// moment d'étape à l'ouverture, une fois, avec le rôle destinataire.
void main() {
  late _MockCubit cubit;
  late RecordingMoments moments;
  late List<Reception> timelineOpened;

  setUpAll(() {
    registerFallbackValue(const ConversationOpenRequested('x'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DonySnackbar.clearDedup();
    moments = useRecordingMoments();
    timelineOpened = [];
    cubit = _MockCubit();
    when(() => cubit.load(any())).thenAnswer((_) async {});
    when(() => cubit.retry()).thenAnswer((_) async {});
    if (getIt.isRegistered<ReceptionDetailCubit>()) {
      getIt.unregister<ReceptionDetailCubit>();
    }
    getIt.registerFactory<ReceptionDetailCubit>(() => cubit);
    final conversationOpen = _MockConversationOpenBloc();
    when(
      () => conversationOpen.state,
    ).thenReturn(const ConversationOpenInitial());
    if (getIt.isRegistered<ConversationOpenBloc>()) {
      getIt.unregister<ConversationOpenBloc>();
    }
    getIt.registerFactory<ConversationOpenBloc>(() => conversationOpen);
  });

  tearDown(() {
    getIt.unregister<ReceptionDetailCubit>();
    getIt.unregister<ConversationOpenBloc>();
  });

  Future<void> pump(
    WidgetTester tester,
    List<ReceptionDetailState> later, {
    ReceptionDetailState initial = const ReceptionDetailLoading(),
  }) async {
    whenListen(cubit, Stream.fromIterable(later), initialState: initial);
    final router = GoRouter(
      initialLocation: '/receptions/$_id',
      routes: [
        GoRoute(
          path: '/receptions/:bidId',
          builder: (_, state) => ReceptionDetailScreen(
            bidId: state.pathParameters['bidId']!,
            openTimeline: (_, reception) async => timelineOpened.add(reception),
            openQr: (_, _) async {},
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    await flushStorage(tester);
  }

  testWidgets('lien confirmé : le moment de l\'étape, rôle destinataire', (
    tester,
  ) async {
    await pump(tester, [ReceptionDetailLoaded(_reception())]);
    expect(moments.triggers, [VideoModalTrigger.parcelArrived]);
    final moment = moments.emitted.single;
    expect(moment.parcel!.bidId, _id);
    expect(moment.parcel!.roles, {ParcelRole.recipient});
    expect(moment.parcel!.detailRoute, '/receptions/$_id');
    // Émis par la réception de ce colis : « Voir le colis » ferme le modal.
    expect(moment.parcel!.onDetailScreen, isTrue);
    expect(moment.variables, {
      'destinataire': 'Moussa Diop',
      'voyageur': 'Ibrahima',
      'expéditeur': 'Awa',
      'ville_arrivee': 'Dakar',
    });
    expect(moment.variables.values.join(), isNot(contains('482913')));
    expect(moments.origins.single!.mounted, isTrue);
    // QR et envoi du code : jamais pour le destinataire ; le suivi oui.
    expect(moment.parcel!.canRun(InfoScreen.parcelQr), isFalse);
    expect(moment.parcel!.canRun(InfoScreen.parcelSendCode), isFalse);
    expect(moment.parcel!.canRun(InfoScreen.parcelTracking), isTrue);
    await moment.parcel!.openers.tracking!(
      tester.element(find.byType(Scaffold)),
    );
    expect(timelineOpened.single.bidId, _id);
  });

  testWidgets('chaque étape des rails a son déclencheur', (tester) async {
    for (final (status, trigger) in [
      ('ACCEPTED', VideoModalTrigger.parcelAccepted),
      ('HANDED_OVER', VideoModalTrigger.parcelHandedOver),
      ('IN_TRANSIT', VideoModalTrigger.parcelInTransit),
      ('COMPLETED', VideoModalTrigger.parcelDelivered),
    ]) {
      moments.emitted.clear();
      await pump(tester, [
        ReceptionDetailLoaded(_reception(bidStatus: status)),
      ]);
      expect(moments.triggers, [trigger], reason: status);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'lien en attente : rien ; confirmé pendant l\'ouverture : une fois',
    (tester) async {
      await pump(tester, [
        ReceptionDetailLoaded(_reception(linkStatus: 'PENDING')),
      ]);
      expect(moments.emitted, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, [
        ReceptionDetailLoaded(_reception(linkStatus: 'PENDING')),
        ReceptionDetailLoaded(_reception(), action: ReceptionAction.confirmed),
        ReceptionDetailLoaded(_reception()),
      ]);
      expect(moments.triggers, [VideoModalTrigger.parcelArrived]);
      expect(moments.emitted.single.parcel!.roles, {ParcelRole.recipient});
    },
  );

  testWidgets('gestes et relectures de la même ouverture : une seule fois', (
    tester,
  ) async {
    await pump(tester, [
      ReceptionDetailLoaded(_reception()),
      ReceptionDetailLoaded(_reception(), action: ReceptionAction.rating),
      ReceptionDetailLoaded(_reception(), action: ReceptionAction.rated),
      ReceptionDetailLoaded(_reception(bidStatus: 'COMPLETED')),
    ]);
    expect(moments.triggers, [VideoModalTrigger.parcelArrived]);
  });

  testWidgets('premier chargement en échec puis « Réessayer » : une fois', (
    tester,
  ) async {
    await pump(tester, [
      const ReceptionDetailError(OfflineException()),
      const ReceptionDetailLoading(),
      ReceptionDetailLoaded(_reception()),
    ]);
    expect(moments.triggers, [VideoModalTrigger.parcelArrived]);
  });

  testWidgets('déjà chargé à l\'affichage (aucune transition) : rien', (
    tester,
  ) async {
    await pump(tester, const [], initial: ReceptionDetailLoaded(_reception()));
    expect(moments.emitted, isEmpty);
  });
}
