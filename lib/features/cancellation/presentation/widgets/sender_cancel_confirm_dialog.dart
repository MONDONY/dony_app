import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_fee_preview/cancellation_fee_preview_cubit.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_preview_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Confirmation d'une annulation par l'EXPÉDITEUR, avec l'aperçu des frais
/// d'annulation (yadony-back #779) lu à l'ouverture.
///
/// - Frais > 0 : [bodyWithFee] (à défaut [body]) puis le bloc des frais
///   ([CancellationFeeNotice]) avant les boutons.
/// - Aucun frais, aperçu indisponible (back antérieur, 403, réseau, délai) :
///   le dialogue d'avant la fonction, mot pour mot ; l'annulation reste
///   possible.
///
/// Jamais pour le voyageur : il n'a ni frais ni aperçu (le serveur répondrait
/// 403). [onConfirmed] part une fois le dialogue fermé.
Future<void> showSenderCancelConfirmDialog(
  BuildContext context, {
  required BidModel bid,
  required String title,
  required String body,
  String? bodyWithFee,
  required VoidCallback onConfirmed,
}) => showDialog<void>(
  context: context,
  builder: (_) => BlocProvider<CancellationFeePreviewCubit>(
    create: (_) => getIt<CancellationFeePreviewCubit>()..load(bid.id),
    child: SenderCancelConfirmDialog(
      bid: bid,
      title: title,
      body: body,
      bodyWithFee: bodyWithFee,
      onConfirmed: onConfirmed,
    ),
  ),
);

class SenderCancelConfirmDialog extends StatelessWidget {
  const SenderCancelConfirmDialog({
    super.key,
    required this.bid,
    required this.title,
    required this.body,
    this.bodyWithFee,
    required this.onConfirmed,
  });

  static const confirmButtonKey = Key('sender-cancel-confirm');

  final BidModel bid;
  final String title;
  final String body;
  final String? bodyWithFee;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return BlocBuilder<
      CancellationFeePreviewCubit,
      CancellationFeePreviewState
    >(
      builder: (context, state) {
        final fee = state.shownFee;
        final loaded = state is CancellationFeePreviewLoaded ? state : null;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.sheet),
          ),
          title: Text(title, style: tt.headlineMedium),
          content: AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fee == null ? body : bodyWithFee ?? body,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (fee != null && loaded != null) ...[
                    const SizedBox(height: DonySpacing.base),
                    CancellationFeeNotice(
                      preview: fee,
                      fallbackCurrency: bid.currency,
                      departureAt: bid.resolvedDepartureAt,
                      now: loaded.now,
                      increased: loaded.increased,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: Text(
                l.bidDetailNo,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            FilledButton(
              key: confirmButtonKey,
              onPressed: state.busy ? null : () => _confirm(context),
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: DonyColors.textOnBrand,
                // Lecture de l'aperçu (une fraction de seconde) : le bouton
                // garde sa couleur, un indicateur remplace le libellé.
                disabledBackgroundColor: cs.error,
                disabledForegroundColor: DonyColors.textOnBrand,
                elevation: 0,
              ),
              child: _BusyLabel(
                busy: state.busy,
                child: Text(
                  l.bidDetailConfirmCancelButton,
                  style: tt.labelLarge,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final proceed = await context.read<CancellationFeePreviewCubit>().confirm();
    if (!proceed || !context.mounted) return;
    context.pop();
    onConfirmed();
  }
}

/// Le libellé reste en place (largeur du bouton inchangée, lu par le lecteur
/// d'écran), masqué derrière un indicateur pendant la lecture.
class _BusyLabel extends StatelessWidget {
  const _BusyLabel({required this.busy, required this.child});

  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: busy ? 0 : 1,
          alwaysIncludeSemantics: true,
          child: child,
        ),
        if (busy)
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: DonyColors.textOnBrand,
            ),
          ),
      ],
    );
  }
}

/// Bloc des frais d'annulation : frais retenus, montant rendu, pourquoi ce
/// taux, et la hausse à venir. Montants dans la devise du paiement, à défaut
/// celle du colis, par le formateur commun ([CurrencyFormatter]).
class CancellationFeeNotice extends StatelessWidget {
  const CancellationFeeNotice({
    super.key,
    required this.preview,
    required this.fallbackCurrency,
    required this.now,
    this.departureAt,
    this.increased = false,
  });

  final CancellationFeePreviewModel preview;
  final String fallbackCurrency;
  final DateTime now;
  final DateTime? departureAt;
  final bool increased;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final currency = SupportedCurrency.fromCodeOrDefault(
      preview.currency ?? fallbackCurrency,
    );
    String money(double v) => CurrencyFormatter.format(v, currency);
    final strong = tt.bodyMedium?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w600,
    );
    final muted = tt.bodySmall?.copyWith(color: cs.onSurfaceVariant);

    return Container(
      key: const Key('cancel-fee-notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.warningLight,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (increased) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: DonyIcon(
                    'triangle-alert',
                    size: 16,
                    color: cs.warning,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                Expanded(child: Text(l.cancelFeeIncreased, style: strong)),
              ],
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
          Text(l.cancelFeeRetained(money(preview.fee)), style: strong),
          if (preview.refundAmount > 0)
            Text(
              l.cancelFeeRefunded(money(preview.refundAmount)),
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            ),
          const SizedBox(height: DonySpacing.xs),
          Text(_reason(l), style: muted),
          if (preview.willRise) Text(l.cancelFeeLaterCostsMore, style: muted),
        ],
      ),
    );
  }

  /// Pourquoi ce taux : le temps qui reste avant le départ, en jours entiers
  /// puis en heures. Le barème est décompté sur le départ par le serveur ;
  /// l'écran ne fait que le dire.
  String _reason(AppLocalizations l) {
    final percent = preview.ratePercent;
    final at = departureAt;
    final left = at?.difference(now);
    if (left == null || left <= Duration.zero) {
      return l.cancelFeeReasonRate(percent);
    }
    if (left.inDays >= 1) return l.cancelFeeReasonDays(left.inDays, percent);
    if (left.inHours >= 1) return l.cancelFeeReasonHours(left.inHours, percent);
    return l.cancelFeeReasonSoon(percent);
  }
}
