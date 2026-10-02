import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/presentation/notification_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationBloc extends Mock implements NotificationBloc {}

class _FakeEvent extends Fake implements NotificationEvent {}

final _notif = NotificationModel(
  id: 'n1',
  type: 'NEW_BID',
  title: 'Nouvelle demande d\'envoi',
  body: 'Ibou, 2 kg, Paris vers Abidjan.',
  data: const {},
  read: false,
  createdAt: DateTime.now().subtract(const Duration(hours: 6)),
  deeplink: 'yadony://bids/b1',
);

/// Sentry FLUTTER-8K : ouverte depuis le sheet des notifications, une page
/// renvoyait au retour sur l'écran de dessous, le sheet ayant été fermé.
void main() {
  late _MockNotificationBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    registerFallbackValue(_FakeEvent());
  });

  setUp(() {
    bloc = _MockNotificationBloc();
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => bloc.add(any())).thenReturn(null);
    when(() => bloc.isClosed).thenReturn(false);
    final state = NotificationLoaded(notifications: [_notif], unreadCount: 1);
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => Stream<NotificationState>.value(state));
  });

  GoRouter buildRouter() => GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => BlocProvider<NotificationBloc>.value(
          value: bloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showNotificationBottomSheet(context),
                  child: const Text('Cloche'),
                ),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              const Text('Détail de la demande'),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Retour'),
              ),
              TextButton(
                onPressed: () => context.go('/messages'),
                child: const Text('Vers Messages'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/messages',
        builder: (_, _) => const Scaffold(body: Text('Messages')),
      ),
    ],
  );

  Future<GoRouter> openNotification(WidgetTester tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Cloche'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationBottomSheet), findsOneWidget);

    await tester.tap(find.text('Nouvelle demande d\'envoi'));
    await tester.pumpAndSettle();
    expect(find.text('Détail de la demande'), findsOneWidget);
    expect(find.byType(NotificationBottomSheet), findsNothing);
    return router;
  }

  testWidgets('retour depuis la page ouverte : le sheet revient', (
    tester,
  ) async {
    await openNotification(tester);

    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();

    expect(find.text('Cloche'), findsOneWidget);
    expect(find.byType(NotificationBottomSheet), findsOneWidget);
    expect(find.text('Nouvelle demande d\'envoi'), findsOneWidget);
  });

  testWidgets('parti ailleurs entre-temps : le sheet ne revient pas', (
    tester,
  ) async {
    await openNotification(tester);

    await tester.tap(find.text('Vers Messages'));
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.byType(NotificationBottomSheet), findsNothing);
  });
}
