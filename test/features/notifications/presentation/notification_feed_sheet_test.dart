import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/presentation/notification_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationBloc extends Mock implements NotificationBloc {}

class _FakeEvent extends Fake implements NotificationEvent {}

NotificationModel _notif({
  required String id,
  required DateTime createdAt,
  String title = 'Titre',
  bool read = false,
  String type = 'PAYMENT_RELEASED',
  String? deeplink,
  String? groupKey,
  int count = 1,
}) => NotificationModel(
  id: id,
  type: type,
  title: title,
  body: 'Corps de la notification.',
  data: const {},
  read: read,
  createdAt: createdAt,
  deeplink: deeplink,
  groupKey: groupKey,
  count: count,
  notificationIds: List.generate(count, (i) => '$id-$i'),
);

void main() {
  late _MockNotificationBloc bloc;
  final now = DateTime(2026, 9, 3, 12);

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    registerFallbackValue(_FakeEvent());
  });

  setUp(() {
    bloc = _MockNotificationBloc();
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => bloc.add(any())).thenReturn(null);
  });

  void stub(NotificationState state) {
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => Stream<NotificationState>.value(state));
  }

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<NotificationBloc>.value(
            value: bloc,
            child: const NotificationBottomSheet(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('sections temporelles', () {
    test(
      'moins de 24 h : Nouveau ; moins de 7 j : Cette semaine ; sinon Plus tôt',
      () {
        expect(
          NotificationSection.of(now.subtract(const Duration(hours: 23)), now),
          NotificationSection.nouveau,
        );
        expect(
          NotificationSection.of(now.subtract(const Duration(hours: 25)), now),
          NotificationSection.cetteSemaine,
        );
        expect(
          NotificationSection.of(now.subtract(const Duration(days: 6)), now),
          NotificationSection.cetteSemaine,
        );
        expect(
          NotificationSection.of(now.subtract(const Duration(days: 8)), now),
          NotificationSection.plusTot,
        );
      },
    );

    testWidgets(
      'chaque section présente a son en-tête, dans l\'ordre du feed',
      (tester) async {
        final recent = DateTime.now().subtract(const Duration(minutes: 5));
        final thisWeek = DateTime.now().subtract(const Duration(days: 2));
        final earlier = DateTime.now().subtract(const Duration(days: 20));
        stub(
          NotificationLoaded(
            notifications: [
              _notif(id: 'a', createdAt: recent, title: 'Récente'),
              _notif(id: 'b', createdAt: thisWeek, title: 'Semaine'),
              _notif(id: 'c', createdAt: earlier, title: 'Ancienne'),
            ],
            unreadCount: 3,
          ),
        );

        await pumpSheet(tester);

        expect(find.text('NOUVEAU'), findsOneWidget);
        expect(find.text('CETTE SEMAINE'), findsOneWidget);
        expect(find.text('PLUS TÔT'), findsOneWidget);
        final yNouveau = tester.getTopLeft(find.text('NOUVEAU')).dy;
        final ySemaine = tester.getTopLeft(find.text('CETTE SEMAINE')).dy;
        final yPlusTot = tester.getTopLeft(find.text('PLUS TÔT')).dy;
        expect(yNouveau, lessThan(ySemaine));
        expect(ySemaine, lessThan(yPlusTot));
      },
    );

    testWidgets('une section vide ne s\'affiche pas', (tester) async {
      stub(
        NotificationLoaded(
          notifications: [
            _notif(
              id: 'a',
              createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
          ],
          unreadCount: 1,
        ),
      );

      await pumpSheet(tester);

      expect(find.text('NOUVEAU'), findsOneWidget);
      expect(find.text('CETTE SEMAINE'), findsNothing);
      expect(find.text('PLUS TÔT'), findsNothing);
    });
  });

  group('horodatage compact', () {
    test('minutes, heures, jours, puis la date', () {
      expect(
        formatNotificationAge(now.subtract(const Duration(seconds: 20)), now),
        'maintenant',
      );
      expect(
        formatNotificationAge(now.subtract(const Duration(minutes: 2)), now),
        '2 min',
      );
      expect(
        formatNotificationAge(now.subtract(const Duration(hours: 3)), now),
        '3 h',
      );
      expect(
        formatNotificationAge(now.subtract(const Duration(days: 2)), now),
        '2 j',
      );
      expect(formatNotificationAge(DateTime(2026, 8, 12), now), '12 août');
      expect(
        formatNotificationAge(DateTime(2025, 12, 24), now),
        '24 déc. 2025',
      );
    });
  });

  group('ligne agrégée', () {
    test('sa route est le deeplink du groupe, pas celle de la dernière', () {
      final aggregate = _notif(
        id: 'agg',
        createdAt: now,
        type: 'BID_CREATED',
        deeplink: 'yadony://announcements/a1/bids',
        groupKey: 'bid:announcement:a1',
        count: 3,
      );
      expect(routeForNotification(aggregate), '/announcements/a1/bids');
    });

    test(
      'une ligne seule suit son deeplink, le resolver ne sert qu\'en repli',
      () {
        final withLink = _notif(
          id: 's',
          createdAt: now,
          type: 'KYC_VERIFIED',
          deeplink: 'yadony://kyc/verify',
        );
        expect(routeForNotification(withLink), '/kyc/verify');

        final legacy = _notif(id: 'l', createdAt: now, type: 'KYC_VERIFIED');
        expect(routeForNotification(legacy), '/kyc/status');
      },
    );

    test('sans deeplink ni route connue, la ligne ouvre son détail', () {
      final annonce = _notif(id: 'a1', createdAt: now, type: 'ADMIN_BROADCAST');
      expect(routeForNotification(annonce), '/notifications/a1');
    });

    testWidgets('le tap lit la ligne par son id, comme une ligne seule', (
      tester,
    ) async {
      stub(
        NotificationLoaded(
          notifications: [
            _notif(
              id: 'agg',
              createdAt: DateTime.now(),
              title: '3 demandes d\'envoi',
              groupKey: 'bid:announcement:a1',
              count: 3,
            ),
          ],
          unreadCount: 3,
        ),
      );

      await pumpSheet(tester);
      await tester.tap(find.text('3 demandes d\'envoi'));
      await tester.pump();

      verify(
        () => bloc.add(
          any(
            that: isA<NotificationMarkReadRequested>().having(
              (e) => e.id,
              'id',
              'agg',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('une ligne agrégée ne se supprime pas d\'un geste', (
      tester,
    ) async {
      stub(
        NotificationLoaded(
          notifications: [
            _notif(
              id: 'agg',
              createdAt: DateTime.now(),
              title: 'Agrégat',
              groupKey: 'bid:announcement:a1',
              count: 3,
            ),
            _notif(id: 's', createdAt: DateTime.now(), title: 'Seule'),
          ],
          unreadCount: 4,
        ),
      );

      await pumpSheet(tester);

      expect(find.byType(Dismissible), findsOneWidget);
    });
  });

  testWidgets('le titre tient sur une ligne et le corps sur deux', (
    tester,
  ) async {
    stub(
      NotificationLoaded(
        notifications: [
          _notif(id: 'a', createdAt: DateTime.now(), title: 'Un titre'),
        ],
        unreadCount: 1,
      ),
    );

    await pumpSheet(tester);

    final title = tester.widget<Text>(find.text('Un titre'));
    final body = tester.widget<Text>(find.text('Corps de la notification.'));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(body.maxLines, 2);
    expect(body.overflow, TextOverflow.ellipsis);
  });
}
