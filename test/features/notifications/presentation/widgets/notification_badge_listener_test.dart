import 'package:dony/core/services/app_badge_service.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/announcements_summary.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:dony/features/notifications/presentation/widgets/notification_badge_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

NotificationModel _notif(String id) => NotificationModel(
  id: id,
  type: 'BID_ACCEPTED',
  title: 't',
  body: 'b',
  data: const {},
  read: false,
  createdAt: DateTime(2026, 9, 28),
);

/// Lire ses notifications puis quitter l'application laissait l'ancien nombre
/// sur l'icône : la pastille n'était relue qu'au démarrage, à une push ou au
/// retour au premier plan. Elle doit suivre chaque lecture, sur-le-champ.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AppBadgeService.channelName);
  late List<int> ecrits;
  late MockNotificationRepository repository;
  late NotificationBloc bloc;

  setUp(() {
    ecrits = <int>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'setBadge') {
            ecrits.add((call.arguments as Map)['count'] as int);
          }
          return null;
        });
    repository = MockNotificationRepository();
    when(
      () => repository.getFeed(),
    ).thenAnswer((_) async => [_notif('a'), _notif('b'), _notif('c')]);
    when(() => repository.getUnreadCount()).thenAnswer((_) async => 3);
    when(
      () => repository.getAnnouncementsSummary(),
    ).thenAnswer((_) async => AnnouncementsSummary.empty);
    when(() => repository.markRead(any())).thenAnswer((_) async {});
    when(() => repository.markAllRead()).thenAnswer((_) async {});
    bloc = NotificationBloc(repository);
  });

  tearDown(() async {
    await bloc.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // Le bloc et le canal natif enchaînent de vrais futurs : le temps simulé de
  // testWidgets ne les laisse pas aboutir, d'où le passage par runAsync.
  Future<void> envoyer(WidgetTester tester, NotificationEvent event) async {
    await tester.runAsync(() async {
      bloc.add(event);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }

  Future<void> monter(WidgetTester tester) => tester.pumpWidget(
    BlocProvider<NotificationBloc>.value(
      value: bloc,
      child: NotificationBadgeListener(
        badge: AppBadgeService(),
        child: const SizedBox(),
      ),
    ),
  );

  testWidgets('la pastille suit chaque lecture sans quitter l\'application', (
    tester,
  ) async {
    await monter(tester);

    await envoyer(tester, const NotificationsLoadRequested());
    expect(ecrits, [3]);

    await envoyer(tester, const NotificationMarkReadRequested('a'));
    expect(ecrits, [3, 2]);

    await envoyer(tester, const NotificationsMarkAllReadRequested());
    expect(ecrits, [3, 2, 0]);
  });

  testWidgets(
    'les états de chargement et d\'erreur ne touchent pas la pastille',
    (tester) async {
      when(() => repository.getFeed()).thenThrow(Exception('réseau'));
      await monter(tester);

      await envoyer(tester, const NotificationsLoadRequested());

      expect(bloc.state, isA<NotificationError>());
      expect(ecrits, isEmpty);
    },
  );
}
