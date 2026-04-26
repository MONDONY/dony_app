import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/shipment_list_screen.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class MatchingManagementScreen extends StatefulWidget {
  const MatchingManagementScreen({super.key});

  @override
  State<MatchingManagementScreen> createState() => _MatchingManagementScreenState();
}

class _MatchingManagementScreenState extends State<MatchingManagementScreen> {
  bool _showSendersView = true;

  @override
  void initState() {
    super.initState();
    final s = context.read<AuthBloc>().state;
    final user = s is AuthAuthenticated
        ? s.user
        : s is AuthProfileUpdated
            ? s.user
            : null;
    _showSendersView = user?.isSender ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated
            ? state.user
            : state is AuthProfileUpdated
                ? state.user
                : null;
        if (user == null) return const SizedBox();

        // Si l'utilisateur n'a qu'un rôle, on impose la vue
        if (user.isSender && !user.isTraveler) {
          return BlocProvider(
            key: const ValueKey('sender_only'),
            create: (_) => getIt<BidBloc>(),
            child: const ShipmentListScreen(),
          );
        }
        if (!user.isSender && user.isTraveler) {
          return BlocProvider(
            key: const ValueKey('traveler_only'),
            create: (_) => getIt<AnnouncementBloc>(),
            child: const AnnouncementListScreen(),
          );
        }

        // Si l'utilisateur est les deux, on ajoute un bouton de switch discret
        return Scaffold(
          body: Stack(
            children: [
              _showSendersView
                  ? BlocProvider(
                      key: const ValueKey('sender_view'),
                      create: (_) => getIt<BidBloc>(),
                      child: const ShipmentListScreen(),
                    )
                  : BlocProvider(
                      key: const ValueKey('traveler_view'),
                      create: (_) => getIt<AnnouncementBloc>(),
                      child: const AnnouncementListScreen(),
                    ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 50, // To avoid being exactly on top of other icons
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _showSendersView = !_showSendersView),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: DonyColors.blue400.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showSendersView ? Icons.flight_takeoff_rounded : Icons.inventory_2_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showSendersView ? 'Mode Voyageur' : 'Mode Expéditeur',
                            style: GoogleFonts.sora(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
