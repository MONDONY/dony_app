import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum SenderHeroVariant { wait, alert }

// ── Public widget ─────────────────────────────────────────────────────────────

/// Carte d'action contextuelle au statut du bid (vue expéditeur).
///
/// Absorbe les flux no-show / contestation de la bannière précédente. Elle ne
/// s'affiche que s'il y a quelque chose à faire ([hasAction]) ; le reste de
/// l'information d'état passe par [statusLine], reprise par les tuiles.
/// Le feedback snackbar / refresh reste géré par le BlocListener parent.
class SenderHeroCard extends StatelessWidget {
  const SenderHeroCard({super.key, required this.bid});

  final BidModel bid;

  /// Le colis demande une réponse de l'expéditeur : contestation d'une absence
  /// du voyageur (priorité 1), absence à la livraison signalée ou contestée
  /// (1b), fenêtre de dépôt dépassée (2).
  static bool hasAction(BidModel bid) =>
      bid.cancellationNoShowStatus == 'PENDING_CONFIRMATION' ||
      _isDeliveryNoShowOpen(bid.deliveryNoShowStatus) ||
      _isWindowExpired(bid);

  /// Résumé d'état du colis : fenêtre et lieu de dépôt en ACCEPTED, embarquement
  /// ou arrivée prévus, renvoi vers les instructions de retrait, note du code
  /// bloqué ou expiré. `null` sans résumé (statuts terminaux). Reprise par les
  /// tuiles Suivi et Lieux, pour qu'aucune information de l'ancienne bannière
  /// ne se perde.
  static String? statusLine(BuildContext context, BidModel bid) =>
      _buildSubtitle(context, bid);

  @override
  Widget build(BuildContext context) {
    // ── Priorité 1 : contestation PENDING_CONFIRMATION ─────────────────────
    if (bid.cancellationNoShowStatus == 'PENDING_CONFIRMATION') {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _ContestationHero(
          bid: bid,
          key: ValueKey('PENDING_CONFIRMATION${bid.id}'),
        ),
      );
    }

    // ── Priorité 1b : absence à la livraison déjà signalée ────────────────
    // bid.deliveryNoShowReportedByTraveler distingue qui a signalé : le
    // voyageur (true, l'adversaire côté expéditeur) ou l'expéditeur (false,
    // lui-même) — sans ce champ, deliveryNoShowStatus seul ne suffit pas à
    // savoir qui doit voir "Absence signalée" (auteur) vs "Une absence est
    // signalée" (adversaire).
    final deliveryStatus = bid.deliveryNoShowStatus;
    if (_isDeliveryNoShowOpen(deliveryStatus)) {
      final iAmReporter = bid.deliveryNoShowReportedByTraveler == false;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _DeliveryNoShowHero(
          bid: bid,
          iAmReporter: iAmReporter,
          contested: deliveryStatus == 'CONTESTED',
          key: ValueKey('SENDER_DELIVERY_NOSHOW_$deliveryStatus${bid.id}'),
        ),
      );
    }

    // ── Priorité 2 : date limite de dépôt dépassée ────────────────────────
    if (_isWindowExpired(bid)) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _WindowExpiredHero(
          bid: bid,
          key: ValueKey('WINDOW_EXPIRED${bid.id}'),
        ),
      );
    }

    // Plus de bannière d'information : voir [statusLine].
    return const SizedBox.shrink();
  }
}

bool _isDeliveryNoShowOpen(String? status) =>
    status == 'PENDING_CONFIRMATION' || status == 'CONTESTED';

bool _isWindowExpired(BidModel bid) {
  final deadline = bid.handoverDeadline;
  return bid.status == 'ACCEPTED' &&
      deadline != null &&
      DateTime.now().isAfter(deadline);
}

// ── Status mapping ────────────────────────────────────────────────────────────

/// Montant payé par l'expéditeur = net + commission (totalSenderAmountEur),
/// supplément payé compris.
String _senderAmountLabel(BidModel bid) {
  final value =
      bid.totalSenderAmountWithSupplementEur ??
      bid.totalSenderAmountEur ??
      bid.totalAmountEur;
  return value != null ? formatPriceIn(value, bid.currency) : '–';
}

String? _buildSubtitle(BuildContext context, BidModel bid) {
  final l = context.l10n;
  switch (bid.status) {
    // Colis carte pas encore payé : l'expéditeur doit payer, le voyageur ne
    // peut encore rien faire (FLUTTER-G7, cohérent avec le talon du billet).
    case 'PENDING' when bid.isAwaitingSenderCardPayment:
      return l.bidDetailSenderAwaitingPaymentSubtitle(_senderAmountLabel(bid));

    case 'PENDING':
      return l.bidDetailSenderPendingSubtitle;

    case 'AWAITING_PAYMENT':
      return l.bidDetailSenderAwaitingPaymentSubtitle(_senderAmountLabel(bid));

    case 'PAYMENT_ESCROWED':
      return l.bidDetailSenderEscrowedSubtitle(_senderAmountLabel(bid));

    case 'ACCEPTED':
      return _buildAcceptedSubtitle(context, bid);

    // Transit facultatif : une fois le trajet parti, un colis récupéré est en
    // route même sans scan Transit, « Embarquement prévu » serait faux.
    case 'HANDED_OVER' when !bid.hasDeparted:
      final dateStr = _formatDepartureDate(context, bid.departureDate);
      return dateStr.isNotEmpty
          ? l.bidDetailSenderHandedOverSubtitleWithDate(dateStr)
          : l.bidDetailSenderHandedOverSubtitleDefault;

    case 'HANDED_OVER':
    case 'IN_TRANSIT':
      return _buildInTransitSubtitle(context, bid);

    case 'ARRIVED':
      final hasInstructions = (bid.arrivalInstructions ?? '').trim().isNotEmpty;
      // Le texte lui-même vit dans ArrivalInstructionsCard : le répéter ici le
      // dédoublait.
      return bid.needsNewPickupCode
          // FLUTTER-G1 : sans code, le destinataire ne peut pas retirer le
          // colis ; c'est l'information qui prime à l'arrivée.
          ? (bid.isPickupCodeExpired
                ? l.bidDetailSenderCodeExpiredNote
                : l.bidDetailSenderCodeBlockedNote)
          : hasInstructions
          ? l.bidDetailSenderArrivedSubtitleSeeInstructions
          : l.bidDetailSenderArrivedSubtitleDefault;

    case 'COMPLETED':
    case 'DELIVERED':
      return l.bidDetailSenderDeliveredSubtitle;

    // Terminal or unknown statuses → pas de résumé
    case 'REJECTED':
    case 'CANCELLED':
    case 'NO_SHOW':
    case 'EXPIRED':
    case 'PARCEL_REFUSED':
    default:
      return null;
  }
}

// ── Date helpers ──────────────────────────────────────────────────────────────

String _formatDeadline(BuildContext context, DateTime? deadline) {
  if (deadline == null) {
    return '';
  }
  final l = context.l10n;
  final locale = l.localeName;
  // Instant UTC : jour de l'appareil, le colis ne porte pas le fuseau du
  // trajet (PROD-1R).
  final local = deadline.toLocal();
  try {
    return l.bidDetailUntil(DateFormat.MMMEd(locale).format(local));
  } catch (_) {
    // Repli quand les données de locale manquent (tests isolés).
    return l.bidDetailUntil(DateFormat.Md(locale).format(local));
  }
}

String _formatDepartureDate(BuildContext context, DateTime? date) {
  if (date == null) {
    return '';
  }
  final l = context.l10n;
  final locale = l.localeName;
  try {
    return l.commonDateAtTime(
      DateFormat.MMMEd(locale).format(date),
      DateFormat.jm(locale).format(date),
    );
  } catch (_) {
    // Repli quand les données de locale manquent (tests isolés) : même
    // gabarit espace (sans « à ») que l'ancien motif fixe 'dd/MM HH:mm'.
    return '${DateFormat.Md(locale).format(date)} '
        '${DateFormat.jm(locale).format(date)}';
  }
}

String _buildAcceptedSubtitle(BuildContext context, BidModel bid) {
  final l = context.l10n;
  final window = _formatDeadline(context, bid.handoverDeadline);
  final location = bid.handoverLocation;
  final parts = <String>[];
  if (window.isNotEmpty) {
    parts.add(window);
  }
  if (location != null && location.isNotEmpty) {
    parts.add(location);
  }

  final instructions = l.bidDetailSenderAcceptedInstructions;
  final base = parts.join(' · ');
  if (base.isNotEmpty) {
    return '$base.\n$instructions';
  }
  return instructions;
}

String _buildInTransitSubtitle(BuildContext context, BidModel bid) {
  final l = context.l10n;
  final arrivalCity = bid.arrivalCity ?? l.bidDetailFallbackDestination;
  final arrivalTime = bid.arrivalTime ?? '';
  final timePart = arrivalTime.isNotEmpty
      ? l.bidDetailSenderInTransitEta(arrivalTime, arrivalCity)
      : l.bidDetailSenderInTransitEnRoute(arrivalCity);

  // Avant le code présent : un code expiré est encore là mais inutilisable.
  if (bid.needsNewPickupCode) {
    // FLUTTER-G1 : le code a été bloqué, le talon propose d'en générer un.
    // FLUTTER-G2 : expiré, même action, autre explication.
    final note = bid.isPickupCodeExpired
        ? l.bidDetailSenderCodeExpiredNote
        : l.bidDetailSenderCodeBlockedNote;
    return '$timePart $note';
  }
  if (bid.confirmationCode != null) {
    // Pas de mention « à qui » ici : l'instruction de transmission fait
    // autorité sur le talon (carte « CODE DE RETRAIT »), juste au-dessus.
    return '$timePart ${l.bidDetailSenderInTransitTicketNote}';
  }
  return timePart;
}

// ── _HeroShell ────────────────────────────────────────────────────────────────

class _HeroShell extends StatelessWidget {
  const _HeroShell({
    required this.variant,
    required this.title,
    required this.subtitle,
    this.countdownWidget,
    this.footer,
  });

  final SenderHeroVariant variant;
  final String title;
  final String subtitle;

  /// Optional widget rendered below [subtitle] with tighter spacing.
  /// Used for the contestation countdown so its digits render with tabular
  /// figures without affecting the rest of the subtitle text.
  final Widget? countdownWidget;

  final Widget? footer;

  /// Aplat uni de la carte et couleur de son texte. Les variantes bleues
  /// suivent le thème ; les autres restent sombres dans les deux thèmes,
  /// sous un texte blanc (≥ 4.5:1), comme les boutons `_HeroButton`.
  (Color, Color) _colors(BuildContext context) {
    const white = Color(0xFFFFFFFF);
    switch (variant) {
      case SenderHeroVariant.wait:
        return (DonyColors.ink700, white);
      case SenderHeroVariant.alert:
        return (DonyColors.danger700, white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final (background, foreground) = _colors(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.titleLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            subtitle,
            style: tt.bodySmall?.copyWith(
              color: foreground.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),
          if (countdownWidget != null) ...[
            const SizedBox(height: DonySpacing.xs),
            countdownWidget!,
          ],
          if (footer != null) ...[
            const SizedBox(height: DonySpacing.base),
            footer!,
          ],
        ],
      ),
    );
  }
}

// ── _HeroButton (OutlinedButton custom, NOT a DonyButton) ─────────────────────

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    const white = Color(0xFFFFFFFF);

    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: white,
          backgroundColor: white.withValues(alpha: 0.14),
          side: BorderSide(color: white.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: white),
              )
            : FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
      ),
    );
  }
}

// ── Hero : fenêtre dépassée ───────────────────────────────────────────────────

class _WindowExpiredHero extends StatelessWidget {
  const _WindowExpiredHero({super.key, required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final window = _formatDeadline(context, bid.handoverDeadline);
    final subtitle = l.bidDetailSenderWindowExpiredSubtitle(window);

    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final isLoading = state is CancellationLoading;
        return _HeroShell(
          variant: SenderHeroVariant.alert,
          title: l.bidDetailSenderWindowExpiredTitle,
          subtitle: subtitle,
          // Annuler d'abord : la fenêtre peut être dépassée sans faute du
          // voyageur (demande faite après la date limite, FLUTTER-46/47).
          // Le signalement d'absence ne doit pas être la seule issue.
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bid.canCancelBeforeHandover) ...[
                _HeroButton(
                  label: l.bidDetailCancelRequestLabel,
                  isLoading: isLoading,
                  onPressed: () => showSenderCancelBidDialog(context, bid),
                ),
                const SizedBox(height: DonySpacing.sm),
              ],
              _HeroButton(
                label: l.bidDetailSenderReportNoShowButton,
                isLoading: isLoading,
                onPressed: () => _showNoShowSheet(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showNoShowSheet(BuildContext context) async {
    final l = context.l10n;
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: l.bidDetailSenderNoShowSheetTitle,
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: l.bidDetailReportNoShowConfirmButton,
          iconAsset: 'user-x',
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.bidDetailSenderNoShowSheetBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              l.bidDetailSenderNoShowSheetHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }
    context.read<CancellationBloc>().add(TravelerNoShowReportRequested(bid.id));
  }
}

// ── Hero : contestation ───────────────────────────────────────────────────────

class _ContestationHero extends StatefulWidget {
  const _ContestationHero({super.key, required this.bid});

  final BidModel bid;

  @override
  State<_ContestationHero> createState() => _ContestationHeroState();
}

class _ContestationHeroState extends State<_ContestationHero> {
  Timer? _tick;

  /// `null` tant qu'il n'y a pas de délai. Le texte affiché (dont "Délai
  /// expiré", traduit) n'est calculé qu'au build : `context.l10n` ne doit
  /// jamais être lu depuis `initState`.
  Duration? _remaining;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(_updateCountdown);
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final deadline = widget.bid.contestationDeadline;
    if (deadline == null) {
      _remaining = null;
      _expired = false;
      return;
    }
    final remaining = deadline.difference(DateTime.now());
    _expired = remaining.isNegative;
    _remaining = _expired ? null : remaining;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    var timeLeft = '';
    if (_expired) {
      timeLeft = l.bidDetailSenderContestationExpired;
    } else if (_remaining != null) {
      final remaining = _remaining!;
      final h = remaining.inHours;
      final m = remaining.inMinutes % 60;
      final s = remaining.inSeconds % 60;
      timeLeft =
          '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }

    const white = Color(0xFFFFFFFF);

    final countdownWidget = timeLeft.isNotEmpty
        ? Text(
            l.bidDetailSenderContestCountdown(timeLeft),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: white.withValues(alpha: 0.85),
              height: 1.45,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        : null;

    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final isLoading = state is CancellationLoading;
        return _HeroShell(
          variant: SenderHeroVariant.alert,
          title: l.bidDetailSenderNoShowByTravelerTitle,
          subtitle: l.bidDetailSenderNoShowByTravelerSubtitle,
          countdownWidget: countdownWidget,
          footer: Row(
            children: [
              Expanded(
                child: _HeroButton(
                  label: l.bidDetailContestButton,
                  isLoading: isLoading,
                  onPressed: () => _showContestSheet(context),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: _HeroButton(
                  label: l.bidDetailSenderConfirmNoShowButton,
                  isLoading: isLoading,
                  onPressed: () => _showConfirmSheet(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showContestSheet(BuildContext context) async {
    final l = context.l10n;
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: l.bidDetailSenderContestSheetTitle,
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: l.bidDetailSenderContestConfirmButton,
          iconAsset: 'gavel',
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.bidDetailSenderContestSheetBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              l.bidDetailSenderContestSheetHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }
    context.read<CancellationBloc>().add(NoShowContestRequested(widget.bid.id));
  }

  Future<void> _showConfirmSheet(BuildContext context) async {
    final l = context.l10n;
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: l.bidDetailSenderConfirmSheetTitle,
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: l.bidDetailSenderConfirmSheetButton,
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Text(
          l.bidDetailSenderConfirmSheetBody,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }
    context.read<CancellationBloc>().add(NoShowConfirmRequested(widget.bid.id));
  }
}

// ── Hero : absence à la livraison signalée ────────────────────────────────────

class _DeliveryNoShowHero extends StatelessWidget {
  const _DeliveryNoShowHero({
    super.key,
    required this.bid,
    required this.iAmReporter,
    required this.contested,
  });

  final BidModel bid;
  final bool iAmReporter;
  final bool contested;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (iAmReporter) {
      return _HeroShell(
        variant: SenderHeroVariant.wait,
        title: contested
            ? l.bidDetailNoShowContestedTitle
            : l.bidDetailNoShowReportedTitle,
        subtitle: contested
            ? l.bidDetailDeliveryNoShowReporterContestedSubtitle
            : l.bidDetailDeliveryNoShowReporterPendingSubtitle,
      );
    }
    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final isLoading = state is CancellationLoading;
        return _HeroShell(
          variant: SenderHeroVariant.alert,
          title: contested
              ? l.bidDetailDeliveryNoShowContestSentTitle
              : l.bidDetailDeliveryNoShowAlertTitle,
          subtitle: contested
              ? l.bidDetailDeliveryNoShowContestSentSubtitle
              : l.bidDetailDeliveryNoShowAlertSubtitle,
          footer: contested
              ? null
              : _HeroButton(
                  label: l.bidDetailDeliveryNoShowContestButton,
                  isLoading: isLoading,
                  onPressed: () => context.read<CancellationBloc>().add(
                    DeliveryNoShowContestRequested(bid.id),
                  ),
                ),
        );
      },
    );
  }
}
