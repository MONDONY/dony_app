import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/core/services/screen_feedback_sender.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Contenu d'un rapport de bug d'écran : le message du testeur et les
/// captures qu'il a jointes lui-même (chemins locaux, max
/// [DonyFeedbackButton.maxAttachments]). La capture automatique de l'écran
/// n'en fait pas partie : elle est prise au moment de l'envoi.
class FeedbackReport {
  const FeedbackReport({
    required this.message,
    this.attachments = const [],
    this.route = 'unknown',
  });

  final String message;
  final List<String> attachments;

  /// Route GoRouter de l'écran d'où part le rapport, lue AU TAP sur le
  /// scarabée : la feuille vit sur le navigateur racine, hors de tout écran,
  /// et son contexte ne connaît pas la route (tous les premiers rapports
  /// arrivaient en `unknown`). `'unknown'` si le contexte n'était pas dans
  /// un GoRouter.
  final String route;
}

/// Bouton global de signalement de bug vers Sentry (le « scarabée »).
///
/// Présent par défaut dans les `actions` de [DonyAppBar] et
/// [DonySliverAppBar] ; pour un `AppBar` brut ou un header maison :
/// ```dart
/// AppBar(actions: const [DonyFeedbackButton()])
/// ```
///
/// À l'envoi, capture l'écran via le [RepaintBoundary] global posé dans
/// `app.dart` ([appBoundaryKey]), y ajoute les captures choisies par le
/// testeur, puis envoie un message + feedback à Sentry. En test,
/// [onSubmitOverride] remplace la logique Sentry et [pickImageOverride]
/// remplace le sélecteur d'images.
class DonyFeedbackButton extends StatelessWidget {
  const DonyFeedbackButton({
    super.key,
    this.onSubmitOverride,
    this.pickImageOverride,
    this.captureOverride,
    this.repaintBoundaryKey,
  });

  /// Nombre maximal de captures jointes par le testeur.
  static const int maxAttachments = 4;

  /// Clé du [RepaintBoundary] qui enveloppe toute l'app (posé dans
  /// `app.dart`). Utilisée par défaut pour la capture d'écran : aucun écran
  /// n'a plus besoin de son propre `RepaintBoundary`.
  static final GlobalKey appBoundaryKey = GlobalKey(
    debugLabel: 'dony_feedback_capture',
  );

  /// Remplace `_submitToSentry` dans les tests.
  final Future<void> Function(FeedbackReport report)? onSubmitOverride;

  /// Remplace le sélecteur d'images ([DonyMediaService]) dans les tests.
  /// Rend le chemin local de l'image, ou `null` si l'utilisateur annule.
  final Future<String?> Function(ImageSource source)? pickImageOverride;

  /// Remplace la capture d'écran dans les tests : le binding de test ne
  /// rasterise jamais, `toImage` y échoue toujours.
  final Future<Uint8List?> Function()? captureOverride;

  /// Clé d'un [RepaintBoundary] à capturer à la place de [appBoundaryKey]
  /// (écran qui veut une capture plus resserrée). Sinon la capture globale.
  final GlobalKey? repaintBoundaryKey;

  // ── Analytics resolver ────────────────────────────────────────────────────

  static AnalyticsService Function()? _analyticsResolver;

  /// À appeler dans `injection.dart` après l'enregistrement d'[AnalyticsService].
  static void registerAnalyticsResolver(AnalyticsService Function() resolver) {
    _analyticsResolver = resolver;
  }

  /// Remet le resolver à null entre les tests pour éviter la pollution d'état.
  @visibleForTesting
  static void resetAnalyticsResolver() => _analyticsResolver = null;

  /// Retourne le chemin GoRouter courant, ou `'unknown'` si le contexte n'est
  /// pas hébergé dans un GoRouter (ex : tests unitaires plain MaterialApp).
  ///
  /// Extrait ici pour être testable indépendamment.
  @visibleForTesting
  static String resolveRoute(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return 'unknown';
    }
  }

  // ── Screen capture ────────────────────────────────────────────────────────

  Future<Uint8List?> _captureScreen() async {
    final override = captureOverride;
    if (override != null) {
      return override();
    }
    final key = repaintBoundaryKey ?? appBoundaryKey;
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
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

  static String _contentTypeFor(String path) {
    final dot = path.lastIndexOf('.');
    final ext = dot == -1 ? '' : path.substring(dot + 1).toLowerCase();
    return ext == 'png' ? 'image/png' : 'image/jpeg';
  }

  // ── Sentry submission ─────────────────────────────────────────────────────

  Future<void> _submit(
    BuildContext context,
    FeedbackReport report,
    Uint8List? bytes,
  ) async {
    final route = report.route;
    await _submitToSentry(route, report, bytes);
    await _submitToBackend(route, report, bytes);
  }

  /// Backend (admin › Signalements), en plus de Sentry. Jamais bloquant :
  /// hors ligne, backend ancien ou service absent (tests), le rapport Sentry
  /// est déjà parti et le testeur voit le succès.
  Future<void> _submitToBackend(
    String route,
    FeedbackReport report,
    Uint8List? bytes,
  ) async {
    if (!getIt.isRegistered<ScreenFeedbackSender>()) {
      return;
    }
    try {
      await getIt<ScreenFeedbackSender>().send(
        report: report,
        route: route,
        screenshot: bytes,
      );
    } catch (e) {
      final logMessage =
          'Rapport d\'écran non transmis au backend : $e'; // i18n-ignore
      AppLog.warn(logMessage);
    }
  }

  Future<void> _submitToSentry(
    String route,
    FeedbackReport report,
    Uint8List? bytes,
  ) async {
    // Captures jointes par le testeur : une pièce illisible ne bloque pas
    // l'envoi du rapport.
    final attachments = <SentryAttachment>[];
    for (var i = 0; i < report.attachments.length; i++) {
      final path = report.attachments[i];
      try {
        final data = await File(path).readAsBytes();
        final attachmentName =
            'capture_${i + 1}.${_contentTypeFor(path) == 'image/png' ? 'png' : 'jpg'}'; // i18n-ignore : nom de fichier technique, jamais affiché
        attachments.add(
          SentryAttachment.fromUint8List(
            data,
            attachmentName,
            contentType: _contentTypeFor(path),
          ),
        );
      } catch (_) {}
    }

    final eventId = await Sentry.captureMessage(
      'screen_feedback: $route', // i18n-ignore : identifiant Sentry, jamais affiché
      withScope: (scope) async {
        if (bytes != null) {
          scope.addAttachment(
            SentryAttachment.fromUint8List(
              bytes,
              'screenshot.png',
              contentType: 'image/png',
            ),
          );
        }
        for (final attachment in attachments) {
          scope.addAttachment(attachment);
        }
        await scope.setTag('feedback_route', route);
        await scope.setTag('feedback_attachments', '${attachments.length}');
      },
    );

    await Sentry.captureFeedback(
      SentryFeedback(message: report.message, associatedEventId: eventId),
    );

    // Analytics — best-effort
    try {
      final analytics = _analyticsResolver?.call();
      if (analytics != null) {
        unawaited(
          analytics.logEvent(
            AnalyticsEvents.screenFeedbackSubmitted,
            properties: {
              'route': route,
              'attachment_count': report.attachments.length,
            },
          ),
        );
      }
    } catch (_) {}
  }

  // ── Image picking ─────────────────────────────────────────────────────────

  Future<String?> _pickImage(ImageSource source) async {
    final override = pickImageOverride;
    if (override != null) {
      return override(source);
    }
    final file = await getIt<DonyMediaService>().pick(source: source);
    return file?.path;
  }

  // ── Sheet ─────────────────────────────────────────────────────────────────

  Future<void> _openSheet(BuildContext outerContext) async {
    unawaited(HapticFeedback.lightImpact());

    // Textes résolus AVANT le await qui suit : outerContext pourrait ne plus
    // être valide une fois la capture d'écran terminée.
    final l = outerContext.l10n;
    final sheetTitle = l.feedbackSheetTitle;
    final sheetSubtitle = l.feedbackSheetSubtitle;
    // Capture the ScaffoldMessenger before the sheet opens so that the success
    // snackbar can be shown in the parent scaffold after the sheet is popped.
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(outerContext);
    // La route se lit ici, depuis l'écran : le contexte de la feuille (navigateur
    // racine) ne la connaît pas.
    final route = resolveRoute(outerContext);
    // La capture aussi se prend ICI, avant que la feuille ne s'ouvre : prise à
    // l'envoi, elle montrait la feuille de signalement au lieu de l'écran.
    final screenshot = await _captureScreen();
    if (!outerContext.mounted) {
      return;
    }

    await DonyBottomSheet.show<void>(
      outerContext,
      title: sheetTitle,
      subtitle: sheetSubtitle,
      // wrapper provides the shared form state to both child (TextField) and
      // stickyBottom (DonyButton) — pattern recommandé CLAUDE.md pour état local.
      wrapper: (content) => _FeedbackFormProvider(
        route: route,
        screenshot: screenshot,
        onSubmitOverride: onSubmitOverride,
        submit: _submit,
        pickImage: _pickImage,
        scaffoldMessenger: scaffoldMessenger,
        child: content,
      ),
      // ✅ DonyButton dans stickyBottom, jamais dans child
      stickyBottom: const _FeedbackSubmitButton(),
      child: const _FeedbackFormBody(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // `IconButton.tooltip` enveloppe déjà dans un Tooltip : le Tooltip externe
    // qui existait ici en créait un second, avec le même message.
    return IconButton(
      tooltip: context.l10n.feedbackButtonTooltip,
      icon: const DonyIcon('bug'),
      onPressed: () => _openSheet(context),
    );
  }
}

// ── InheritedWidget — shared form state ──────────────────────────────────

class _FeedbackFormState {
  _FeedbackFormState({
    required this.controller,
    required this.canSend,
    required this.sending,
    required this.attachments,
    required this.route,
    required this.screenshot,
    required this.onSubmitOverride,
    required this.submit,
    required this.pickImage,
    required this.scaffoldMessenger,
  });

  final TextEditingController controller;
  final ValueNotifier<bool> canSend;
  final ValueNotifier<bool> sending;
  final ValueNotifier<List<String>> attachments;
  final String route;

  /// Capture de l'écran prise au tap sur le scarabée, avant la feuille.
  final Uint8List? screenshot;
  final Future<void> Function(FeedbackReport report)? onSubmitOverride;
  final Future<void> Function(BuildContext, FeedbackReport, Uint8List?) submit;
  final Future<String?> Function(ImageSource source) pickImage;
  final ScaffoldMessengerState? scaffoldMessenger;
}

class _FeedbackFormInherited extends InheritedWidget {
  const _FeedbackFormInherited({required this.state, required super.child});

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
    required this.route,
    required this.screenshot,
    required this.onSubmitOverride,
    required this.submit,
    required this.pickImage,
    required this.scaffoldMessenger,
    required this.child,
  });

  final String route;
  final Uint8List? screenshot;
  final Future<void> Function(FeedbackReport report)? onSubmitOverride;
  final Future<void> Function(BuildContext, FeedbackReport, Uint8List?) submit;
  final Future<String?> Function(ImageSource source) pickImage;
  final ScaffoldMessengerState? scaffoldMessenger;
  final Widget child;

  @override
  State<_FeedbackFormProvider> createState() => _FeedbackFormProviderState();
}

class _FeedbackFormProviderState extends State<_FeedbackFormProvider> {
  late final TextEditingController _controller;
  late final ValueNotifier<bool> _canSend;
  late final ValueNotifier<bool> _sending;
  late final ValueNotifier<List<String>> _attachments;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _canSend = ValueNotifier<bool>(false);
    _sending = ValueNotifier<bool>(false);
    _attachments = ValueNotifier<List<String>>(const []);
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
    _attachments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FeedbackFormInherited(
      state: _FeedbackFormState(
        controller: _controller,
        canSend: _canSend,
        sending: _sending,
        attachments: _attachments,
        route: widget.route,
        screenshot: widget.screenshot,
        onSubmitOverride: widget.onSubmitOverride,
        submit: widget.submit,
        pickImage: widget.pickImage,
        scaffoldMessenger: widget.scaffoldMessenger,
      ),
      child: widget.child,
    );
  }
}

// ── Corps du formulaire (child) ────────────────────────────────────────────

class _FeedbackFormBody extends StatelessWidget {
  const _FeedbackFormBody();

  @override
  Widget build(BuildContext context) {
    final formState = _FeedbackFormInherited.of(context);
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: formState.controller,
          minLines: 3,
          maxLines: 4,
          decoration: InputDecoration(hintText: l.feedbackHint),
          autofocus: true,
          textInputAction: TextInputAction.newline,
        ),
        const SizedBox(height: DonySpacing.base),
        Text(
          l.feedbackAttachmentsLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: DonySpacing.sm),
        const _FeedbackAttachments(),
      ],
    );
  }
}

/// Vignettes des captures jointes + tuile « Ajouter ». Max
/// [DonyFeedbackButton.maxAttachments].
class _FeedbackAttachments extends StatelessWidget {
  const _FeedbackAttachments();

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final formState = _FeedbackFormInherited.of(context);
    try {
      final path = await formState.pickImage(source);
      if (path == null) {
        return;
      }
      final current = formState.attachments.value;
      if (current.length >= DonyFeedbackButton.maxAttachments) {
        return;
      }
      formState.attachments.value = [...current, path];
    } catch (_) {
      if (context.mounted) {
        DonySnackbar.show(
          context,
          message: context.l10n.commonImageUnsupported,
          type: DonySnackbarType.error,
        );
      }
    }
  }

  void _showSourceSheet(BuildContext context) {
    final l = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: cs.primary),
                title: Text(l.commonPickFromGallery),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pick(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera_rounded, color: cs.primary),
                title: Text(l.commonTakePhoto),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pick(context, ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = _FeedbackFormInherited.of(context);
    final cs = Theme.of(context).colorScheme;
    final addLabel = context.l10n.feedbackAddAttachment;
    return ValueListenableBuilder<List<String>>(
      valueListenable: formState.attachments,
      builder: (context, attachments, _) {
        final canAdd = attachments.length < DonyFeedbackButton.maxAttachments;
        return Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: [
            for (final path in attachments)
              _AttachmentThumb(
                path: path,
                onRemove: () {
                  formState.attachments.value = attachments
                      .where((p) => p != path)
                      .toList();
                },
              ),
            if (canAdd)
              Semantics(
                button: true,
                container: true,
                excludeSemantics: true,
                label: addLabel,
                child: GestureDetector(
                  onTap: () => _showSourceSheet(context),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                      border: Border.all(color: cs.primary, width: 1.5),
                    ),
                    child: Icon(Icons.add_rounded, color: cs.primary),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            child: Image.file(
              File(path),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              // Fichier illisible (ou chemin factice en test) : on garde une
              // vignette neutre plutôt qu'une exception de rendu.
              errorBuilder: (_, _, _) => Container(
                width: 64,
                height: 64,
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.image_rounded, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              button: true,
              label: context.l10n.feedbackRemoveAttachment,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: cs.error,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 14, color: cs.onError),
                ),
              ),
            ),
          ),
        ],
      ),
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
    // Textes résolus ICI, pendant que le contexte est encore valide : ils
    // sont réutilisés après le `pop` du sheet, une fois le widget démonté.
    final l = context.l10n;
    final successMessage = l.feedbackSuccessMessage;
    final errorMessage = l.feedbackErrorMessage;
    final report = FeedbackReport(
      message: formState.controller.text.trim(),
      attachments: List<String>.unmodifiable(formState.attachments.value),
      route: formState.route,
    );
    formState.sending.value = true;
    try {
      if (formState.onSubmitOverride != null) {
        await formState.onSubmitOverride!(report);
      } else {
        await formState.submit(context, report, formState.screenshot);
      }
      // Succès : fermer le sheet, afficher le snackbar dans le scaffold parent
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      // Intentionnellement SANS garde `mounted` : le ScaffoldMessengerState
      // a été capturé AVANT l'ouverture du sheet (dans `_openSheet`) et
      // appartient au scaffold parent, qui reste monté après le pop du sheet.
      // Déplacer cet appel dans le bloc `if (mounted)` ci-dessus ferait
      // échouer le snackbar une fois le sheet dépilé.
      formState.scaffoldMessenger?.showSnackBar(
        SnackBar(
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      // Échec : garder le sheet ouvert, afficher l'erreur
      if (mounted) {
        DonySnackbar.show(
          context,
          message: errorMessage,
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
    final label = context.l10n.feedbackSubmitButton;
    return ValueListenableBuilder<bool>(
      valueListenable: formState.canSend,
      builder: (ctx, enabled, _) => ValueListenableBuilder<bool>(
        valueListenable: formState.sending,
        builder: (ctx2, isSending, _) => DonyButton(
          label: label,
          onPressed: enabled && !isSending ? _handleSubmit : null,
          isLoading: isSending,
        ),
      ),
    );
  }
}
