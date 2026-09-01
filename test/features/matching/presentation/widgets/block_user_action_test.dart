import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/features/matching/presentation/widgets/block_user_action.dart';
import 'package:dony/features/settings/bloc/blocked_users_bloc.dart';
import 'package:dony/features/settings/data/repositories/blocked_users_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBlockedUsersRepository extends Mock
    implements BlockedUsersRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockBlockedUsersRepository mockRepo;
  late MockAnalyticsService mockAnalytics;
  late BlockEventsService blockEvents;

  setUp(() {
    mockRepo = MockBlockedUsersRepository();
    mockAnalytics = MockAnalyticsService();
    blockEvents = BlockEventsService();
    when(
      () => mockAnalytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    // Le dialog fournit son propre BLoC via getIt : c'est le seul point
    // d'injection à truquer pour le tester sans toucher aux écrans appelants.
    if (getIt.isRegistered<BlockedUsersBloc>()) {
      getIt.unregister<BlockedUsersBloc>();
    }
    getIt.registerFactory<BlockedUsersBloc>(
      () => BlockedUsersBloc(mockRepo, mockAnalytics, blockEvents),
    );
  });

  tearDown(() async {
    if (getIt.isRegistered<BlockedUsersBloc>()) {
      getIt.unregister<BlockedUsersBloc>();
    }
    await blockEvents.dispose();
  });

  /// Écran minimal dont le seul rôle est d'ouvrir le dialog au premier tap.
  Widget host() => MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => showBlockConfirmDialog(
            context,
            userId: 'u1',
            displayName: 'Mamadou Diallo',
          ),
          child: const Text('ouvrir'),
        ),
      ),
    ),
  );

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('le dialog annonce le blocage du prénom de la personne', (
    tester,
  ) async {
    await openDialog(tester);

    expect(find.text('Bloquer Mamadou ?'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
  });

  testWidgets('confirmer déclenche le blocage côté repository', (tester) async {
    when(() => mockRepo.blockUser('u1')).thenAnswer((_) async {});

    await openDialog(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Bloquer'));
    await tester.pump();

    verify(() => mockRepo.blockUser('u1')).called(1);
  });

  testWidgets('un échec serveur affiche le message d\'erreur dans le dialog', (
    tester,
  ) async {
    when(() => mockRepo.blockUser('u1')).thenThrow(Exception('Server'));

    await openDialog(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Bloquer'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Une erreur est survenue. Réessaie plus tard.'),
      findsOneWidget,
    );
    // Le dialog reste ouvert pour laisser réessayer.
    expect(find.text('Bloquer Mamadou ?'), findsOneWidget);
  });

  testWidgets('annuler ferme le dialog sans rien bloquer', (tester) async {
    await openDialog(tester);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Bloquer Mamadou ?'), findsNothing);
    verifyNever(() => mockRepo.blockUser(any()));
  });
}
