import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/calls/bloc/call_bloc.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:dony/features/calls/presentation/widgets/call_controls.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ce que l'écran d'appel affiche avant que l'appel ne soit connecté.
class CallScreenArgs {
  const CallScreenArgs({
    required this.remoteName,
    this.remoteAvatarUrl,
    this.conversationId,
    this.incomingCallId,
    this.acceptedNatively = false,
  });

  final String remoteName;
  final String? remoteAvatarUrl;

  /// Appel sortant : conversation depuis laquelle on appelle.
  final String? conversationId;

  /// Appel entrant : identifiant Stream de l'appel décroché.
  final String? incomingCallId;
  final bool acceptedNatively;

  /// Appel entrant décroché depuis CallKit ou la notification Android.
  factory CallScreenArgs.incoming(IncomingCall call) => CallScreenArgs(
    remoteName: call.callerName,
    remoteAvatarUrl: call.callerImageUrl,
    incomingCallId: call.callId,
    acceptedNatively: call.acceptedNatively,
  );

  /// Route d'un appel entrant, tout dans l'URL : elle peut ainsi attendre
  /// derrière le verrou PIN ou la connexion (porte des liens profonds) sans
  /// perdre ses détails, ce qu'un `extra` ne permet pas.
  static String incomingLocation(IncomingCall call) => Uri(
    path: '/calls/${call.callId}',
    queryParameters: {
      'name': call.callerName,
      'avatar': ?call.callerImageUrl,
      if (call.acceptedNatively) 'native': '1',
    },
  ).toString();

  /// Inverse de [incomingLocation]. Sans nom, la route ne vient pas d'un
  /// appel entrant : l'écran n'engage rien.
  factory CallScreenArgs.fromRoute(String callId, Map<String, String> query) {
    final name = query['name'];
    if (name == null) return const CallScreenArgs(remoteName: '');
    return CallScreenArgs(
      remoteName: name,
      remoteAvatarUrl: query['avatar'],
      incomingCallId: callId,
      acceptedNatively: query['native'] == '1',
    );
  }

  /// Ce que l'écran demande au [CallBloc] en s'ouvrant.
  CallEvent? get initialEvent {
    if (conversationId != null) {
      return CallStartRequested(conversationId!, remoteName);
    }
    if (incomingCallId != null) {
      return CallIncomingAcceptRequested(
        incomingCallId!,
        remoteName,
        acceptedNatively: acceptedNatively,
      );
    }
    return null;
  }
}

/// Écran plein écran d'un appel audio : nom, statut, chronomètre, et trois
/// commandes (micro, haut-parleur, raccrocher). Se ferme seul à la fin.
class CallScreen extends StatelessWidget {
  const CallScreen({
    super.key,
    required this.args,
    @visibleForTesting this.onClose,
  });

  final CallScreenArgs args;
  final VoidCallback? onClose;

  static const _closeDelay = Duration(milliseconds: 1500);

  void _close(BuildContext context) {
    if (onClose != null) {
      onClose!();
    } else if (context.canPop()) {
      context.pop();
    }
  }

  static bool _isTerminal(CallState state) =>
      state is CallEnded || state is CallFailure;

  static bool _isMicrophoneDenied(CallState state) =>
      state is CallFailure && state.error is CallPermissionDeniedException;

  /// Pendant un appel : raccrocher. Appel déjà terminé ou impossible : fermer.
  void _onHangUp(BuildContext context, CallState state) {
    if (state is CallStarting || state is CallInProgress) {
      context.read<CallBloc>().add(const CallHangUpRequested());
    } else {
      _close(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocConsumer<CallBloc, CallState>(
      // Une seule fermeture, même si une seconde fin arrive.
      listenWhen: (previous, current) =>
          _isTerminal(current) && !_isTerminal(previous),
      listener: (context, state) {
        // Micro refusé : l'écran reste ouvert pour guider vers les réglages.
        if (_isMicrophoneDenied(state)) return;
        if (state is CallFailure) {
          unawaited(ErrorPresenter.show(context, state.error));
        }
        Future<void>.delayed(_closeDelay, () {
          if (context.mounted) _close(context);
        });
      },
      builder: (context, state) {
        final inProgress = state is CallInProgress ? state : null;
        final name = inProgress?.remoteName ?? args.remoteName;
        return Scaffold(
          backgroundColor: cs.surface,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
              child: Column(
                children: [
                  _Avatar(name: name, url: args.remoteAvatarUrl),
                  const SizedBox(height: 20),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _StatusLine(state: state),
                  if (_isMicrophoneDenied(state)) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => unawaited(AppSettings.openAppSettings()),
                      child: Text(context.l10n.callOpenSettings),
                    ),
                  ],
                  const Spacer(),
                  CallControls(
                    muted: inProgress?.muted ?? false,
                    speakerOn: inProgress?.speakerOn ?? false,
                    enabled: inProgress != null,
                    onMute: () => context.read<CallBloc>().add(
                      const CallMuteToggleRequested(),
                    ),
                    onSpeaker: () => context.read<CallBloc>().add(
                      const CallSpeakerToggleRequested(),
                    ),
                    onHangUp: () => _onHangUp(context, state),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: 48,
      backgroundColor: cs.primaryContainer,
      foregroundImage: url == null ? null : NetworkImage(url!),
      child: Text(
        initial,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(color: cs.onPrimaryContainer),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final current = state;
    if (current is CallInProgress &&
        current.phase == CallPhase.connected &&
        current.connectedAt != null) {
      return _Timer(since: current.connectedAt!, style: style);
    }
    final text = switch (current) {
      CallInProgress(phase: CallPhase.ringing) => l.callStatusRinging,
      CallEnded(reason: 'rejected') => l.callStatusRejected,
      CallEnded(reason: 'missed') => l.callStatusMissed,
      CallEnded(reason: 'failed') => l.callStatusFailed,
      CallEnded() => l.callStatusEnded,
      CallFailure(error: CallPermissionDeniedException()) =>
        l.callMicrophoneDenied,
      CallFailure() => l.callStatusFailed,
      _ => l.callStatusConnecting,
    };
    return Text(text, style: style, textAlign: TextAlign.center);
  }
}

class _Timer extends StatelessWidget {
  const _Timer({required this.since, this.style});

  final DateTime since;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) {
        final elapsed = DateTime.now().difference(since);
        final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
        final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        return Text(
          '$minutes:$seconds',
          style: style?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}
