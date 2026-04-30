import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final String id;
  const AnnouncementDetailScreen({super.key, required this.id});

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AnnouncementBloc>().add(AnnouncementDetailRequested(widget.id));
  }

  Future<bool> _confirmDelete({bool isCancelled = false}) async {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Détail du trajet'),
      body: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (context, state) {
          if (state is AnnouncementDeleted) {
            DonySnackbar.show(context, message: 'Trajet supprimé', type: DonySnackbarType.success);
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          } else if (state is AnnouncementNotFound) {
            DonySnackbar.show(
              context,
              message: 'Cette annonce n\'existe plus',
              type: DonySnackbarType.warning,
            );
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          } else if (state is AnnouncementError) {
            DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
          }
        },
        builder: (context, state) {
          if (state is AnnouncementLoading || state is AnnouncementInitial) {
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }

          if (state is AnnouncementDetailLoaded) {
            return _buildContent(context, cs, tt, state);
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    AnnouncementDetailLoaded state,
  ) {
    final a = state.announcement;
    final canEdit = a.status == 'ACTIVE' && (a.bidsCount ?? 0) == 0;
    final isCancelled = a.status == 'CANCELLED';
    final canDelete = (a.status == 'ACTIVE' && (a.bidsCount ?? 0) == 0) || isCancelled;

    final h = DonyLayout.hPadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(h, DonySpacing.xl, h, DonySpacing.huge),
      child: DonyLayout.constrained(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero card — corridor + date
          Container(
            padding: const EdgeInsets.all(DonySpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [DonyColors.blue700, cs.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(DonyRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flight_takeoff_rounded, color: cs.onPrimary, size: 20),
                    const SizedBox(width: DonySpacing.sm),
                    Text(
                      'Trajet',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(status: a.status, cs: cs, tt: tt),
                  ],
                ),
                const SizedBox(height: DonySpacing.base),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      a.departureCity,
                      style: tt.headlineLarge?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
                      child: Icon(Icons.arrow_forward_rounded, color: cs.onPrimary.withValues(alpha: 0.7), size: 20),
                    ),
                    Text(
                      a.arrivalCity,
                      style: tt.headlineLarge?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.md),
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: cs.onPrimary.withValues(alpha: 0.6), size: 15),
                    const SizedBox(width: DonySpacing.xs),
                    Text(
                      DateFormat('EEEE d MMMM yyyy', 'fr').format(a.departureDate),
                      style: tt.bodySmall?.copyWith(
                        color: cs.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                if (a.departureTime != null || a.arrivalTime != null) ...[
                  const SizedBox(height: DonySpacing.sm),
                  Row(
                    children: [
                      if (a.departureTime != null) ...[
                        Icon(Icons.flight_takeoff_rounded, color: cs.onPrimary.withValues(alpha: 0.6), size: 13),
                        const SizedBox(width: DonySpacing.xs),
                        Text(
                          a.departureTime!,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onPrimary.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (a.departureTime != null && a.arrivalTime != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
                          child: Text(
                            '→',
                            style: tt.bodySmall?.copyWith(color: cs.onPrimary.withValues(alpha: 0.5)),
                          ),
                        ),
                      if (a.arrivalTime != null) ...[
                        Icon(Icons.flight_land_rounded, color: cs.onPrimary.withValues(alpha: 0.6), size: 13),
                        const SizedBox(width: DonySpacing.xs),
                        Text(
                          a.arrivalTime!,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onPrimary.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.04, curve: Curves.easeOutCubic),

          // Lieux de remise
          if (a.departureLocation != null || a.arrivalLocation != null) ...[
            const SizedBox(height: DonySpacing.md),
            Container(
              padding: const EdgeInsets.all(DonySpacing.md),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.lg),
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lieux de remise',
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (a.departureLocation != null) ...[
                    const SizedBox(height: DonySpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_rounded, size: 14, color: cs.primary),
                        const SizedBox(width: DonySpacing.sm),
                        Expanded(
                          child: Text(
                            a.departureLocation!,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (a.arrivalLocation != null) ...[
                    const SizedBox(height: DonySpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: cs.error),
                        const SizedBox(width: DonySpacing.sm),
                        Expanded(
                          child: Text(
                            a.arrivalLocation!,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: 80.ms),
          ],

          const SizedBox(height: DonySpacing.base),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.scale_rounded,
                  label: 'Capacité dispo.',
                  value: '${a.availableKg.toStringAsFixed(1)} kg',
                  color: DonyColors.blue800,
                  cs: cs,
                  tt: tt,
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: _StatCard(
                  icon: Icons.euro_rounded,
                  label: 'Prix par kg',
                  value: '${a.pricePerKg.toStringAsFixed(2)} €',
                  color: cs.primary,
                  cs: cs,
                  tt: tt,
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: _StatCard(
                  icon: Icons.inbox_rounded,
                  label: 'Demandes',
                  value: '${a.bidsCount ?? 0}',
                  color: DonyColors.violet,
                  cs: cs,
                  tt: tt,
                ),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: DonySpacing.xxl),

          // Voir les demandes — toujours visible si le statut est ACTIVE
          if (a.status == 'ACTIVE') ...[
            DonyButton(
              label: 'Voir les demandes (${a.bidsCount ?? 0})',
              icon: Icons.inbox_rounded,
              onPressed: () => context.push('/announcements/${a.id}/bids'),
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: DonySpacing.md),
          ],

          if (canEdit) ...[
            DonyButton(
              label: 'Modifier ce trajet',
              icon: Icons.edit_rounded,
              variant: DonyButtonVariant.secondary,
              onPressed: () => context.push('/announcements/${a.id}/edit', extra: a),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: DonySpacing.md),
          ],

          if (!canDelete && a.status == 'ACTIVE') ...[
            DonyButton(
              label: 'Annuler ce trajet',
              icon: Icons.cancel_outlined,
              variant: DonyButtonVariant.destructive,
              onPressed: () => context.push('/announcements/${a.id}/cancel'),
            ).animate().fadeIn(delay: 250.ms),
            const SizedBox(height: DonySpacing.md),
          ],

          if (canDelete)
            DonyButton(
              label: 'Supprimer ce trajet',
              icon: Icons.delete_outline_rounded,
              variant: DonyButtonVariant.destructive,
              onPressed: () async {
                final confirmed = await _confirmDelete(isCancelled: isCancelled);
                if (confirmed && context.mounted) {
                  context.read<AnnouncementBloc>().add(
                    AnnouncementDeleteRequested(a.id),
                  );
                }
              },
            ).animate().fadeIn(delay: 300.ms),

          if (!canEdit && !canDelete && a.status != 'ACTIVE')
            Container(
              padding: const EdgeInsets.all(DonySpacing.md),
              decoration: BoxDecoration(
                color: DonyColors.warning50,
                borderRadius: BorderRadius.circular(DonyRadius.md),
                border: Border.all(color: DonyColors.amberLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: DonyColors.warning, size: 18),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Text(
                      'Ce trajet ne peut plus être modifié.',
                      style: tt.bodySmall?.copyWith(color: DonyColors.amberDark),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms),
        ],
      ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final ColorScheme cs;
  final TextTheme tt;
  const _StatusBadge({required this.status, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'ACTIVE'    => (cs.success, 'Actif'),
      'FULL'      => (cs.warning, 'Complet'),
      'COMPLETED' => (DonyColors.blue700, 'Terminé'),
      'CANCELLED' => (cs.error, 'Annulé'),
      _           => (cs.onSurfaceVariant, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
      decoration: BoxDecoration(
        color: cs.onPrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(DonyRadius.xl),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: tt.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onPrimary,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme cs;
  final TextTheme tt;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(DonySpacing.xs),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DonyRadius.sm),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            value,
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          Text(
            label,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
