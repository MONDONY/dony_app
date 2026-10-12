import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/corridor_alerts/bloc/trip_space_alert_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pied de la feuille d'un trajet complet (FLUTTER-JH) : ni demande ni
/// négociation, mais « Me prévenir si de la place se libère ».
///
/// Lit le [TripSpaceAlertCubit] fourni par le `wrapper` de la feuille. Se
/// place dans le `stickyBottom`, jamais dans le contenu défilant.
class TripSpaceAlertFooter extends StatelessWidget {
  const TripSpaceAlertFooter({
    super.key,
    required this.hasSession,
    required this.onAuthRequired,
  });

  /// Session réelle : sans elle, le bouton propose de se connecter.
  final bool hasSession;
  final VoidCallback onAuthRequired;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocConsumer<TripSpaceAlertCubit, TripSpaceAlertState>(
      listenWhen: (prev, next) =>
          (next.failed && !prev.failed) ||
          (next.isSubscribed && !prev.isSubscribed && prev.isSubmitting),
      listener: (ctx, state) {
        if (state.failed) {
          DonySnackbar.show(
            ctx,
            message: l.tripSpaceAlertError,
            type: DonySnackbarType.error,
          );
        } else {
          DonySnackbar.show(
            ctx,
            message: l.tripSpaceAlertSubscribedSnack,
            type: DonySnackbarType.success,
          );
        }
      },
      builder: (ctx, state) {
        final message = switch (state.status) {
          TripSpaceAlertStatus.subscribed => l.tripSpaceAlertSubscribedMessage,
          TripSpaceAlertStatus.spaceAvailable => l.tripSpaceAlertSpaceAvailable,
          _ => l.listingTripFullMessage,
        };
        return Column(
          key: const Key('trip-full-footer'),
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoLine(message: message),
            if (state.status == TripSpaceAlertStatus.subscribed)
              DonyButton(
                key: const Key('trip-space-alert-cancel-btn'),
                label: l.tripSpaceAlertCancelButton,
                iconAsset: 'bell-off',
                variant: DonyButtonVariant.secondary,
                isLoading: state.isSubmitting,
                onPressed: state.isSubmitting
                    ? null
                    : () => ctx.read<TripSpaceAlertCubit>().unsubscribe(),
              )
            else if (state.status != TripSpaceAlertStatus.spaceAvailable)
              DonyButton(
                key: const Key('trip-space-alert-btn'),
                label: l.tripSpaceAlertNotifyButton,
                iconAsset: 'bell',
                isLoading: state.isSubmitting,
                onPressed: state.isSubmitting
                    ? null
                    : () {
                        if (!hasSession) {
                          onAuthRequired();
                          return;
                        }
                        ctx.read<TripSpaceAlertCubit>().subscribe();
                      },
              ),
          ],
        );
      },
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DonyIcon('info', size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.xs),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
