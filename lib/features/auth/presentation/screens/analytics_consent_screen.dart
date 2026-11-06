import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/analytics_consent_cubit.dart';
import 'package:dony/features/auth/presentation/screens/profile_basics_screen.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran « Une dernière chose » : la question de la mesure d'usage, juste
/// après le code de vérification (SMS ou e-mail) d'un nouveau compte, avant
/// « Faisons connaissance » (`profileBasicsRoute`).
///
/// Hors du préfixe `/onboarding`, que le routeur traite comme public : cet
/// écran suppose un compte connecté.
const String analyticsConsentRoute = '/auth/analytics-consent';

/// Paramètre d'adresse qui dit où aller ensuite. Absent : « Faisons
/// connaissance » (nouveau compte).
const String analyticsConsentNextParam = 'next';

/// Valeur de [analyticsConsentNextParam] pour un compte existant connecté par
/// numéro ou e-mail : l'accueil.
const String analyticsConsentNextHome = 'home';

/// Valeur pour un compte existant connecté par Google ou Apple : le verrou
/// local (`/auth/local`), qui mène ensuite à l'accueil.
const String analyticsConsentNextLocal = 'local';

/// Destination après la question. Liste fermée : une adresse venue d'un lien
/// ne peut pas envoyer ailleurs.
String analyticsConsentDestination(String? next) => switch (next) {
  analyticsConsentNextHome => '/home',
  analyticsConsentNextLocal => '/auth/local',
  _ => profileBasicsRoute,
};

/// Question facultative, toujours en opt-in : rien n'est mesuré tant que la
/// personne n'a pas touché « Accepter ».
///
/// L'écran ne s'affiche que si la question doit être posée
/// ([AnalyticsConsentCubit.resolve]) ; sinon il passe directement à la suite
/// de l'inscription, sans que l'utilisateur le voie.
class AnalyticsConsentScreen extends StatefulWidget {
  const AnalyticsConsentScreen({super.key, this.next});

  /// Valeur du paramètre [analyticsConsentNextParam] (`null` : nouveau
  /// compte).
  final String? next;

  @override
  State<AnalyticsConsentScreen> createState() => _AnalyticsConsentScreenState();
}

class _AnalyticsConsentScreenState extends State<AnalyticsConsentScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<AnalyticsConsentCubit>().resolve());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AnalyticsConsentCubit, AnalyticsConsentState>(
      listenWhen: (p, c) => c is AnalyticsConsentDone,
      listener: (context, state) =>
          context.go(analyticsConsentDestination(widget.next)),
      builder: (context, state) {
        final h = DonyLayout.hPadding(context);
        final bottom = MediaQuery.paddingOf(context).bottom;
        final l = context.l10n;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const AuthFlowBackground(),
              if (state is AnalyticsConsentAsk)
                SafeArea(
                  bottom: false,
                  child: DonyLayout.constrained(
                    context,
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        h,
                        DonySpacing.base,
                        h,
                        DonySpacing.base + bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AuthFlowHeader.plain(),
                          const SizedBox(height: DonySpacing.md),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AuthIntroCard.compact(
                                        iconAsset: 'shield-check',
                                        title: l.authConsentTitle,
                                        body: l.authConsentBody,
                                        footnote: l.authConsentFootnote,
                                      )
                                      .animate()
                                      .fadeIn(duration: 300.ms)
                                      .slideY(begin: 0.04),
                                  const SizedBox(height: DonySpacing.md),
                                  const _ConsentPoints().animate().fadeIn(
                                    delay: 100.ms,
                                    duration: 300.ms,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // « Accepter » d'abord, « Non merci » dessous, tous
                          // deux collés en bas, à portée du pouce.
                          const SizedBox(height: DonySpacing.sm),
                          DonyButton(
                            key: const Key('analytics-consent-accept'),
                            label: l.authConsentAccept,
                            iconAsset: 'shield-check',
                            onPressed: () => unawaited(
                              context.read<AnalyticsConsentCubit>().answer(
                                granted: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: DonySpacing.sm),
                          DonyButton(
                            key: const Key('analytics-consent-decline'),
                            label: l.authConsentDecline,
                            variant: DonyButtonVariant.secondary,
                            onPressed: () => unawaited(
                              context.read<AnalyticsConsentCubit>().answer(
                                granted: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ConsentPoints extends StatelessWidget {
  const _ConsentPoints();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final points = [
      ('trending-up', l.authConsentPointScreens),
      ('search', l.authConsentPointGestures),
      ('lock', l.authConsentPointNeverPersonal),
      ('refresh-cw', l.authConsentPointChangeAnytime),
    ];

    return DonyCard(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        children: [
          for (var i = 0; i < points.length; i++) ...[
            if (i > 0)
              Divider(
                height: DonySpacing.lg,
                color: cs.outline.withValues(alpha: 0.5),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: DonyIcon(points[i].$1, size: 18, color: cs.primary),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Text(
                    points[i].$2,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
