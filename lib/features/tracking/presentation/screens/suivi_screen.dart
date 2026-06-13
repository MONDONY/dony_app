import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
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
      // TrackingSearchScreen consomme TrackingBloc (recherche par numéro).
      // En in-shell il n'y a pas de provider de route (contrairement à la
      // route poussée /tracking/search) → on le fournit ici.
      case SuiviLayout.senderOnly:
        return BlocProvider(
          create: (_) => getIt<TrackingBloc>(),
          child: const TrackingSearchScreen(showBackButton: false),
        );

      case SuiviLayout.occasionalTraveler:
        return BlocProvider(
          create: (_) => getIt<TrackingBloc>(),
          child: TrackingSearchScreen(
            showBackButton: false,
            onScanTrip: () {
              unawaited(
                getIt<AnalyticsService>().logEvent(
                  AnalyticsEvents.suiviScanOpened,
                ),
              );
              context.push('/tracking/scan-hub');
            },
          ),
        );

      case SuiviLayout.proTraveler:
        return ScanHubScreen(
          onTrackParcel: () {
            unawaited(
              getIt<AnalyticsService>().logEvent(
                AnalyticsEvents.suiviTrackOpened,
              ),
            );
            context.push('/tracking/search');
          },
        );
    }
  }
}
