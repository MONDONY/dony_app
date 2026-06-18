import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/open_surplus_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
          return AnnouncementDetailBody(a: state.announcement);
        }

        return const SizedBox();
      },
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

