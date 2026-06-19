import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
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

    // ── Priorité 2 : fenêtre dépassée ─────────────────────────────────────
    final windowEnd = bid.handoverWindowEnd;
    if (bid.status == 'ACCEPTED' &&
        windowEnd != null &&
        DateTime.now().isAfter(windowEnd)) {
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

_HeroContent? _buildContent(BuildContext context, BidModel bid) {
  switch (bid.status) {
    case 'PENDING':
      return const _HeroContent(
        variant: SenderHeroVariant.wait,
        title: '⏳ En attente du voyageur',
        subtitle: 'Vous serez notifié dès sa réponse.',
      );

    case 'AWAITING_PAYMENT':
      // Montant payé par l'expéditeur = net + commission (totalSenderAmountEur).
      final amount =
          (bid.totalSenderAmountEur ?? bid.totalAmountEur)?.toStringAsFixed(2) ?? '–';
      return _HeroContent(
        variant: SenderHeroVariant.pay,
        title: "Payez pour confirmer l'envoi",
        subtitle:
            'Votre paiement de $amount € sera séquestré jusqu\'à la livraison.',
      );

    case 'PAYMENT_ESCROWED':
      final amount =
          (bid.totalSenderAmountEur ?? bid.totalAmountEur)?.toStringAsFixed(2) ?? '–';
      return _HeroContent(
        variant: SenderHeroVariant.wait,
        title: '🔒 Paiement sécurisé',
        subtitle: '$amount € séquestrés. En attente de remise.',
      );

    case 'ACCEPTED':
      final subtitle = _buildAcceptedSubtitle(bid);
      return _HeroContent(
        variant: SenderHeroVariant.info,
        title: '⚡ Remise du colis',
        subtitle: subtitle,
      );

    case 'HANDED_OVER':
      final name = bid.travelerName ?? 'le voyageur';
      final dateStr = _formatDepartureDate(bid.departureDate);
      return _HeroContent(
        variant: SenderHeroVariant.info,
        title: '✓ Colis remis à $name',
        subtitle: dateStr.isNotEmpty
            ? 'Embarquement prévu le $dateStr.'
            : 'Colis remis.',
      );

    case 'IN_TRANSIT':
      final subtitle = _buildInTransitSubtitle(bid);
      return _HeroContent(
        variant: SenderHeroVariant.info,
        title: '✈ Colis en vol',
        subtitle: subtitle,
      );

    case 'COMPLETED':
    case 'DELIVERED':
      final recipient = bid.recipientName ?? 'votre destinataire';
      return _HeroContent(
        variant: SenderHeroVariant.done,
        title: '✓ Livré à $recipient',
        subtitle: 'Paiement libéré au voyageur.',
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

// ── Date / window helpers ─────────────────────────────────────────────────────

String _formatWindow(DateTime? start, DateTime? end) {
  if (start == null && end == null) {
    return '';
  }
  try {
    final fmt = DateFormat('EEE d MMM HH:mm', 'fr');
    final fmtTime = DateFormat('HH:mm', 'fr');

    if (start != null && end != null) {
      final sameDay = start.year == end.year &&
          start.month == end.month &&
          start.day == end.day;
      if (sameDay) {
        return '${fmt.format(start)} – ${fmtTime.format(end)}';
      }
      return '${fmt.format(start)} – ${fmt.format(end)}';
    }
    if (start != null) {
      return fmt.format(start);
    }
    return fmt.format(end!);
  } catch (_) {
    // Fallback when locale data unavailable (e.g. isolated tests)
    final fallback = DateFormat('dd/MM HH:mm');
    if (start != null && end != null) {
      return '${fallback.format(start)} – ${fallback.format(end)}';
    }
    if (start != null) {
      return fallback.format(start);
    }
    return fallback.format(end!);
  }
}

String _formatDepartureDate(DateTime? date) {
  if (date == null) {
    return '';
  }
  try {
    return DateFormat('EEE d MMM à HH:mm', 'fr').format(date);
  } catch (_) {
    return DateFormat('dd/MM HH:mm').format(date);
  }
}

String _buildAcceptedSubtitle(BidModel bid) {
  final window = _formatWindow(bid.handoverWindowStart, bid.handoverWindowEnd);
  final location = bid.handoverLocation;
  final parts = <String>[];
  if (window.isNotEmpty) {
    parts.add(window);
  }
  if (location != null && location.isNotEmpty) {
    parts.add(location);
  }

  final base = parts.join(' · ');
  if (base.isNotEmpty) {
    return '$base.\nPrésentez le QR — ou collez-le sur le colis.';
  }
  return 'Présentez le QR — ou collez-le sur le colis.';
}

String _buildInTransitSubtitle(BidModel bid) {
  final arrivalCity = bid.arrivalCity ?? 'destination';
  final arrivalTime = bid.arrivalTime ?? '';
  final timePart = arrivalTime.isNotEmpty
      ? 'Arrivée prévue $arrivalTime à $arrivalCity.'
      : 'En route vers $arrivalCity.';

  if (bid.confirmationCode != null) {
    // Pas de mention « à qui » ici : l'instruction de transmission fait
    // autorité sur le talon (carte « CODE DE RETRAIT »), juste au-dessus.
    return '$timePart Le code de retrait figure sur votre billet.';
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: white,
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, maxLines: 1),
              ),
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
    final window = _formatWindow(bid.handoverWindowStart, bid.handoverWindowEnd);
    final subtitle =
        "La remise était prévue $window. Le voyageur ne s'est pas présenté ?";

    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final isLoading = state is CancellationLoading;
        return _HeroShell(
          variant: SenderHeroVariant.alert,
          title: '⚠ Fenêtre de remise dépassée',
          subtitle: subtitle,
          footer: _HeroButton(
            label: "Signaler l'absence du voyageur",
            isLoading: isLoading,
            onPressed: () => _showNoShowSheet(context),
          ),
        );
      },
    );
  }

  Future<void> _showNoShowSheet(BuildContext context) async {
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: "Le voyageur ne s'est pas présenté ?",
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: "Signaler l'absence",
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
              "Le voyageur ne s'est pas présenté au point de remise.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              'Le voyageur aura 48 h pour contester. '
              'Sans réponse de sa part, le bid sera annulé.',
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
  String _timeLeft = '';

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
      _timeLeft = '';
      return;
    }
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) {
      _timeLeft = 'Délai expiré';
      return;
    }
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    _timeLeft =
        '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final timeLeft = _timeLeft;

    const white = Color(0xFFFFFFFF);

    final countdownWidget = timeLeft.isNotEmpty
        ? Text(
            '⏱ Temps pour contester : $timeLeft',
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
          title: '⚠ Absence signalée par le voyageur',
          subtitle: "Il indique que vous n'étiez pas présent au point de remise.",
          countdownWidget: countdownWidget,
          footer: Row(
            children: [
              Expanded(
                child: _HeroButton(
                  label: 'Je conteste',
                  isLoading: isLoading,
                  onPressed: () => _showContestSheet(context),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: _HeroButton(
                  label: 'Je confirme',
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
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: "Contester l'absence",
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: 'Confirmer la contestation',
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
              "Vous contestez l'absence signalée par le voyageur.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              'Notre équipe examinera votre demande et vous contactera sous 24 h.',
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
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: 'Confirmer votre absence',
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: 'Confirmer mon absence',
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Text(
          'En confirmant votre absence, le bid sera annulé '
          'et vous ne serez pas débité.',
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
