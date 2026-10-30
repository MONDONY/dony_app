import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

class AuthFlowBackground extends StatelessWidget {
  const AuthFlowBackground({super.key});

  static const imageAsset = 'assets/illustrations/auth-login-security.png';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          imageAsset,
          fit: BoxFit.cover,
          opacity: AlwaysStoppedAnimation(isLight ? 0.24 : 0.48),
          semanticLabel: context.l10n.authFlowIllustrationLabel,
        ),
        // Voile uni : lisibilité du formulaire posé sur l'illustration.
        ColoredBox(
          color: isLight
              ? Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9)
              : DonyColors.ink900.withValues(alpha: 0.8),
        ),
      ],
    );
  }
}

class AuthFlowHeader extends StatelessWidget {
  /// Tunnel pré-compte (téléphone, e-mail, code) : une pastille « n / total ».
  const AuthFlowHeader({
    super.key,
    required int this.current,
    required int this.total,
    required this.label,
    this.showBack = true,
  }) : _hasProgress = true;

  /// Écran après le code (« Faisons connaissance », pays) : le logo et le
  /// scarabée, sans pastille. Pas de retour : l'écran suit le code
  /// de vérification, revenir dessus n'a pas de sens.
  const AuthFlowHeader.plain({super.key})
    : current = null,
      total = null,
      label = '',
      showBack = false,
      _hasProgress = false;

  final int? current;
  final int? total;
  final String label;
  final bool showBack;

  final bool _hasProgress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (showBack)
              const DonyAppBarBackButton()
            else
              // Contrepoids du scarabée : le logo reste centré.
              const SizedBox(width: kDonyMinTapTarget),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(DonyRadius.full),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.46),
                    ),
                  ),
                  child: const Center(child: DonyLogo(fontSize: 24)),
                ),
              ),
            ),
            const Spacer(),
            const DonyFeedbackButton(),
          ],
        ),
        if (_hasProgress) ...[
          const SizedBox(height: DonySpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: DonyStepPill(current: current!, total: total!, label: label),
          ),
        ],
      ],
    );
  }
}

class AuthTrustBadge extends StatelessWidget {
  const AuthTrustBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(
          alpha: cs.brightness == Brightness.light ? 0.76 : 0.16,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('shield-check', size: 18, color: cs.success),
          const SizedBox(width: DonySpacing.xs),
          Flexible(
            child: Text(
              context.l10n.authFlowProtectedBadge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthIntroCard extends StatelessWidget {
  const AuthIntroCard({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.body,
    this.footnote,
  }) : compact = false;

  /// Variante du parcours d'onboarding : l'en-tête (icône + badge), le titre
  /// géant et les grands espacements du tunnel y mangeaient l'écran au point
  /// de repousser les boutons hors de vue (retour utilisateur). Icône et
  /// titre partagent une ligne, corps resserré — la carte redevient une
  /// introduction, pas un écran.
  const AuthIntroCard.compact({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.body,
    this.footnote,
  }) : compact = true;

  final String iconAsset;
  final String title;
  final String body;
  final String? footnote;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(compact ? DonySpacing.md : DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface.withValues(
          alpha: cs.brightness == Brightness.light ? 0.94 : 0.82,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.sheet),
        border: Border.all(color: cs.outline.withValues(alpha: 0.44)),
        boxShadow: DonyShadow.md,
      ),
      child: compact ? _buildCompact(cs, tt) : _buildFull(cs, tt),
    );
  }

  Widget _buildCompact(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                // Rayon concentrique : carte DonyRadius.sheet moins le
                // padding md — un rayon interne plus petit que l'externe.
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: Center(
                child: DonyIcon(iconAsset, size: 20, color: cs.primary),
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Text(
                title,
                style: tt.titleLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          body,
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        if (footnote != null) ...[
          const SizedBox(height: DonySpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyIcon('lock', size: 14, color: cs.success),
              const SizedBox(width: DonySpacing.xs),
              Expanded(
                child: Text(
                  footnote!,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFull(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(DonyRadius.card),
              ),
              child: Center(
                child: DonyIcon(iconAsset, size: 26, color: cs.primary),
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            const Expanded(child: AuthTrustBadge()),
          ],
        ),
        const SizedBox(height: DonySpacing.lg),
        Text(
          title,
          style: tt.displayLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w900,
            height: 1.06,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          body,
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.48,
          ),
        ),
        if (footnote != null) ...[
          const SizedBox(height: DonySpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyIcon('lock', size: 16, color: cs.success),
              const SizedBox(width: DonySpacing.xs),
              Expanded(
                child: Text(
                  footnote!,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Zone d'action du parcours d'onboarding : le bouton principal et le lien
/// « Passer pour l'instant », ancrés en bas de l'écran, au même endroit sur
/// tous les écrans.
///
/// C'est un contrat de position, pas un simple habillage (retour utilisateur :
/// des boutons tantôt au milieu, tantôt hors de vue selon la taille du
/// contenu). Chaque écran du parcours se structure en
/// `en-tête / Expanded(contenu défilant) / AuthFlowActions` : le contenu
/// défile, les actions ne bougent jamais.
///
/// [primary] est un slot et non un libellé : les écrans à état (identité,
/// paiements, parrainage) y placent leur bouton construit sous BlocBuilder ou
/// ValueListenableBuilder. `null` quand l'écran n'a pas d'action principale
/// (pays : choisir une suggestion navigue immédiatement) — le lien passer
/// reste alors seul, à la même hauteur que partout ailleurs.
class AuthFlowActions extends StatelessWidget {
  const AuthFlowActions({
    super.key,
    this.primary,
    this.onSkip,
    this.skipEnabled = true,
    this.skipLabel,
  });

  final Widget? primary;

  /// `null` quand **aucune** étape n'est à passer sur cet écran (l'identité
  /// ou les paiements ouverts depuis le profil, par exemple) : rien n'est
  /// affiché et le bouton principal reste tout en bas.
  final VoidCallback? onSkip;

  /// Passer est-il possible **en ce moment** ? Distinct de [onSkip] `null` :
  /// pendant un enregistrement l'action existe toujours, elle est seulement
  /// inerte — le bouton reste donc visible, grisé, plutôt que de disparaître
  /// et faire sauter la mise en page.
  final bool skipEnabled;

  /// Libellé du lien « passer ». `null` : « Passer pour l'instant » traduit.
  final String? skipLabel;

  @override
  Widget build(BuildContext context) {
    // « Passer » est un bouton bordé AU-DESSUS du bouton principal : le
    // principal est tout en bas, à portée du pouce, et « Passer » ne se perd
    // plus en petit lien gris sous lui (retours testeur FLUTTER-SA). Sans
    // « Passer », le principal reste en bas, au même endroit.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onSkip != null) ...[
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            label: skipLabel ?? context.l10n.authFlowSkipForNow,
            variant: DonyButtonVariant.secondary,
            onPressed: skipEnabled ? onSkip : null,
          ),
        ],
        if (primary != null) ...[
          const SizedBox(height: DonySpacing.sm),
          primary!,
        ],
      ],
    );
  }
}
