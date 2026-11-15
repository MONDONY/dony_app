import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Écran où l'expéditeur lit les points à connaître (propriété analytics
/// `source`).
enum BoatWarningsSource {
  bidCreate('bid_create'),
  requestCreate('request_create');

  const BoatWarningsSource(this.wire);
  final String wire;
}

/// Points à connaître avant d'envoyer un colis par bateau : objets interdits,
/// douane, délai, frais à l'arrivée, emballage. Information seule, rien ne
/// bloque. Replié sur un résumé, le détail s'ouvre d'un geste.
class BoatShippingWarnings extends StatefulWidget {
  const BoatShippingWarnings({super.key, required this.source, this.analytics});

  final BoatWarningsSource source;

  /// Service injectable pour garder le widget testable.
  final AnalyticsService? analytics;

  @override
  State<BoatShippingWarnings> createState() => _BoatShippingWarningsState();
}

class _BoatShippingWarningsState extends State<BoatShippingWarnings> {
  final _expanded = ValueNotifier<bool>(false);
  bool _expansionLogged = false;

  /// Même repli que les autres widgets de lecture : sans service enregistré
  /// (écran isolé), rien n'est envoyé.
  void _log(String event) {
    final analytics =
        widget.analytics ??
        (getIt.isRegistered<AnalyticsService>()
            ? getIt<AnalyticsService>()
            : null);
    if (analytics == null) return;
    unawaited(
      analytics.logEvent(event, properties: {'source': widget.source.wire}),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _log(AnalyticsEvents.boatWarningsViewed);
    });
  }

  @override
  void dispose() {
    _expanded.dispose();
    super.dispose();
  }

  void _toggle() {
    _expanded.value = !_expanded.value;
    if (_expanded.value && !_expansionLogged) {
      _expansionLogged = true;
      _log(AnalyticsEvents.boatWarningsExpanded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return DonyStatusBanner(
      key: const Key('boat-shipping-warnings'),
      type: DonyStatusBannerType.warning,
      title: l.boatWarningsTitle,
      message: l.boatWarningsSummary,
      action: ValueListenableBuilder<bool>(
        valueListenable: _expanded,
        builder: (context, open, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: open
                  ? Column(
                      key: const Key('boat-shipping-warnings-details'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (title, body) in [
                          (
                            l.boatWarningsForbiddenTitle,
                            l.boatWarningsForbiddenBody,
                          ),
                          (
                            l.boatWarningsCustomsTitle,
                            l.boatWarningsCustomsBody,
                          ),
                          (l.boatWarningsDelayTitle, l.boatWarningsDelayBody),
                          (l.boatWarningsFeesTitle, l.boatWarningsFeesBody),
                          (
                            l.boatWarningsPackingTitle,
                            l.boatWarningsPackingBody,
                          ),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(top: DonySpacing.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: DonySpacing.xs),
                                Text(
                                  body,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
            TextButton(
              key: const Key('boat-shipping-warnings-toggle'),
              onPressed: _toggle,
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurface,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
                tapTargetSize: MaterialTapTargetSize.padded,
                textStyle: tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
              // Fusionné dans le nœud du bouton : l'état ouvert est annoncé.
              child: Semantics(
                expanded: open,
                child: Text(open ? l.boatWarningsHide : l.boatWarningsShow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
