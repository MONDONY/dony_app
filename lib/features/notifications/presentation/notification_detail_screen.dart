import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/notifications/bloc/notification_detail_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// L'écran de détail générique d'une notification : titre, date et texte
/// complet. Il ne sert qu'aux lignes sans deeplink, les annonces plateforme,
/// dont le texte n'existe nulle part ailleurs dans l'app. Une notification
/// actionnable ne passe jamais ici : son écran cible porte déjà le texte.
class NotificationDetailScreen extends StatelessWidget {
  final String id;
  const NotificationDetailScreen({super.key, required this.id});

  static String routeFor(String id) => '/notifications/$id';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<NotificationDetailCubit>()..load(id),
      child: _NotificationDetailView(id: id),
    );
  }
}

class _NotificationDetailView extends StatelessWidget {
  final String id;
  const _NotificationDetailView({required this.id});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: const DonyAppBarBackButton(),
        title: BlocBuilder<NotificationDetailCubit, NotificationDetailState>(
          builder: (context, state) => Text(
            state is NotificationDetailLoaded &&
                    state.detail.category == 'annonce'
                ? 'Annonce Yadony'
                : 'Notification',
            style: tt.headlineLarge,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cs.outline, height: 1),
        ),
      ),
      body: BlocBuilder<NotificationDetailCubit, NotificationDetailState>(
        builder: (context, state) => switch (state) {
          NotificationDetailLoading() => Center(
            child: CircularProgressIndicator(color: cs.primary),
          ),
          NotificationDetailError() => DonyEmptyState(
            mascotte: DonyMascotteType.erreurLegere,
            type: DonyEmptyStateType.error,
            iconAsset: 'wifi-off',
            title: 'Notification introuvable',
            description:
                'Elle a peut-être été supprimée, ou le réseau est indisponible.',
            actionLabel: 'Réessayer',
            onAction: () => context.read<NotificationDetailCubit>().load(id),
          ),
          NotificationDetailLoaded(:final detail) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.huge + MediaQuery.of(context).viewPadding.bottom,
            ),
            child:
                Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.title,
                          style: tt.headlineMedium?.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: DonySpacing.sm),
                        Text(
                          DateFormat(
                            "d MMMM yyyy 'à' HH:mm",
                            'fr',
                          ).format(detail.createdAt.toLocal()),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: DonySpacing.xl),
                        SelectableText(
                          detail.text,
                          style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ),
        },
      ),
    );
  }
}
