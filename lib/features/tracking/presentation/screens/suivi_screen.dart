import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/tracking/presentation/screens/scan_hub_screen.dart';
import 'package:dony/features/tracking/presentation/screens/tracking_search_screen.dart';
import 'package:dony/features/tracking/presentation/suivi_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Onglet Suivi — additif, in-shell, piloté par le profil (voir spec Phase 3).
class SuiviScreen extends StatelessWidget {
  const SuiviScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final UserModel? user = switch (authState) {
      AuthAuthenticated(:final user) => user,
      AuthProfileUpdated(:final user) => user,
      _ => null,
    };
    final layout = suiviLayoutFor(
      isTraveler: user?.isTraveler ?? false,
      isPro: user?.isProAccount ?? false,
    );

    switch (layout) {
      case SuiviLayout.senderOnly:
        return const TrackingSearchScreen(showBackButton: false);

      case SuiviLayout.occasionalTraveler:
        return TrackingSearchScreen(
          showBackButton: false,
          onScanTrip: () {
            unawaited(getIt<AnalyticsService>()
                .logEvent(AnalyticsEvents.suiviScanOpened));
            context.push('/tracking/scan-hub');
          },
        );

      case SuiviLayout.proTraveler:
        return ScanHubScreen(
          onTrackParcel: () {
            unawaited(getIt<AnalyticsService>()
                .logEvent(AnalyticsEvents.suiviTrackOpened));
            context.push('/tracking/search');
          },
        );
    }
  }
}
