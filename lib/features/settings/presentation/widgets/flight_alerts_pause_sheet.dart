import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/flight_alerts_pause_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Feuille « Mettre aussi vos alertes prix en pause ? », ouverte quand
/// l'utilisateur masque les billets avec des alertes actives. Les billets
/// sont déjà masqués : seule la pause des alertes est en jeu.
abstract final class FlightAlertsPauseSheet {
  /// Se referme seule après « Mettre en pause » ou « Garder les alertes ».
  /// Fermée par geste, elle vaut « garder » ([FlightAlertsPauseCubit.dismiss]).
  static Future<void> show(
    BuildContext context,
    FlightAlertsPauseCubit cubit,
  ) async {
    final l = context.l10n;
    await DonyBottomSheet.show<void>(
      context,
      title: l.settingsFlightsPauseTitle,
      wrapper: (child) => BlocProvider.value(value: cubit, child: child),
      stickyBottom: const _Actions(),
      child: _Body(count: cubit.state.activeCount),
    );
    cubit.dismiss();
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      context.l10n.settingsFlightsPauseBody(count),
      key: const Key('flight-alerts-pause-body'),
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocBuilder<FlightAlertsPauseCubit, FlightAlertsPauseState>(
      builder: (context, state) {
        final pausing = state.phase == FlightAlertsPausePhase.pausing;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              key: const Key('flight-alerts-pause-confirm'),
              label: l.settingsFlightsPauseConfirm,
              isLoading: pausing,
              onPressed: pausing ? null : () => unawaited(_pause(context)),
            ),
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              key: const Key('flight-alerts-pause-keep'),
              label: l.settingsFlightsPauseKeep,
              variant: DonyButtonVariant.secondary,
              onPressed: pausing
                  ? null
                  : () {
                      context.read<FlightAlertsPauseCubit>().keep();
                      Navigator.of(context).pop();
                    },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pause(BuildContext context) async {
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    await context.read<FlightAlertsPauseCubit>().pause();
    // Feuille déjà fermée par geste pendant l'appel : ne rien dépiler d'autre.
    if (navigator.mounted && (route?.isCurrent ?? false)) navigator.pop();
  }
}
