import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart';
import 'package:dony/core/di/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Dispatcher rôle-aware pour le tab 1 de la bottom nav.
///
/// - **Voyageur** → `AnnouncementListScreen` (inchangé)
/// - **Sender**   → `EnvoyerHubScreen` (Phase 1 — hub 3 onglets)
class MatchingManagementScreen extends StatelessWidget {
  const MatchingManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveRoleCubit, ActiveRole>(
      builder: (context, activeRole) {
        if (activeRole == ActiveRole.traveler) {
          return BlocProvider(
            key: const ValueKey('traveler_view'),
            create: (_) => getIt<AnnouncementBloc>(),
            child: const AnnouncementListScreen(),
          );
        }
        // Sender : nouveau hub avec 3 onglets internes. Les BLoCs sont créés
        // dans le hub lui-même (PackageRequestBloc + BidBloc).
        return const EnvoyerHubScreen(key: ValueKey('sender_view'));
      },
    );
  }
}
