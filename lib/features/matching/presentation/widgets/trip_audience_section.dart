import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Audience du trajet sur l'écran du voyageur : combien de personnes l'ont vu
/// dans l'app, et combien de fois son affiche partagée a été consultée.
///
/// Monté seulement pour le propriétaire confirmé : c'est lui qui déclenche le
/// chargement, un visiteur n'appelle donc jamais la route (404 côté back).
/// Rien n'est affiché tant que rien n'est sûr : chargement, échec, ancien back.
/// Sans aucune vue, la carte le dit (« Personne n'a encore vu ton trajet ») :
/// le voyageur sait que le compteur existe.
class TripAudienceSection extends StatefulWidget {
  const TripAudienceSection({super.key, required this.announcementId});

  final String announcementId;

  @override
  State<TripAudienceSection> createState() => _TripAudienceSectionState();
}

class _TripAudienceSectionState extends State<TripAudienceSection> {
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
        return Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.lg),
          child: DonyCard(
            key: const Key('trip-audience-card'),
            child: Row(
              children: [
                const DonyIconContainer(
                  iconAsset: 'eye',
                  size: DonyIconContainerSize.sm,
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // À 0 dans l'app, la ligne ne s'affiche que si l'affiche
                      // n'a pas été vue non plus : « personne » contredirait
                      // les vues de l'affiche juste en dessous.
                      if (audience.uniqueViewerCount > 0 || audience.isEmpty)
                        Text(
                          l.tripAudienceViewers(audience.uniqueViewerCount),
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (audience.shareViewCount > 0)
                        Text(
                          l.tripAudiencePosterViews(audience.shareViewCount),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
