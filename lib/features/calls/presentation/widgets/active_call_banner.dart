import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/calls/bloc/active_call_holder.dart';
import 'package:dony/features/calls/bloc/call_bloc.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:dony/features/calls/presentation/widgets/call_timer.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Barre « appel en cours » en haut de l'app, au-dessus de toute route
/// (montée une seule fois dans `app.dart`, comme le bandeau réseau). Visible
/// quand un appel continue écran réduit ; un toucher y ramène (FLUTTER-DG).
class ActiveCallBanner extends StatelessWidget {
  const ActiveCallBanner({
    super.key,
    required this.holder,
    required this.onReturnToCall,
  });

  final ActiveCallHolder holder;
  final VoidCallback onReturnToCall;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CallBloc?>(
      valueListenable: holder.current,
      builder: (context, bloc, _) => ValueListenableBuilder<bool>(
        valueListenable: holder.callScreenVisible,
        builder: (context, screenVisible, _) {
          if (bloc == null || bloc.isClosed || screenVisible) {
            return const SizedBox.shrink();
          }
          return BlocBuilder<CallBloc, CallState>(
            bloc: bloc,
            builder: (context, state) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.topCenter,
                child: child,
              ),
              child: bloc.isLive
                  ? _ActiveCallBar(
                      key: const ValueKey('active-call-banner'),
                      state: state,
                      onTap: onReturnToCall,
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('active-call-banner-hidden'),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _ActiveCallBar extends StatelessWidget {
  const _ActiveCallBar({super.key, required this.state, required this.onTap});

  final CallState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    final current = state;
    final name = current is CallInProgress ? current.remoteName : '';
    final Widget status =
        current is CallInProgress &&
            current.phase == CallPhase.connected &&
            current.connectedAt != null
        ? CallTimer(since: current.connectedAt!, style: textStyle)
        : Text(
            current is CallInProgress && current.phase == CallPhase.ringing
                ? l.callStatusRinging
                : l.callStatusConnecting,
            style: textStyle,
          );
    return Semantics(
      button: true,
      label: l.callBannerReturnHint,
      child: Material(
        color: cs.success,
        child: InkWell(
          onTap: onTap,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.sm,
              ),
              child: Row(
                children: [
                  const DonyIcon('phone', size: 16, color: Colors.white),
                  const SizedBox(width: DonySpacing.sm),
                  Flexible(
                    child: Text(
                      name.isEmpty ? l.callBannerTitle : name,
                      style: textStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text(' · ', style: textStyle),
                  status,
                  const Spacer(),
                  Text(
                    l.callBannerReturn,
                    style: textStyle.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
