import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

/// Carousel evergreen affiché juste avant la liste de résultats de l'écran
/// Recherche. Remplace `RoleGuidanceBanner` (CTA mort, dismiss définitif) et
/// `ContextualTutorialCard` (carte séparée) par des cartes pleine couleur en
/// rotation automatique, chacune masquée dès que l'action qu'elle propose
/// est faite. Aucune croix de fermeture manuelle : la disparition est
/// entièrement pilotée par l'état applicatif.
class EvergreenGuidanceCarousel extends StatefulWidget {
  const EvergreenGuidanceCarousel({
    super.key,
    required this.hiveService,
    required this.isKycVerified,
  });

  final HiveService hiveService;
  final bool isKycVerified;

  static const Duration autoplayInterval = Duration(seconds: 4);

  @override
  State<EvergreenGuidanceCarousel> createState() =>
      _EvergreenGuidanceCarouselState();
}

class _EvergreenGuidanceCarouselState
    extends State<EvergreenGuidanceCarousel> {
  final PageController _pageController = PageController();
  Timer? _autoplayTimer;
  int _currentIndex = 0;
  int? _lastSlideCount;

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _restartAutoplay(int slideCount) {
    _autoplayTimer?.cancel();
    if (slideCount <= 1) return;
    if (MediaQuery.of(context).disableAnimations) return;
    _autoplayTimer = Timer.periodic(
      EvergreenGuidanceCarousel.autoplayInterval,
      (_) {
        if (!mounted || !_pageController.hasClients) return;
        final next = (_currentIndex + 1) % slideCount;
        _pageController.animateToPage(
          next,
          duration: DonyDuration.page,
          curve: DonyCurve.enter,
        );
      },
    );
  }

  void _onPageChanged(int index, int slideCount) {
    setState(() => _currentIndex = index);
    _restartAutoplay(slideCount);
  }

  void _onSlideTap(
    BuildContext context, {
    required String slideId,
    required String route,
  }) {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.homeGuidanceCarouselCtaTapped,
        properties: {'slide': slideId},
      ),
    );
    context.push(route);
  }

  void _onTutorialTap(BuildContext context, HelpTutorial tutorial) {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.homeGuidanceCarouselCtaTapped,
        properties: {'slide': 'tutorial'},
      ),
    );
    context.read<HelpCenterBloc>().add(
          HelpTutorialOpenRequested(
            tutorialId: tutorial.id,
            source: TutorialContext.search,
          ),
        );
    context.push('/profile/help/tutorial/${tutorial.id}');
  }

  @override
  Widget build(BuildContext context) {
    final tutorialConfig = context.select<HelpCenterBloc, HelpCenterConfig>(
      (bloc) => switch (bloc.state) {
        HelpCenterSuccess(:final config) => config,
        HelpCenterError(:final config) => config,
        _ => HelpCenterConfig.empty,
      },
    );
    final tutorial = tutorialConfig.tutorialFor(TutorialContext.search);

    return ValueListenableBuilder<Box>(
      valueListenable: widget.hiveService.listenUserPrefs(keys: [
        HiveService.kHasPublishedAsTraveler,
        HiveService.kHasPublishedAsSender,
        HiveService.kHasActiveCorridorAlert,
        if (tutorial != null)
          '${HiveService.kContextualTutorialDismissedPrefix}${tutorial.id}',
      ]),
      builder: (context, box, _) {
        final hasPublishedTrip = box.get(
          HiveService.kHasPublishedAsTraveler,
          defaultValue: false,
        ) as bool;
        final hasPublishedParcel = box.get(
          HiveService.kHasPublishedAsSender,
          defaultValue: false,
        ) as bool;
        final hasActiveCorridorAlert = box.get(
          HiveService.kHasActiveCorridorAlert,
          defaultValue: false,
        ) as bool;
        final tutorialDismissed = tutorial != null &&
            (box.get(
              '${HiveService.kContextualTutorialDismissedPrefix}${tutorial.id}',
              defaultValue: false,
            ) as bool);

        final slides = <_GuidanceSlideData>[
          if (!hasPublishedTrip)
            _GuidanceSlideData(
              id: 'trip',
              icon: 'plane',
              title: 'Publier mon trajet',
              subtitle:
                  'Rentabilise tes voyages en transportant des colis pour d’autres.',
              ctaLabel: 'Commencer',
              // Primitive fixe, pas cs.primary : en dark mode le ColorScheme
              // recalibre ce token pour du texte/icônes sur fond sombre, pas
              // pour un fill plein avec du texte blanc dessus (cf.
              // app_theme.dart:143-151, même piège documenté pour cs.primary).
              color: DonyColors.blue500,
              onTap: () => _onSlideTap(
                context,
                slideId: 'trip',
                route: '/trips/publish-intro',
              ),
            ),
          if (!hasPublishedParcel)
            _GuidanceSlideData(
              id: 'parcel',
              icon: 'send',
              title: 'Envoyer un colis',
              subtitle:
                  'Trouve un voyageur qui emporte ton colis à destination.',
              ctaLabel: 'Rechercher',
              color: DonyColors.success500,
              onTap: () => _onSlideTap(
                context,
                slideId: 'parcel',
                route: '/parcels/send-intro',
              ),
            ),
          if (!hasActiveCorridorAlert)
            _GuidanceSlideData(
              id: 'alert',
              icon: 'bell',
              title: 'Créer une alerte',
              subtitle:
                  'Sois notifié dès qu’une annonce correspond à tes critères.',
              ctaLabel: 'Créer',
              color: DonyColors.warning500,
              onTap: () => _onSlideTap(
                context,
                slideId: 'alert',
                route: '/corridor-alerts',
              ),
            ),
          if (!widget.isKycVerified)
            _GuidanceSlideData(
              id: 'kyc',
              icon: 'shield-check',
              title: 'Vérifier mon identité',
              subtitle:
                  'Valide ton profil pour publier un trajet et réserver en toute confiance.',
              ctaLabel: 'Vérifier',
              color: DonyColors.info500,
              onTap: () => _onSlideTap(
                context,
                slideId: 'kyc',
                route: '/kyc/verify',
              ),
            ),
          if (tutorial != null && !tutorialDismissed)
            _GuidanceSlideData(
              id: 'tutorial',
              icon: 'circle-play',
              title: 'Comment ça marche ?',
              subtitle: tutorial.title,
              ctaLabel: 'Voir le tuto',
              color: DonyColors.terra500,
              onTap: () => _onTutorialTap(context, tutorial),
            ),
        ];

        if (slides.isEmpty) return const SizedBox.shrink();

        if (_lastSlideCount != slides.length) {
          _lastSlideCount = slides.length;
          if (_currentIndex >= slides.length) _currentIndex = 0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _restartAutoplay(slides.length);
          });
        }
        final safeIndex = _currentIndex.clamp(0, slides.length - 1).toInt();

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.lg,
            vertical: DonySpacing.md,
          ),
          child: Column(
            children: [
              if (slides.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                  child: DonyStepIndicator(
                    total: slides.length,
                    current: safeIndex,
                  ),
                ),
              SizedBox(
                height: 172,
                child: PageView.builder(
                  key: const Key('evergreen-guidance-carousel'),
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (i) => _onPageChanged(i, slides.length),
                  itemBuilder: (context, i) => _SlideCard(data: slides[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GuidanceSlideData {
  const _GuidanceSlideData({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.color,
    required this.onTap,
  });

  final String id;
  final String icon;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final Color color;
  final VoidCallback onTap;
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.data});

  final _GuidanceSlideData data;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      key: Key('guidance-slide-${data.id}'),
      margin: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Row(
        children: [
          DonyIconContainer(
            iconAsset: data.icon,
            size: DonyIconContainerSize.lg,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            iconColor: Colors.white,
            borderRadius: DonyRadius.md,
          ),
          const SizedBox(width: DonySpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.title,
                  style: tt.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  data.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                GestureDetector(
                  key: Key('guidance-slide-${data.id}-cta'),
                  onTap: data.onTap,
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: kDonyMinTapTarget),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.md,
                    ),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      '${data.ctaLabel} →',
                      style: tt.labelMedium?.copyWith(
                        color: data.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
