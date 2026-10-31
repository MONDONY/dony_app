import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Audience du trajet en une ligne discrète, sous les compteurs « Activité
/// du trajet » : combien de personnes l'ont vu dans l'app, et combien de
/// fois son affiche partagée a été consultée (`TripAudienceCubit`,
/// `tripAudienceViewers`, `tripAudiencePosterViews`), sans carte.
///
/// Monté seulement pour le propriétaire confirmé : c'est lui qui déclenche le
/// chargement, un visiteur n'appelle jamais la route (404 côté back). Rien
/// n'est affiché tant que rien n'est sûr (chargement, échec, ancien back).
/// Sans aucune vue, la ligne le dit (« Personne n'a encore vu votre trajet »).
/// Un trajet que les expéditeurs ne voient pas ou plus ([shownFor] faux) n'en
/// a pas.
class TripAudienceLine extends StatefulWidget {
  const TripAudienceLine({
    super.key,
    required this.announcementId,
    this.padding = EdgeInsets.zero,
  });

  final String announcementId;

  /// Marge autour de la ligne, appliquée seulement quand elle s'affiche.
  final EdgeInsetsGeometry padding;

  static const _hiddenStatuses = {'DRAFT', 'CANCELLED', 'REMOVED_BY_ADMIN'};

  /// L'audience a-t-elle un sens pour ce statut ? Non pour un brouillon
  /// (invisible des expéditeurs), un trajet annulé ou retiré par l'équipe.
  static bool shownFor(String status) => !_hiddenStatuses.contains(status);

  @override
  State<TripAudienceLine> createState() => _TripAudienceLineState();
}

class _TripAudienceLineState extends State<TripAudienceLine> {
  @override
  void initState() {
    super.initState();
    context.read<TripAudienceCubit>().load(widget.announcementId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripAudienceCubit, TripAudienceState>(
      builder: (context, state) {
        final audience = state.audience;
        if (state.status != TripAudienceStatus.loaded || audience == null) {
          return const SizedBox.shrink();
        }
        final l = context.l10n;
        final tt = Theme.of(context).textTheme;
        final cs = Theme.of(context).colorScheme;
        final parts = [
          // À 0 dans l'app, le nombre de personnes ne s'affiche que si
          // l'affiche n'a pas été vue non plus : « personne » contredirait
          // les vues de l'affiche juste à côté.
          if (audience.uniqueViewerCount > 0 || audience.isEmpty)
            l.tripAudienceViewers(audience.uniqueViewerCount),
          if (audience.shareViewCount > 0)
            l.tripAudiencePosterViews(audience.shareViewCount),
        ];
        return Padding(
          padding: widget.padding,
          child: Row(
            key: const Key('trip-audience-card'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: DonyIcon('eye', size: 16, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Text(
                  parts.join(' · '),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
