import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/widgets/first_steps_personalized.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Route de l'écran de fin d'inscription.
///
/// Hors du préfixe `/onboarding`, que le routeur traite comme public : cet
/// écran suppose un compte connecté.
const String firstStepsRoute = '/first-steps';

/// Fin d'inscription : « Par quoi voulez-vous commencer ? ».
///
/// L'inscription déposait tout le monde sur l'accueil. PostHog (29/09) : sur 37
/// comptes vérifiés, 17 seulement publiaient, et 4 allaient vers la publication
/// juste après. Cet écran pose la question une fois, à la fin du parcours, et
/// mène droit à l'intro de publication choisie ; « Plus tard » garde l'ancien
/// comportement.
class FirstStepsScreen extends StatefulWidget {
  const FirstStepsScreen({super.key, this.analytics});

  /// Injectable pour les tests ; `null` lit le service du conteneur.
  final AnalyticsService? analytics;

  @override
  State<FirstStepsScreen> createState() => _FirstStepsScreenState();
}

class _FirstStepsScreenState extends State<FirstStepsScreen> {
  @override
  void initState() {
    super.initState();
    // Statut d'activation (intention, trajets ou colis de la ligne) : la vue
    // personnalisée remplace les tuiles dès qu'il est connu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<ActivationCubit>().load());
    });
  }

  void _choose(BuildContext context, String choice, String route) =>
      _track(choice, null, () => context.go(route));

  void _track(String choice, String? variant, VoidCallback go) {
    final service =
        widget.analytics ??
        (getIt.isRegistered<AnalyticsService>()
            ? getIt<AnalyticsService>()
            : null);
    if (service != null) {
      unawaited(
        service.logEvent(
          AnalyticsEvents.firstStepsChoice,
          properties: {'choice': choice, 'variant': ?variant},
        ),
      );
    }
    go();
  }

  Widget _personalized(BuildContext context, ActivationStatus status) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.xl,
            DonySpacing.lg,
            DonySpacing.base,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FirstStepsPersonalized(status: status, onChoose: _track),
              ),
              DonyButton(
                key: const Key('first-steps-later'),
                label: context.l10n.firstStepsLater,
                variant: DonyButtonVariant.ghost,
                onPressed: () => _track(
                  'later',
                  firstStepsVariant(status),
                  () => context.go('/home'),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.03),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final activation = context.watch<ActivationCubit>().state;
    if (activation is ActivationLoaded && activation.status.intent != null) {
      return _personalized(context, activation.status);
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.xl,
            DonySpacing.lg,
            DonySpacing.base,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Done(label: l.firstStepsDoneLabel),
                      const SizedBox(height: DonySpacing.xxl),
                      Text(
                        l.firstStepsTitle,
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.sm),
                      Text(
                        l.firstStepsSubtitle,
                        style: tt.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xl),
                      _ChoiceCard(
                        key: const Key('first-steps-trip'),
                        asset: 'assets/illustrations/publier_trajet.png',
                        accent: cs.primary,
                        title: l.firstStepsTripTitle,
                        subtitle: l.firstStepsTripSubtitle,
                        onTap: () =>
                            _choose(context, 'trip', '/trips/publish-intro'),
                      ),
                      const SizedBox(height: DonySpacing.md),
                      _ChoiceCard(
                        key: const Key('first-steps-parcel'),
                        asset: 'assets/illustrations/envoie_colis.png',
                        accent: cs.secondary,
                        title: l.firstStepsParcelTitle,
                        subtitle: l.firstStepsParcelSubtitle,
                        onTap: () =>
                            _choose(context, 'parcel', '/parcels/send-intro'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.base),
              DonyButton(
                key: const Key('first-steps-later'),
                label: l.firstStepsLater,
                variant: DonyButtonVariant.ghost,
                onPressed: () => _choose(context, 'later', '/home'),
              ),
            ],
          ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.03),
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = cs.success;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(DonyRadius.sm),
          ),
          alignment: Alignment.center,
          child: DonyIcon('check', size: 18, color: color),
        ),
        const SizedBox(width: DonySpacing.sm),
        Text(
          label,
          style: tt.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.asset,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String asset;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const radius = BorderRadius.all(Radius.circular(DonyRadius.xl));
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: cs.surfaceContainerLowest,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    // Rayon concentrique : carte xl (20) moins son padding.
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  padding: const EdgeInsets.all(DonySpacing.xs),
                  child: Image.asset(asset, fit: BoxFit.contain),
                ),
                const SizedBox(width: DonySpacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        subtitle,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                DonyIcon('chevron-right', size: 20, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
