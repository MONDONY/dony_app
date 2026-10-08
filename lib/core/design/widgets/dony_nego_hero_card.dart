import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Carte héros d'un fil de négociation : dégradé de statut, montant mis en
/// valeur, pastille de statut et progression des tours.
///
/// Partagée par les deux fils de prix (demande de colis et trajet). Elle ne
/// connaît aucun modèle : chaque fil lui passe ses propres libellés et son
/// propre montant. Les deux fils ne montrent pas le même chiffre (le voyageur
/// lit son net, l'expéditeur le brut) et ce choix reste chez l'appelant.
class DonyNegoHeroCard extends StatelessWidget {
  const DonyNegoHeroCard({
    super.key,
    required this.gradient,
    required this.shadowColor,
    required this.iconAsset,
    required this.caption,
    required this.amount,
    required this.badgeLabel,
    required this.roundLabel,
    required this.roundsCount,
    required this.maxRounds,
    this.amountKey,
    this.warning,
    this.turnLabel,
    this.myTurn = false,
    this.margin = const EdgeInsets.fromLTRB(
      DonySpacing.base,
      DonySpacing.md,
      DonySpacing.base,
      DonySpacing.sm,
    ),
  });

  final LinearGradient gradient;

  /// Couleur de l'ombre portée, celle du statut.
  final Color shadowColor;
  final String iconAsset;

  /// Libellé au-dessus du montant (« PRIX ACTUEL », « Vous paieriez »).
  final String caption;

  /// Montant déjà formaté, devise comprise.
  final String amount;
  final Key? amountKey;
  final String badgeLabel;

  /// Libellé des tours (« Round 2/5 », « Tour 2 sur 6 »).
  final String roundLabel;
  final int roundsCount;

  /// Nombre de segments de la jauge. 0 (serveur ancien) : jauge masquée.
  final int maxRounds;

  /// Avertissement sous la jauge (dernier tour), absent sinon.
  final String? warning;

  /// Qui doit jouer (« À vous de jouer »). Absent : aucune ligne.
  final String? turnLabel;

  /// La main est à l'utilisateur : la pastille de tour passe au plein.
  final bool myTurn;

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // Glow circle décoration top-right
          Positioned(
            top: -24,
            right: -24,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DonySpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DonySpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DonyIcon(iconAsset, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            caption,
                            style: tt.bodyMedium!.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.70),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            amount,
                            key: amountKey,
                            style: tt.bodyMedium!.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.1,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(label: badgeLabel),
                  ],
                ),
                const SizedBox(height: 14),
                _RoundProgress(
                  label: roundLabel,
                  roundsCount: roundsCount,
                  max: maxRounds,
                ),
                if (warning != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.20),
                      // Concentric with parent card (DonyRadius.card - padding)
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      warning!,
                      style: tt.bodyMedium?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade200,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ).animate().fadeIn(duration: 200.ms),
                ],
                if (turnLabel != null) ...[
                  const SizedBox(height: 10),
                  _TurnPill(label: turnLabel!, myTurn: myTurn),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _RoundProgress extends StatelessWidget {
  const _RoundProgress({
    required this.label,
    required this.roundsCount,
    required this.max,
  });
  final String label;
  final int roundsCount;
  final int max;

  @override
  Widget build(BuildContext context) {
    final n = max > 0 ? roundsCount.clamp(0, max) : 0;
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (int i = 0; i < max; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < n
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Pastille « qui doit jouer ». Pleine quand la main est à l'utilisateur,
/// translucide quand il attend : le contraste suffit à dire l'urgence, sans
/// animation en boucle (une boucle ferait tourner `pumpAndSettle` sans fin).
class _TurnPill extends StatelessWidget {
  const _TurnPill({required this.label, required this.myTurn});
  final String label;
  final bool myTurn;

  @override
  Widget build(BuildContext context) {
    final fg = myTurn ? DonyColors.ink800 : Colors.white;
    return Container(
      key: Key(myTurn ? 'nego-hero-my-turn' : 'nego-hero-their-turn'),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: DonySpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: myTurn ? Colors.white : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: myTurn ? DonyColors.terra500 : Colors.white70,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
