import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/widgets/dony_icon.dart';
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
  String type = 'BID_ACCEPTED',
}) => NotificationModel(
  id: id,
  type: type,
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

  group('icône par type', () {
    /// Monte une notification du [type] donné et rend l'asset de son icône.
    /// Null quand le type est rendu par un emoji (famille colis) plutôt que
    /// par un SVG.
    Future<String?> iconAssetFor(WidgetTester tester, String type) async {
      // Démontage explicite : sans ça, le pumpWidget suivant met à jour
      // l'arbre existant au lieu de le remonter, et le BlocBuilder garde la
      // tuile précédente — chaque cas verrait l'icône du cas d'avant.
      await tester.pumpWidget(const SizedBox.shrink());
      stub(
        NotificationLoaded(notifications: [_notif(type: type)], unreadCount: 1),
      );
      await pumpSheet(tester);
      final icons = tester.widgetList<DonyIcon>(find.byType(DonyIcon)).toList();
      // La tuile porte aussi un chevron quand le type a une route : on ne
      // retient que la première icône, celle du carré de gauche.
      return icons.isEmpty ? null : icons.first.name;
    }

    testWidgets('les familles ont chacune leur icône', (tester) async {
      expect(await iconAssetFor(tester, 'BID_ACCEPTED'), 'circle-check');
      expect(await iconAssetFor(tester, 'PAYMENT_RELEASED'), 'banknote');
      expect(await iconAssetFor(tester, 'TRIP_CANCELLED'), 'ban');
      expect(await iconAssetFor(tester, 'DISPUTE_OPENED'), 'triangle-alert');
      expect(await iconAssetFor(tester, 'MM_PAYMENT_PENDING'), 'credit-card');
      expect(await iconAssetFor(tester, 'NEW_MESSAGE'), 'message-circle');
      expect(await iconAssetFor(tester, 'CORRIDOR_ALERT'), 'plane');
    });

    /// Les trois familles qui tombaient sur la cloche générique avant d'être
    /// cartographiées — le test garde la régression fermée.
    testWidgets(
      'négociations, automatisations et expirations sont distinguées',
      (tester) async {
        expect(
          await iconAssetFor(tester, 'negotiation_counter'),
          'arrow-left-right',
        );
        expect(await iconAssetFor(tester, 'automation_last_minute'), 'zap');
        expect(await iconAssetFor(tester, 'negotiation_expired'), 'timer-off');
      },
    );

    testWidgets('un type inconnu garde la cloche neutre', (tester) async {
      expect(await iconAssetFor(tester, 'TYPE_INEXISTANT'), 'bell');
    });
  });
}
