import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ReferralCodeScreen extends StatefulWidget {
  const ReferralCodeScreen({super.key, required this.progress});

  /// Le parrainage est hors décompte (spec §4.2) : `progress.current` y vaut
  /// toujours `null`, aucun segment n'est donc jamais à moitié rempli ici.
  final OnboardingProgress progress;

  @override
  State<ReferralCodeScreen> createState() => _ReferralCodeScreenState();
}

class _ReferralCodeScreenState extends State<ReferralCodeScreen> {
  final _ctrl = TextEditingController();
  final _isNotEmpty = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => _isNotEmpty.value = _ctrl.text.trim().isNotEmpty);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _isNotEmpty.dispose();
    super.dispose();
  }

  /// Le parrainage n'est plus systématiquement l'écran terminal : il ne
  /// l'est que si aucune étape (identité, paiements) n'est encore à faire.
  /// [OnboardingProgress.nextAfter] tranche, en partant de l'adresse : sans
  /// lui, un utilisateur à qui il reste l'identité ou les paiements filerait
  /// droit sur `/home` sans jamais les voir. `nextAfter` plutôt que `next`
  /// parce qu'une étape *passée* n'entre pas dans `done` — `next` la
  /// redésignerait et le parcours boucleraient sur elle sans fin.
  ///
  /// `onboarding_seen_at` ne se pose donc plus qu'ici, quand la destination
  /// est réellement `/home` — jamais quand le parcours continue. Cet écran
  /// n'a pas accès au cubit de l'étape informations (hors de son arbre de
  /// providers) — on passe donc directement par le repository. Jamais
  /// awaité, jamais bloquant : un échec réseau ne doit pas retenir
  /// l'utilisateur sur cet écran, et l'appel est idempotent côté serveur.
  void _continue(BuildContext context) {
    final destination =
        widget.progress
            .nextAfter(OnboardingStep.personalInfo)
            ?.onboardingRoute ??
        '/home';
    if (destination == '/home') {
      unawaited(
        getIt<AuthRepository>().markOnboardingSeen().catchError((_) {}),
      );
    }
    context.go(destination);
  }

  void _apply() {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      return;
    }
    context.read<ReferralBloc>().add(ReferralRedeemRequested(code));
  }

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return BlocConsumer<ReferralBloc, ReferralState>(
      listener: (context, state) {
        if (state is ReferralRedeemError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      builder: (context, state) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AuthFlowBackground(),
            SafeArea(
              child: DonyLayout.constrained(
                context,
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    h,
                    DonySpacing.base,
                    h,
                    DonySpacing.base + bottom,
                  ),
                  child: state is ReferralRedeemed
                      ? _SuccessView(
                          progress: widget.progress,
                          onContinue: () => _continue(context),
                        )
                      : _FormView(
                          progress: widget.progress,
                          ctrl: _ctrl,
                          isNotEmpty: _isNotEmpty,
                          isLoading: state is ReferralRedeemLoading,
                          onApply: _apply,
                          onSkip: () => _continue(context),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Form view ─────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  const _FormView({
    required this.progress,
    required this.ctrl,
    required this.isNotEmpty,
    required this.isLoading,
    required this.onApply,
    required this.onSkip,
  });

  final OnboardingProgress progress;
  final TextEditingController ctrl;
  final ValueNotifier<bool> isNotEmpty;
  final bool isLoading;
  final VoidCallback onApply;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthFlowHeader.gauge(segments: progress.segments, label: 'Parrainage'),
        const SizedBox(height: DonySpacing.md),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: DonySpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthIntroCard.compact(
                  iconAsset: 'gift',
                  title: 'Tu as été invité par un ami ?',
                  body:
                      'Entre son code pour qu’il soit récompensé à ta première livraison.',
                  footnote:
                      'Cette étape est facultative. Tu peux entrer dans Yadony sans code.',
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
                const SizedBox(height: DonySpacing.md),
                _ReferralActionPanel(
                  child: DonyTextField(
                    controller: ctrl,
                    label: 'Code parrain',
                    hint: 'Ex : JEAN0234',
                  ),
                ).animate().fadeIn(delay: 120.ms, duration: 300.ms),
              ],
            ),
          ),
        ),
        // Le bouton et le lien vivaient dans le panneau, au milieu de l'écran :
        // ils rejoignent la zone d'action commune, en bas comme partout.
        AuthFlowActions(
          primary: ValueListenableBuilder<bool>(
            valueListenable: isNotEmpty,
            builder: (context, hasText, _) => DonyButton(
              label: 'Appliquer le code',
              iconAsset: 'gift',
              isLoading: isLoading,
              onPressed: hasText && !isLoading ? onApply : null,
            ),
          ),
          skipEnabled: !isLoading,
          onSkip: onSkip,
        ),
      ],
    );
  }
}

class _ReferralActionPanel extends StatelessWidget {
  const _ReferralActionPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: isLight
            ? cs.surface.withValues(alpha: 0.94)
            : DonyColors.ink900.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(DonyRadius.sheet),
        border: Border.all(
          color: isLight
              ? cs.outline.withValues(alpha: 0.42)
              : DonyColors.neutral0.withValues(alpha: 0.18),
        ),
        boxShadow: DonyShadow.lg,
      ),
      child: child,
    );
  }
}

// ── Success view ──────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.progress, required this.onContinue});
  final OnboardingProgress progress;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthFlowHeader.gauge(segments: progress.segments, label: 'Parrainage'),
        const SizedBox(height: DonySpacing.md),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: DonySpacing.base),
            child:
                const AuthIntroCard(
                      iconAsset: 'circle-check',
                      title: 'Code appliqué !',
                      body:
                          'Ton ami sera récompensé dès que tu complètes ta première livraison.',
                      footnote:
                          'Ton compte Yadony est prêt. Tu peux commencer à rechercher, envoyer ou suivre tes colis.',
                    )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .scale(
                      duration: 300.ms,
                      curve: Curves.easeOutCubic,
                      begin: const Offset(0.96, 0.96),
                    ),
          ),
        ),
        AuthFlowActions(
          primary: DonyButton(
            label: 'Continuer vers l\'accueil',
            iconAsset: 'arrow-right',
            onPressed: onContinue,
            variant: DonyButtonVariant.success,
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
      ],
    );
  }
}
