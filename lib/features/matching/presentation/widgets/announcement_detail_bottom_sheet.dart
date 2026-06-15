import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/open_surplus_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AnnouncementDetailBottomSheet {
  static Future<void> show(BuildContext context, {required String announcementId}) {
    return DonyBottomSheet.show(
      context,
      title: 'Détail du trajet',
      wrapper: (child) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => getIt<AnnouncementBloc>()
              ..add(AnnouncementDetailRequested(announcementId)),
          ),
          BlocProvider(create: (_) => getIt<CancellationBloc>()),
        ],
        child: child,
      ),
      stickyBottom: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (context, state) {
          if (state is! AnnouncementDetailLoaded) {
            return const SizedBox.shrink();
          }
          final a = state.announcement;
          final canEdit = a.status == 'ACTIVE' && (a.bidsCount ?? 0) == 0;
          final isCancelled = a.status == 'CANCELLED';
          final canDelete =
              (a.status == 'ACTIVE' && (a.bidsCount ?? 0) == 0) || isCancelled;
          final cs = Theme.of(context).colorScheme;

          // Bouton surplus — garde sa forme pleine largeur (action rare)
          final Widget? surplusBtn = a.canOpenSurplus
              ? DonyButton(
                  label: 'Ouvrir les kg restants',
                  iconAsset: 'square-plus',
                  variant: DonyButtonVariant.secondary,
                  onPressed: () async {
                    final bloc = context.read<AnnouncementBloc>();
                    final opened = await OpenSurplusBottomSheet.show(
                      context,
                      announcement: a,
                    );
                    if (opened == true) {
                      bloc.add(AnnouncementDetailRequested(a.id));
                    }
                  },
                )
              : null;

          // Aucune action disponible (COMPLETED, FULL, …)
          final hasAnyAction = a.status == 'ACTIVE' || isCancelled;
          if (!hasAnyAction && surplusBtn == null) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (surplusBtn != null) ...[
                surplusBtn,
                const SizedBox(height: DonySpacing.md),
              ],
              if (hasAnyAction)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Voir les demandes — toujours visible si ACTIVE
                    if (a.status == 'ACTIVE')
                      _IconActionBtn(
                        iconAsset: 'package',
                        label: 'Demandes',
                        bgColor: cs.primaryContainer,
                        iconColor: cs.primary,
                        labelColor: cs.primary,
                        showBadge: (a.bidsCount ?? 0) > 0,
                        onPressed: () =>
                            context.push('/announcements/${a.id}/bids'),
                      ),
                    // Modifier — uniquement si 0 demande
                    if (canEdit)
                      _IconActionBtn(
                        iconAsset: 'square-pen',
                        label: 'Modifier',
                        bgColor: cs.surfaceContainerHighest,
                        iconColor: cs.onSurface,
                        labelColor: cs.onSurfaceVariant,
                        onPressed: () => CreateAnnouncementBottomSheet.show(
                            context,
                            announcement: a),
                      ),
                    // Supprimer ou Annuler
                    if (canDelete)
                      _IconActionBtn(
                        iconAsset: 'trash-2',
                        label: 'Supprimer',
                        bgColor: cs.errorContainer,
                        iconColor: cs.error,
                        labelColor: cs.error,
                        onPressed: () async {
                          final confirmed = await _confirmDelete(context,
                              isCancelled: isCancelled);
                          if (confirmed && context.mounted) {
                            context.read<AnnouncementBloc>().add(
                                AnnouncementDeleteRequested(a.id));
                          }
                        },
                      )
                    else if (a.status == 'ACTIVE')
                      _IconActionBtn(
                        iconAsset: 'circle-x',
                        label: 'Annuler',
                        bgColor: cs.errorContainer,
                        iconColor: cs.error,
                        labelColor: cs.error,
                        onPressed: () => CancellationBottomSheet.show(context,
                            announcementId: a.id),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
      child: _AnnouncementDetailContent(id: announcementId),
    );
  }

  static Future<bool> _confirmDelete(
    BuildContext context, {
    bool isCancelled = false,
  }) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Supprimer ce trajet ?',
      message: isCancelled
          ? 'Cette action est irréversible. Le trajet annulé et toutes les demandes associées seront définitivement retirés de la plateforme.'
          : 'Cette action est irréversible. Le trajet ne sera plus visible pour les expéditeurs.',
      confirmLabel: 'Supprimer',
      variant: DonyDialogVariant.destructive,
      iconAsset: 'trash-2',
    );
    return confirmed ?? false;
  }
}

class _AnnouncementDetailContent extends StatelessWidget {
  final String id;
  const _AnnouncementDetailContent({required this.id});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<AnnouncementBloc, AnnouncementState>(
      listener: (context, state) {
        if (state is AnnouncementDeleted) {
          DonySnackbar.show(
              context, message: 'Trajet supprimé', type: DonySnackbarType.success);
          Navigator.of(context, rootNavigator: true).pop();
          if (context.mounted) {
            context.go('/announcements');
          }
        } else if (state is AnnouncementNotFound) {
          DonySnackbar.show(
            context,
            message: 'Cette annonce n\'existe plus',
            type: DonySnackbarType.warning,
          );
          Navigator.of(context, rootNavigator: true).pop();
        } else if (state is AnnouncementDeleteBlockedByAcceptedBid) {
          _onDeleteBlocked(context, state.announcementId);
        } else if (state is AnnouncementError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      builder: (context, state) {
        if (state is AnnouncementLoading || state is AnnouncementInitial) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(DonySpacing.xxl),
              child: CircularProgressIndicator(color: cs.primary),
            ),
          );
        }

        if (state is AnnouncementDetailLoaded) {
          final cs2 = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          return _buildContent(context, cs2, tt, state);
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    AnnouncementDetailLoaded state,
  ) {
    final a = state.announcement;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Hero bleu nuit ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(DonySpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF0C4A6E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DonyRadius.xl),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRAJET',
                          style: tt.labelSmall?.copyWith(
                            color: Colors.white38,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${a.departureCity} → ${a.arrivalCity}',
                          style: tt.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: a.status),
                ],
              ),
              const SizedBox(height: DonySpacing.sm),
              Wrap(
                spacing: DonySpacing.xs,
                runSpacing: DonySpacing.xs,
                children: [
                  _HeroChip(
                    label: DateFormat('EEE d MMM yyyy', 'fr').format(a.departureDate),
                  ),
                  if (a.transportMode != null)
                    _HeroChip(label: a.transportMode!.label),
                  if (a.departureTime != null)
                    _HeroChip(
                      label: a.departureTime! +
                          (a.arrivalTime != null ? ' → ${a.arrivalTime}' : ''),
                    ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 250.ms),
        const SizedBox(height: DonySpacing.md),

        // ── Répartition capacité (trajet dédié au surplus ouvert) ───────────
        if (a.surplusPublished) ...[
          _SurplusSplitRow(
            reservedKg: a.reservedKg,
            openKg: a.availableKg,
          ).animate().fadeIn(delay: 40.ms),
          const SizedBox(height: DonySpacing.md),
        ],

        // ── 2 info pills (capacité · prix) ───────────────────────────────────
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _InfoPill(
                  value: a.capacityUnit == 'KG_FREE'
                      ? 'Kg libre'
                      : '${a.availableKg.toStringAsFixed(0)} kg',
                  label: 'disponibles',
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: _InfoPill(
                  value: a.pricingMode == 'MIXED'
                      ? 'Grille'
                      : '${a.pricePerKg % 1 == 0 ? a.pricePerKg.toStringAsFixed(0) : a.pricePerKg.toStringAsFixed(1)}€/kg',
                  label: a.pricingMode == 'MIXED' ? 'tarifaire' : 'prix',
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 60.ms),
        const SizedBox(height: DonySpacing.sm),

        // ── Colis : acceptés vs en attente ───────────────────────────────────
        _ParcelStatsRow(
          accepted: a.confirmedParcelCount,
          pending: a.bidsCount ?? 0,
        ).animate().fadeIn(delay: 80.ms),
        const SizedBox(height: DonySpacing.lg),

        // ── Lieux de remise (orange) ─────────────────────────────────────────
        if (a.pickupAddress != null || a.deliveryAddress != null) ...[
          const _BSectionTitle(label: 'Lieux de remise', color: Color(0xFFEA580C)),
          const SizedBox(height: DonySpacing.xs),
          if (a.pickupAddress != null)
            _BSectionRow(
              iconAsset: 'upload',
              label: 'Remise colis',
              value: a.pickupAddress!.label,
              iconBg: const Color(0xFFFFF7ED),
              iconColor: const Color(0xFFF97316),
            ).animate().fadeIn(delay: 80.ms),
          if (a.deliveryAddress != null) ...[
            const SizedBox(height: DonySpacing.xs),
            _BSectionRow(
              iconAsset: 'download',
              label: 'Récupération',
              value: a.deliveryAddress!.label,
              iconBg: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
            ).animate().fadeIn(delay: 100.ms),
          ],
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Fenêtre de remise (sky) — dates complètes ────────────────────────
        if (a.handoverWindowStart != null && a.handoverWindowEnd != null) ...[
          const _BSectionTitle(label: 'Fenêtre de remise', color: Color(0xFF0284C7)),
          const SizedBox(height: DonySpacing.xs),
          _BSectionRow(
            iconAsset: 'clock',
            label: 'Créneau',
            value: _handoverRangeLabel(
              a.handoverWindowStart!.toLocal(),
              a.handoverWindowEnd!.toLocal(),
            ),
            iconBg: const Color(0xFFFEF9C3),
            iconColor: const Color(0xFFB45309),
          ).animate().fadeIn(delay: 110.ms),
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Paiements (violet) ───────────────────────────────────────────────
        if (a.acceptedPaymentMethods.isNotEmpty) ...[
          const _BSectionTitle(label: 'Paiements acceptés', color: Color(0xFF7C3AED)),
          const SizedBox(height: DonySpacing.xs),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: a.acceptedPaymentMethods.map((m) {
              final label = switch (m.apiValue) {
                'CASH' => '💵 Espèces',
                'STRIPE' => '💳 Carte',
                'WAVE' => '🌊 Wave',
                'ORANGE_MONEY' => '🟠 Orange Money',
                _ => m.apiValue,
              };
              return _BChip(
                label: label,
                bg: const Color(0xFFEDE9FE),
                fg: const Color(0xFF6D28D9),
              );
            }).toList(),
          ),
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Ce que j'accepte (vert) ──────────────────────────────────────────
        if (a.acceptedContentTypes?.isNotEmpty ?? false) ...[
          _BSectionTitle(label: 'Ce que j\'accepte', color: cs.success),
          const SizedBox(height: DonySpacing.xs),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: (a.acceptedContentTypes ?? [])
                .map((t) => _BChip(label: t, bg: cs.successLight, fg: cs.success))
                .toList(),
          ),
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Ce que je refuse (rouge) ─────────────────────────────────────────
        if (a.refusedTypes?.isNotEmpty ?? false) ...[
          _BSectionTitle(label: 'Ce que je refuse', color: cs.error),
          const SizedBox(height: DonySpacing.xs),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: (a.refusedTypes ?? [])
                .map((t) => _BChip(label: t, bg: cs.errorContainer, fg: cs.error))
                .toList(),
          ),
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Note expéditeurs ─────────────────────────────────────────────────
        if (a.description != null && a.description!.isNotEmpty) ...[
          const _BSectionTitle(label: 'Note aux expéditeurs', color: Color(0xFFB45309)),
          const SizedBox(height: DonySpacing.xs),
          Container(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEA),
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              a.description!,
              style: tt.bodySmall?.copyWith(
                color: const Color(0xFF78350F),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.md),
        ],
      ],
    );
  }

  Future<void> _onDeleteBlocked(
    BuildContext context,
    String announcementId,
  ) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Suppression impossible',
      message:
          "Un colis est déjà accepté sur ce trajet. Pour le retirer, vous devez d'abord annuler le voyage : l'expéditeur sera remboursé automatiquement.",
      confirmLabel: 'Annuler le voyage',
      cancelLabel: 'Fermer',
      variant: DonyDialogVariant.destructive,
      iconAsset: 'calendar-x',
    );
    if (confirmed == true && context.mounted) {
      await CancellationBottomSheet.show(context, announcementId: announcementId);
    }
  }
}

// ── Widgets helpers du sheet de détail ────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'ACTIVE' => ('● ACTIF', const Color(0xFF16A34A), Colors.white),
      'FULL' => ('● COMPLET', const Color(0xFFF59E0B), Colors.white),
      'IN_PROGRESS' => ('● EN COURS', const Color(0xFF16A34A), Colors.white),
      'COMPLETED' => ('✓ TERMINÉ', Colors.white24, Colors.white),
      'CANCELLED' => ('✕ ANNULÉ', const Color(0xFFE53935), Colors.white),
      _ => (status.toUpperCase(), Colors.white24, Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Répartition « X kg réservés · Y kg ouverts » affichée sur un trajet dédié
/// dont le surplus a été publié au public.
class _SurplusSplitRow extends StatelessWidget {
  final double reservedKg;
  final double openKg;
  const _SurplusSplitRow({required this.reservedKg, required this.openKg});

  String _fmt(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.successLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.success.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          DonyIcon('globe', size: 18, color: cs.success),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${_fmt(reservedKg)} kg réservés',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  ),
                  TextSpan(
                    text: ' · ',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  TextSpan(
                    text: '${_fmt(openKg)} kg ouverts',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String value;
  final String label;
  const _InfoPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Deux compteurs côte à côte : colis acceptés (vert) vs demandes en attente
/// (ambre). Affiché sous les pills de capacité/prix dans le détail du trajet.
class _ParcelStatsRow extends StatelessWidget {
  final int accepted;
  final int pending;
  const _ParcelStatsRow({required this.accepted, required this.pending});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _ParcelStatCell(
              iconAsset: 'circle-check',
              value: accepted,
              label: accepted > 1 ? 'colis acceptés' : 'colis accepté',
              tint: const Color(0xFFE7F6EC),
              accent: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: _ParcelStatCell(
              iconAsset: 'hourglass',
              value: pending,
              label: 'en attente',
              tint: const Color(0xFFFEF9C3),
              accent: const Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParcelStatCell extends StatelessWidget {
  final String iconAsset;
  final int value;
  final String label;
  final Color tint;
  final Color accent;

  const _ParcelStatCell({
    required this.iconAsset,
    required this.value,
    required this.label,
    required this.tint,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.sm),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Center(child: DonyIcon(iconAsset, size: 17, color: accent)),
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                    height: 1,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
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

/// Formate la plage de remise — toujours dates complètes début et fin.
String _handoverRangeLabel(DateTime start, DateTime end) {
  final fmt = DateFormat('EEE d MMM, HH:mm', 'fr');
  return '${fmt.format(start)} → ${fmt.format(end)}';
}

class _IconActionBtn extends StatelessWidget {
  final String iconAsset;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final Color labelColor;
  final VoidCallback? onPressed;
  final bool showBadge;

  const _IconActionBtn({
    required this.iconAsset,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.labelColor,
    this.onPressed,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(DonyRadius.full),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: DonyIcon(iconAsset, size: 22, color: iconColor)),
                ),
                if (showBadge)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;
  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BSectionTitle extends StatelessWidget {
  final String label;
  final Color color;
  const _BSectionTitle({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 0.7,
      ),
    );
  }
}

class _BSectionRow extends StatelessWidget {
  final String iconAsset;
  final String label;
  final String value;
  final Color iconBg;
  final Color iconColor;

  const _BSectionRow({
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(DonyRadius.sm),
          ),
          child: Center(child: DonyIcon(iconAsset, size: 16, color: iconColor)),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: tt.bodySmall?.copyWith(color: cs.onSurface),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _BChip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

