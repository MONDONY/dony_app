import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/app_update/bloc/app_update_banner_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bandeau de mise à jour douce, en tête du shell principal. Invisible tant
/// qu'aucune version plus récente n'est recommandée (`recommended_build`).
/// Contrairement à l'écran bloquant, l'utilisateur peut le fermer.
class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({super.key, this.cubit});

  /// Injectable pour les tests. Un Cubit fourni de l'extérieur reste à son
  /// propriétaire : le widget ne le ferme pas.
  final AppUpdateBannerCubit? cubit;

  @override
  Widget build(BuildContext context) {
    const view = _AppUpdateBannerView();
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<AppUpdateBannerCubit>.value(
        value: provided,
        child: view,
      );
    }
    return BlocProvider<AppUpdateBannerCubit>(
      create: (_) => getIt<AppUpdateBannerCubit>()..check(),
      child: view,
    );
  }
}

class _AppUpdateBannerView extends StatelessWidget {
  const _AppUpdateBannerView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppUpdateBannerCubit, bool>(
      builder: (context, visible) {
        if (!visible) return const SizedBox.shrink();
        final l = context.l10n;
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.md,
              DonySpacing.sm,
              DonySpacing.md,
              0,
            ),
            child: DonyStatusBanner(
              type: DonyStatusBannerType.info,
              title: l.appUpdateSoftTitle,
              message: l.appUpdateSoftMessage,
              onDismiss: () => context.read<AppUpdateBannerCubit>().dismiss(),
              action: GestureDetector(
                onTap: () => context.read<AppUpdateBannerCubit>().openStore(),
                child: Text(
                  l.appUpdateSoftAction,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: cs.primary),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
