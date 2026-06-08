import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/presentation/annonces_layout.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Onglet Annonces — additif, piloté par le profil (capacité + statut pro).
/// Aucun switch de rôle : la présentation découle de user.isTraveler / user.isProAccount.
/// ActiveRoleCubit n'est intentionnellement PAS lu ici (Phase 2 — retiré pour cet onglet).
class MatchingManagementScreen extends StatelessWidget {
  const MatchingManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final UserModel? user = switch (authState) {
      AuthAuthenticated s => s.user,
      AuthProfileUpdated s => s.user,
      _ => null,
    };
    final layout = annoncesLayoutFor(
      isTraveler: user?.isTraveler ?? false,
      isPro: user?.isProAccount ?? false,
    );

    return switch (layout) {
      AnnoncesLayout.senderOnly => const EnvoyerHubScreen(
          key: ValueKey('sender_view'),
        ),
      AnnoncesLayout.occasionalTraveler => EnvoyerHubScreen(
          key: const ValueKey('occasional_view'),
          onShowTrips: () {
            unawaited(getIt<AnalyticsService>()
                .logEvent(AnalyticsEvents.annoncesTripsOpened));
            context.push('/announcements/trips');
          },
        ),
      AnnoncesLayout.proTraveler => BlocProvider(
          key: const ValueKey('pro_view'),
          create: (_) => getIt<AnnouncementBloc>(),
          child: AnnouncementListScreen(
            onSendParcel: () {
              unawaited(getIt<AnalyticsService>()
                  .logEvent(AnalyticsEvents.annoncesSendOpened));
              context.push('/announcements/send');
            },
          ),
        ),
    };
  }
}
