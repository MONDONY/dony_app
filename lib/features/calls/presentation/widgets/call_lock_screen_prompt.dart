import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/calls/bloc/call_lock_screen_cubit.dart';
import 'package:dony/features/calls/data/call_lock_screen_service.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Feuille « Ne manquez aucun appel » (FLUTTER-92), montrée une seule fois,
/// à l'ouverture d'une conversation où l'appel Yadony est possible, si un
/// réglage du téléphone masque les appels sur l'écran verrouillé.
abstract final class CallLockScreenPrompt {
  static Future<void> maybeShow(
    BuildContext context, {
    CallLockScreenCubit? cubit,
  }) async {
    final owned = cubit == null;
    final c = cubit ?? getIt<CallLockScreenCubit>();
    try {
      if (!await c.shouldPrompt() || !context.mounted) return;
      c.markPromptShown();
      await DonyBottomSheet.show<void>(
        context,
        title: context.l10n.callLockScreenTitle,
        child: BlocProvider.value(value: c, child: const _PromptBody()),
      );
    } finally {
      if (owned) unawaited(c.close());
    }
  }
}

class _PromptBody extends StatelessWidget {
  const _PromptBody();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final cubit = context.read<CallLockScreenCubit>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.lg,
        DonySpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _body(l, cubit.state.blocker),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.xl),
          DonyButton(
            key: const Key('call-lock-screen-open-settings'),
            label: l.callLockScreenOpenSettings,
            onPressed: () async {
              Navigator.of(context).pop();
              await cubit.openSettings(source: 'prompt');
            },
          ),
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            label: l.callLockScreenLater,
            variant: DonyButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

String _body(AppLocalizations l, LockScreenCallBlocker? blocker) =>
    blocker == LockScreenCallBlocker.manufacturer
    ? l.callLockScreenBodyManufacturer
    : l.callLockScreenBodyFullScreen;

/// Ligne de Réglages › Notifications : Android seulement, état relu à chaque
/// retour dans l'app (l'utilisateur revient des réglages système).
class CallLockScreenTile extends StatelessWidget {
  const CallLockScreenTile({super.key, this.cubit});

  /// Injecté par les tests ; sinon une instance GetIt.
  final CallLockScreenCubit? cubit;

  /// Android seulement (iOS passe par CallKit), et service d'appel câblé.
  static bool get isAvailable =>
      defaultTargetPlatform == TargetPlatform.android &&
      getIt.isRegistered<CallLockScreenCubit>();

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    const child = _CallLockScreenTileView();
    return provided != null
        ? BlocProvider.value(value: provided, child: child)
        : BlocProvider(
            create: (_) => getIt<CallLockScreenCubit>(),
            child: child,
          );
  }
}

class _CallLockScreenTileView extends StatefulWidget {
  const _CallLockScreenTileView();

  @override
  State<_CallLockScreenTileView> createState() =>
      _CallLockScreenTileViewState();
}

class _CallLockScreenTileViewState extends State<_CallLockScreenTileView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(context.read<CallLockScreenCubit>().load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<CallLockScreenCubit>().load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<CallLockScreenCubit, CallLockScreenState>(
      builder: (context, state) {
        if (!state.loaded || !state.supported) return const SizedBox.shrink();
        final blocked = state.blocked;
        // Plein écran refusé : avéré, en rouge. Xiaomi : seulement probable
        // (le réglage est illisible), simple rappel aux couleurs neutres.
        final denied = state.blocker == LockScreenCallBlocker.fullScreenIntent;
        return DonyListTile(
          key: const Key('call-lock-screen-tile'),
          iconAsset: 'phone',
          iconColor: denied ? cs.error : cs.primary,
          iconBgColor: denied ? cs.errorContainer : cs.primaryContainer,
          label: l.callLockScreenSettingsLabel,
          subtitle: blocked
              ? _body(l, state.blocker)
              : l.callLockScreenSettingsAllowed,
          trailing: blocked
              ? const DonyIcon('chevron-right', size: 18)
              : DonyIcon('circle-check', size: 18, color: cs.primary),
          showDivider: false,
          onTap: blocked
              ? () => unawaited(
                  context.read<CallLockScreenCubit>().openSettings(
                    source: 'settings',
                  ),
                )
              : null,
        );
      },
    );
  }
}
