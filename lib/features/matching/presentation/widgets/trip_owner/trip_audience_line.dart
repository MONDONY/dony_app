import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/data/models/trip_audience_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Audience du trajet vue par son voyageur (`TripAudienceCubit`,
/// `GET /announcements/{id}/insights`) : combien de personnes l'ont vu dans
/// l'app, et combien de fois son affiche partagée a été consultée.
///
/// Elle n'a plus de place dans le corps de l'écran : « N personnes ont vu
/// votre trajet » est le sous-titre de la tuile « Affiche »
/// ([tileSubtitle]) et la ligne complète s'affiche dans son sheet
/// ([TripAudienceLine]). Le chargement reste fait par l'écran, pour le seul
/// propriétaire confirmé ([TripAudienceLoader]) : un visiteur n'appelle
/// jamais la route (404 côté back).
abstract final class TripAudience {
  /// L'audience est-elle utile pour ce statut ? Seulement tant que la tuile
  /// « Affiche » existe, qui est son seul affichage (ACTIVE, même règle que
  /// [canShareTripPoster]) : ailleurs (brouillon, complet, en cours, terminé,
  /// annulé, retiré par l'équipe) elle n'est pas chargée, pour éviter un appel
  /// inutile.
  static bool shownFor(String status) => status == 'ACTIVE';

  /// Morceaux de la ligne d'audience, dans l'ordre : personnes qui ont vu le
  /// trajet dans l'app, puis vues de l'affiche partagée.
  ///
  /// À 0 dans l'app, le nombre de personnes ne s'affiche que si l'affiche
  /// n'a pas été vue non plus (« Personne n'a encore vu votre trajet ») :
  /// « personne » contredirait les vues de l'affiche juste à côté.
  static List<String> parts(AppLocalizations l, TripAudienceModel audience) => [
    if (audience.uniqueViewerCount > 0 || audience.isEmpty)
      l.tripAudienceViewers(audience.uniqueViewerCount),
    if (audience.shareViewCount > 0)
      l.tripAudiencePosterViews(audience.shareViewCount),
  ];

  /// Sous-titre de la tuile « Affiche » d'après l'audience chargée : son
  /// premier morceau (« 12 personnes ont vu votre trajet », sinon les vues de
  /// l'affiche). `null` tant que rien n'est sûr (chargement, échec, ancien
  /// back, cubit absent) : la tuile garde alors son texte habituel.
  static String? tileSubtitle(AppLocalizations l, TripAudienceState? state) {
    final audience = state?.audience;
    if (state?.status != TripAudienceStatus.loaded || audience == null) {
      return null;
    }
    return parts(l, audience).first;
  }
}

/// Lance le chargement de l'audience du trajet [announcementId] tant que son
/// statut [status] lui donne un sens ([TripAudience.shownFor]) : au montage,
/// puis quand le trajet y entre (brouillon publié) ou change. Ne charge rien
/// sans `TripAudienceCubit` au-dessus. Rend [child] tel quel.
///
/// Posé par le corps de l'écran pour le seul propriétaire confirmé.
class TripAudienceLoader extends StatefulWidget {
  const TripAudienceLoader({
    super.key,
    required this.announcementId,
    required this.status,
    required this.child,
  });

  final String announcementId;
  final String status;
  final Widget child;

  @override
  State<TripAudienceLoader> createState() => _TripAudienceLoaderState();
}

class _TripAudienceLoaderState extends State<TripAudienceLoader> {
  @override
  void initState() {
    super.initState();
    if (TripAudience.shownFor(widget.status)) _load();
  }

  @override
  void didUpdateWidget(TripAudienceLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shown = TripAudience.shownFor(widget.status);
    final wasShown = TripAudience.shownFor(oldWidget.status);
    if (shown &&
        (!wasShown || oldWidget.announcementId != widget.announcementId)) {
      _load();
    }
  }

  void _load() =>
      maybeRead<TripAudienceCubit>(context)?.load(widget.announcementId);

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Ligne d'audience du sheet de la tuile « Affiche » : icône œil et
/// morceaux joints par « · » ([TripAudience.parts]), en texte discret, sans
/// carte. Ne rend rien tant que rien n'est sûr (chargement, échec, ancien
/// back) ni sans `TripAudienceCubit` au-dessus. Sans aucune vue, la ligne le
/// dit (« Personne n'a encore vu votre trajet »).
class TripAudienceLine extends StatelessWidget {
  const TripAudienceLine({super.key, this.padding = EdgeInsets.zero});

  /// Marge autour de la ligne, appliquée seulement quand elle s'affiche.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cubit = maybeRead<TripAudienceCubit>(context);
    if (cubit == null) return const SizedBox.shrink();
    return BlocBuilder<TripAudienceCubit, TripAudienceState>(
      bloc: cubit,
      builder: (context, state) {
        final audience = state.audience;
        if (state.status != TripAudienceStatus.loaded || audience == null) {
          return const SizedBox.shrink();
        }
        final tt = Theme.of(context).textTheme;
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: padding,
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
                  TripAudience.parts(context.l10n, audience).join(' · '),
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
