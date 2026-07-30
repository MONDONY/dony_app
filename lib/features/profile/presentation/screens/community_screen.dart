import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/help_tutorial_card.dart';
import 'package:dony/features/profile/presentation/widgets/social_community_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Tutoriels vidéo et réseaux sociaux officiels Yadony, au même niveau que
/// « FAQ & aide » dans le menu Profil — sans passer par le hub FAQ.
///
/// `HelpCenterBloc` est fourni globalement (voir `lib/app/app.dart`) : cet
/// écran se contente de le lire, jamais de le fournir lui-même.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<HelpCenterBloc, HelpCenterState>(
      builder: (context, state) {
        final config = switch (state) {
          HelpCenterSuccess(:final config) => config,
          HelpCenterError(:final config) => config,
          _ => HelpCenterConfig.empty,
        };
        final tutorials =
            config.tutorials.where((tutorial) => tutorial.active).toList()
              ..sort((a, b) => a.order.compareTo(b.order));
        final socialLinks = config.socialLinks
            .where((link) => link.active)
            .toList();

        return DonyPageScaffold(
          title: 'Réseaux sociaux et tutoriels',
          body: tutorials.isEmpty && socialLinks.isEmpty
              ? const DonyEmptyState(
                  key: Key('community-empty-state'),
                  title: 'Aucun contenu pour le moment',
                  description:
                      'Nos tutoriels et espaces communautaires seront bientôt disponibles ici.',
                  mascotte: DonyMascotteType.assis,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (socialLinks.isNotEmpty) ...[
                      SocialCommunitySection(links: socialLinks),
                    ],
                    if (tutorials.isNotEmpty) ...[
                      if (socialLinks.isNotEmpty)
                        const SizedBox(height: DonySpacing.xxl),
                      Text(
                        'Tutoriels vidéo',
                        style: tt.titleLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xs),
                      Text(
                        'Apprends les parcours essentiels de Yadony.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.base),
                      ...List.generate(tutorials.length, (index) {
                        final tutorial = tutorials[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == tutorials.length - 1
                                ? 0
                                : DonySpacing.base,
                          ),
                          child: HelpTutorialCard(
                            tutorial: tutorial,
                            onTap: () {
                              context.read<HelpCenterBloc>().add(
                                HelpTutorialOpenRequested(
                                  tutorialId: tutorial.id,
                                  source: null,
                                ),
                              );
                              context.push(
                                '/profile/help/tutorial/${tutorial.id}',
                              );
                            },
                          ),
                        );
                      }),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
