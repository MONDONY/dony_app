import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/help_tutorial_card.dart';
import 'package:dony/features/profile/presentation/widgets/social_community_section.dart';
import 'package:dony/l10n/l10n.dart';
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
    final l = context.l10n;

    return BlocBuilder<HelpCenterBloc, HelpCenterState>(
      builder: (context, state) {
        final config = switch (state) {
          HelpCenterSuccess(:final config) => config,
          HelpCenterError(:final config) => config,
          _ => HelpCenterConfig.empty,
        };
        final tutorials =
            config.tutorials
                .where(
                  (tutorial) =>
                      tutorial.active &&
                      tutorial.appliesToLanguage(AppL10n.localeName),
                )
                .toList()
              ..sort((a, b) => a.order.compareTo(b.order));
        final guides = tutorials.where((t) => !t.isDemo).toList();
        final demos = tutorials.where((t) => t.isDemo).toList();
        final socialLinks = config.socialLinks
            .where((link) => link.active)
            .toList();

        return DonyPageScaffold(
          title: l.profileHelpCommunity,
          body: tutorials.isEmpty && socialLinks.isEmpty
              ? DonyEmptyState(
                  key: const Key('community-empty-state'),
                  title: l.communityEmptyTitle,
                  description: l.communityEmptyDescription,
                  mascotte: DonyMascotteType.assis,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (socialLinks.isNotEmpty) ...[
                      SocialCommunitySection(links: socialLinks),
                    ],
                    if (guides.isNotEmpty) ...[
                      if (socialLinks.isNotEmpty)
                        const SizedBox(height: DonySpacing.xxl),
                      _TutorialSection(
                        title: l.communityTutorialsTitle,
                        subtitle: l.communityTutorialsSubtitle,
                        tutorials: guides,
                      ),
                    ],
                    if (demos.isNotEmpty) ...[
                      if (socialLinks.isNotEmpty || guides.isNotEmpty)
                        const SizedBox(height: DonySpacing.xxl),
                      _TutorialSection(
                        title: l.communityDemosTitle,
                        subtitle: l.communityDemosSubtitle,
                        tutorials: demos,
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _TutorialSection extends StatelessWidget {
  const _TutorialSection({
    required this.title,
    required this.subtitle,
    required this.tutorials,
  });

  final String title;
  final String subtitle;
  final List<HelpTutorial> tutorials;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tt.titleLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          subtitle,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.base),
        ...List.generate(tutorials.length, (index) {
          final tutorial = tutorials[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == tutorials.length - 1 ? 0 : DonySpacing.base,
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
                context.push('/profile/help/tutorial/${tutorial.id}');
              },
            ),
          );
        }),
      ],
    );
  }
}
