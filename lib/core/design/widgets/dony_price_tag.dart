import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';

/// Étiquette de bagage — représentation d'un article tarifé de la grille
/// voyageur.
///
/// Direction visuelle « étiquettes de bagage » : œillet à gauche, ligne
/// perforée, prix tamponné dans un pavé plein. Le même widget sert au profil
/// (taille normale), dans le formulaire de trajet et dans la feuille de
/// sélection côté expéditeur (taille [compact]), afin qu'on reconnaisse le
/// même objet d'un écran à l'autre plutôt qu'une copie redessinée.
///
/// Le widget ne résout pas l'emoji lui-même : `emojiForLabel` appartient à la
/// feature `content_categories`, et le design system ne dépend d'aucune
/// feature. L'appelant le passe.
class DonyPriceTag extends StatelessWidget {
  const DonyPriceTag({
    super.key,
    required this.label,
    required this.emoji,
    required this.price,
    this.caption,
    this.compact = false,
    this.highlighted = false,
    this.onTap,
    this.trailing,
    this.semanticLabel,
  });

  /// Nom de l'article, tel qu'il sera lu par l'expéditeur.
  final String label;

  /// Emoji de catégorie, résolu par l'appelant.
  final String emoji;

  /// Prix affiché, déjà formaté et déjà converti dans la devise voulue.
  /// C'est le montant payé par l'expéditeur, commission comprise.
  final String price;

  /// Ligne secondaire, typiquement « vous recevez 12,00 € ». Masquée en mode
  /// [compact], où la place manque et où le net n'est pas l'information utile.
  final String? caption;

  /// Format réduit, utilisé partout où l'étiquette n'est qu'un rappel :
  /// aperçu dans le formulaire de trajet, liste côté expéditeur.
  final bool compact;

  /// Met l'étiquette en avant : bordure et tampon passent en couleur primaire.
  final bool highlighted;

  final VoidCallback? onTap;

  /// Élément de fin, après le prix — menu d'options, sélecteur de quantité.
  final Widget? trailing;

  /// Remplace l'annonce par défaut, qui énonce l'article puis son prix.
  final String? semanticLabel;

  /// Silhouette de l'étiquette : accrochée par la gauche, donc coin gauche
  /// presque droit et coins droits arrondis. Partagée par la décoration et par
  /// le ripple, qui déborderait du cadre si les deux divergeaient.
  static const _shape = BorderRadius.horizontal(
    left: Radius.circular(DonyRadius.xs + 1),
    right: Radius.circular(DonyRadius.card),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final borderColor = highlighted ? cs.primary : cs.outline;
    final stampColor = highlighted ? cs.primary : cs.onSurface;
    final stampInk = highlighted ? cs.onPrimary : cs.surface;
    final titleStyle = compact ? tt.titleMedium : tt.titleLarge;

    final stamp = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? DonySpacing.sm : DonySpacing.sm + 2,
        vertical: compact ? DonySpacing.xs : DonySpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: stampColor,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Text(
        price,
        style: titleStyle?.copyWith(
          color: stampInk,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    // Un sélecteur de quantité en fin de ligne ne laisse plus assez de place
    // au nom de l'article sur un écran étroit : « Alimentation sèche » se
    // réduit à « Alimentati… ». Le prix descend alors sous le libellé, qui
    // récupère toute la largeur.
    final stackPrice = compact && trailing != null;

    final tag = Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 24 : 28,
        compact ? DonySpacing.sm + 2 : DonySpacing.md,
        compact ? DonySpacing.md : DonySpacing.base,
        compact ? DonySpacing.sm + 2 : DonySpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: _shape,
        border: Border.all(color: borderColor, width: highlighted ? 1.5 : 1),
        boxShadow: [
          // Ombre franche, sans flou : du papier posé, pas une carte qui
          // flotte. C'est ce décalage net qui porte la direction.
          BoxShadow(
            color: (highlighted ? cs.primary : cs.onSurface).withValues(
              alpha: highlighted ? 0.22 : 0.09,
            ),
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: compact ? 15 : 19)),
              const SizedBox(width: DonySpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: titleStyle?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (stackPrice) ...[
                      const SizedBox(height: DonySpacing.xs + 1),
                      stamp,
                    ],
                  ],
                ),
              ),
              if (!stackPrice) ...[
                const SizedBox(width: DonySpacing.sm),
                stamp,
              ],
              if (trailing != null) ...[
                const SizedBox(width: DonySpacing.sm),
                trailing!,
              ],
            ],
          ),
          // La légende occupe toute la largeur, sous la ligne principale.
          // Logée dans la colonne du libellé, elle se réduisait à
          // « vous recevez 1… » : le prix et le menu ne lui laissaient qu'une
          // centaine de points.
          if (caption != null && !compact) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              caption!,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    // L'œillet et la perforation sont posés par-dessus le fond de l'étiquette,
    // sur la marge gauche réservée par le padding.
    final withPunch = Stack(
      children: [
        tag,
        Positioned(
          left: compact ? 8 : 9,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              width: compact ? 8 : 10,
              height: compact ? 8 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: cs.onSurface.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: compact ? 18 : 21,
          top: DonySpacing.sm,
          bottom: DonySpacing.sm,
          child: CustomPaint(
            size: const Size(1.5, double.infinity),
            painter: _PerforationPainter(cs.onSurface.withValues(alpha: 0.18)),
          ),
        ),
      ],
    );

    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel ?? '$label, $price',
      excludeSemantics: trailing == null,
      child: onTap == null
          ? withPunch
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: _shape,
                child: withPunch,
              ),
            ),
    );
  }
}

/// Ligne pointillée verticale, la perforation détachable de l'étiquette.
class _PerforationPainter extends CustomPainter {
  const _PerforationPainter(this.color);

  final Color color;

  static const double _dash = 3;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (double y = 0; y < size.height; y += _dash + _gap) {
      final end = (y + _dash).clamp(0.0, size.height);
      canvas.drawLine(Offset(0.75, y), Offset(0.75, end), paint);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter oldDelegate) =>
      oldDelegate.color != color;
}
