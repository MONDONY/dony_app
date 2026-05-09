import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/role_guidance_banner.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockHiveService extends Mock implements HiveService {}
class MockBox extends Mock implements Box {}

Widget _buildBanner({
  required ActiveRole role,
  required bool hasPublished,
  required MockHiveService hive,
}) {
  final mockBox = MockBox();
  when(() => hive.userPrefs).thenReturn(mockBox);
  when(() => mockBox.get(HiveService.kHasPublishedAsTraveler, defaultValue: false))
      .thenReturn(role == ActiveRole.traveler ? hasPublished : false);
  when(() => mockBox.get(HiveService.kHasPublishedAsSender, defaultValue: false))
      .thenReturn(role == ActiveRole.sender ? hasPublished : false);
  when(() => hive.listenUserPrefs(keys: any(named: 'keys')))
      .thenReturn(ValueNotifier<Box>(mockBox));

  return MaterialApp(
    home: Scaffold(
      body: RoleGuidanceBanner(role: role, hiveService: hive),
    ),
  );
}

void main() {
  late MockHiveService mockHive;
  setUp(() => mockHive = MockHiveService());

  testWidgets('affiche le banner Expéditeur quand pas encore publié', (tester) async {
    await tester.pumpWidget(
      _buildBanner(role: ActiveRole.sender, hasPublished: false, hive: mockHive),
    );
    expect(find.text('Envoyer ton premier colis'), findsOneWidget);
    expect(find.text("Publier ma demande d'envoi"), findsOneWidget);
  });

  testWidgets('affiche le banner Voyageur quand pas encore publié', (tester) async {
    await tester.pumpWidget(
      _buildBanner(role: ActiveRole.traveler, hasPublished: false, hive: mockHive),
    );
    expect(find.text('Publier ton premier trajet'), findsOneWidget);
    expect(find.text('Publier mon trajet'), findsOneWidget);
  });

  testWidgets("ne s'affiche pas si déjà publié en mode Expéditeur", (tester) async {
    await tester.pumpWidget(
      _buildBanner(role: ActiveRole.sender, hasPublished: true, hive: mockHive),
    );
    expect(find.text('Envoyer ton premier colis'), findsNothing);
  });

  testWidgets("ne s'affiche pas si déjà publié en mode Voyageur", (tester) async {
    await tester.pumpWidget(
      _buildBanner(role: ActiveRole.traveler, hasPublished: true, hive: mockHive),
    );
    expect(find.text('Publier ton premier trajet'), findsNothing);
  });
}
