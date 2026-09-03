import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_bloc.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_event.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/presentation/announcements_inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends Mock implements AnnouncementsInboxBloc {}

class _FakeEvent extends Fake implements AnnouncementsInboxEvent {}

NotificationModel _annonce({
  required String id,
  String title = 'Maintenance ce soir',
  bool read = false,
}) => NotificationModel(
  id: id,
  type: 'ADMIN_BROADCAST',
  category: 'annonce',
  title: title,
  body: 'Le service sera interrompu de 22 h à 23 h.',
  data: const {},
  read: read,
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
);

void main() {
  late _MockBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    registerFallbackValue(_FakeEvent());
  });

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => bloc.add(any())).thenReturn(null);
    if (getIt.isRegistered<AnnouncementsInboxBloc>()) {
      getIt.unregister<AnnouncementsInboxBloc>();
    }
    getIt.registerFactory<AnnouncementsInboxBloc>(() => bloc);
  });

  tearDown(() => getIt.unregister<AnnouncementsInboxBloc>());

  void stub(AnnouncementsInboxState state) {
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => Stream<AnnouncementsInboxState>.value(state));
  }

  Future<void> pump(WidgetTester tester, {bool settle = true}) async {
    await tester.pumpWidget(
      const MaterialApp(home: AnnouncementsInboxScreen()),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('ouverture : la liste est demandée au bloc', (tester) async {
    stub(const AnnouncementsInboxInitial());

    await pump(tester, settle: false);

    verify(
      () => bloc.add(any(that: isA<AnnouncementsInboxLoadRequested>())),
    ).called(1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Annonces Yadony'), findsOneWidget);
  });

  testWidgets('erreur : état dédié avec réessai', (tester) async {
    stub(const AnnouncementsInboxError(NetworkException('Hors ligne')));

    await pump(tester);
    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    verify(
      () => bloc.add(any(that: isA<AnnouncementsInboxLoadRequested>())),
    ).called(2);
  });

  testWidgets('aucune annonce : état vide', (tester) async {
    stub(const AnnouncementsInboxLoaded([]));

    await pump(tester);

    expect(find.text('Aucune annonce'), findsOneWidget);
  });

  testWidgets('les annonces sont listées sans icône, titre et corps bornés', (
    tester,
  ) async {
    stub(
      AnnouncementsInboxLoaded([
        _annonce(id: 'a'),
        _annonce(id: 'b', title: 'Nouvelles conditions', read: true),
      ]),
    );

    await pump(tester);

    expect(find.text('Maintenance ce soir'), findsOneWidget);
    expect(find.text('Nouvelles conditions'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Maintenance ce soir'));
    expect(title.maxLines, 1);
    final body = tester
        .widgetList<Text>(
          find.text('Le service sera interrompu de 22 h à 23 h.'),
        )
        .first;
    expect(body.maxLines, 2);
  });

  testWidgets('le tap marque l\'annonce lue', (tester) async {
    stub(AnnouncementsInboxLoaded([_annonce(id: 'a')]));

    await pump(tester);
    await tester.tap(find.text('Maintenance ce soir'));
    await tester.pump();

    verify(
      () => bloc.add(
        any(
          that: isA<AnnouncementsInboxMarkReadRequested>().having(
            (e) => e.id,
            'id',
            'a',
          ),
        ),
      ),
    ).called(1);
  });
}
