import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Carte compacte réutilisable qui suggère le tutoriel vidéo actif couvrant
/// [context], si le catalogue distant en propose un pour ce point du
/// parcours (recherche, publication, négociation, paiement...).
///
/// `HelpCenterBloc` est fourni globalement (voir `lib/app/app.dart`) : ce
/// widget se contente de le lire, jamais de le fournir lui-même. Ne rend
/// rien si aucun tutoriel actif ne correspond.
class ContextualTutorialCard extends StatelessWidget {
  const ContextualTutorialCard({required this.context, super.key});

  /// Le point du parcours où cette carte est affichée.
  final TutorialContext context;

  @override
  Widget build(BuildContext context) {
    final config = context.select<HelpCenterBloc, HelpCenterConfig>(
      (bloc) => switch (bloc.state) {
        HelpCenterSuccess(:final config) => config,
        HelpCenterError(:final config) => config,
        _ => HelpCenterConfig.empty,
      },
    );
    final tutorial = config.tutorialFor(this.context);
    if (tutorial == null) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    void openTutorial() {
      context.read<HelpCenterBloc>().add(
        HelpTutorialOpenRequested(
          tutorialId: tutorial.id,
          source: this.context,
        ),
      );
      context.push('/profile/help/tutorial/${tutorial.id}');
    }

    return Semantics(
          button: true,
          label: 'Besoin d’aide ? Voir le tutoriel ${tutorial.title}',
          onTap: openTutorial,
          child: ExcludeSemantics(
            child: DonyCard(
              key: const Key('contextual-tutorial-card'),
              onTap: openTutorial,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                      ),
                      child: Center(
                        child: DonyIcon(
                          'circle-play',
                          size: 22,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Text(
                        'Besoin d\'aide ? Voir le tutoriel',
                        style: tt.titleSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: DonySpacing.xs),
                    DonyIcon(
                      'chevron-right',
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: DonyDuration.slow, curve: DonyCurve.enter)
        .slideY(
          begin: 0.04,
          duration: DonyDuration.slow,
          curve: DonyCurve.enter,
        );
  }
}
