import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/owner_action_grid.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcels_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

const _biddableActiveStatuses = <String>{
  'ACCEPTED',
  'HANDED_OVER',
  'IN_TRANSIT',
};

bool _allActiveBidsInTransit(List<BidModel> bids) {
  final active = bids
      .where((b) => _biddableActiveStatuses.contains(b.status))
      .toList();
  return active.isNotEmpty && active.every((b) => b.status == 'IN_TRANSIT');
}

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

  /// Dernière annonce connue (chargée ou passée en `extra`) — sert de repli
  /// pour construire les [CreateTripArgs] quand le listener reçoit un state
  /// d'erreur (ex. [AnnouncementDepartureDatePassed]) qui ne porte pas le
  /// modèle complet.
  AnnouncementModel? _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
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
            if (state is AnnouncementDetailLoaded) {
              _current = state.announcement;
            } else if (state is AnnouncementUpdated) {
              _current = state.announcement;
            }
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
            } else if (state is AnnouncementPublished) {
              _current = state.announcement;
              context.read<AnnouncementBloc>().add(
                AnnouncementDetailRequested(widget.announcementId),
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (routeContext) => DonySuccessScreen(
                    mascotteType: DonyMascotteType.succes,
                    title: 'Trajet publié !',
                    subtitle:
                        'Ton trajet ${state.announcement.departureCity} → ${state.announcement.arrivalCity} est en ligne.',
                    ctaLabel: 'Continuer',
                    ctaVariant: DonyButtonVariant.accent,
                    onCta: () => Navigator.of(
                      routeContext,
                    ).pop(), // revient au détail, déjà rafraîchi
                    analyticsContext: 'trip_draft_published',
                    secondaryLabel: 'Partager mon trajet',
                    onSecondary: () => unawaited(
                      Share.share(
                        '✈️ Je voyage ${state.announcement.departureCity} → '
                        '${state.announcement.arrivalCity} le '
                        '${DateFormat('d MMMM', 'fr').format(state.announcement.departureDate)} '
                        'avec de la place dans mes bagages !\n'
                        'Réserve tes kilos sur Yadony 📦',
                        sharePositionOrigin: sharePositionOriginFor(
                          routeContext,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            } else if (state is AnnouncementKycRequired) {
              DonySnackbar.show(
                context,
                message: state.message,
                type: DonySnackbarType.warning,
              );
              context.push('/kyc/status');
            } else if (state is AnnouncementDepartureDatePassed) {
              DonySnackbar.show(
                context,
                message: state.message,
                type: DonySnackbarType.warning,
              );
              unawaited(_onDepartureDatePassed(context));
            } else if (state is AnnouncementProLimitReached) {
              unawaited(_onProLimitReached(context, state.message));
            } else if (state is AnnouncementError) {
              ErrorPresenter.show(context, state.error);
            }
          },
          builder: (context, state) {
            final a = state is AnnouncementDetailLoaded
                ? state.announcement
                : (_current ?? widget.initial);
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
                  if (a.status == 'DRAFT') ...[
                    const DonyStatusBanner(
                      type: DonyStatusBannerType.warning,
                      title: 'Ce trajet est un brouillon',
                      message:
                          'Il est invisible pour les expéditeurs tant qu\'il n\'est pas publié.',
                    ),
                    const SizedBox(height: DonySpacing.md),
                  ],
                  AnnouncementDetailBody(a: a),
                  const SizedBox(height: DonySpacing.lg),
                  OwnerActionGrid(a: a, isOwner: isOwner),
                  const SizedBox(height: DonySpacing.lg),
                  const TripParcelsSection(),
                  BlocBuilder<BidBloc, BidState>(
                    builder: (context, bidState) {
                      if (!isOwner || bidState is! BidListLoaded) {
                        return const SizedBox.shrink();
                      }
                      if (!_allActiveBidsInTransit(bidState.bids)) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: DonySpacing.md),
                        child: DonyButton(
                          label: 'Arrivé à destination',
                          onPressed: () => ArrivalInstructionsBottomSheet.show(
                            context,
                            announcementId: a.id,
                            initialInstructions: a.arrivalInstructions,
                          ),
                        ),
                      );
                    },
                  ),
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
    final currentUserId = authState.currentUserId;
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

  /// La date de départ est passée : publication refusée tant que
  /// l'utilisateur ne corrige pas la date. Ouvre directement l'édition.
  Future<void> _onDepartureDatePassed(BuildContext context) async {
    final current = _current;
    if (current == null) {
      return;
    }
    final changed = await context.push<bool>(
      '/trips/create',
      extra: CreateTripArgs(announcement: current),
    );
    if ((changed ?? false) && context.mounted) {
      context.read<AnnouncementBloc>().add(
        AnnouncementDetailRequested(widget.announcementId),
      );
    }
  }

  /// Limite mensuelle de trajets PRO atteinte — invite à passer PRO (pattern
  /// repris de [CreateTripScreen]).
  Future<void> _onProLimitReached(BuildContext context, String message) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Limite mensuelle atteinte',
      message: message,
      confirmLabel: 'Passer en PRO',
      cancelLabel: 'Plus tard',
    );
    if (confirmed == true && context.mounted) {
      unawaited(context.push('/profile/upgrade-to-pro'));
    }
  }
}
