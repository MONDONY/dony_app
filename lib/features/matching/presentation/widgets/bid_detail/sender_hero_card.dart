import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum SenderHeroVariant { wait, pay, info, alert, done }

// ── Public widget ─────────────────────────────────────────────────────────────

/// Carte "prochaine étape" contextuelle au statut du bid (vue expéditeur).
///
/// Absorbe les flux no-show / contestation de la bannière précédente.
/// Le feedback snackbar / refresh reste géré par le BlocListener parent.
class SenderHeroCard extends StatelessWidget {
  const SenderHeroCard({super.key, required this.bid});

  final BidModel bid;

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
    if (deliveryStatus == 'PENDING_CONFIRMATION' ||
        deliveryStatus == 'CONTESTED') {
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
    final deadline = bid.handoverDeadline;
    if (bid.status == 'ACCEPTED' &&
        deadline != null &&
        DateTime.now().isAfter(deadline)) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _WindowExpiredHero(
          bid: bid,
          key: ValueKey('WINDOW_EXPIRED${bid.id}'),
        ),
      );
    }

    // ── Priorité 3 : mapping par statut ────────────────────────────────────
    final content = _buildContent(context, bid);
    if (content == null) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _HeroShell(
        key: ValueKey('${bid.status}${content.title}'),
        variant: content.variant,
        title: content.title,
        subtitle: content.subtitle,
      ),
    );
  }
}

// ── Internal data class ────────────────────────────────────────────────────────

class _HeroContent {
  const _HeroContent({
    required this.variant,
    required this.title,
    required this.subtitle,
  });

  final SenderHeroVariant variant;
  final String title;
  final String subtitle;
}

// ── Status mapping ────────────────────────────────────────────────────────────

/// Montant payé par l'expéditeur = net + commission (totalSenderAmountEur).
String _senderAmountLabel(BidModel bid) {
  final value = bid.totalSenderAmountEur ?? bid.totalAmountEur;
  return value != null ? formatPriceIn(value, bid.currency) : '–';
}

_HeroContent? _buildContent(BuildContext context, BidModel bid) {
  final l = context.l10n;
  switch (bid.status) {
    case 'PENDING':
      return _HeroContent(
        variant: SenderHeroVariant.wait,
        title: l.bidDetailSenderPendingTitle,
        subtitle: l.bidDetailSenderPendingSubtitle,
      );

    case 'AWAITING_PAYMENT':
      final amount = _senderAmountLabel(bid);
      return _HeroContent(
        variant: SenderHeroVariant.pay,
        title: l.bidDetailSenderAwaitingPaymentTitle,
        subtitle: l.bidDetailSenderAwaitingPaymentSubtitle(amount),
      );

    case 'PAYMENT_ESCROWED':
      final amount = _senderAmountLabel(bid);
      return _HeroContent(
        variant: SenderHeroVariant.wait,
        title: l.bidDetailSenderEscrowedTitle,
        subtitle: l.bidDetailSenderEscrowedSubtitle(amount),
      );

    case 'ACCEPTED':
      final subtitle = _buildAcceptedSubtitle(context, bid);
      return _HeroContent(
        variant: SenderHeroVariant.info,
        title: l.bidDetailSenderAcceptedTitle,
        subtitle: subtitle,
      );

    case 'HANDED_OVER':
      final name = bid.travelerName ?? l.bidDetailSenderTravelerFallback;
      final dateStr = _formatDepartureDate(context, bid.departureDate);
      return _HeroContent(
        variant: SenderHeroVariant.info,
        title: l.bidDetailSenderHandedOverTitle(name),
        subtitle: dateStr.isNotEmpty
            ? l.bidDetailSenderHandedOverSubtitleWithDate(dateStr)
            : l.bidDetailSenderHandedOverSubtitleDefault,
      );

    case 'IN_TRANSIT':
      final subtitle = _buildInTransitSubtitle(context, bid);
      return _HeroContent(
        variant: SenderHeroVariant.info,
        title: l.bidDetailSenderInTransitTitle,
        subtitle: subtitle,
      );

    case 'ARRIVED':
      final hasInstructions = (bid.arrivalInstructions ?? '').trim().isNotEmpty;
      return _HeroContent(
        variant: SenderHeroVariant.info,
        title: l.bidDetailSenderArrivedTitle,
        // bid.arrivalInstructions : texte libre saisi par le voyageur, donnée
        // serveur, jamais un littéral à traduire.
        subtitle: hasInstructions
            ? bid.arrivalInstructions!
            : l.bidDetailSenderArrivedSubtitleDefault,
      );

    case 'COMPLETED':
    case 'DELIVERED':
      final recipient = bid.recipientName ?? l.bidDetailSenderRecipientFallback;
      return _HeroContent(
        variant: SenderHeroVariant.done,
        title: l.bidDetailSenderDeliveredTitle(recipient),
        subtitle: l.bidDetailSenderDeliveredSubtitle,
      );

    // Terminal or unknown statuses → shrink
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
  try {
    return l.bidDetailUntil(DateFormat.MMMEd(locale).format(deadline));
  } catch (_) {
    // Repli quand les données de locale manquent (tests isolés).
    return l.bidDetailUntil(DateFormat.Md(locale).format(deadline));
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
    super.key,
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

  List<Color> _gradientColors(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (variant) {
      case SenderHeroVariant.wait:
        return [DonyColors.ink600, DonyColors.ink800];
      case SenderHeroVariant.pay:
        return [DonyColors.terra500, DonyColors.terra700];
      case SenderHeroVariant.info:
        return [DonyColors.blue500, DonyColors.blue700];
      case SenderHeroVariant.alert:
        return [cs.error, DonyColors.ink800];
      case SenderHeroVariant.done:
        return [DonyColors.blue600, DonyColors.blue800];
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final colors = _gradientColors(context);
    const white = Color(0xFFFFFFFF);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.titleLarge?.copyWith(
              color: white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            subtitle,
            style: tt.bodySmall?.copyWith(
              color: white.withValues(alpha: 0.85),
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
          footer: _HeroButton(
            label: l.bidDetailSenderReportNoShowButton,
            isLoading: isLoading,
            onPressed: () => _showNoShowSheet(context),
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
