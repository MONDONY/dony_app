import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/qr_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/billet/copy_code_button.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/presentation/widgets/recipient_conversation_launcher.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/features/receptions/bloc/reception_detail_cubit.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/tracking/presentation/widgets/route_label.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_timeline_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Signature de l'ouverture du suivi, injectable pour les tests.
typedef ReceptionTimelineOpener =
    Future<void> Function(BuildContext context, Reception reception);

/// Signature de l'ouverture du QR du colis, injectable pour les tests.
typedef ReceptionQrOpener =
    Future<void> Function(BuildContext context, Reception reception);

Future<void> _openTimeline(BuildContext context, Reception reception) =>
    showTrackingTimelineSheet(
      context,
      bidId: reception.bidId,
      departureCity: reception.departureCity,
      arrivalCity: reception.arrivalCity,
      trackingNumber: reception.trackingNumber,
      arrivalInstructions: reception.arrivalInstructions,
    );

/// La même feuille que l'expéditeur (luminosité maximale, enregistrer,
/// partager) : `GET /tracking/{bidId}/qr-code` est ouvert au destinataire
/// dont le lien est confirmé. Un refus (403, back antérieur) s'affiche dans
/// la feuille, sans rien bloquer : le code de retrait suffit à la remise.
Future<void> _openQr(BuildContext context, Reception reception) =>
    QrSheet.show(context, bidId: reception.bidId, status: reception.bidStatus);

/// Un colis que l'utilisateur va recevoir (lot 2 destinataire).
///
/// - Lien `PENDING` : l'expéditeur a saisi son numéro. Il confirme que le
///   colis est pour lui, ou le refuse.
/// - Lien `CONFIRMED` : étape du colis, code de retrait, QR du colis à
///   montrer au voyageur, personnes et détails.
class ReceptionDetailScreen extends StatelessWidget {
  const ReceptionDetailScreen({
    super.key,
    required this.bidId,
    this.openTimeline,
    this.openQr,
  });

  final String bidId;

  /// Injecté en test ; sinon la feuille du suivi.
  final ReceptionTimelineOpener? openTimeline;

  /// Injecté en test ; sinon la [QrSheet].
  final ReceptionQrOpener? openQr;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ReceptionDetailCubit>()..load(bidId),
      child: _ReceptionDetailView(
        openTimeline: openTimeline ?? _openTimeline,
        openQr: openQr ?? _openQr,
      ),
    );
  }
}

class _ReceptionDetailView extends StatelessWidget {
  const _ReceptionDetailView({
    required this.openTimeline,
    required this.openQr,
  });

  final ReceptionTimelineOpener openTimeline;
  final ReceptionQrOpener openQr;

  void _onAction(BuildContext context, ReceptionDetailLoaded state) {
    final l = context.l10n;
    switch (state.action) {
      case ReceptionAction.confirmed:
        DonySnackbar.show(
          context,
          message: l.receptionConfirmedSnackbar,
          type: DonySnackbarType.success,
        );
      case ReceptionAction.declined || ReceptionAction.withdrawn:
        // Message posé avant de quitter l'écran : le ScaffoldMessenger de
        // l'app le garde affiché sur l'onglet Suivi.
        DonySnackbar.show(
          context,
          message: state.action == ReceptionAction.withdrawn
              ? l.receptionWithdrawnSnackbar
              : l.receptionDeclinedSnackbar,
        );
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/tracking');
        }
      case ReceptionAction.failed:
        ErrorPresenter.show(context, state.actionError);
      case ReceptionAction.idle ||
          ReceptionAction.confirming ||
          ReceptionAction.declining:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocConsumer<ReceptionDetailCubit, ReceptionDetailState>(
      listenWhen: (previous, current) =>
          current is ReceptionDetailLoaded &&
          (previous is! ReceptionDetailLoaded ||
              previous.action != current.action),
      listener: (context, state) =>
          _onAction(context, state as ReceptionDetailLoaded),
      builder: (context, state) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          actions: const [DonyFeedbackButton()],
          backgroundColor: cs.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          leading: const DonyAppBarBackButton(),
          title: Text(l.receptionDetailTitle, style: tt.headlineLarge),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: cs.outline, height: 1),
          ),
        ),
        body: switch (state) {
          ReceptionDetailLoading() => const DonyDetailSkeleton(),
          ReceptionDetailError(notFound: true) => DonyEmptyState(
            key: const Key('reception-not-found'),
            mascotte: DonyMascotteType.aucunResultat,
            iconAsset: 'package',
            title: l.receptionNotFoundTitle,
            description: l.receptionNotFoundDescription,
            actionLabel: l.receptionNotFoundAction,
            onAction: () => context.go('/tracking'),
          ),
          ReceptionDetailError() => DonyEmptyState(
            key: const Key('reception-error'),
            mascotte: DonyMascotteType.erreurLegere,
            type: DonyEmptyStateType.error,
            iconAsset: 'wifi-off',
            title: l.receptionErrorTitle,
            description: l.receptionErrorDescription,
            actionLabel: l.commonRetry,
            onAction: () => context.read<ReceptionDetailCubit>().retry(),
          ),
          ReceptionDetailLoaded(:final reception) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              DonyLayout.hPadding(context),
              DonySpacing.lg,
              DonyLayout.hPadding(context),
              DonySpacing.huge,
            ),
            child: DonyLayout.constrained(
              context,
              reception.isConfirmed
                  ? _ConfirmedContent(reception: reception, openQr: openQr)
                  : _PendingContent(reception: reception),
            ),
          ),
        },
        bottomNavigationBar: state is ReceptionDetailLoaded
            ? _BottomBar(state: state, openTimeline: openTimeline)
            : null,
      ),
    );
  }
}

String? _formatDate(AppLocalizations l, DateTime? date) =>
    date == null ? null : DateFormat.yMMMMd(l.localeName).format(date);

// ─────────────────────────────────────────────────────────────
// Briques partagées
// ─────────────────────────────────────────────────────────────

/// Sections de l'écran, entrées une à une : fondu et léger glissement,
/// décalés de 60 ms. L'animation ne rejoue pas aux rebuilds du même écran
/// (geste en cours, snackbar) : `Animate` garde son état.
class _StaggeredColumn extends StatelessWidget {
  const _StaggeredColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(const SizedBox(height: DonySpacing.base));
      items.add(
        children[i]
            .animate(delay: (60 * i).ms)
            .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
            .slideY(begin: 0.06, duration: 300.ms, curve: Curves.easeOutCubic),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items,
    );
  }
}

/// Surface de carte : ombre douce plutôt qu'une bordure pleine, avec un
/// liseré léger qui garde la carte lisible en mode sombre (où l'ombre
/// encre ne porte presque pas).
class _Surface extends StatelessWidget {
  const _Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DonySpacing.base),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
        boxShadow: DonyShadow.sm,
      ),
      child: child,
    );
  }
}

/// Pastille ronde teintée portant une icône.
class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final String icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: DonySpacing.icon,
      height: DonySpacing.icon,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: DonyIcon(icon, size: DonySpacing.iconSm, color: color),
    );
  }
}

/// Titre de section en petites capitales.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// En-tête héros : dégradé, statut en grand, trajet. Le texte reste blanc
/// sur un dégradé foncé, lisible dans les deux thèmes.
class _Hero extends StatelessWidget {
  const _Hero({
    super.key,
    required this.colors,
    required this.eyebrow,
    required this.title,
    required this.children,
  });

  final List<Color> colors;
  final Widget eyebrow;
  final String title;
  final List<Widget> children;

  static const white = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(DonyRadius.xl);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
              ),
            ),
            // Halo décoratif dans le coin : donne de la profondeur au
            // dégradé sans charger le contenu.
            Positioned(
              top: -60,
              right: -40,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        white.withValues(alpha: 0.18),
                        white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(DonySpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  eyebrow,
                  const SizedBox(height: DonySpacing.md),
                  Text(
                    title,
                    style: tt.headlineMedium?.copyWith(
                      color: white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastille translucide de l'en-tête héros.
class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: _Hero.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: _Hero.white.withValues(alpha: 0.22)),
      ),
      child: child,
    );
  }
}

class _HeroPillText extends StatelessWidget {
  const _HeroPillText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: _Hero.white,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Lien à confirmer
// ─────────────────────────────────────────────────────────────

class _PendingContent extends StatelessWidget {
  const _PendingContent({required this.reception});

  final Reception reception;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sender = reception.senderFirstName;
    final from = reception.departureCity;
    final to = reception.arrivalCity;
    final departure = _formatDate(l, reception.departureDate);
    final recipient = reception.recipientName;
    final muted = tt.bodyMedium?.copyWith(
      color: _Hero.white.withValues(alpha: 0.85),
    );

    return _StaggeredColumn(
      children: [
        _Hero(
          key: const Key('reception-pending-hero'),
          colors: const [DonyColors.ink500, DonyColors.ink800],
          eyebrow: _HeroPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DonyEmoji.parcel(size: 14),
                const SizedBox(width: DonySpacing.xs),
                Flexible(child: _HeroPillText(l.receptionsPendingChip)),
              ],
            ),
          ),
          title: sender != null
              ? l.receptionPendingHeadline(sender)
              : l.receptionPendingHeadlineAnonymous,
          children: [
            if (from != null && to != null) ...[
              const SizedBox(height: DonySpacing.sm),
              RouteLabel(
                from: from,
                to: to,
                style: tt.titleLarge?.copyWith(
                  color: _Hero.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (departure != null) ...[
              const SizedBox(height: DonySpacing.sm),
              Text(l.receptionDepartureOn(departure), style: muted),
            ],
            if (recipient != null) ...[
              const SizedBox(height: DonySpacing.xxs),
              Text(l.receptionRecipientName(recipient), style: muted),
            ],
          ],
        ),
        if (reception.senderId case final senderId?)
          _PeopleCard(
            rows: [
              _ProfileRow.sender(
                senderId: senderId,
                name: sender,
                avatarUrl: reception.senderAvatarUrl,
              ),
            ],
          ),
        _Surface(
          key: const Key('reception-pending-question'),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBubble(icon: 'circle-help', color: cs.primary),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.receptionPendingQuestion,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      l.receptionPendingExplanation,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Lien confirmé
// ─────────────────────────────────────────────────────────────

/// Étapes faites selon le statut du colis.
int _doneSteps(String bidStatus) => switch (bidStatus) {
  'HANDED_OVER' || 'IN_TRANSIT' => 1,
  'ARRIVED' => 3,
  'COMPLETED' => 4,
  _ => 0,
};

const _stepCount = 4;

class _ConfirmedContent extends StatelessWidget {
  const _ConfirmedContent({required this.reception, required this.openQr});

  final Reception reception;
  final ReceptionQrOpener openQr;

  String _stepHeadline(AppLocalizations l) {
    final city = reception.arrivalCity;
    if (reception.bidStatus == 'ARRIVED' && city != null) {
      return l.receptionStepArrivedIn(city);
    }
    return l.receptionStepHeadline(reception.bidStatus);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final from = reception.departureCity;
    final to = reception.arrivalCity;
    final code = reception.confirmationCode;
    final instructions = reception.arrivalInstructions;
    final done = _doneSteps(reception.bidStatus);
    final heroColors = reception.bidStatus == 'COMPLETED'
        ? const [DonyColors.success500, DonyColors.success700]
        : const [DonyColors.blue500, DonyColors.blue800];

    final details = <Widget>[
      // Avec un id, la ligne voyageur devient sa carte (photo + profil).
      if (reception.travelerId == null)
        if (reception.travelerFirstName case final traveler?)
          DonyInfoRow(
            icon: Icons.person_outline_rounded,
            label: l.receptionTravelerLabel,
            value: traveler,
          ),
      if (_formatDate(l, reception.departureDate) case final date?)
        DonyInfoRow(
          icon: Icons.flight_takeoff_rounded,
          label: l.receptionDepartureLabel,
          value: date,
        ),
      if (_formatDate(l, reception.arrivalDate) case final date?)
        DonyInfoRow(
          icon: Icons.flight_land_rounded,
          label: l.receptionArrivalLabel,
          value: date,
        ),
      if (reception.trackingNumber case final number?)
        DonyInfoRow(
          icon: Icons.tag_rounded,
          label: l.receptionTrackingNumberLabel,
          value: number,
        ),
      if (reception.weightKg case final kg?)
        DonyInfoRow(
          icon: Icons.scale_rounded,
          label: l.receptionWeightLabel,
          value: formatWeightKg(l, kg),
        ),
    ];

    final people = <_ProfileRow>[
      if (reception.senderId case final senderId?)
        _ProfileRow.sender(
          senderId: senderId,
          name: reception.senderFirstName,
          avatarUrl: reception.senderAvatarUrl,
        ),
      if (reception.travelerId case final travelerId?)
        _ProfileRow.traveler(
          travelerId: travelerId,
          name: reception.travelerFirstName,
          avatarUrl: reception.travelerAvatarUrl,
        ),
    ];

    return _StaggeredColumn(
      children: [
        _Hero(
          key: const Key('reception-step'),
          colors: heroColors,
          eyebrow: _HeroPill(
            child: _HeroPillText(
              l.receptionStepCounter(
                done < _stepCount ? done + 1 : _stepCount,
                _stepCount,
              ),
            ),
          ),
          title: _stepHeadline(l),
          children: [
            if (from != null && to != null) ...[
              const SizedBox(height: DonySpacing.xs),
              RouteLabel(
                from: from,
                to: to,
                style: tt.bodyLarge?.copyWith(
                  color: _Hero.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: DonySpacing.lg),
            _ReceptionSteps(done: done, accent: heroColors.last),
          ],
        ),
        if (code != null)
          _PickupCodeCard(code: code)
        else if (reception.bidStatus == 'ACCEPTED')
          _Surface(
            key: const Key('reception-code-pending'),
            child: Row(
              children: [
                _IconBubble(icon: 'clock', color: cs.primary),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Text(
                    l.receptionCodePending,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (reception.canShowParcelQr)
          _ParcelQrTile(onTap: () => openQr(context, reception)),
        if (instructions != null)
          _SectionCard(
            title: l.receptionInstructionsTitle,
            child: Text(
              instructions,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface, height: 1.45),
            ),
          ),
        if (people.isNotEmpty) _PeopleCard(rows: people),
        if (details.isNotEmpty)
          _SectionCard(
            title: l.receptionDetailsTitle,
            child: Column(children: details),
          ),
      ],
    );
  }
}

/// Les quatre étapes du colis, en frise verticale, avec leur libellé : la
/// barre seule ne disait pas ce qui était fait (Sentry FLUTTER-6E, « le colis
/// a été donné mais l'étape n'est pas complète »).
class _ReceptionSteps extends StatelessWidget {
  const _ReceptionSteps({required this.done, required this.accent});

  /// Étapes faites (0 à 4).
  final int done;

  /// Teinte du dégradé, reprise par la coche des étapes faites.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [
      l.receptionTimelineHandedOver,
      l.receptionTimelineInTransit,
      l.receptionTimelineArrived,
      l.receptionTimelineDelivered,
    ];
    return Column(
      key: const Key('reception-steps'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < labels.length; i++)
          _StepRow(
            key: Key('reception-step-$i'),
            label: labels[i],
            accent: accent,
            isLast: i == labels.length - 1,
            state: i < done
                ? _StepState.done
                : i == done
                ? _StepState.current
                : _StepState.todo,
            // Le trait vers l'étape suivante est plein si celle-ci est faite.
            nextDone: i + 1 < done,
          ),
      ],
    );
  }
}

enum _StepState { done, current, todo }

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.label,
    required this.accent,
    required this.state,
    required this.isLast,
    required this.nextDone,
  });

  final String label;
  final Color accent;
  final _StepState state;
  final bool isLast;
  final bool nextDone;

  static const _node = 22.0;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    const white = _Hero.white;
    final status = switch (state) {
      _StepState.done => l.receptionStepDoneSemantics,
      _StepState.current => l.receptionStepCurrentSemantics,
      _StepState.todo => l.receptionStepTodoSemantics,
    };

    final Widget node = switch (state) {
      _StepState.done => Container(
        width: _node,
        height: _node,
        decoration: const BoxDecoration(color: white, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: DonyIcon('check', size: 14, color: accent),
      ),
      _StepState.current => Container(
        width: _node,
        height: _node,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: white, width: 2),
          color: white.withValues(alpha: 0.18),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: white, shape: BoxShape.circle),
        ),
      ),
      _StepState.todo => Container(
        width: _node,
        height: _node,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: white.withValues(alpha: 0.4), width: 2),
        ),
      ),
    };

    return Semantics(
      label: '$label, $status',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _node,
              child: Column(
                children: [
                  node,
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(
                          vertical: DonySpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: white.withValues(alpha: nextDone ? 0.9 : 0.3),
                          borderRadius: BorderRadius.circular(DonyRadius.full),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 1,
                  bottom: isLast ? 0 : DonySpacing.md,
                ),
                child: Text(
                  label,
                  style: tt.bodyMedium?.copyWith(
                    color: state == _StepState.todo
                        ? white.withValues(alpha: 0.7)
                        : white,
                    fontWeight: state == _StepState.current
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une personne liée au colis (rôle, photo, prénom) qui ouvre son profil
/// public : l'expéditeur (Sentry FLUTTER-7P) ou le voyageur (Sentry
/// FLUTTER-6F, 6G, 6H).
class _ProfileRow {
  const _ProfileRow({
    required this.rowKey,
    required this.userId,
    required this.role,
    required this.name,
    required this.avatarUrl,
  });

  factory _ProfileRow.sender({
    required String senderId,
    required String? name,
    required String? avatarUrl,
  }) => _ProfileRow(
    rowKey: const Key('reception-sender-card'),
    userId: senderId,
    role: _Role.sender,
    name: name,
    avatarUrl: avatarUrl,
  );

  factory _ProfileRow.traveler({
    required String travelerId,
    required String? name,
    required String? avatarUrl,
  }) => _ProfileRow(
    rowKey: const Key('reception-traveler-card'),
    userId: travelerId,
    role: _Role.traveler,
    name: name,
    avatarUrl: avatarUrl,
  );

  final Key rowKey;
  final String userId;
  final _Role role;
  final String? name;
  final String? avatarUrl;
}

enum _Role { sender, traveler }

/// Expéditeur et voyageur réunis dans une seule carte, séparés d'un trait.
class _PeopleCard extends StatelessWidget {
  const _PeopleCard({required this.rows});

  final List<_ProfileRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(
          Divider(
            height: 1,
            indent: DonySpacing.base + DonySpacing.icon + DonySpacing.md,
            color: cs.outline.withValues(alpha: 0.6),
          ),
        );
      }
      children.add(_PersonTile(row: rows[i]));
    }
    return _Surface(
      key: const Key('reception-people'),
      padding: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.row});

  final _ProfileRow row;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final role = row.role == _Role.sender
        ? l.receptionSenderLabel
        : l.receptionTravelerLabel;
    final display = row.name ?? role;
    final semantics = row.role == _Role.sender
        ? l.receptionViewSenderProfile(display)
        : l.receptionViewTravelerProfile(display);

    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: DonyPressable(
        key: row.rowKey,
        scale: 0.98,
        onTap: () => context.push(
          '/profile/public',
          extra: ProfilePublicArgs(userId: row.userId),
        ),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.md,
          ),
          child: Row(
            children: [
              DonyAvatar(name: display, imageUrl: row.avatarUrl),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l.receptionSeeTravelerProfile,
                      style: tt.bodySmall?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
              ),
              DonyIcon('chevron-right', size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le code de retrait mis en vedette : le destinataire le dicte au voyageur
/// à la remise. Un chiffre par case, à chasse fixe, pour qu'aucun ne se
/// confonde.
class _PickupCodeCard extends StatelessWidget {
  const _PickupCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return _Surface(
      key: const Key('reception-code'),
      padding: const EdgeInsets.all(DonySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconBubble(icon: 'key-round', color: cs.primary),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Text(
                  l.receptionCodeTitle,
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.lg),
          Semantics(
            label: l.receptionCodeSemantics(code.split('').join(' ')),
            excludeSemantics: true,
            child: _CodeDigits(code: code),
          ),
          const SizedBox(height: DonySpacing.lg),
          CopyCodeButton(
            code: code,
            label: l.ticketCopyCodeButton,
            copiedLabel: l.ticketCodeCopiedSnackbar,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            l.receptionCodeExplanation,
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une case par chiffre, largeur adaptée à la place disponible. Couleurs
/// inversées (fond texte, chiffre surface) : contraste maximal dans les deux
/// thèmes.
class _CodeDigits extends StatelessWidget {
  const _CodeDigits({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final digits = code.split('');
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = DonySpacing.sm;
        final n = digits.length;
        final width = ((constraints.maxWidth - gap * (n - 1)) / n).clamp(
          24.0,
          52.0,
        );
        final height = (width * 1.2).clamp(32.0, 62.0);
        final fontSize = (width * 0.55).clamp(16.0, 28.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Container(
                    key: Key('reception-code-digit-$i'),
                    width: width,
                    height: height,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.onSurface,
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                    ),
                    child: Text(
                      digits[i],
                      style: tt.headlineMedium?.copyWith(
                        color: cs.surface,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  )
                  .animate(delay: (200 + 40 * i).ms)
                  .fadeIn(duration: 250.ms, curve: Curves.easeOutCubic)
                  .slideY(
                    begin: 0.25,
                    duration: 250.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ],
          ],
        );
      },
    );
  }
}

/// Accès au QR du colis : le voyageur le scanne pour identifier le colis,
/// puis saisit le code de retrait. Le QR seul ne vaut pas remise.
class _ParcelQrTile extends StatelessWidget {
  const _ParcelQrTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${l.receptionShowQrTitle}. ${l.receptionShowQrExplanation}',
      excludeSemantics: true,
      child: DonyPressable(
        key: const Key('reception-show-qr'),
        onTap: onTap,
        child: _Surface(
          child: Row(
            children: [
              _IconBubble(icon: 'qr-code', color: cs.primary),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.receptionShowQrTitle,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      l.receptionShowQrExplanation,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              DonyIcon('chevron-right', size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Barre fixe
// ─────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.openTimeline});

  final ReceptionDetailLoaded state;
  final ReceptionTimelineOpener openTimeline;

  /// « Me retirer de ce colis » (FLUTTER-9F) : destructif, l'expéditeur et
  /// le voyageur sont prévenus.
  Future<void> _withdraw(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<ReceptionDetailCubit>();
    final confirmed = await DonyDialog.show(
      context,
      title: l.receptionWithdrawDialogTitle,
      message: l.receptionWithdrawDialogMessage,
      confirmLabel: l.receptionWithdrawConfirm,
      variant: DonyDialogVariant.destructive,
      iconAsset: 'user-x',
    );
    if (confirmed ?? false) await cubit.decline();
  }

  Future<void> _decline(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<ReceptionDetailCubit>();
    final confirmed = await DonyDialog.show(
      context,
      title: l.receptionDeclineDialogTitle,
      message: l.receptionDeclineDialogMessage,
      confirmLabel: l.receptionDeclineButton,
      iconAsset: 'circle-help',
    );
    if (confirmed ?? false) await cubit.decline();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final reception = state.reception;
    // Après le refus, l'écran se ferme : plus aucun geste possible.
    final locked =
        state.busy ||
        state.action == ReceptionAction.declined ||
        state.action == ReceptionAction.withdrawn;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outline.withValues(alpha: 0.6)),
        ),
        boxShadow: DonyShadow.sticky,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.md,
            DonySpacing.lg,
            DonySpacing.md,
          ),
          child: reception.isConfirmed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Le colis est encore en route : le destinataire écrit
                    // au voyageur dans une conversation à part, que
                    // l'expéditeur ne voit pas (lot 3C).
                    if (reception.canMessageTraveler) ...[
                      RecipientConversationLauncher(
                        bidId: reception.bidId,
                        role: RecipientConversationRole.recipient,
                        builder: (context, onPressed, isLoading) => DonyButton(
                          key: const Key('reception-message-traveler'),
                          label: l.receptionMessageTraveler,
                          iconAsset: 'message-circle',
                          flat: true,
                          isLoading: isLoading,
                          onPressed: onPressed,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.sm),
                    ],
                    DonyButton(
                      key: const Key('reception-view-tracking'),
                      label: l.receptionViewTracking,
                      iconAsset: 'route',
                      variant: DonyButtonVariant.secondary,
                      onPressed: () => openTimeline(context, reception),
                    ),
                    if (reception.canWithdraw) ...[
                      const SizedBox(height: DonySpacing.xs),
                      DonyButton(
                        key: const Key('reception-withdraw'),
                        label: l.receptionWithdrawButton,
                        variant: DonyButtonVariant.ghost,
                        isLoading: state.action == ReceptionAction.declining,
                        onPressed: locked ? null : () => _withdraw(context),
                      ),
                    ],
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DonyButton(
                      key: const Key('reception-confirm'),
                      label: l.receptionConfirmButton,
                      flat: true,
                      isLoading: state.action == ReceptionAction.confirming,
                      onPressed: locked
                          ? null
                          : () =>
                                context.read<ReceptionDetailCubit>().confirm(),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    DonyButton(
                      key: const Key('reception-decline'),
                      label: l.receptionDeclineButton,
                      variant: DonyButtonVariant.ghost,
                      isLoading: state.action == ReceptionAction.declining,
                      onPressed: locked ? null : () => _decline(context),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
