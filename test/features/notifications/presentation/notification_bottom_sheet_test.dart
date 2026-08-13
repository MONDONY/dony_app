import 'package:dony/core/error/app_exception.dart';
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
  String id = 'n1',
  String title = 'Colis accepté',
  String body = 'Votre colis part demain',
  bool read = false,
}) => NotificationModel(
  id: id,
  type: 'BID_ACCEPTED',
  title: title,
  body: body,
  data: const {},
  read: read,
  createdAt: DateTime.utc(2026, 3, 14),
);

void main() {
  late _MockNotificationBloc bloc;

  setUpAll(() async {
    // Les tuiles formatent la date de la notification en fr_FR.
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

  /// [settle] reste faux quand un CircularProgressIndicator est affiché : son
  /// animation ne s'arrête jamais, pumpAndSettle expirerait.
  Future<void> pumpSheet(WidgetTester tester, {bool settle = true}) async {
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('ouverture : la liste est demandée au bloc', (tester) async {
    stub(const NotificationInitial());

    await pumpSheet(tester, settle: false);

    verify(
      () => bloc.add(any(that: isA<NotificationsLoadRequested>())),
    ).called(1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('erreur : état d’erreur avec action de réessai', (tester) async {
    stub(const NotificationError(NetworkException('Hors ligne')));

    await pumpSheet(tester);

    expect(find.text('Erreur de chargement'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    // Un premier chargement a lieu à l'ouverture, le réessai en ajoute un.
    verify(
      () => bloc.add(any(that: isA<NotificationsLoadRequested>())),
    ).called(2);
  });

  testWidgets('aucune notification : état vide dédié', (tester) async {
    stub(const NotificationLoaded(notifications: [], unreadCount: 0));

    await pumpSheet(tester);

    expect(find.text('Aucune notification'), findsOneWidget);
  });

  testWidgets('notifications listées avec titre et corps', (tester) async {
    stub(
      NotificationLoaded(
        notifications: [
          _notif(),
          _notif(id: 'n2', title: 'Colis livré'),
        ],
        unreadCount: 2,
      ),
    );

    await pumpSheet(tester);

    expect(find.text('Colis accepté'), findsOneWidget);
    expect(find.text('Votre colis part demain'), findsWidgets);
    expect(find.text('Colis livré'), findsOneWidget);
  });

  testWidgets('« Tout lire » n’apparaît que s’il reste des non lues', (
    tester,
  ) async {
    stub(
      NotificationLoaded(notifications: [_notif(read: true)], unreadCount: 0),
    );

    await pumpSheet(tester);

    expect(find.text('Tout lire'), findsNothing);
  });

  testWidgets('« Tout lire » marque toutes les notifications lues', (
    tester,
  ) async {
    stub(NotificationLoaded(notifications: [_notif()], unreadCount: 1));

    await pumpSheet(tester);

    expect(find.text('Tout lire'), findsOneWidget);

    await tester.tap(find.text('Tout lire'));
    await tester.pump();

    verify(
      () => bloc.add(any(that: isA<NotificationsMarkAllReadRequested>())),
    ).called(1);
  });

  testWidgets('tap sur une notification la marque comme lue', (tester) async {
    stub(NotificationLoaded(notifications: [_notif()], unreadCount: 1));

    await pumpSheet(tester);

    await tester.tap(find.text('Colis accepté'));
    await tester.pump();

    verify(
      () => bloc.add(any(that: isA<NotificationMarkReadRequested>())),
    ).called(1);
  });
}
