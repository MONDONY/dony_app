import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dony/core/config/api_config.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/poster/trip_poster_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Canal de diffusion, porté par le lien sous la forme `?c=<canal>`.
///
/// La dimension doit voyager dans l'URL **dès la première affiche publiée** :
/// une affiche postée est irrécupérable, et un lien sans paramètre ne pourra
/// jamais être attribué rétroactivement. Le backend n'exploite pas encore ce
/// paramètre, mais il apparaît dans les journaux d'accès, donc l'historique est
/// préservé le jour où la ventilation par canal sera construite.
enum PosterShareChannel {
  /// Feuille de partage système (WhatsApp, Messages, Instagram…).
  share('partage'),

  /// Légende copiée puis collée dans le texte d'un post.
  caption('post'),

  /// Lien copié seul.
  link('lien');

  const PosterShareChannel(this.code);

  final String code;
}

/// Point d'entrée de la route `/announcements/:id/affiche`.
///
/// L'affiche est adressée par identifiant, elle doit donc savoir se résoudre à
/// partir de lui seul : une notification « ton trajet n'a reçu aucune demande,
/// partage ton affiche », un lien profond ou une entrée depuis Activités n'ont
/// que l'identifiant en main. Sans cela, chaque futur appelant devrait
/// recharger l'annonce lui-même avant de pouvoir router.
///
/// [initial] court-circuite l'attente quand l'appelant tient déjà le trajet,
/// ce qui est le cas des deux entrées actuelles : l'affiche s'ouvre alors
/// instantanément juste après la publication, au moment précis où elle est
/// postée. Même contrat que la route sœur `/announcements/:id/trip`.
class TripPosterRoute extends StatelessWidget {
  const TripPosterRoute({super.key, this.initial});

  final AnnouncementModel? initial;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        final announcement = state is AnnouncementDetailLoaded
            ? state.announcement
            : initial;

        if (announcement != null) {
          return TripPosterScreen(announcement: announcement);
        }

        return Scaffold(
          appBar: AppBar(
            leading: const DonyAppBarBackButton(),
            title: const Text('Mon affiche'),
            centerTitle: false,
          ),
          body: Center(
            child: state is AnnouncementError
                ? const DonyEmptyState(
                    title: 'Trajet introuvable',
                    description:
                        'Impossible de charger ce trajet pour le moment.',
                    type: DonyEmptyStateType.error,
                  )
                : const CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

/// Aperçu de l'affiche d'un trajet, avec les actions qui permettent au voyageur
/// de la publier tel qu'il le fait déjà aujourd'hui.
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
    this.shareBaseUrl = posterShareBaseUrl,
  });

  final AnnouncementModel announcement;

  /// Injectable pour les tests. En production, [posterShareBaseUrl].
  final String shareBaseUrl;

  @override
  State<TripPosterScreen> createState() => _TripPosterScreenState();
}

class _TripPosterScreenState extends State<TripPosterScreen> {
  final GlobalKey _posterKey = GlobalKey();
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);

  /// PNG mémoïsé. Le trajet affiché est immuable pour la durée de l'écran, et
  /// le texte invite explicitement à enchaîner « Partager » puis
  /// « Enregistrer » : sans mémoïsation, chaque action refait une
  /// rastérisation de 1080 x 1350 pour un résultat identique. Même motif que
  /// `qr_sheet.dart`.
  Uint8List? _posterBytes;

  /// Décodage des images de l'affiche, attendu avant toute capture.
  ///
  /// `toImage()` fige ce qui est peint à l'instant où on l'appelle. Un
  /// `Image.asset` se charge de façon asynchrone : sans cette attente, un
  /// voyageur qui tape « Partager » aussitôt l'écran ouvert exporterait une
  /// affiche amputée de son mot-logo et de ses badges, et rien dans le code ne
  /// le signalerait. La mise en page, elle, ne bouge pas, toutes ces images
  /// ayant une hauteur imposée.
  Future<void>? _imagesReady;

  static const List<String> _posterAssets = [
    DonyLogo.asset,
    TripPosterCard.appStoreBadgeAsset,
    TripPosterCard.googlePlayBadgeAsset,
  ];

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _imagesReady ??= Future.wait([
      for (final asset in _posterAssets)
        precacheImage(AssetImage(asset), context),
    ]);
  }

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  /// Forme courte, sans `/public` : elle résout dans tous les environnements,
  /// le backend exposant `/annonce/{id}` comme alias de `/public/annonce/{id}`
  /// (même contrôleur, même sécurité, cf. `PublicAnnouncementPageController`).
  /// Avec le repli par défaut de [TripPosterScreen.shareBaseUrl] sur
  /// `kApiBaseUrl`, elle donne une URL techniquement correcte quoique encore
  /// adossée à l'origine API ; une fois `POSTER_SHARE_BASE_URL` pointé sur le
  /// domaine nu (`https://yadony.com`), c'est nginx qui la rend pleinement
  /// lisible — sans qu'un seul octet ne change ici.
  String _urlFor(PosterShareChannel channel) =>
      '${widget.shareBaseUrl}/annonce/${widget.announcement.id}'
      '?c=${channel.code}';

  /// Légende prête à coller dans le texte du post. C'est elle qui porte le lien
  /// cliquable, l'image ne le rendant pas actionnable sur les réseaux.
  String _captionFor(PosterShareChannel channel) {
    final a = widget.announcement;
    final deadline = a.handoverDeadline;
    final pickup = a.pickupAddress?.label;
    final delivery = a.deliveryAddress?.label;

    return <String>[
      '✈️ ${a.departureCity} vers ${a.arrivalCity}',
      '📅 Départ le ${TripPosterCard.dayFormat.format(a.departureDate)}',
      if (deadline != null)
        '⏰ Dernier dépôt le ${TripPosterCard.deadlineFormat.format(deadline)}',
      '📦 ${TripPosterCard.capacityLabel(a)}, ${_priceSentence(a)}',
      if (pickup != null) '📍 Remise : $pickup',
      if (delivery != null) '🏁 Récupération : $delivery',
      '',
      'Réservez vos kilos ici :',
      _urlFor(channel),
      '',
      'Paiement sécurisé, suivi du colis, voyageur vérifié.',
    ].join('\n');
  }

  /// Phrase de prix de la légende, alignée mot pour mot sur le bloc prix de
  /// l'affiche : les deux partent des mêmes accesseurs, donc un trajet vendu à
  /// l'article ne peut pas annoncer « 0 € le kilo » d'un côté et sa grille de
  /// l'autre.
  static String _priceSentence(AnnouncementModel a) {
    // Garde sur hasKgPrice (valeur > 0), pas sur la seule nullité :
    // senderPricePerKg n'est en pratique jamais null, mais peut valoir 0
    // (mode MIXED sans grille renseignée, cas limite) — ce 0 est la vraie
    // valeur trompeuse à écarter, pas une absence.
    final senderPricePerKg = a.senderPricePerKg;
    final kilo = a.hasKgPrice
        ? '${formatPriceIn(senderPricePerKg!, a.currency)} le kilo'
        : null;
    final grid = a.cheapestGridPrice;
    if (grid == null) return kilo ?? 'Prix indisponible';

    final article = "dès ${formatPriceIn(grid, a.currency)} l'article";
    return (a.hasKgPrice && kilo != null) ? '$article et $kilo' : article;
  }

  /// Capture l'affiche en PNG, une seule fois par écran.
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
    final cached = _posterBytes;
    if (cached != null) {
      return cached;
    }
    // Les images doivent être décodées ET peintes avant la capture. Le
    // décodage seul ne suffit pas : il déclenche une reconstruction, dont il
    // faut attendre la frame, faute de quoi on rastérise l'état précédent.
    await _imagesReady;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return null;
    }

    final boundary =
        _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return null;
    }
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      // ~5,8 Mo de pixels natifs : sans dispose explicite, la libération dépend
      // d'un finalizer non déterministe.
      return _posterBytes = byteData?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// Coque commune aux deux actions qui produisent l'image : garde de
  /// réentrance, capture, message d'échec, remise à zéro. Seul le traitement
  /// des octets diffère entre partager et enregistrer.
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

  Future<void> _sharePoster() {
    // Lu avant tout await : sharePositionOriginFor interroge le RenderBox du
    // contexte, qui peut être démonté pendant les opérations asynchrones.
    final origin = sharePositionOriginFor(context);
    return _withPoster('Impossible de partager l\'affiche', (bytes) async {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/yadony_affiche_${widget.announcement.id}.png',
      );
      await file.writeAsBytes(bytes);

      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject:
            'Trajet ${widget.announcement.departureCity} vers ${widget.announcement.arrivalCity}',
        text: _captionFor(PosterShareChannel.share),
        sharePositionOrigin: origin,
      );
      if (result.status != ShareResultStatus.dismissed) {
        unawaited(
          getItSafe<AnalyticsService>()?.logEvent(
            AnalyticsEvents.tripPosterShared,
            properties: {'action': 'share'},
          ),
        );
      }
    });
  }

  Future<void> _saveToGallery() {
    const failureMessage = 'Impossible d\'enregistrer l\'affiche';
    return _withPoster(failureMessage, (bytes) async {
      // gal expose hasAccess()/requestAccess() mais ne les appelle jamais
      // lui-même avant d'écrire — putImageBytes écrit directement. Sans
      // cette demande explicite, WRITE_EXTERNAL_STORAGE (permission
      // dangereuse depuis l'API 23, déclarée avec maxSdkVersion=28) reste
      // accordée nulle part sur Android 7-9 (API 24-28), et l'écriture y
      // échoue toujours. requestAccess() ne réaffiche pas la boîte si
      // l'accès est déjà accordé — no-op sur API 29+, où gal le considère de
      // toute façon déjà acquis hors album.
      if (!await Gal.requestAccess()) {
        _notify(failureMessage, DonySnackbarType.error);
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
      _notify(
        'Affiche enregistrée dans votre galerie',
        DonySnackbarType.success,
      );
    });
  }

  Future<void> _copy({
    required String value,
    required String confirmation,
  }) async {
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
        leading: const DonyAppBarBackButton(),
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
            // Le RepaintBoundary est SOUS le FittedBox : il conserve donc la
            // taille logique de l'affiche, et la capture n'hérite pas de la
            // réduction appliquée pour l'affichage.
            ClipRRect(
              borderRadius: BorderRadius.circular(DonyRadius.card),
              child: AspectRatio(
                aspectRatio:
                    TripPosterCard.logicalWidth / TripPosterCard.logicalHeight,
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _posterKey,
                    child: TripPosterCard(announcement: widget.announcement),
                  ),
                ),
              ),
            ),
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
                            value: _captionFor(PosterShareChannel.caption),
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
                            value: _urlFor(PosterShareChannel.link),
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
