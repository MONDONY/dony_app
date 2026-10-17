import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Feuille qui explique le badge GP Pro (voyageur régulier accordé par
/// l'équipe Yadony), ouverte en touchant le badge.
abstract final class GpProInfoSheet {
  /// [surface] : écran d'origine, chaîne fermée envoyée à l'analytics.
  static Future<void> show(BuildContext context, {required String surface}) {
    return DonyBottomSheet.show<void>(
      context,
      title: context.l10n.gpProInfoTitle,
      child: _GpProInfoContent(surface: surface),
    );
  }
}

class _GpProInfoContent extends StatefulWidget {
  const _GpProInfoContent({required this.surface});

  final String surface;

  @override
  State<_GpProInfoContent> createState() => _GpProInfoContentState();
}

class _GpProInfoContentState extends State<_GpProInfoContent> {
  @override
  void initState() {
    super.initState();
    // Event de vue (exception acceptée du CLAUDE.md) : le badge touché ouvre
    // cette feuille, c'est son ouverture qui est mesurée.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        getItSafe<AnalyticsService>()?.logEvent(
          AnalyticsEvents.gpProBadgeTapped,
          properties: {'surface': widget.surface},
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.lg),
      child: Text(
        context.l10n.gpProInfoBody,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
