import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/notifications/bloc/notification_detail_cubit.dart';
import 'package:dony/features/notifications/data/notification_detail.dart';
import 'package:dony/features/notifications/presentation/notification_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends Mock implements NotificationDetailCubit {}

NotificationDetail _detail({String category = 'annonce'}) => NotificationDetail(
  id: 'a1',
  type: 'ADMIN_BROADCAST',
  category: category,
  title: 'Conditions de transport mises à jour',
  body: 'Court.',
  fullBody:
      'À partir du 15 septembre, les objets de valeur doivent être '
      'déclarés avant la remise. Le voyageur peut refuser un colis non '
      'déclaré.',
  read: false,
  createdAt: DateTime(2026, 9, 3, 10, 30),
);

void main() {
  late _MockCubit cubit;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  setUp(() {
    cubit = _MockCubit();
    when(() => cubit.close()).thenAnswer((_) async {});
    when(() => cubit.load(any())).thenAnswer((_) async {});
    if (getIt.isRegistered<NotificationDetailCubit>()) {
      getIt.unregister<NotificationDetailCubit>();
    }
    getIt.registerFactory<NotificationDetailCubit>(() => cubit);
  });

  tearDown(() => getIt.unregister<NotificationDetailCubit>());

  void stub(NotificationDetailState state) {
    when(() => cubit.state).thenReturn(state);
    when(
      () => cubit.stream,
    ).thenAnswer((_) => Stream<NotificationDetailState>.value(state));
  }

  Future<void> pump(WidgetTester tester, {bool settle = true}) async {
    await tester.pumpWidget(
      const MaterialApp(home: NotificationDetailScreen(id: 'a1')),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('ouverture : le détail est demandé au cubit', (tester) async {
    stub(const NotificationDetailLoading());

    await pump(tester, settle: false);

    verify(() => cubit.load('a1')).called(1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('une annonce : titre, date et texte complet', (tester) async {
    stub(NotificationDetailLoaded(_detail()));

    await pump(tester);

    expect(find.text('Annonce Yadony'), findsOneWidget);
    expect(find.text('Conditions de transport mises à jour'), findsOneWidget);
    expect(find.textContaining('3 septembre 2026'), findsOneWidget);
    expect(
      find.textContaining('déclarés avant la remise'),
      findsOneWidget,
      reason: 'le texte complet, pas le corps court',
    );
    expect(find.text('Court.'), findsNothing);
  });

  testWidgets('hors annonce, l\'en-tête reste générique', (tester) async {
    stub(NotificationDetailLoaded(_detail(category: 'paiements')));

    await pump(tester);

    expect(find.text('Notification'), findsOneWidget);
  });

  testWidgets('introuvable : repli explicite avec réessai', (tester) async {
    stub(const NotificationDetailError(NetworkException('404')));

    await pump(tester);

    expect(find.text('Notification introuvable'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    verify(() => cubit.load('a1')).called(2);
  });
}
