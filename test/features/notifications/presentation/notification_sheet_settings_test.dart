import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/presentation/notification_bottom_sheet.dart';
import 'package:dony/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

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
);

const _settingsKey = Key('notification-sheet-settings');

/// Sentry FLUTTER-QA : « permettre de paramétrer les notifications ici ».
/// L'en-tête du centre de notifications ouvre Réglages › Notifications.
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
  });

  void stub(NotificationState state) {
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => Stream<NotificationState>.value(state));
  }

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
        path: NotificationSettingsScreen.route,
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              const Text('Réglages des notifications (écran)'),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Future<void> openSheet(WidgetTester tester, {Locale? locale}) async {
    final router = buildRouter();
    await tester.pumpWidget(
      locale == null
          ? MaterialApp.router(routerConfig: router)
          : MaterialApp.router(
              routerConfig: router,
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
    );
    await tester.tap(find.text('Cloche'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationBottomSheet), findsOneWidget);
  }

  test('la route vise Réglages › Notifications', () {
    expect(NotificationSettingsScreen.route, '/settings/notifications');
  });

  testWidgets('bouton réglages dans l\'en-tête, avec son libellé', (
    tester,
  ) async {
    stub(NotificationLoaded(notifications: [_notif], unreadCount: 1));
    await openSheet(tester);

    expect(find.byKey(_settingsKey), findsOneWidget);
    expect(find.byTooltip('Réglages des notifications'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(_settingsKey)),
      isSemantics(
        tooltip: 'Réglages des notifications',
        isButton: true,
        isEnabled: true,
      ),
    );
    // « Tout lire » reste à côté.
    expect(find.text('Tout lire'), findsOneWidget);
  });

  testWidgets('aussi dans l\'état vide', (tester) async {
    stub(const NotificationLoaded(notifications: [], unreadCount: 0));
    await openSheet(tester);

    expect(find.byKey(_settingsKey), findsOneWidget);
  });

  testWidgets('libellé anglais', (tester) async {
    enableEnglish();
    stub(const NotificationLoaded(notifications: [], unreadCount: 0));
    await openSheet(tester, locale: AppL10n.en);

    expect(find.byTooltip('Notification settings'), findsOneWidget);
  });

  testWidgets('tap : le sheet se ferme, les réglages s\'ouvrent, le retour '
      'ramène au sheet', (tester) async {
    stub(NotificationLoaded(notifications: [_notif], unreadCount: 1));
    await openSheet(tester);

    await tester.tap(find.byKey(_settingsKey));
    await tester.pumpAndSettle();

    expect(find.text('Réglages des notifications (écran)'), findsOneWidget);
    expect(find.byType(NotificationBottomSheet), findsNothing);

    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();

    expect(find.text('Cloche'), findsOneWidget);
    expect(find.byType(NotificationBottomSheet), findsOneWidget);
  });
}
