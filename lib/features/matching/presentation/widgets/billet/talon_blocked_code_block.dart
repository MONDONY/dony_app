import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Talon expéditeur d'un colis remis dont le code de retrait a disparu
/// (FLUTTER-G1) : effacé par le serveur après trois essais faux du voyageur, ou
/// à l'expiration. Sans lui, l'expéditeur ne voyait plus que le QR et le colis
/// n'était plus jamais confirmable.
///
/// Le bouton déclenche la régénération existante
/// (`POST /tracking/{bidId}/refresh-code`, 5 par 24 h) ; au succès, le détail
/// du colis est rechargé et le talon repasse aux boutons QR + « Code de
/// retrait ». Consomme [TrackingBloc] et [BidBloc] fournis par l'écran.
class TalonBlockedCodeBlock extends StatelessWidget {
  const TalonBlockedCodeBlock({super.key, required this.bidId});

  final String bidId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return BlocConsumer<TrackingBloc, TrackingState>(
      listenWhen: (_, c) =>
          c is TrackingConfirmCodeLoaded || c is TrackingRefreshCodeError,
      listener: (ctx, state) {
        if (state is TrackingRefreshCodeError) {
          ErrorPresenter.show(ctx, state.error);
        } else if (state is TrackingConfirmCodeLoaded) {
          ctx.read<BidBloc>().add(BidDetailRequested(bidId));
        }
      },
      buildWhen: (p, c) =>
          (p is TrackingRefreshCodeLoading) !=
          (c is TrackingRefreshCodeLoading),
      builder: (ctx, state) {
        final isLoading = state is TrackingRefreshCodeLoading;
        return Container(
          key: const Key('talon-blocked-code'),
          padding: const EdgeInsets.all(DonySpacing.md),
          decoration: BoxDecoration(
            color: cs.warningLight,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(color: cs.warning.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: DonyIcon('key-round', size: 18, color: cs.warning),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.ticketBlockedCodeTitle,
                          style: tt.titleSmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: DonySpacing.xs),
                        Text(
                          l.ticketBlockedCodeMessage,
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
              const SizedBox(height: DonySpacing.md),
              DonyButton(
                key: const Key('talon-generate-new-code'),
                label: l.ticketGenerateNewCodeButton,
                iconAsset: 'refresh-cw',
                variant: DonyButtonVariant.secondary,
                isLoading: isLoading,
                onPressed: isLoading
                    ? null
                    : () => ctx.read<TrackingBloc>().add(
                        TrackingRefreshCodeRequested(bidId, afterBlock: true),
                      ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 250.ms);
      },
    );
  }
}
