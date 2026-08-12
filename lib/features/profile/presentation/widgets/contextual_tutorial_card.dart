import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

/// Carte compacte réutilisable qui suggère le tutoriel vidéo actif couvrant
/// [tutorialContext], si le catalogue distant en propose un pour ce point du
/// parcours (recherche, publication, négociation, paiement...).
///
/// `HelpCenterBloc` est fourni globalement (voir `lib/app/app.dart`) : ce
/// widget se contente de le lire, jamais de le fournir lui-même. Ne rend
/// rien si aucun tutoriel actif ne correspond, ou si l'utilisateur l'a déjà
/// fermée via le X — la fermeture est définitive et persistée par tutoriel
/// dans Hive. Ouvrir le tutoriel (tap sur la carte) ne la ferme pas.
///
/// L'onglet qui héberge cette carte (ex. Activités) reste monté en
/// permanence (`StatefulShellRoute.indexedStack`) : sans écoute réactive de
/// la clé Hive, un reset externe (Réglages › Réafficher les suggestions) ne
/// referait jamais réapparaître une carte déjà construite. D'où le
/// `ValueListenableBuilder` sur `HiveService.listenUserPrefs`, identique au
/// mécanisme d'`EvergreenGuidanceCarousel`.
class ContextualTutorialCard extends StatefulWidget {
  const ContextualTutorialCard({required this.context, super.key});

  /// Le point du parcours où cette carte est affichée.
  final TutorialContext context;

  @override
  State<ContextualTutorialCard> createState() =>
      _ContextualTutorialCardState();
}

class _ContextualTutorialCardState extends State<ContextualTutorialCard> {
  // Repli utilisé uniquement quand HiveService n'est pas enregistré (ex.
  // certains tests) : sans box à écouter, la fermeture ne peut durer que le
  // temps de vie de ce widget.
  bool _dismissedThisSession = false;

  String _dismissKey(String tutorialId) =>
      '${HiveService.kContextualTutorialDismissedPrefix}$tutorialId';

  bool get _hiveAvailable {
    try {
      return getIt.isRegistered<HiveService>();
    } catch (_) {
      return false;
    }
  }

  void _dismiss(String tutorialId) {
    if (_hiveAvailable) {
      unawaited(
        getIt<HiveService>().userPrefs.put(_dismissKey(tutorialId), true),
      );
    } else {
      setState(() => _dismissedThisSession = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.select<HelpCenterBloc, HelpCenterConfig>(
      (bloc) => switch (bloc.state) {
        HelpCenterSuccess(:final config) => config,
        HelpCenterError(:final config) => config,
        _ => HelpCenterConfig.empty,
      },
    );
    final tutorial = config.tutorialFor(widget.context);
    if (tutorial == null) {
      return const SizedBox.shrink();
    }

    if (!_hiveAvailable) {
      if (_dismissedThisSession) {
        return const SizedBox.shrink();
      }
      return _buildCard(context, tutorial);
    }

    final dismissKey = _dismissKey(tutorial.id);
    return ValueListenableBuilder<Box>(
      valueListenable: getIt<HiveService>().listenUserPrefs(
        keys: [dismissKey],
      ),
      builder: (context, box, _) {
        final dismissed = box.get(dismissKey, defaultValue: false) as bool;
        if (dismissed) {
          return const SizedBox.shrink();
        }
        return _buildCard(context, tutorial);
      },
    );
  }

  Widget _buildCard(BuildContext context, HelpTutorial tutorial) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    void openTutorial() {
      context.read<HelpCenterBloc>().add(
        HelpTutorialOpenRequested(
          tutorialId: tutorial.id,
          source: widget.context,
        ),
      );
      context.push('/profile/help/tutorial/${tutorial.id}');
    }

    return DonyCard(
          key: const Key('contextual-tutorial-card'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Besoin d’aide ? Voir le tutoriel ${tutorial.title}',
                    onTap: openTutorial,
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: openTutorial,
                        borderRadius: BorderRadius.circular(DonyRadius.card),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer,
                                borderRadius: BorderRadius.circular(
                                  DonyRadius.md,
                                ),
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('contextual-tutorial-card-dismiss'),
                  onPressed: () => _dismiss(tutorial.id),
                  tooltip: 'Masquer ce conseil',
                  visualDensity: VisualDensity.compact,
                  icon: DonyIcon('x', size: 16, color: cs.onSurfaceVariant),
                ),
              ],
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
