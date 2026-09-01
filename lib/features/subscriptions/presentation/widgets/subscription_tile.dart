import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:dony/features/subscriptions/presentation/widgets/subscription_recency.dart';
import 'package:flutter/material.dart';

/// Carte d'un voyageur suivi.
///
/// Elle affiche en premier ce pour quoi on s'abonne — le dernier trajet publié
/// et son ancienneté — plutôt que la note et le nombre de trajets en cours, que
/// l'ancienne tuile mettait seuls en avant alors que le serveur servait déjà le
/// corridor et le prix.
class SubscriptionTile extends StatelessWidget {
  const SubscriptionTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onToggleBell,
    this.onOpenLastTrip,
    this.now,
  });

  final SubscriptionItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleBell;

  /// Ouvre le détail du dernier trajet. La carte a deux zones : le nom et
  /// l'avatar mènent au profil du voyageur, la ligne du trajet mène au trajet
  /// lui-même — sans quoi il fallait trois taps pour atteindre l'annonce que la
  /// carte affiche déjà.
  final VoidCallback? onOpenLastTrip;

  /// Injectée par les tests pour figer les libellés d'ancienneté.
  final DateTime? now;

  String get _tripsLabel => switch (item.ongoingTripsCount) {
    0 => 'Aucun trajet en cours',
    1 => '1 trajet en cours',
    final n => '$n trajets en cours',
  };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final last = item.lastAnnouncement;

    return Semantics(
      // Le « nouveau » est signalé visuellement par une pastille sur l'avatar :
      // sans ce label, un lecteur d'écran ne le percevrait pas du tout.
      label: item.hasNew ? 'Nouveau trajet publié par ${item.travelerName}' : null,
      child: DonyCard(
        onTap: onTap,
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvatarWithNewDot(item: item),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.travelerName,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isProAccount) ...[
                        const SizedBox(width: DonySpacing.xs),
                        const _ProTag(),
                      ],
                    ],
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  if (last != null)
                    _LastTripLine(
                      last: last,
                      highlight: item.hasNew,
                      travelerName: item.travelerName,
                      onOpen: onOpenLastTrip,
                    )
                  else
                    Text(
                      'Aucun trajet publié pour le moment',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: DonySpacing.xs),
                  _MetaLine(
                    rating: item.averageRating,
                    tripsLabel: _tripsLabel,
                    // La date de départ prime sur l'ancienneté de la
                    // publication : c'est elle qui décide si l'expéditeur peut
                    // confier son colis. L'ancienneté ne reste qu'en repli,
                    // le temps que le serveur serve le champ.
                    dateLabel: last == null
                        ? null
                        : (last.departureDate != null
                              ? 'Départ ${subscriptionDepartureLabel(last.departureDate!, now: now)}'
                              : subscriptionRecencyLabel(
                                  last.publishedAt,
                                  now: now,
                                )),
                  ),
                ],
              ),
            ),
            _BellButton(
              pushEnabled: item.pushEnabled,
              travelerName: item.travelerName,
              onPressed: onToggleBell,
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar surmonté d'une pastille quand le voyageur a publié depuis la dernière
/// visite. Remplace la rangée de « stories » : celle-ci sortait le voyageur de
/// la liste, donc de portée du balayage et de la cloche.
class _AvatarWithNewDot extends StatelessWidget {
  const _AvatarWithNewDot({required this.item});

  final SubscriptionItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatar = DonyAvatar(
      name: item.travelerName,
      imageUrl: item.avatarUrl,
      pro: item.isProAccount,
    );
    if (!item.hasNew) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: DonyColors.accent,
              shape: BoxShape.circle,
              // Liseré à la couleur de la carte : la pastille se détache même
              // posée sur le bord sombre d'une photo de profil.
              border: Border.all(color: cs.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProTag extends StatelessWidget {
  const _ProTag();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        'PRO',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Ligne du dernier trajet, cible tactile à part entière.
///
/// Elle se distingue de la carte qui la porte par un fond légèrement teinté et
/// un chevron : sans ces deux signes, rien n'annoncerait qu'un tap ici ne mène
/// pas au même endroit qu'un tap ailleurs sur la carte.
class _LastTripLine extends StatelessWidget {
  const _LastTripLine({
    required this.last,
    required this.highlight,
    required this.travelerName,
    this.onOpen,
  });

  final LastAnnouncement last;
  final bool highlight;
  final String travelerName;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final currency = SupportedCurrency.fromCodeOrDefault(last.currency);
    final price = CurrencyFormatter.format(
      last.pricePerKg,
      currency,
      compact: true,
    );
    final trajet = '${last.departureCity} → ${last.arrivalCity}';
    final style = tt.bodySmall?.copyWith(
      color: cs.onSurface,
      fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
    );

    final contenu = Row(
      children: [
        DonyIcon(
          'plane',
          size: 13,
          color: highlight ? DonyColors.accent : cs.onSurfaceVariant,
        ),
        const SizedBox(width: DonySpacing.xs),
        // Le corridor s'abrège, jamais le prix : c'est lui qu'on vient lire, et
        // « Marseille → Abidjan · 7 … » ne dit rien.
        Flexible(
          child: Text(
            trajet,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(' · ', style: style),
        Text(
          '$price/kg',
          style: style?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (onOpen != null) ...[
          const SizedBox(width: DonySpacing.xs),
          DonyIcon('chevron-right', size: 15, color: cs.onSurfaceVariant),
        ],
      ],
    );

    if (onOpen == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
        child: contenu,
      );
    }

    return Semantics(
      button: true,
      label: 'Voir le trajet $trajet de $travelerName',
      child: Material(
        color: highlight
            ? DonyColors.accent.withValues(alpha: 0.07)
            : cs.onSurface.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(DonyRadius.sm),
          child: Container(
            // 44 de haut : cible tactile minimale, imposée ici parce que la
            // ligne ne fait que 17px de texte.
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.sm,
              vertical: DonySpacing.xs,
            ),
            child: contenu,
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.rating,
    required this.tripsLabel,
    this.dateLabel,
  });

  final double? rating;
  final String tripsLabel;

  /// Date du trajet — départ si le serveur la sert, ancienneté de publication
  /// sinon. Elle vit ici plutôt qu'à côté du nom : en bout de première ligne,
  /// elle amputait le nom du voyageur, qui se lisait « Adama KAMAG… » sur un
  /// écran de 360 points.
  final String? dateLabel;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final style = tt.labelSmall?.copyWith(color: cs.onSurfaceVariant);

    return Row(
      children: [
        // La note n'apparaît que si elle existe : l'ancienne tuile affichait
        // « ⭐ - » pour un voyageur jamais noté, ce qui se lisait comme une
        // mauvaise note plutôt que comme une absence.
        if (rating != null) ...[
          DonyIcon('star', size: 12, color: cs.warning),
          const SizedBox(width: 3),
          Text(
            rating!.toStringAsFixed(1).replaceAll('.', ','),
            style: style?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(' · ', style: style),
        ],
        Flexible(
          child: Text(
            tripsLabel,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (dateLabel != null) ...[
          Text(' · ', style: style),
          Text(
            dateLabel!,
            style: style?.copyWith(
              // Chiffres à chasse fixe : sans quoi la valeur danse d'un pixel
              // à l'autre au rafraîchissement.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

/// Bascule des alertes push.
///
/// Le libellé dit « alertes push » et non « notifications » : couper la cloche
/// n'empêche pas le serveur d'inscrire le trajet dans le centre de
/// notifications, il supprime seulement l'envoi push.
class _BellButton extends StatelessWidget {
  const _BellButton({
    required this.pushEnabled,
    required this.travelerName,
    required this.onPressed,
  });

  final bool pushEnabled;
  final String travelerName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      toggled: pushEnabled,
      label: 'Alertes push de $travelerName',
      child: IconButton(
        tooltip: pushEnabled
            ? 'Couper les alertes push'
            : 'Activer les alertes push',
        onPressed: onPressed,
        icon: DonyIcon(
          pushEnabled ? 'bell' : 'bell-off',
          color: pushEnabled ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
