import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'mock_analytics_backend.dart';

class _EmptyHelpCenterSource implements HelpCenterConfigSource {
  const _EmptyHelpCenterSource();

  @override
  String get activatedJson => '';

  @override
  Future<String?> fetchAndActivate() async => null;
}

/// `HelpCenterBloc` est fourni globalement dans l'app (`app.dart`) : les
/// écrans qui posent une `ContextualTutorialCard` le lisent. Jamais chargé,
/// ce bloc reste à l'état initial et n'affiche aucune carte.
BlocProvider<HelpCenterBloc> emptyHelpCenterProvider() =>
    BlocProvider<HelpCenterBloc>(
      create: (_) => HelpCenterBloc(
        HelpCenterRepository(
          const _EmptyHelpCenterSource(),
          fallbackJsonLoader: () async => '{}',
        ),
        makeDisabledAnalytics(MockAnalyticsBackend()),
      ),
    );
