import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart';
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
          if (state is! AnnouncementDetailLoaded) return const SizedBox.shrink();
          final a = state.announcement;
          final canEdit = a.status == 'ACTIVE' && (a.bidsCount ?? 0) == 0;
          final isCancelled = a.status == 'CANCELLED';
          final canDelete =
              (a.status == 'ACTIVE' && (a.bidsCount ?? 0) == 0) || isCancelled;

          // Bouton principal — Voir les demandes (pleine largeur)
          // TODO(backend): bidsCount doit retourner le total (pending + accepted)
          // pour que ce compteur soit fidèle à la réalité.
          final Widget? primaryBtn = a.status == 'ACTIVE'
              ? DonyButton(
                  label: 'Voir les demandes (${a.bidsCount ?? 0})',
                  icon: Icons.inbox_rounded,
                  onPressed: () => context.push('/announcements/${a.id}/bids'),
                )
              : null;

          // Bouton secondaire — Modifier (gauche)
          final Widget? modifierBtn = canEdit
              ? DonyButton(
                  label: 'Modifier',
                  icon: Icons.edit_rounded,
                  variant: DonyButtonVariant.secondary,
                  onPressed: () =>
                      CreateAnnouncementBottomSheet.show(context, announcement: a),
                )
              : null;

          // Bouton destructif — Annuler ou Supprimer (droite)
          final Widget? destructifBtn = canDelete
              ? DonyButton(
                  label: 'Supprimer',
                  icon: Icons.delete_outline_rounded,
                  variant: DonyButtonVariant.destructive,
                  onPressed: () async {
                    final confirmed =
                        await _confirmDelete(context, isCancelled: isCancelled);
                    if (confirmed && context.mounted) {
                      context
                          .read<AnnouncementBloc>()
                          .add(AnnouncementDeleteRequested(a.id));
                    }
                  },
                )
              : (!canDelete && a.status == 'ACTIVE')
                  ? DonyButton(
                      label: 'Annuler',
                      icon: Icons.cancel_outlined,
                      variant: DonyButtonVariant.destructive,
                      onPressed: () =>
                          CancellationBottomSheet.show(context, announcementId: a.id),
                    )
                  : null;

          if (primaryBtn == null && modifierBtn == null && destructifBtn == null) {
            return const SizedBox.shrink();
          }

          final hasSecondRow = modifierBtn != null || destructifBtn != null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (primaryBtn != null) ...[
                primaryBtn,
                if (hasSecondRow) const SizedBox(height: DonySpacing.sm),
              ],
              if (hasSecondRow)
                Row(
                  children: [
                    if (modifierBtn != null) Expanded(child: modifierBtn),
                    if (modifierBtn != null && destructifBtn != null)
                      const SizedBox(width: DonySpacing.sm),
                    if (destructifBtn != null) Expanded(child: destructifBtn),
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
      icon: Icons.delete_outline_rounded,
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
          if (context.mounted) context.go('/announcements');
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
        // ── Hero gradient card ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(DonySpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2D1B69), Color(0xFF1A0D3E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DonyRadius.xl),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2D1B69).withValues(alpha: 0.35),
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
                            color: Colors.white54,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${a.departureCity} → ${a.arrivalCity}',
                          style: tt.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: a.status),
                ],
              ),
              const SizedBox(height: DonySpacing.sm),
              // Date + horaires
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 12, color: Colors.white54),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    DateFormat('EEE d MMM yyyy', 'fr').format(a.departureDate),
                    style: tt.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  if (a.departureTime != null) ...[
                    const SizedBox(width: DonySpacing.sm),
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: Colors.white54),
                    const SizedBox(width: DonySpacing.xs),
                    Text(
                      a.departureTime! +
                          (a.arrivalTime != null ? ' → ${a.arrivalTime}' : ''),
                      style: tt.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ],
              ),
              if (a.transportMode != null) ...[
                const SizedBox(height: DonySpacing.xs),
                Row(
                  children: [
                    Icon(
                      a.transportMode!.icon,
                      size: 12,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: DonySpacing.xs),
                    Text(
                      a.transportMode!.label,
                      style: tt.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 250.ms),
        const SizedBox(height: DonySpacing.md),

        // ── 3 info pills ────────────────────────────────────────────────────
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
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: _InfoPill(
                  value: '${a.bidsCount ?? 0}',
                  label: 'demande${(a.bidsCount ?? 0) > 1 ? 's' : ''}',
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 60.ms),
        const SizedBox(height: DonySpacing.md),

        // ── Lieux de remise ─────────────────────────────────────────────────
        if (a.pickupAddress != null || a.deliveryAddress != null) ...[
          Text(
            'LIEUX DE REMISE',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          if (a.pickupAddress != null)
            _LieuRow(
              icon: Icons.upload_rounded,
              label: 'REMISE COLIS',
              address: a.pickupAddress!.label,
            ).animate().fadeIn(delay: 80.ms),
          if (a.deliveryAddress != null) ...[
            const SizedBox(height: DonySpacing.xs),
            _LieuRow(
              icon: Icons.download_rounded,
              label: 'RÉCUPÉRATION',
              address: a.deliveryAddress!.label,
            ).animate().fadeIn(delay: 100.ms),
          ],
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Paiements ────────────────────────────────────────────────────────
        if (a.acceptedPaymentMethods.isNotEmpty) ...[
          Text(
            'PAIEMENTS ACCEPTÉS',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: a.acceptedPaymentMethods.map((m) {
              final label = switch (m.name.toUpperCase()) {
                'CASH' => '💵 Espèces',
                'STRIPE' => '💳 Carte',
                _ => m.name,
              };
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  label,
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Conditions ──────────────────────────────────────────────────────
        if ((a.acceptedContentTypes?.isNotEmpty ?? false) ||
            (a.refusedTypes?.isNotEmpty ?? false)) ...[
          if (a.acceptedContentTypes?.isNotEmpty ?? false) ...[
            Text(
              'CE QUE J\'ACCEPTE',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            Wrap(
              spacing: DonySpacing.xs,
              runSpacing: DonySpacing.xs,
              children: (a.acceptedContentTypes ?? []).map((t) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
                decoration: BoxDecoration(
                  color: cs.successLight,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                  border: Border.all(color: cs.success.withValues(alpha: 0.3)),
                ),
                child: Text(
                  t,
                  style: tt.labelSmall?.copyWith(
                    color: cs.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
          if (a.refusedTypes?.isNotEmpty ?? false) ...[
            Text(
              'CE QUE JE REFUSE',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            Wrap(
              spacing: DonySpacing.xs,
              runSpacing: DonySpacing.xs,
              children: (a.refusedTypes ?? []).map((t) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                  border: Border.all(color: cs.error.withValues(alpha: 0.3)),
                ),
                child: Text(
                  t,
                  style: tt.labelSmall?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
          const SizedBox(height: DonySpacing.xs),
        ],

        // ── Note expéditeurs ────────────────────────────────────────────────
        if (a.description != null && a.description!.isNotEmpty) ...[
          Text(
            'NOTE AUX EXPÉDITEURS',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Container(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEA),
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
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
      icon: Icons.event_busy_rounded,
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

class _LieuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String address;
  const _LieuRow({required this.icon, required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.sm),
            ),
            child: Icon(icon, size: 16, color: cs.primary),
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
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: tt.bodySmall?.copyWith(color: cs.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
