import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/tracking/bloc/suivi_cubit.dart';
import 'package:dony/features/tracking/presentation/widgets/qr_camera_view.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// En-tête maison de l'onglet Suivi : titre, aide (mode Valider), lampe
/// (caméra affichée), scarabée de signalement et, pour un voyageur, le
/// choix du mode.
///
/// [onDark] : posé au-dessus du flux caméra (texte blanc).
class SuiviHeader extends StatelessWidget {
  const SuiviHeader({
    super.key,
    required this.onDark,
    this.mode,
    this.onModeSelected,
    this.torchOn,
  });

  final bool onDark;

  /// Mode affiché ; `null` masque le sélecteur (utilisateur non voyageur).
  final SuiviMode? mode;
  final ValueChanged<SuiviMode>? onModeSelected;

  /// Lampe de la caméra ; `null` masque le bouton.
  final ValueNotifier<bool>? torchOn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = onDark ? DonyColors.neutral0 : cs.onSurface;
    final torch = torchOn;
    final current = mode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.xs,
        DonySpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    context.l10n.suiviTitle,
                    style: tt.headlineLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (current == SuiviMode.valider) SuiviHelpButton(onDark: onDark),
              if (torch != null) QrTorchButton(torchOn: torch),
              DonyFeedbackButton(color: onDark ? DonyColors.neutral0 : null),
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: DonySpacing.md),
            Padding(
              padding: const EdgeInsets.only(right: DonySpacing.md),
              child: SuiviModeTabs(
                mode: current,
                onDark: onDark,
                onSelected: onModeSelected ?? (_) {},
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// « ? » : tutoriel vidéo de la remise par QR. Rien si le catalogue du
/// Centre d'aide n'en propose pas.
class SuiviHelpButton extends StatelessWidget {
  const SuiviHelpButton({super.key, required this.onDark});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final tutorial = context.select<HelpCenterBloc, HelpTutorial?>(
      (bloc) => switch (bloc.state) {
        HelpCenterSuccess(:final config) => config,
        HelpCenterError(:final config) => config,
        _ => HelpCenterConfig.empty,
      }.tutorialFor(TutorialContext.qrHandover),
    );
    if (tutorial == null) return const SizedBox.shrink();
    final fg = onDark
        ? DonyColors.neutral0
        : Theme.of(context).colorScheme.onSurface;

    return IconButton(
      key: const Key('suivi-help'),
      tooltip: context.l10n.suiviHelpTooltip,
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      icon: DonyIcon('circle-help', color: fg, size: 20),
      onPressed: () {
        context.read<HelpCenterBloc>().add(
          HelpTutorialOpenRequested(
            tutorialId: tutorial.id,
            source: TutorialContext.qrHandover,
          ),
        );
        context.push('/profile/help/tutorial/${tutorial.id}');
      },
    );
  }
}

/// Sélecteur « Valider une étape » | « Suivre un colis ».
class SuiviModeTabs extends StatelessWidget {
  const SuiviModeTabs({
    super.key,
    required this.mode,
    required this.onDark,
    required this.onSelected,
  });

  final SuiviMode mode;
  final bool onDark;
  final ValueChanged<SuiviMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Semantics(
      container: true,
      label: l.suiviModeTabsLabel,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.xs),
        decoration: BoxDecoration(
          color: onDark
              ? DonyColors.neutral0.withValues(alpha: 0.12)
              : cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(DonyRadius.lg),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ModeTab(
                key: const Key('suivi-mode-valider'),
                label: l.suiviModeValidate,
                iconAsset: 'check',
                selected: mode == SuiviMode.valider,
                onDark: onDark,
                onTap: () => onSelected(SuiviMode.valider),
              ),
            ),
            Expanded(
              child: _ModeTab(
                key: const Key('suivi-mode-suivre'),
                label: l.suiviModeTrack,
                iconAsset: 'eye',
                selected: mode == SuiviMode.suivre,
                onDark: onDark,
                // Suivre n'est pas une action de validation : sur la caméra,
                // l'onglet actif passe en blanc, jamais en bleu primaire.
                neutralWhenSelected: true,
                onTap: () => onSelected(SuiviMode.suivre),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    super.key,
    required this.label,
    required this.iconAsset,
    required this.selected,
    required this.onDark,
    required this.onTap,
    this.neutralWhenSelected = false,
  });

  final String label;
  final String iconAsset;
  final bool selected;
  final bool onDark;
  final bool neutralWhenSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final Color bg;
    final Color fg;
    if (!selected) {
      bg = Colors.transparent;
      fg = onDark
          ? DonyColors.neutral0.withValues(alpha: 0.8)
          : cs.onSurfaceVariant;
    } else if (onDark && neutralWhenSelected) {
      bg = DonyColors.neutral0;
      fg = DonyColors.ink800;
    } else {
      bg = cs.primary;
      fg = cs.onPrimary;
    }

    return Semantics(
      selected: selected,
      button: true,
      child: DonyPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.sm,
            vertical: DonySpacing.xs,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DonyIcon(iconAsset, size: 16, color: fg),
              const SizedBox(width: DonySpacing.xs),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
