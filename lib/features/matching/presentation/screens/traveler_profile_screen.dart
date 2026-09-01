import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Charge une annonce par son identifiant, puis en présente le détail.
///
/// Cette route est la porte d'entrée de tout ce qui ne dispose que d'un
/// identifiant : notification d'un voyageur suivi, alerte corridor, carte de
/// « Mes abonnements », onglet Trajets d'une fiche voyageur.
///
/// Elle affichait auparavant un écran plein dédié, `TravelerProfileScreen`, qui
/// dupliquait la feuille ouverte depuis la recherche en moins complet : ni
/// entrée de négociation — alors que `announcement.negotiable` existe et est
/// servi par le backend —, ni mini-carte, ni signalement, ni état « vous avez
/// déjà un colis sur ce trajet ». L'écran a été supprimé ; ses deux apports
/// propres, l'avertissement « espèces uniquement » et le cœur des favoris, ont
/// été portés dans la feuille avant sa suppression.
class TravelerProfileLoaderScreen extends StatelessWidget {
  final String announcementId;
  const TravelerProfileLoaderScreen({super.key, required this.announcementId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<AnnouncementBloc>()
            ..add(AnnouncementDetailRequested(announcementId)),
      child: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (context, state) {
          if (state is AnnouncementInitial || state is AnnouncementLoading) {
            return const Scaffold(
              appBar: DonyAppBar(title: ''),
              body: DonyDetailSkeleton(),
            );
          }

          if (state is AnnouncementDetailLoaded) {
            return _AnnouncementSheetHost(announcement: state.announcement);
          }

          final description = state is AnnouncementError
              ? ErrorPresenter.resolve(state.error).message
              : 'Impossible de charger le détail';
          return Scaffold(
            appBar: const DonyAppBar(title: ''),
            body: DonyEmptyState(
              iconAsset: 'circle-alert',
              type: DonyEmptyStateType.error,
              mascotte: DonyMascotteType.erreurLegere,
              title: 'Erreur de chargement',
              description: description,
              actionLabel: 'Réessayer',
              onAction: () => context.read<AnnouncementBloc>().add(
                AnnouncementDetailRequested(announcementId),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Page d'accueil de la feuille de détail, quand on arrive par une route.
///
/// La feuille est modale : il lui faut une page dessous. Celle-ci l'ouvre à la
/// première frame et se referme quand la feuille se referme, si bien que le
/// retour ramène à l'écran d'où l'on venait, et non à une page vide.
class _AnnouncementSheetHost extends StatefulWidget {
  const _AnnouncementSheetHost({required this.announcement});

  final AnnouncementModel announcement;

  @override
  State<_AnnouncementSheetHost> createState() => _AnnouncementSheetHostState();
}

class _AnnouncementSheetHostState extends State<_AnnouncementSheetHost> {
  bool _ouverte = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ouvrir());
  }

  Future<void> _ouvrir() async {
    // Le BLoC peut réémettre l'état chargé (rafraîchissement) : sans ce garde,
    // une seconde feuille s'empilerait sur la première.
    if (_ouverte || !mounted) return;
    _ouverte = true;
    await showTravelerAnnouncementSheet(
      context,
      announcement: widget.announcement,
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Fond neutre le temps d'une frame, puis la feuille le recouvre.
    return const Scaffold(
      appBar: DonyAppBar(title: ''),
      body: SizedBox.shrink(),
    );
  }
}
