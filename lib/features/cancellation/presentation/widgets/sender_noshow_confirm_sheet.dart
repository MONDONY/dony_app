import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/cancellation/bloc/cancellation_fee_preview/cancellation_fee_preview_cubit.dart';
import 'package:dony/features/cancellation/data/cancellation_fee_coverage.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_fee_config_builder.dart';
import 'package:dony/features/cancellation/presentation/widgets/sender_cancel_confirm_dialog.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Feuille « Confirmer votre absence » : l'expéditeur confirme lui-même
/// l'absence que le voyageur a signalée (`confirm-noshow-self`), l'envoi est
/// annulé. Rend `true` quand l'expéditeur confirme.
///
/// - Colis non couvert par les frais d'annulation (frais éteints, back
///   antérieur, colis antérieur à la date d'effet, espèces) : la feuille
///   d'avant la fonction, mot pour mot, sans aucune lecture.
/// - Colis couvert : le corps prévient que des frais peuvent être retenus.
///   Colis accepté : l'aperçu des frais (`GET .../fee-preview`, expéditeur
///   seul) est lu à l'ouverture et montré sous le corps quand des frais
///   s'appliquent. Le serveur calcule les frais au moment de la
///   confirmation : le taux montré est celui d'une confirmation maintenant.
///   Aperçu illisible : le corps seul. Jamais bloquant : le bouton attend la
///   lecture (6 s au plus), puis confirme ; palier passé pendant que la
///   feuille est ouverte, relecture et seconde confirmation si les frais
///   montent (même règle que le dialogue d'annulation).
Future<bool> showSenderNoShowConfirmSheet(
  BuildContext context, {
  required BidModel bid,
}) async {
  final l = context.l10n;
  final confirmed = await DonyBottomSheet.show<bool>(
    context,
    title: l.bidDetailSenderConfirmSheetTitle,
    // L'aperçu n'est créé qu'au premier besoin (colis couvert et accepté) :
    // non couvert, aucune lecture.
    wrapper: (child) => BlocProvider<CancellationFeePreviewCubit>(
      create: (_) => getIt<CancellationFeePreviewCubit>(),
      child: child,
    ),
    stickyBottom: CancellationFeeConfigBuilder(
      builder: (ctx, config) => _showsPreview(bid, config)
          ? const _ConfirmWithPreviewButton()
          : DonyButton(
              label: ctx.l10n.bidDetailSenderConfirmSheetButton,
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
            ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
      child: CancellationFeeConfigBuilder(
        builder: (ctx, config) => isCoveredByCancellationFee(bid, config)
            ? _CoveredBody(bid: bid, withPreview: _showsPreview(bid, config))
            : Text(
                ctx.l10n.bidDetailSenderConfirmSheetBody,
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
      ),
    ),
  );
  return confirmed == true;
}

/// L'aperçu des frais ne vaut que pour un colis accepté : c'est le statut que
/// le serveur retient pour une absence confirmée.
bool _showsPreview(BidModel bid, CancellationFeeConfigModel config) =>
    bid.status == 'ACCEPTED' && isCoveredByCancellationFee(bid, config);

class _CoveredBody extends StatefulWidget {
  const _CoveredBody({required this.bid, required this.withPreview});

  final BidModel bid;
  final bool withPreview;

  @override
  State<_CoveredBody> createState() => _CoveredBodyState();
}

class _CoveredBodyState extends State<_CoveredBody> {
  @override
  void initState() {
    super.initState();
    if (widget.withPreview) {
      unawaited(
        context.read<CancellationFeePreviewCubit>().load(widget.bid.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final body = Text(
      l.bidDetailSenderConfirmSheetBodyWithFee,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    if (!widget.withPreview) return body;
    return BlocBuilder<
      CancellationFeePreviewCubit,
      CancellationFeePreviewState
    >(
      builder: (context, state) => CancellationFeePreviewSection(
        state: state,
        bid: widget.bid,
        body: body,
      ),
    );
  }
}

/// Bouton de la feuille quand l'aperçu est lu : en attente pendant la lecture
/// (plafonnée), puis confirmation, relecture comprise si le palier est passé.
class _ConfirmWithPreviewButton extends StatelessWidget {
  const _ConfirmWithPreviewButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      CancellationFeePreviewCubit,
      CancellationFeePreviewState
    >(
      builder: (context, state) => DonyButton(
        label: context.l10n.bidDetailSenderConfirmSheetButton,
        isLoading: state.busy,
        onPressed: state.busy ? null : () => _confirm(context),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final proceed = await context.read<CancellationFeePreviewCubit>().confirm();
    if (!proceed || !context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(true);
  }
}
