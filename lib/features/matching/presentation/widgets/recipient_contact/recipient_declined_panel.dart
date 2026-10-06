import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/recipient_replacement/recipient_replacement_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Vue voyageur d'un colis dont le destinataire a refusé ou s'est retiré
/// (`BidModel.recipientDeclined`, FLUTTER-E8) : son nom et son numéro ne sont
/// plus servis. L'encart l'explique et propose « Demander un autre
/// destinataire » ([RecipientReplacementCubit]), après confirmation dans une
/// feuille. Pendant les 12 h qui suivent une demande, le bouton reste inactif
/// (« Demande envoyée ») avec l'heure de la prochaine demande possible.
///
/// Le bouton n'est pas un [DonyButton] : l'encart vit aussi dans le contenu
/// défilant de feuilles (« Prévenir les destinataires », options voyageur),
/// où seul le `stickyBottom` porte des CTA globaux.
class RecipientDeclinedPanel extends StatelessWidget {
  const RecipientDeclinedPanel({
    super.key,
    required this.bid,
    this.showTitle = true,
    this.clock,
  });

  final BidModel bid;

  /// Titre « Destinataire à redésigner » dans l'encart. Faux quand l'hôte
  /// l'affiche déjà (ligne de la feuille « Prévenir les destinataires »).
  final bool showTitle;

  /// Heure courante, injectée en test.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RecipientReplacementCubit>(
      create: (_) => getIt<RecipientReplacementCubit>(),
      child: _RecipientDeclinedView(
        bid: bid,
        showTitle: showTitle,
        clock: clock ?? DateTime.now,
      ),
    );
  }
}

class _RecipientDeclinedView extends StatelessWidget {
  const _RecipientDeclinedView({
    required this.bid,
    required this.showTitle,
    required this.clock,
  });

  final BidModel bid;
  final bool showTitle;
  final DateTime Function() clock;

  /// Recharge le détail d'envoi s'il est à l'écran ([BidBloc]) ; ailleurs
  /// (feuille de l'écran trajet), l'état du cubit suffit.
  void _refreshDetail(BuildContext context) {
    try {
      context.read<BidBloc>().add(BidDetailRequested(bid.id));
    } on ProviderNotFoundException {
      // Pas de détail d'envoi à recharger.
    }
  }

  Future<void> _ask(BuildContext context) async {
    final cubit = context.read<RecipientReplacementCubit>();
    final confirmed = await confirmRecipientReplacement(context);
    if (confirmed ?? false) await cubit.request(bid);
  }

  void _onState(BuildContext context, RecipientReplacementState state) {
    final l = context.l10n;
    switch (state) {
      case RecipientReplacementSent():
        DonySnackbar.show(
          context,
          message: l.recipientReplacementSentSnackbar,
          type: DonySnackbarType.success,
        );
        _refreshDetail(context);
      case RecipientReplacementTooSoon():
        DonySnackbar.show(
          context,
          message: l.recipientReplacementTooSoonSnackbar,
          type: DonySnackbarType.warning,
        );
      case RecipientReplacementConflict():
        DonySnackbar.show(
          context,
          message: l.recipientReplacementConflictSnackbar,
          type: DonySnackbarType.error,
        );
        _refreshDetail(context);
      case RecipientReplacementFailure(:final error):
        ErrorPresenter.show(context, error);
      case RecipientReplacementIdle() || RecipientReplacementSubmitting():
        break;
    }
  }

  /// Instant de la prochaine demande possible, `null` si une demande est
  /// possible tout de suite. [_unknownNext] couvre un 429 sans date.
  static const _unknownNext = _NextRequest(null);

  _NextRequest? _nextRequest(RecipientReplacementState state, DateTime now) {
    final DateTime? next = switch (state) {
      RecipientReplacementSent(:final bid) =>
        bid.nextRecipientReplacementAllowedAt ??
            now.add(BidModel.recipientReplacementCooldown),
      RecipientReplacementTooSoon(:final nextRequestAllowedAt) =>
        nextRequestAllowedAt ?? bid.nextRecipientReplacementAllowedAt,
      _ => bid.nextRecipientReplacementAllowedAt,
    };
    if (next == null) {
      return state is RecipientReplacementTooSoon ? _unknownNext : null;
    }
    return next.isAfter(now) ? _NextRequest(next) : null;
  }

  String _nextLabel(AppLocalizations l, DateTime? next, DateTime now) {
    if (next == null) return l.recipientReplacementNextLater;
    final local = next.toLocal();
    final time = DateFormat.Hm(l.localeName).format(local);
    final today = DateUtils.isSameDay(local, now.toLocal());
    if (today) return l.recipientReplacementNextAt(time);
    final date = DateFormat.MMMd(l.localeName).format(local);
    return l.recipientReplacementNextOn(date, time);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocConsumer<RecipientReplacementCubit, RecipientReplacementState>(
      listener: _onState,
      builder: (context, state) {
        final now = clock();
        final next = _nextRequest(state, now);
        final submitting = state is RecipientReplacementSubmitting;
        final canRequest = bid.canChangeRecipient;

        return Column(
          key: Key('recipient-declined-${bid.id}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(DonySpacing.md),
              decoration: BoxDecoration(
                color: cs.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonyIcon('user-x', size: 18, color: cs.warning),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showTitle) ...[
                          Text(
                            l.recipientDeclinedTravelerTitle,
                            style: tt.titleSmall?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          l.recipientDeclinedTravelerBody,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (canRequest) ...[
              const SizedBox(height: DonySpacing.sm),
              if (next != null) ...[
                _PanelButton(
                  key: Key('recipient-replacement-sent-${bid.id}'),
                  iconAsset: 'check',
                  label: l.recipientReplacementSentButton,
                  onTap: null,
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  _nextLabel(l, next.at, now),
                  key: Key('recipient-replacement-next-${bid.id}'),
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ] else
                _PanelButton(
                  key: Key('recipient-replacement-request-${bid.id}'),
                  iconAsset: 'user-plus',
                  label: l.recipientReplacementRequestButton,
                  loading: submitting,
                  onTap: submitting ? null : () => _ask(context),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Prochaine demande possible ; [at] `null` quand le serveur ne l'a pas dite.
class _NextRequest {
  const _NextRequest(this.at);

  final DateTime? at;
}

/// Feuille de confirmation de la demande de remplacement. Rend `true` sur
/// « Envoyer la demande », `false` ou `null` sinon.
Future<bool?> confirmRecipientReplacement(BuildContext context) {
  final l = context.l10n;
  return DonyBottomSheet.show<bool>(
    context,
    title: l.recipientReplacementConfirmTitle,
    stickyBottom: Builder(
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DonyButton(
            key: const Key('recipient-replacement-confirm'),
            label: l.recipientReplacementConfirmSend,
            iconAsset: 'send',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          const SizedBox(height: DonySpacing.xs),
          DonyButton(
            key: const Key('recipient-replacement-cancel'),
            label: l.commonCancel,
            variant: DonyButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    ),
    child: Builder(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.md),
          child: Text(
            l.recipientReplacementConfirmBody,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        );
      },
    ),
  );
}

/// Bouton pleine largeur de l'encart, même facture que les boutons de
/// contact du destinataire. Inactif quand [onTap] est `null`.
class _PanelButton extends StatelessWidget {
  const _PanelButton({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String iconAsset;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final enabled = onTap != null;
    final fg = enabled || loading ? cs.primary : cs.onSurfaceVariant;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: enabled || loading
            ? cs.primaryContainer.withValues(alpha: 0.5)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.md,
                vertical: DonySpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  else
                    DonyIcon(iconAsset, size: 16, color: fg),
                  const SizedBox(width: DonySpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: tt.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
