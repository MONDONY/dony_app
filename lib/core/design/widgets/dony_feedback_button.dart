import 'dart:async';
import 'dart:ui' as ui;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Bouton global de signalement de bug vers Sentry.
///
/// S'utilise dans les `actions` d'un AppBar :
/// ```dart
/// AppBar(actions: [DonyFeedbackButton()])
/// ```
///
/// En production, capture automatiquement l'écran (si [repaintBoundaryKey] est
/// fourni) et envoie un message + feedback à Sentry. En test, [onSubmitOverride]
/// remplace la logique Sentry pour permettre les tests unitaires.
class DonyFeedbackButton extends StatelessWidget {
  const DonyFeedbackButton({
    super.key,
    this.onSubmitOverride,
    this.repaintBoundaryKey,
  });

  /// Remplace `_submitToSentry` dans les tests.
  final Future<void> Function(String message)? onSubmitOverride;

  /// Clé d'un [RepaintBoundary] wrappant l'écran — utilisée pour la capture
  /// d'écran. Si null, la capture est ignorée.
  final GlobalKey? repaintBoundaryKey;

  // ── Analytics resolver ────────────────────────────────────────────────────

  static AnalyticsService Function()? _analyticsResolver;

  /// À appeler dans `injection.dart` après l'enregistrement d'[AnalyticsService].
  static void registerAnalyticsResolver(AnalyticsService Function() resolver) {
    _analyticsResolver = resolver;
  }

  // ── Screen capture ────────────────────────────────────────────────────────

  Future<Uint8List?> _captureScreen() async {
    if (repaintBoundaryKey == null) {
      return null;
    }
    try {
      final boundary = repaintBoundaryKey!.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        return null;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // ── Sentry submission ─────────────────────────────────────────────────────

  Future<void> _submitToSentry(BuildContext context, String message) async {
    String route;
    try {
      route = GoRouterState.of(context).uri.path;
    } catch (_) {
      route = 'unknown';
    }

    final bytes = await _captureScreen();

    final eventId = await Sentry.captureMessage(
      'screen_feedback: $route',
      withScope: (scope) async {
        if (bytes != null) {
          scope.addAttachment(SentryAttachment.fromUint8List(
            bytes,
            'screenshot.png',
            contentType: 'image/png',
          ));
        }
        await scope.setTag('feedback_route', route);
      },
    );

    await Sentry.captureFeedback(
      SentryFeedback(message: message, associatedEventId: eventId),
    );

    // Analytics — best-effort
    try {
      final analytics = _analyticsResolver?.call();
      if (analytics != null) {
        unawaited(analytics.logEvent(
          AnalyticsEvents.screenFeedbackSubmitted,
          properties: {'route': route},
        ));
      }
    } catch (_) {}
  }

  // ── Sheet ─────────────────────────────────────────────────────────────────

  Future<void> _openSheet(BuildContext outerContext) async {
    unawaited(HapticFeedback.lightImpact());

    // Capture the ScaffoldMessenger before the sheet opens so that the success
    // snackbar can be shown in the parent scaffold after the sheet is popped.
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(outerContext);

    await DonyBottomSheet.show<void>(
      outerContext,
      title: 'Un problème sur cet écran ?',
      subtitle:
          'Décrivez le bug — une capture de l\'écran sera jointe automatiquement.',
      // wrapper provides the shared form state to both child (TextField) and
      // stickyBottom (DonyButton) — pattern recommandé CLAUDE.md pour état local.
      wrapper: (content) => _FeedbackFormProvider(
        onSubmitOverride: onSubmitOverride,
        submitToSentry: _submitToSentry,
        scaffoldMessenger: scaffoldMessenger,
        child: content,
      ),
      // ✅ DonyButton dans stickyBottom, jamais dans child
      stickyBottom: const _FeedbackSubmitButton(),
      child: const _FeedbackTextField(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Signaler un problème',
      child: IconButton(
        icon: const Icon(Icons.bug_report_outlined),
        onPressed: () => _openSheet(context),
      ),
    );
  }
}

// ── InheritedWidget — shared form state ──────────────────────────────────

class _FeedbackFormState {
  _FeedbackFormState({
    required this.controller,
    required this.canSend,
    required this.sending,
    required this.onSubmitOverride,
    required this.submitToSentry,
    required this.scaffoldMessenger,
  });

  final TextEditingController controller;
  final ValueNotifier<bool> canSend;
  final ValueNotifier<bool> sending;
  final Future<void> Function(String message)? onSubmitOverride;
  final Future<void> Function(BuildContext, String) submitToSentry;
  final ScaffoldMessengerState? scaffoldMessenger;
}

class _FeedbackFormInherited extends InheritedWidget {
  const _FeedbackFormInherited({
    required this.state,
    required super.child,
  });

  final _FeedbackFormState state;

  static _FeedbackFormState of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_FeedbackFormInherited>()!
        .state;
  }

  @override
  bool updateShouldNotify(_FeedbackFormInherited old) => false;
}

/// [StatefulWidget] wrapper fourni via `wrapper:` à [DonyBottomSheet.show].
/// Gère le cycle de vie de tous les objets mutables du formulaire.
class _FeedbackFormProvider extends StatefulWidget {
  const _FeedbackFormProvider({
    required this.onSubmitOverride,
    required this.submitToSentry,
    required this.scaffoldMessenger,
    required this.child,
  });

  final Future<void> Function(String message)? onSubmitOverride;
  final Future<void> Function(BuildContext, String) submitToSentry;
  final ScaffoldMessengerState? scaffoldMessenger;
  final Widget child;

  @override
  State<_FeedbackFormProvider> createState() => _FeedbackFormProviderState();
}

class _FeedbackFormProviderState extends State<_FeedbackFormProvider> {
  late final TextEditingController _controller;
  late final ValueNotifier<bool> _canSend;
  late final ValueNotifier<bool> _sending;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _canSend = ValueNotifier<bool>(false);
    _sending = ValueNotifier<bool>(false);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _canSend.value = _controller.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _canSend.dispose();
    _sending.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FeedbackFormInherited(
      state: _FeedbackFormState(
        controller: _controller,
        canSend: _canSend,
        sending: _sending,
        onSubmitOverride: widget.onSubmitOverride,
        submitToSentry: widget.submitToSentry,
        scaffoldMessenger: widget.scaffoldMessenger,
      ),
      child: widget.child,
    );
  }
}

// ── TextField (child) ──────────────────────────────────────────────────────

class _FeedbackTextField extends StatelessWidget {
  const _FeedbackTextField();

  @override
  Widget build(BuildContext context) {
    final formState = _FeedbackFormInherited.of(context);
    return TextField(
      controller: formState.controller,
      minLines: 3,
      maxLines: 4,
      decoration: const InputDecoration(
        hintText: 'Ex : le code retrait ne s\'affiche pas…',
      ),
      autofocus: true,
      textInputAction: TextInputAction.newline,
    );
  }
}

// ── Submit button (stickyBottom) ───────────────────────────────────────────

/// Bouton "Envoyer le rapport" placé dans `stickyBottom` du sheet.
class _FeedbackSubmitButton extends StatefulWidget {
  const _FeedbackSubmitButton();

  @override
  State<_FeedbackSubmitButton> createState() => _FeedbackSubmitButtonState();
}

class _FeedbackSubmitButtonState extends State<_FeedbackSubmitButton> {
  Future<void> _handleSubmit() async {
    final formState = _FeedbackFormInherited.of(context);
    final text = formState.controller.text.trim();
    formState.sending.value = true;
    try {
      if (formState.onSubmitOverride != null) {
        await formState.onSubmitOverride!(text);
      } else {
        await formState.submitToSentry(context, text);
      }
      // Succès : fermer le sheet, afficher le snackbar dans le scaffold parent
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      formState.scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text('Merci ! Votre rapport a bien été envoyé.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      // Échec : garder le sheet ouvert, afficher l'erreur
      if (mounted) {
        DonySnackbar.show(
          context,
          message: 'Envoi impossible. Réessayez.',
          type: DonySnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        formState.sending.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = _FeedbackFormInherited.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: formState.canSend,
      builder: (ctx, enabled, _) => ValueListenableBuilder<bool>(
        valueListenable: formState.sending,
        builder: (ctx2, isSending, _) => DonyButton(
          label: 'Envoyer le rapport',
          onPressed: enabled && !isSending ? _handleSubmit : null,
          isLoading: isSending,
        ),
      ),
    );
  }
}
