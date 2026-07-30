import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/social_community_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Accès direct aux réseaux sociaux officiels Yadony, au même niveau que
/// « FAQ & aide » dans le menu Profil — sans passer par le hub FAQ.
///
/// `HelpCenterBloc` est fourni globalement (voir `lib/app/app.dart`) : cet
/// écran se contente de le lire, jamais de le fournir lui-même.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HelpCenterBloc, HelpCenterState>(
      builder: (context, state) {
        final config = switch (state) {
          HelpCenterSuccess(:final config) => config,
          HelpCenterError(:final config) => config,
          _ => HelpCenterConfig.empty,
        };
        final socialLinks = config.socialLinks
            .where((link) => link.active)
            .toList();

        return DonyPageScaffold(
          title: 'Réseaux sociaux',
          body: socialLinks.isEmpty
              ? const DonyEmptyState(
                  key: Key('community-empty-state'),
                  title: 'Aucun réseau pour le moment',
                  description:
                      'Nos espaces communautaires seront bientôt disponibles ici.',
                  mascotte: DonyMascotteType.assis,
                )
              : SocialCommunitySection(links: socialLinks),
        );
      },
    );
  }
}
