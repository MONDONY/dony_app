import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/connectivity/bloc/connectivity_cubit.dart';
import 'package:dony/features/connectivity/bloc/connectivity_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bandeau de statut réseau global façon Facebook/Messenger : invisible tant
/// que tout va bien, apparaît en haut de l'écran (monté une seule fois dans
/// `app.dart`, par-dessus toute route — shell ou pushée) dès que la connexion
/// est absente ou peu fiable, et confirme brièvement le retour à la normale
/// au lieu de disparaître en silence. C'est cette confirmation qui évite la
/// frustration : sans elle l'utilisateur ne sait jamais si c'est reparti.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        final config = _configFor(context, state);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: child,
          ),
          child: config == null
              ? const SizedBox.shrink(
                  key: ValueKey('connectivity-banner-hidden'),
                )
              : _ConnectivityBar(
                  key: ValueKey('connectivity-banner-${config.testId}'),
                  config: config,
                ),
        );
      },
    );
  }

  _BannerConfig? _configFor(BuildContext context, ConnectivityState state) {
    final cs = Theme.of(context).colorScheme;
    if (state.justReconnected) {
      return _BannerConfig(
        color: cs.success,
        iconName: 'wifi',
        label: 'Connexion rétablie',
        testId: 'reconnected',
      );
    }
    switch (state.status) {
      case ConnectivityStatus.offline:
        return _BannerConfig(
          color: cs.error,
          iconName: 'wifi-off',
          label: 'Pas de connexion internet',
          testId: 'offline',
        );
      case ConnectivityStatus.weak:
        return _BannerConfig(
          color: cs.warning,
          iconName: 'triangle-alert',
          label: 'Connexion instable',
          testId: 'weak',
        );
      case ConnectivityStatus.online:
        return null;
    }
  }
}

class _BannerConfig {
  const _BannerConfig({
    required this.color,
    required this.iconName,
    required this.label,
    required this.testId,
  });

  final Color color;
  final String iconName;
  final String label;
  final String testId;
}

class _ConnectivityBar extends StatelessWidget {
  const _ConnectivityBar({super.key, required this.config});

  final _BannerConfig config;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: config.color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DonyIcon(config.iconName, size: 14, color: Colors.white),
              const SizedBox(width: DonySpacing.xs),
              Flexible(
                child: Text(
                  config.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
