import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/config/api_config.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/poster/poster_capture.dart';
import 'package:dony/core/design/widgets/poster/poster_parts.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/presentation/screens/trip_poster_screen.dart'
    show PosterShareChannel;
import 'package:dony/features/package_request/bloc/package_request_detail_cubit.dart';
import 'package:dony/features/package_request/bloc/package_request_detail_state.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/features/package_request/presentation/widgets/poster/package_request_poster_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Point d'entrée de la route `/package-requests/:id/affiche`.
///
/// Même contrat que l'affiche de trajet : l'identifiant suffit (la demande est
/// rechargée par [PackageRequestDetailCubit]), et [initial] affiche l'affiche
/// sans attendre quand l'appelant tient déjà la demande, ce qui est le cas
/// juste après la publication et depuis « Ma demande ».
class PackageRequestPosterRoute extends StatelessWidget {
  const PackageRequestPosterRoute({super.key, this.initial});

  final PackageRequest? initial;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PackageRequestDetailCubit, PackageRequestDetailState>(
      builder: (context, state) {
        final request = state is PackageRequestDetailLoaded
            ? state.request
            : initial;
        if (request != null) {
          return PackageRequestPosterScreen(request: request);
        }

        final l = context.l10n;
        return Scaffold(
          appBar: AppBar(
            actions: const [DonyFeedbackButton()],
            leading: const DonyAppBarBackButton(),
            title: Text(l.tripPosterTitle),
            centerTitle: false,
          ),
          body: Center(
            child: state is PackageRequestDetailError
                ? DonyEmptyState(
                    title: l.requestPosterNotFoundTitle,
                    description: l.requestPosterNotFoundDescription,
                    type: DonyEmptyStateType.error,
                  )
                : const CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

/// Aperçu de l'affiche d'une demande d'envoi et ses actions de diffusion.
///
/// Comme pour le trajet, l'image seule ne suffit pas : une URL n'est pas
/// cliquable dans une image. Le lien part donc dans la légende (partage,
/// « Copier la légende », « Copier le lien »), et le QR code de l'affiche le
/// porte pour qui ne voit que l'image.
class PackageRequestPosterScreen extends StatefulWidget {
  const PackageRequestPosterScreen({
    super.key,
    required this.request,
    this.shareBaseUrl = posterShareBaseUrl,
    @visibleForTesting this.captureOverride,
  });

  final PackageRequest request;

  /// Injectable pour les tests. En production, [posterShareBaseUrl].
  final String shareBaseUrl;

  /// Remplace la rastérisation dans les tests de widget, où `toImage` ne rend
  /// pas la main sans `runAsync`.
  final Future<Uint8List?> Function()? captureOverride;

  @override
  State<PackageRequestPosterScreen> createState() =>
      _PackageRequestPosterScreenState();
}

class _PackageRequestPosterScreenState
    extends State<PackageRequestPosterScreen> {
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);

  /// Première photo du colis, préchargée avec les assets avant la capture.
  late final ImageProvider? _photo = _photoOf(widget.request);

  late final PosterCapture _poster = PosterCapture(images: [?_photo]);

  static ImageProvider? _photoOf(PackageRequest r) {
    final url = r.photoUrls.isNotEmpty ? r.photoUrls.first : r.photoUrl;
    return (url == null || url.isEmpty)
        ? null
        : CachedNetworkImageProvider(url);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        getItSafe<AnalyticsService>()?.logEvent(
          AnalyticsEvents.packageRequestPosterOpened,
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _poster.warmUp(context);
  }

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  /// Forme courte `/demande/{id}`, alias public servi par le backend
  /// (`PublicPackageRequestPageController`), qui renvoie vers l'app ou le
  /// store. Le canal de diffusion voyage dans `?c=`.
  String _urlFor(PosterShareChannel channel) =>
      '${widget.shareBaseUrl}/demande/${widget.request.id}'
      '?c=${channel.code}';

  /// Légende prête à coller dans le texte du post : c'est elle qui porte le
  /// lien cliquable. Alignée mot pour mot sur l'affiche.
  String _captionFor(PosterShareChannel channel) {
    final l = context.l10n;
    final r = widget.request;
    final size = r.parcelSize.label(l).toLowerCase();
    final budget = PackageRequestPosterCard.budgetLabel(r);
    final contents = [
      for (final c in r.categories) contentCategoryDisplayName(l, c),
    ];
    return <String>[
      '📦 ${l.requestPosterCaptionCorridor(r.departureCity, r.arrivalCity)}',
      '📅 ${PackageRequestPosterCard.dateLabel(l, r)}',
      '⚖️ ${l.requestPosterCaptionWeight(formatKg(l, r.weightKg), size)}',
      if (contents.isNotEmpty)
        '🧳 ${l.requestPosterCaptionContents(contents.join(', '))}',
      if (budget != null)
        '💶 ${l.requestPosterCaptionBudget(budget, r.negotiable ? l.requestPosterNegotiable : l.requestPosterFirmPrice)}',
      '📍 ${l.requestPosterCaptionFrom(PackageRequestPosterCard.placeLabel(r.departureCity, r.pickupNeighborhood))}',
      '🏁 ${l.requestPosterCaptionTo(PackageRequestPosterCard.placeLabel(r.arrivalCity, r.deliveryNeighborhood))}',
      '',
      l.requestPosterCaptionCta,
      _urlFor(channel),
      '',
      l.requestPosterCaptionFooter,
    ].join('\n');
  }

  Future<Uint8List?> _capture() async {
    final override = widget.captureOverride;
    if (override != null) {
      return override();
    }
    final bytes = await _poster.capture();
    return mounted ? bytes : null;
  }

  /// Garde de réentrance, capture, message d'échec, remise à zéro : seul le
  /// traitement des octets diffère entre partager et enregistrer.
  Future<void> _withPoster(
    String failureMessage,
    Future<void> Function(Uint8List bytes) action,
  ) async {
    _busy.value = true;
    try {
      final bytes = await _capture();
      if (bytes == null) {
        _notify(failureMessage, DonySnackbarType.error);
        return;
      }
      await action(bytes);
    } catch (_) {
      _notify(failureMessage, DonySnackbarType.error);
    } finally {
      if (mounted) {
        _busy.value = false;
      }
    }
  }

  String get _fileName => 'yadony_demande_${widget.request.id}.png';

  Future<void> _sharePoster() {
    // Lu avant tout await : le RenderBox du contexte peut être démonté
    // pendant les opérations asynchrones.
    final origin = sharePositionOriginFor(context);
    final l = context.l10n;
    final r = widget.request;
    return _withPoster(l.tripPosterShareError, (bytes) async {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_fileName');
      await file.writeAsBytes(bytes);

      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: l.requestPosterShareSubject(r.departureCity, r.arrivalCity),
        text: _captionFor(PosterShareChannel.share),
        sharePositionOrigin: origin,
      );
      if (result.status != ShareResultStatus.dismissed) {
        _track(AnalyticsEvents.packageRequestPosterShared, 'share');
      }
    });
  }

  Future<void> _saveToGallery() {
    final l = context.l10n;
    final failureMessage = l.tripPosterSaveError;
    return _withPoster(failureMessage, (bytes) async {
      // gal n'appelle jamais requestAccess() lui-même avant d'écrire : sans
      // cette demande, l'écriture échoue toujours sur Android 7 à 9.
      if (!await Gal.requestAccess()) {
        _notify(failureMessage, DonySnackbarType.error);
        return;
      }
      await Gal.putImageBytes(bytes, name: _fileName);
      _track(AnalyticsEvents.packageRequestPosterShared, 'save');
      _notify(l.tripPosterSaveSuccess, DonySnackbarType.success);
    });
  }

  Future<void> _copy({
    required String value,
    required String confirmation,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    _track(AnalyticsEvents.packageRequestPosterLinkCopied, null);
    _notify(confirmation, DonySnackbarType.success);
  }

  void _track(String event, String? action) => unawaited(
    getItSafe<AnalyticsService>()?.logEvent(
      event,
      properties: action == null ? null : {'action': action},
    ),
  );

  void _notify(String message, DonySnackbarType type) {
    if (!mounted) {
      return;
    }
    DonySnackbar.show(context, message: message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        actions: const [DonyFeedbackButton()],
        leading: const DonyAppBarBackButton(),
        title: Text(l.tripPosterTitle),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.xl,
          DonySpacing.lg,
          DonySpacing.huge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Le RepaintBoundary est SOUS le FittedBox : il garde la taille
            // logique de l'affiche, la capture n'hérite pas de la réduction.
            ClipRRect(
              borderRadius: BorderRadius.circular(DonyRadius.card),
              child: AspectRatio(
                aspectRatio: PosterLayout.width / PosterLayout.height,
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _poster.key,
                    child: PackageRequestPosterCard(
                      request: widget.request,
                      qrData: _urlFor(PosterShareChannel.qr),
                      photo: _photo,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.xl),
            Text(
              l.tripPosterInstructions,
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.lg),
            ValueListenableBuilder<bool>(
              valueListenable: _busy,
              builder: (context, busy, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DonyButton(
                    key: const Key('request-poster-share'),
                    label: l.tripPosterShareButton,
                    icon: Icons.ios_share_rounded,
                    isLoading: busy,
                    onPressed: busy ? null : _sharePoster,
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  DonyButton(
                    key: const Key('request-poster-copy-caption'),
                    label: l.tripPosterCopyCaptionButton,
                    icon: Icons.notes_rounded,
                    variant: DonyButtonVariant.secondary,
                    onPressed: busy
                        ? null
                        : () => _copy(
                            value: _captionFor(PosterShareChannel.caption),
                            confirmation: l.tripPosterCaptionCopied,
                          ),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  DonyButton(
                    key: const Key('request-poster-copy-link'),
                    label: l.tripPosterCopyLinkButton,
                    icon: Icons.link_rounded,
                    variant: DonyButtonVariant.secondary,
                    onPressed: busy
                        ? null
                        : () => _copy(
                            value: _urlFor(PosterShareChannel.link),
                            confirmation: l.tripPosterLinkCopiedMessage,
                          ),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  DonyButton(
                    key: const Key('request-poster-save'),
                    label: l.tripPosterSaveButton,
                    icon: Icons.download_rounded,
                    variant: DonyButtonVariant.ghost,
                    onPressed: busy ? null : _saveToGallery,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
