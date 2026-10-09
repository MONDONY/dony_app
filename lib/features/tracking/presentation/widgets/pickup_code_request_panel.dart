import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tracking/bloc/pickup_code_request_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Codes d'erreur de `confirm-delivery` pour lesquels le voyageur ne peut
/// plus rien sans un nouveau code de l'expéditeur (FLUTTER-G1, FLUTTER-G2).
bool needsPickupCodeRequest(String? errorCode) =>
    errorCode == 'code-blocked' || errorCode == 'code-expired';

/// Bouton voyageur « Demander un nouveau code » (FLUTTER-G2) : le code de
/// retrait a été bloqué après trop d'essais ou a expiré, et seul l'expéditeur
/// peut en générer un nouveau. La demande lui envoie une notification
/// (`POST /tracking/{bidId}/request-code`, yadony-back #461).
///
/// Après succès, le bouton cède la place à « Demande envoyée à
/// l'expéditeur ». Une demande refaite moins de 15 min après la précédente
/// affiche le délai restant. Fournit son propre [PickupCodeRequestCubit].
class PickupCodeRequestPanel extends StatelessWidget {
  const PickupCodeRequestPanel({
    super.key,
    required this.bidId,
    required this.source,
  });

  final String bidId;

  /// Écran d'origine, pour l'analytique (`scan_confirm`, `bid_detail`).
  final String source;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<PickupCodeRequestCubit>(),
      child: _PickupCodeRequestView(bidId: bidId, source: source),
    );
  }
}

class _PickupCodeRequestView extends StatelessWidget {
  const _PickupCodeRequestView({required this.bidId, required this.source});

  final String bidId;
  final String source;

  static String? tooSoonMessage(
    BuildContext context,
    PickupCodeRequestState s,
  ) {
    if (s is! PickupCodeRequestTooSoon) return null;
    final minutes = s.minutesLeft(DateTime.now());
    final l = context.l10n;
    return minutes == null
        ? l.pickupCodeRequestTooSoonNoDelay
        : l.pickupCodeRequestTooSoon(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return BlocConsumer<PickupCodeRequestCubit, PickupCodeRequestState>(
      listener: (ctx, state) {
        if (state is PickupCodeRequestSent) {
          DonySnackbar.show(
            ctx,
            message: ctx.l10n.pickupCodeRequestSent,
            type: DonySnackbarType.success,
          );
        } else if (state is PickupCodeRequestFailure) {
          ErrorPresenter.show(ctx, state.error);
        }
      },
      builder: (ctx, state) {
        if (state is PickupCodeRequestSent) {
          return const _SentConfirmation(key: Key('pickup-code-request-sent'))
              .animate()
              .fadeIn(duration: 200.ms)
              .scaleXY(
                begin: 0.97,
                end: 1,
                duration: 200.ms,
                curve: Curves.easeOut,
              );
        }
        final isSending = state is PickupCodeRequestSending;
        final tooSoon = tooSoonMessage(ctx, state);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyButton(
              key: const Key('pickup-code-request-button'),
              label: l.pickupCodeRequestButton,
              iconAsset: 'send',
              variant: DonyButtonVariant.secondary,
              isLoading: isSending,
              onPressed: isSending
                  ? null
                  : () => ctx.read<PickupCodeRequestCubit>().request(
                      bidId,
                      source: source,
                    ),
            ),
            if (tooSoon != null) ...[
              const SizedBox(height: DonySpacing.xs),
              Text(
                tooSoon,
                key: const Key('pickup-code-request-too-soon'),
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ).animate().fadeIn(duration: 200.ms),
            ],
          ],
        );
      },
    );
  }
}

class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DonyIcon('circle-check', size: 18, color: cs.success),
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.pickupCodeRequestSent,
                  style: tt.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  l.pickupCodeRequestSentHint,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
