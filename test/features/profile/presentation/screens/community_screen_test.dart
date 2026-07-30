import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/profile/presentation/screens/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/mock_analytics_backend.dart';

const _emptyConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

const _socialConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [
    {
      "network": "whatsapp",
      "url": "https://community.example/whatsapp",
      "active": true
    },
    {
      "network": "instagram",
      "url": "https://instagram.com/yadony",
      "active": true
    },
    {
      "network": "tiktok",
      "url": "https://tiktok.com/@yadony",
      "active": false
    }
  ],
  "tutorials": []
}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}

Widget _wrap({String configJson = _emptyConfigJson}) {
  return BlocProvider(
    create: (_) => HelpCenterBloc(
      HelpCenterRepository(
        _StaticHelpCenterSource(configJson),
        fallbackJsonLoader: () async => _emptyConfigJson,
      ),
      makeDisabledAnalytics(MockAnalyticsBackend()),
    )..add(const HelpCenterLoadRequested()),
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const CommunityScreen(),
    ),
  );
}

void main() {
  testWidgets('affiche le titre', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Réseaux sociaux'), findsOneWidget);
  });

  testWidgets('catalogue vide : affiche un état vide, pas la section', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('community-empty-state')), findsOneWidget);
    expect(find.text('Rejoindre la communauté'), findsNothing);
  });

  testWidgets(
    'réseaux actifs : affiche uniquement les réseaux actifs, pas l\'état vide',
    (tester) async {
      await tester.pumpWidget(_wrap(configJson: _socialConfigJson));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('community-empty-state')), findsNothing);
      expect(find.text('Rejoindre la communauté'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('TikTok'), findsNothing);
    },
  );
}
