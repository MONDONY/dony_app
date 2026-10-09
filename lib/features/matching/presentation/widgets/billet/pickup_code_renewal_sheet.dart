import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Feuille ouverte par la notification `CONFIRMATION_CODE_REQUESTED`
/// (`/bids/{id}?action=new-code`, FLUTTER-G2) : le voyageur demande un
/// nouveau code de retrait, l'expéditeur le génère d'un geste.
///
/// Réutilise la régénération du talon « Code de retrait bloqué »
/// ([TrackingRefreshCodeRequested], `POST /tracking/{bidId}/refresh-code`) :
/// le talon, toujours affiché sous la feuille, recharge le colis au succès et
/// présente l'erreur sinon. La feuille se ferme dès que le serveur a répondu.
/// [TrackingBloc] et [BidBloc] sont ceux de l'écran du colis.
Future<void> showPickupCodeRenewalSheet(
  BuildContext context, {
  required String bidId,
}) {
  final tracking = context.read<TrackingBloc>();
  final bids = context.read<BidBloc>();
  final l = context.l10n;
  return DonyBottomSheet.show<void>(
    context,
    title: l.pickupCodeRenewalSheetTitle,
    wrapper: (child) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: tracking),
        BlocProvider.value(value: bids),
      ],
      child: child,
    ),
    stickyBottom: _GenerateCodeButton(bidId: bidId),
    child: Builder(
      builder: (ctx) => Text(
        ctx.l10n.pickupCodeRenewalSheetMessage,
        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    ),
  );
}

class _GenerateCodeButton extends StatelessWidget {
  const _GenerateCodeButton({required this.bidId});

  final String bidId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TrackingBloc, TrackingState>(
      listenWhen: (_, c) =>
          c is TrackingConfirmCodeLoaded || c is TrackingRefreshCodeError,
      listener: (ctx, _) {
        final navigator = Navigator.of(ctx);
        if (navigator.canPop()) navigator.pop();
      },
      buildWhen: (p, c) =>
          (p is TrackingRefreshCodeLoading) !=
          (c is TrackingRefreshCodeLoading),
      builder: (ctx, state) {
        final isLoading = state is TrackingRefreshCodeLoading;
        return DonyButton(
          key: const Key('pickup-code-renewal-generate'),
          label: ctx.l10n.ticketGenerateNewCodeButton,
          iconAsset: 'refresh-cw',
          isLoading: isLoading,
          onPressed: isLoading
              ? null
              : () => ctx.read<TrackingBloc>().add(
                  TrackingRefreshCodeRequested(bidId, afterBlock: true),
                ),
        );
      },
    );
  }
}
