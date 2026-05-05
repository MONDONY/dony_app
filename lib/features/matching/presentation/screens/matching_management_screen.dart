import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/presentation/screens/announcement_list_screen.dart';
import 'package:dony/features/matching/presentation/screens/shipment_list_screen.dart';
import 'package:dony/core/di/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        return BlocProvider(
          key: const ValueKey('sender_view'),
          create: (_) => getIt<BidBloc>(),
          child: const ShipmentListScreen(),
        );
      },
    );
  }
}
