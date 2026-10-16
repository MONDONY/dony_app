import 'package:dony/features/maintenance/bloc/maintenance_cubit.dart';
import 'package:dony/features/maintenance/bloc/maintenance_state.dart';
import 'package:dony/features/maintenance/presentation/maintenance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Recouvre TOUTE l'application par [MaintenanceScreen] tant que la
/// maintenance est active, routes, feuilles et dialogues compris (posé dans
/// le `builder` de `MaterialApp.router`, au-dessus du `Navigator`).
///
/// L'application reste montée dessous, gelée (ni toucher, ni lecteur
/// d'écran, ni animation) : à la réouverture, l'utilisateur la retrouve là
/// où il l'avait laissée. Le retour Android, lui, est coupé par
/// `SystemBackDispatcher.isLocked`.
class MaintenanceGate extends StatelessWidget {
  const MaintenanceGate({required this.cubit, required this.child, super.key});

  final MaintenanceCubit cubit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MaintenanceCubit, MaintenanceState>(
      bloc: cubit,
      listenWhen: (previous, current) => !previous.active && current.active,
      // Un clavier ouvert resterait au-dessus de l'écran de maintenance.
      listener: (_, _) => FocusManager.instance.primaryFocus?.unfocus(),
      builder: (context, state) => Stack(
        fit: StackFit.expand,
        children: [
          TickerMode(
            enabled: !state.active,
            child: ExcludeSemantics(
              excluding: state.active,
              child: IgnorePointer(ignoring: state.active, child: child),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            reverseDuration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: state.active
                ? MaintenanceScreen(
                    key: const ValueKey('maintenance-screen'),
                    state: state,
                    onRetry: cubit.retry,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
