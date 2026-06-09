import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart';
import 'package:dony/core/di/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Dispatcher capacité-aware pour le tab 1 de la bottom nav.
///
/// - **Voyageur** (`user.isTraveler`) → `AnnouncementListScreen`
/// - **Expéditeur** (défaut)          → `EnvoyerHubScreen`
class MatchingManagementScreen extends StatelessWidget {
  const MatchingManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, curr) =>
          curr is AuthAuthenticated || curr is AuthProfileUpdated,
      builder: (context, authState) {
        final isTraveler = authState is AuthAuthenticated
            ? authState.user.isTraveler
            : authState is AuthProfileUpdated
            ? authState.user.isTraveler
            : false;

        if (isTraveler) {
          return BlocProvider(
            key: const ValueKey('traveler_view'),
            create: (_) => getIt<AnnouncementBloc>(),
            child: const AnnouncementListScreen(),
          );
        }
        // Expéditeur : hub avec 3 onglets internes.
        return const EnvoyerHubScreen(key: ValueKey('sender_view'));
      },
    );
  }
}
