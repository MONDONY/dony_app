import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/announcements_summary.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/presentation/notification_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationBloc extends Mock implements NotificationBloc {}

class _FakeEvent extends Fake implements NotificationEvent {}

NotificationModel _notif(String id) => NotificationModel(
  id: id,
  type: 'PAYMENT_RELEASED',
  title: 'Paiement reçu !',
  body: 'Corps.',
  data: const {},
  read: false,
  createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
);

const _summary = AnnouncementsSummary(
  unreadCount: 2,
  latestId: 'a1',
  latestTitle: 'Conditions de transport mises à jour',
);

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
  });

  void stub(NotificationState state) {
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => Stream<NotificationState>.value(state));
  }

  Future<void> pumpSheet(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
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

  testWidgets(
    'la carte porte le nom public, la dernière annonce et le compteur',
    (tester) async {
      stub(
        NotificationLoaded(
          notifications: [_notif('n1')],
          unreadCount: 3,
          announcements: _summary,
        ),
      );

      await pumpSheet(tester);

      expect(find.text('Annonces Yadony'), findsOneWidget);
      expect(find.text('Conditions de transport mises à jour'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // La carte précède le feed.
      final yCard = tester.getTopLeft(find.text('Annonces Yadony')).dy;
      final yFeed = tester.getTopLeft(find.text('Paiement reçu !')).dy;
      expect(yCard, lessThan(yFeed));
    },
  );

  testWidgets('sans non-lu, pas de pastille de compteur', (tester) async {
    stub(
      NotificationLoaded(
        notifications: [_notif('n1')],
        unreadCount: 1,
        announcements: _summary.copyWith(unreadCount: 0),
      ),
    );

    await pumpSheet(tester);

    expect(find.text('Annonces Yadony'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('la carte reste visible quand le feed est vide', (tester) async {
    stub(
      const NotificationLoaded(
        notifications: [],
        unreadCount: 2,
        announcements: _summary,
      ),
    );

    await pumpSheet(tester);

    expect(find.text('Annonces Yadony'), findsOneWidget);
    expect(find.text('Aucune notification'), findsOneWidget);
  });

  testWidgets('sans aucune annonce, pas de carte', (tester) async {
    stub(NotificationLoaded(notifications: [_notif('n1')], unreadCount: 1));

    await pumpSheet(tester);

    expect(find.text('Annonces Yadony'), findsNothing);
  });

  testWidgets('en sombre, le chiffre de la pastille n\'est pas blanc', (
    tester,
  ) async {
    stub(
      NotificationLoaded(
        notifications: [_notif('n1')],
        unreadCount: 3,
        announcements: _summary,
      ),
    );

    await pumpSheet(tester, theme: AppTheme.dark());

    final pill = tester.widget<Text>(find.text('2'));
    expect(pill.style?.color, DonyColors.onBrandHcDark);
  });

  testWidgets('en clair, le chiffre de la pastille reste onPrimary', (
    tester,
  ) async {
    stub(
      NotificationLoaded(
        notifications: [_notif('n1')],
        unreadCount: 3,
        announcements: _summary,
      ),
    );

    await pumpSheet(tester, theme: AppTheme.light());

    final pill = tester.widget<Text>(find.text('2'));
    expect(pill.style?.color, AppTheme.light().colorScheme.onPrimary);
  });
}
