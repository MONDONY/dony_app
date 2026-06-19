import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/owner_action_grid.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcels_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran plein écran « Trajet » côté propriétaire (voyageur).
///
/// Bouton retour + bouton de signalement de bug dans l'AppBar, puis, dans l'ordre :
/// le détail complet du trajet via [AnnouncementDetailBody], la grille d'actions
/// [OwnerActionGrid] (Demandes / Colis / Modifier / Supprimer) et la section des
/// colis déjà embarqués [TripParcelsSection].
class TripOwnerDetailScreen extends StatefulWidget {
  const TripOwnerDetailScreen({
    super.key,
    required this.announcementId,
    this.initial,
  });

  /// Identifiant du trajet — sert au rechargement via [AnnouncementBloc].
  final String announcementId;

  /// Annonce passée en `extra` au moment de la navigation. Permet un premier
  /// rendu instantané pendant que le détail complet se recharge.
  final AnnouncementModel? initial;

  @override
  State<TripOwnerDetailScreen> createState() => _TripOwnerDetailScreenState();
}

class _TripOwnerDetailScreenState extends State<TripOwnerDetailScreen> {
  /// Clé du [RepaintBoundary] enveloppant l'écran — capture d'écran du bouton bug.
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.tripOwnerDetailOpened,
          properties: {'status': widget.initial?.status ?? 'unknown'},
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DonyAppBar(
        title: 'Trajet',
        actions: [DonyFeedbackButton(repaintBoundaryKey: _boundaryKey)],
      ),
      body: RepaintBoundary(
        key: _boundaryKey,
        child: BlocConsumer<AnnouncementBloc, AnnouncementState>(
          listener: (context, state) {
            if (state is AnnouncementDeleted) {
              DonySnackbar.show(
                context,
                message: 'Trajet supprimé',
                type: DonySnackbarType.success,
              );
              if (context.mounted) {
                context.pop(true);
              }
            } else if (state is AnnouncementNotFound) {
              DonySnackbar.show(
                context,
                message: 'Cette annonce n\'existe plus',
                type: DonySnackbarType.warning,
              );
              if (context.mounted) {
                context.pop(true);
              }
            } else if (state is AnnouncementDeleteBlockedByAcceptedBid) {
              unawaited(_onDeleteBlocked(context, state.announcementId));
            } else if (state is AnnouncementError) {
              ErrorPresenter.show(context, state.error);
            }
          },
          builder: (context, state) {
            final a = state is AnnouncementDetailLoaded
                ? state.announcement
                : widget.initial;
            if (a == null) {
              return Center(
                child: CircularProgressIndicator(color: cs.primary),
              );
            }
            final isOwner = _isOwner(context, a);
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.md,
                DonySpacing.lg,
                DonySpacing.lg + safeBottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnnouncementDetailBody(a: a),
                  const SizedBox(height: DonySpacing.lg),
                  OwnerActionGrid(
                    a: a,
                    isOwner: isOwner,
                  ),
                  const SizedBox(height: DonySpacing.lg),
                  const TripParcelsSection(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Détermine si l'utilisateur courant est le voyageur propriétaire du trajet.
  ///
  /// Lit l'`AuthBloc` global (fourni par l'app, instance unique). En l'absence
  /// d'utilisateur authentifié — ou si le provider n'est pas dans l'arbre —
  /// considère que ce n'est pas le propriétaire (sécurité non-propriétaire).
  bool _isOwner(BuildContext context, AnnouncementModel a) {
    AuthState authState;
    try {
      authState = context.read<AuthBloc>().state;
    } catch (_) {
      return false;
    }
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : null;
    return currentUserId != null && a.travelerId == currentUserId;
  }

  /// Suppression bloquée par un colis déjà accepté — propose l'annulation du
  /// voyage.
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
      await CancellationBottomSheet.show(
        context,
        announcementId: announcementId,
      );
    }
  }
}
