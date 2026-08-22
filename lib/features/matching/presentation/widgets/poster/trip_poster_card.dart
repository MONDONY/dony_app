import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Affiche partageable d'un trajet, destinée à être capturée en PNG puis
/// postée par le voyageur sur ses propres canaux (Facebook, WhatsApp, TikTok).
///
/// **Couleurs figées, pas de tokens de thème.** Le rendu part en image : il doit
/// être identique que l'utilisateur soit en clair ou en sombre au moment de la
/// capture. Lire `Theme.of(context).colorScheme` produirait deux affiches
/// différentes pour le même trajet, ce qui casserait l'identité visuelle sur
/// les canaux du voyageur. Seule la famille typographique est reprise du thème,
/// elle ne dépend pas de la luminosité.
///
/// **Aucun numéro de téléphone.** Les affiches concurrentes en placardent deux à
/// quatre ; celle-ci n'en porte aucun. C'est cohérent avec le masquage du numéro
/// déjà en place côté profil, et c'est un argument en soi : le voyageur n'est
/// plus appelé à toute heure, les demandes arrivent qualifiées dans
/// l'application.
///
/// **Aucune URL non plus.** Une adresse écrite dans une image n'est cliquable
/// sur aucune plateforme, et personne ne recopie à la main 80 caractères
/// portant un UUID. Le lien vit dans la légende, que le voyageur colle dans le
/// texte de son post. L'image, elle, porte le mot-logo et les badges des deux
/// stores : de quoi savoir quoi chercher et où, même détachée de sa légende,
/// ce qui est le cas dès qu'elle est transférée en capture d'écran.
class TripPosterCard extends StatelessWidget {
  const TripPosterCard({super.key, required this.announcement});

  final AnnouncementModel announcement;

  /// Largeur logique de composition. La capture applique un `pixelRatio` de 3
  /// pour sortir 1080 x 1350, le format 4:5 du fil Facebook et Instagram.
  static const double logicalWidth = 360;
  static const double logicalHeight = 450;

  /// Formats de date construits une fois pour toute la classe : ils ne
  /// dépendent d'aucune donnée d'instance, et l'écran d'aperçu les réutilise
  /// pour composer sa légende, ce qui garantit que l'image et le texte du post
  /// annoncent la même chose.
  static final DateFormat dayFormat = DateFormat('EEEE d MMMM', 'fr');
  static final DateFormat deadlineFormat = DateFormat(
    "d MMMM 'à' HH'h'mm",
    'fr',
  );

  /// Badges officiels des deux plateformes, en français.
  ///
  /// Téléchargés depuis les ressources marketing d'Apple et de Google et
  /// embarqués tels quels : les deux exigent leur propre artwork, non modifié.
  /// Publics car l'écran d'aperçu doit les précharger avant de rastériser
  /// l'affiche.
  static const String appStoreBadgeAsset =
      'assets/logos/store/app-store-fr.png';
  static const String googlePlayBadgeAsset =
      'assets/logos/store/google-play-fr.png';

  /// Réduction maximale tolérée pour garder le corridor sur une seule ligne.
  ///
  /// En deçà, le titre de l'affiche deviendrait plus petit que les libellés qui
  /// le suivent, ce qui inverserait la hiérarchie de lecture. On passe alors sur
  /// deux lignes plutôt que de continuer à rapetisser.
  static const double _corridorMinScale = 0.8;
  static const double _corridorIconSize = 30;
  static const double _corridorGap = 12;

  /// Hauteur de rendu du badge Apple, qui n'a pas de marge intégrée.
  static const double _badgeHeight = 24;

  /// Part utile du badge Google : son PNG officiel réserve 23 % de sa hauteur
  /// à la zone de dégagement imposée par la charte. Sans ce facteur, rendu à
  /// la même hauteur qu'Apple, il paraîtrait nettement plus petit.
  static const double _googleBadgeContentRatio = 0.77;

  static const Color _ink = DonyColors.ink900;
  static const Color _blue = DonyColors.blue500;
  static const Color _terra = DonyColors.terra500;
  static const Color _paper = DonyColors.neutral0;
  static const Color _muted = DonyColors.neutral500;
  static const Color _line = DonyColors.neutral200;

  /// Capacité telle qu'elle doit être annoncée.
  ///
  /// `KG_FREE` signifie « pas de plafond déclaré » : `availableKg` n'est alors
  /// qu'une valeur de forme, et l'imprimer comme une limite tromperait
  /// l'expéditeur. Tout le reste de l'application dit « Kg libre » dans ce cas.
  static String capacityLabel(AnnouncementModel a) => a.isKgFree
      ? 'Kg libre'
      // formatKgPrice retire les décimales superflues ; sa sémantique est celle
      // d'un nombre, pas d'un prix.
      : '${formatKgPrice(a.availableKg)} kg';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final deadline = announcement.handoverDeadline;
    final pickup = announcement.pickupAddress?.label;
    final delivery = announcement.deliveryAddress?.label;

    return SizedBox(
      width: logicalWidth,
      height: logicalHeight,
      child: ColoredBox(
        color: _paper,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _wordmark(),
              const SizedBox(height: 14),
              _corridor(text),
              const SizedBox(height: 14),
              _InfoRow(
                label: 'Départ',
                value: dayFormat.format(announcement.departureDate),
                valueColor: _ink,
              ),
              const SizedBox(height: 8),
              // La date limite de dépôt est le vrai butoir commercial, pas la
              // date de départ : c'est elle qui déclenche la décision de
              // l'expéditeur. Toutes les affiches du marché la mettent en avant
              // en rouge, on garde ce code visuel.
              if (deadline != null) ...[
                _InfoRow(
                  label: 'Dernier dépôt',
                  value: deadlineFormat.format(deadline),
                  valueColor: _terra,
                ),
                const SizedBox(height: 8),
              ],
              _InfoRow(
                label: 'Place disponible',
                value: capacityLabel(announcement),
                valueColor: _ink,
              ),
              // Lieux de remise et de récupération. Les DTO allégés ne les
              // portent pas, d'où le test : une affiche sans adresse reste
              // valable, elle est simplement moins précise.
              if (pickup != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Remise',
                  value: pickup,
                  valueColor: _ink,
                  maxLines: 2,
                ),
              ],
              if (delivery != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Récupération',
                  value: delivery,
                  valueColor: _ink,
                  maxLines: 2,
                ),
              ],
              const Spacer(),
              _priceBlock(text),
              const SizedBox(height: 12),
              _footer(text),
            ],
          ),
        ),
      ),
    );
  }

  /// En-tête volontairement réduit à la seule marque.
  ///
  /// Le mot-logo officiel, et non un texte stylé : l'affiche circule hors de
  /// l'application, sur les canaux du voyageur, où elle est la seule
  /// représentation de la marque que verront des gens qui ne la connaissent pas
  /// encore. Une pastille d'accroche y a été essayée puis retirée, elle
  /// débordait dès que la police de rendu était plus large que prévu.
  ///
  /// [DonyLogo] fixe la hauteur et déduit la largeur du ratio (~3,7:1), donc la
  /// mise en page reste stable même si l'image n'est pas encore décodée. La
  /// capture, elle, exige qu'elle le soit : cf. le préchargement dans
  /// `TripPosterScreen`.
  Widget _wordmark() => const DonyLogo(fontSize: 30);

  /// Corridor : départ puis arrivée, séparés par l'avion qui pointe vers la
  /// droite, dans le sens de la lecture donc du voyage.
  ///
  /// **La disposition suit la longueur des noms.** Sur une ligne, le trajet se
  /// lit d'un coup d'œil, et c'est la forme retenue chaque fois qu'elle tient.
  /// Mais « MARSEILLE ✈ OUAGADOUGOU » est deux fois plus large que
  /// « PARIS ✈ DAKAR » : tout ramener de force sur une ligne le réduirait à la
  /// taille du corps de texte, et le corridor cesserait d'être le titre de
  /// l'affiche. Au-delà de [_corridorMinScale], on repasse donc sur deux
  /// lignes, où chaque ville dispose de toute la largeur.
  ///
  /// Jamais de troncature dans les deux cas : une ellipse amputerait un nom de
  /// ville et rendrait l'affiche inutilisable. On réduit, ou on réorganise.
  Widget _corridor(TextTheme text) {
    final style = (text.displayLarge ?? const TextStyle()).copyWith(
      fontSize: 34,
      height: 1.02,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.6,
      color: _ink,
    );

    final departure = announcement.departureCity.toUpperCase();
    final arrival = announcement.arrivalCity.toUpperCase();

    const available = logicalWidth - 44; // padding horizontal de la carte
    final oneLineWidth =
        _textWidth(departure, style) +
        _textWidth(arrival, style) +
        _corridorIconSize +
        _corridorGap * 2;

    // Le FittedBox réduit dans le rapport available/oneLineWidth : au-delà du
    // seuil, la ligne unique deviendrait illisible face au reste de l'affiche.
    final fitsOnOneLine = oneLineWidth <= available / _corridorMinScale;

    if (fitsOnOneLine) {
      return _corridorLine([
        Text(departure, style: style),
        const SizedBox(width: _corridorGap),
        _plane(),
        const SizedBox(width: _corridorGap),
        Text(arrival, style: style),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _corridorLine([Text(departure, style: style)]),
        _corridorLine([
          _plane(),
          const SizedBox(width: _corridorGap),
          Text(arrival, style: style),
        ]),
      ],
    );
  }

  /// Une ligne de corridor, mise à l'échelle si elle dépasse encore : un seul
  /// nom de ville peut à lui seul être trop large.
  Widget _corridorLine(List<Widget> children) => SizedBox(
    width: double.infinity,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );

  Widget _plane() => Transform.rotate(
    angle: math.pi / 2,
    child: const Icon(
      Icons.flight_rounded,
      size: _corridorIconSize,
      color: _blue,
    ),
  );

  /// Largeur rendue d'un texte, pour arbitrer la disposition avant de peindre.
  ///
  /// Un `LayoutBuilder` ne suffirait pas : il donne la place disponible, pas la
  /// place nécessaire. Le coût est celui d'une mise en page de quelques mots,
  /// une fois par ouverture d'écran.
  static double _textWidth(String value, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      // `intl` exporte lui aussi un TextDirection : sans le prefixe,
      // c'est le sien qui gagne et il n'a pas de membre `ltr`.
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Bloc prix, décliné selon le mode de tarification du trajet.
  ///
  /// Un trajet vendu à l'article n'a pas forcément de tarif au kilo : la
  /// colonne backend étant `NOT NULL`, le formulaire y écrit `0.0`, si bien
  /// qu'un affichage naïf annonçait « 0 € le kilo » sur l'affiche même. Le
  /// mode commande donc ce qui est mis en avant, et les deux tarifs coexistent
  /// quand le voyageur a réellement renseigné les deux.
  Widget _priceBlock(TextTheme text) {
    final currency = announcement.currency;
    final grid = announcement.cheapestGridPrice;
    final senderPricePerKg = announcement.senderPricePerKg;
    final hasKg = announcement.hasKgPrice;

    final String amount;
    final String unit;
    String? secondary;

    if (grid != null) {
      // « dès », parce qu'un prix de grille est un point d'entrée : c'est
      // l'article le moins cher, pas le tarif de tous les articles.
      amount = 'dès ${formatPriceIn(grid, currency)}';
      unit = "l'article";
      if (hasKg && senderPricePerKg != null) {
        secondary = '${formatPriceIn(senderPricePerKg, currency)} le kilo';
      }
    } else {
      // Garde sur hasKg (valeur > 0), pas sur la seule nullité :
      // senderPricePerKg n'est en pratique jamais null, c'est 0 la valeur
      // trompeuse à écarter (jamais de faux « 0 € »).
      amount = hasKg
          ? formatPriceIn(senderPricePerKg!, currency)
          : 'Prix indisponible';
      unit = 'le kilo';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mise à l'échelle plutôt que troncature : « 6 000 F CFA » est deux
          // fois plus large que « 8 € », et un prix coupé par une ellipse
          // serait pire qu'un prix légèrement plus petit. Le bloc reste lisible
          // quelle que soit la devise du corridor.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  // Prix expéditeur, commission comprise, dans la devise du
                  // trajet. `pricePerKg` seul est le net voyageur : l'afficher
                  // annoncerait un tarif que personne ne paie.
                  amount,
                  style: text.displayLarge?.copyWith(
                    fontSize: 36,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.4,
                    color: DonyColors.neutral0,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    unit,
                    style: text.titleMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DonyColors.blue50,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (secondary != null) ...[
            const SizedBox(height: 4),
            Text(
              secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: DonyColors.blue50,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Pied d'affiche : la promesse, puis où trouver l'application.
  ///
  /// L'URL publique n'y figure pas. Écrite dans une image elle n'est de toute
  /// façon pas cliquable, et un lecteur ne recopie pas 80 caractères portant un
  /// UUID. C'est la légende, elle, collable et cliquable, qui porte le lien.
  /// Les badges prennent le relais pour qui ne voit que l'image : ils disent
  /// quoi chercher, et où.
  Widget _footer(TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1, color: _line),
        const SizedBox(height: 8),
        Text(
          'Paiement sécurisé, suivi du colis, voyageurs vérifiés',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _muted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Artwork officiel des deux plateformes, repris tel quel : Apple et
            // Google interdisent de le redessiner ou de le retoucher. Le badge
            // Google embarque sa zone de dégagement obligatoire, qui occupe
            // 23 % de sa hauteur ; il est donc rendu plus haut que celui
            // d'Apple pour que les deux paraissent de la même taille.
            Image.asset(appStoreBadgeAsset, height: _badgeHeight),
            const SizedBox(width: 8),
            Image.asset(
              googlePlayBadgeAsset,
              height: _badgeHeight / _googleBadgeContentRatio,
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final Color valueColor;

  /// Les adresses saisies par le voyageur sont des adresses postales
  /// complètes : sur une seule ligne elles seraient tronquées au milieu du nom
  /// de rue, ce qui vaut moins que pas d'adresse du tout.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final wraps = maxLines > 1;
    return Row(
      // Une valeur sur deux lignes n'a pas de ligne de base commune avec son
      // libellé : on aligne alors par le haut, sinon la première ligne de
      // l'adresse remonte au-dessus du libellé.
      crossAxisAlignment: wraps
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.baseline,
      textBaseline: wraps ? null : TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: TripPosterCard._muted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge?.copyWith(
              fontSize: wraps ? 13 : 15,
              height: wraps ? 1.25 : null,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
