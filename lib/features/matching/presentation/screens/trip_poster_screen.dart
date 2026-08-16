import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dony/core/config/api_config.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/poster/trip_poster_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Aperçu de l'affiche d'un trajet, avec les trois actions qui permettent au
/// voyageur de la publier tel qu'il le fait déjà aujourd'hui.
///
/// Le partage d'image seul ne suffit pas : **sur Facebook, une URL écrite dans
/// une image n'est pas cliquable.** Sans le lien collé dans le texte du post,
/// la personne devrait le retaper à la main, ce que personne ne fait. D'où les
/// boutons « Copier le lien » et « Copier la légende », qui valent autant que
/// le partage lui-même.
class TripPosterScreen extends StatefulWidget {
  const TripPosterScreen({
    super.key,
    required this.announcement,
    this.shareBaseUrl,
  });

  final AnnouncementModel announcement;

  /// Injectable pour les tests. En production, dérivée de `kApiBaseUrl`.
  final String? shareBaseUrl;

  @override
  State<TripPosterScreen> createState() => _TripPosterScreenState();
}

class _TripPosterScreenState extends State<TripPosterScreen> {
  final GlobalKey _posterKey = GlobalKey();
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        getItSafe<AnalyticsService>()?.logEvent(
          AnalyticsEvents.tripPosterOpened,
        ),
      );
    });
  }

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  String get _shareUrl =>
      '${widget.shareBaseUrl ?? defaultPosterShareBaseUrl}/public/annonce/${widget.announcement.id}';

  /// Légende prête à coller dans le texte du post. C'est elle qui porte le lien
  /// cliquable, l'image ne le rendant pas actionnable sur les réseaux.
  String get _caption {
    final a = widget.announcement;
    final dayFmt = DateFormat('EEEE d MMMM', 'fr');
    final deadlineFmt = DateFormat("d MMMM 'à' HH'h'mm", 'fr');
    final price = a.pricePerKgDisplay ?? a.pricePerKg;
    final priceLabel = price == price.roundToDouble()
        ? price.toStringAsFixed(0)
        : price.toStringAsFixed(2);

    final lines = <String>[
      '✈️ ${a.departureCity} vers ${a.arrivalCity}',
      '📅 Départ le ${dayFmt.format(a.departureDate)}',
      if (a.handoverDeadline != null)
        '⏰ Dernier dépôt le ${deadlineFmt.format(a.handoverDeadline!)}',
      '📦 ${_kg(a.availableKg)} kg disponibles, $priceLabel${_symbol(a.currency)} le kilo',
      '',
      'Réservez vos kilos ici :',
      _shareUrl,
      '',
      'Paiement sécurisé, suivi du colis, voyageur vérifié.',
    ];
    return lines.join('\n');
  }

  static String _kg(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  static String _symbol(String currency) => switch (currency) {
        'EUR' => '€',
        'USD' => r'$',
        'GBP' => '£',
        'CAD' => r'$ CA',
        'XOF' => 'F CFA',
        _ => currency,
      };

  /// Capture l'affiche en PNG.
  ///
  /// Le `RepaintBoundary` porte la taille logique de l'affiche et non celle,
  /// réduite, de l'aperçu : la mise à l'échelle est appliquée par le `FittedBox`
  /// au-dessus de lui, hors du calque capturé. Avec un `pixelRatio` de 3, la
  /// sortie fait donc 1080 x 1350, le format 4:5 du fil Facebook.
  ///
  /// Attention : sur l'émulateur `dony_test`, dont le GPU est logiciel, la
  /// capture d'un `RepaintBoundary` rend un écran noir ou gèle. Valider sur un
  /// appareil réel, pas sur l'AVD.
  Future<Uint8List?> _capture() async {
    final boundary =
        _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return null;
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _sharePoster() async {
    if (_busy.value) {
      return;
    }
    _busy.value = true;
    // Lu avant tout await : sharePositionOriginFor interroge le RenderBox du
    // contexte, qui peut être démonté pendant les opérations asynchrones.
    final origin = sharePositionOriginFor(context);
    try {
      final bytes = await _capture();
      if (bytes == null) {
        _notify('Impossible de générer l\'affiche', DonySnackbarType.error);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/yadony_affiche_${widget.announcement.id}.png',
      );
      await file.writeAsBytes(bytes);

      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject:
            'Trajet ${widget.announcement.departureCity} vers ${widget.announcement.arrivalCity}',
        text: _caption,
        sharePositionOrigin: origin,
      );
      if (result.status != ShareResultStatus.dismissed) {
        unawaited(
          getItSafe<AnalyticsService>()?.logEvent(
            AnalyticsEvents.tripPosterShared,
          ),
        );
      }
    } catch (_) {
      _notify('Impossible de partager l\'affiche', DonySnackbarType.error);
    } finally {
      if (mounted) {
        _busy.value = false;
      }
    }
  }

  Future<void> _saveToGallery() async {
    if (_busy.value) {
      return;
    }
    _busy.value = true;
    try {
      final bytes = await _capture();
      if (bytes == null) {
        _notify('Impossible de générer l\'affiche', DonySnackbarType.error);
        return;
      }
      await Gal.putImageBytes(
        bytes,
        name: 'yadony_affiche_${widget.announcement.id}.png',
      );
      unawaited(
        getItSafe<AnalyticsService>()?.logEvent(
          AnalyticsEvents.tripPosterShared,
          properties: {'action': 'save'},
        ),
      );
      _notify('Affiche enregistrée dans votre galerie', DonySnackbarType.success);
    } catch (_) {
      _notify('Impossible d\'enregistrer l\'affiche', DonySnackbarType.error);
    } finally {
      if (mounted) {
        _busy.value = false;
      }
    }
  }

  Future<void> _copy({required String value, required String confirmation}) async {
    await Clipboard.setData(ClipboardData(text: value));
    unawaited(
      getItSafe<AnalyticsService>()?.logEvent(
        AnalyticsEvents.tripPosterLinkCopied,
      ),
    );
    _notify(confirmation, DonySnackbarType.success);
  }

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon affiche'),
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
            _Preview(posterKey: _posterKey, announcement: widget.announcement, shareUrl: _shareUrl),
            const SizedBox(height: DonySpacing.xl),
            Text(
              'Postez cette affiche comme d\'habitude, puis collez la légende dans le texte de votre publication. Le lien y devient cliquable, ce qui n\'est pas le cas d\'une adresse écrite sur l\'image.',
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.lg),
            ValueListenableBuilder<bool>(
              valueListenable: _busy,
              builder: (context, busy, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DonyButton(
                    label: 'Partager l\'affiche',
                    icon: Icons.ios_share_rounded,
                    isLoading: busy,
                    onPressed: busy ? null : _sharePoster,
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  DonyButton(
                    label: 'Copier la légende',
                    icon: Icons.notes_rounded,
                    variant: DonyButtonVariant.secondary,
                    onPressed: busy
                        ? null
                        : () => _copy(
                              value: _caption,
                              confirmation: 'Légende copiée',
                            ),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  DonyButton(
                    label: 'Copier le lien',
                    icon: Icons.link_rounded,
                    variant: DonyButtonVariant.secondary,
                    onPressed: busy
                        ? null
                        : () => _copy(
                              value: _shareUrl,
                              confirmation: 'Lien copié',
                            ),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  DonyButton(
                    label: 'Enregistrer dans la galerie',
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

/// Aperçu mis à l'échelle. Le `RepaintBoundary` est **sous** le `FittedBox` :
/// il conserve donc la taille logique de l'affiche, et la capture n'hérite pas
/// de la réduction appliquée pour l'affichage.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.posterKey,
    required this.announcement,
    required this.shareUrl,
  });

  final GlobalKey posterKey;
  final AnnouncementModel announcement;
  final String shareUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: AspectRatio(
        aspectRatio: TripPosterCard.logicalWidth / TripPosterCard.logicalHeight,
        child: FittedBox(
          child: RepaintBoundary(
            key: posterKey,
            child: TripPosterCard(
              announcement: announcement,
              shareUrl: shareUrl,
            ),
          ),
        ),
      ),
    );
  }
}
