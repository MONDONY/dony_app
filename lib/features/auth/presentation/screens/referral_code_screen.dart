import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/pending_referral_code_store.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ReferralCodeScreen extends StatefulWidget {
  const ReferralCodeScreen({
    super.key,
    required this.progress,
    this.pendingCodeStore,
  });

  /// Le parrainage est hors décompte (spec §4.2) : `progress.current` y vaut
  /// toujours `null`, aucun segment n'est donc jamais à moitié rempli ici.
  final OnboardingProgress progress;

  /// Code venu d'un lien d'invitation (`yadony://referral?code=…`) : il
  /// pré-remplit le champ, la personne valide elle-même.
  final PendingReferralCodeStore? pendingCodeStore;

  @override
  State<ReferralCodeScreen> createState() => _ReferralCodeScreenState();
}

class _ReferralCodeScreenState extends State<ReferralCodeScreen> {
  late final String? _linkCode = widget.pendingCodeStore?.current;
  late final _ctrl = TextEditingController(text: _linkCode);
  late final _isNotEmpty = ValueNotifier<bool>(_linkCode != null);

  /// Le champ porte encore le code du lien : la carte et le champ le disent.
  late final _prefilled = ValueNotifier<bool>(_linkCode != null);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      _isNotEmpty.value = _ctrl.text.trim().isNotEmpty;
      _prefilled.value =
          _linkCode != null && _ctrl.text.trim().toUpperCase() == _linkCode;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _isNotEmpty.dispose();
    _prefilled.dispose();
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
    // Appliqué ou volontairement passé : le code du lien a servi.
    unawaited(widget.pendingCodeStore?.clear());
    if (destination == '/home') {
      unawaited(
        getIt<AuthRepository>().markOnboardingSeen().catchError((_) {}),
      );
      // Fin du parcours : « Par quoi commencer ? » plutôt que l'accueil.
      context.go(firstStepsRoute);
      return;
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
                          prefilled: _prefilled,
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
    required this.prefilled,
    required this.isLoading,
    required this.onApply,
    required this.onSkip,
  });

  final OnboardingProgress progress;
  final TextEditingController ctrl;
  final ValueNotifier<bool> isNotEmpty;
  final ValueNotifier<bool> prefilled;
  final bool isLoading;
  final VoidCallback onApply;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthFlowHeader.gauge(
          segments: progress.segments,
          label: l.authReferralGaugeLabel,
        ),
        const SizedBox(height: DonySpacing.md),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: DonySpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: prefilled,
                  builder: (context, fromLink, _) => AuthIntroCard.compact(
                    iconAsset: 'gift',
                    title: l.authReferralTitle,
                    body: fromLink
                        ? l.authReferralPrefilledBody
                        : l.authReferralBody,
                    footnote: l.authReferralFootnote,
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
                const SizedBox(height: DonySpacing.md),
                _ReferralActionPanel(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: prefilled,
                    builder: (context, fromLink, _) =>
                        _CodeField(ctrl: ctrl, fromLink: fromLink),
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
              label: l.authReferralApply,
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

/// Champ du code. Venu du lien, il porte une coche verte et une ligne qui
/// dit d'où vient le code.
class _CodeField extends StatelessWidget {
  const _CodeField({required this.ctrl, required this.fromLink});

  final TextEditingController ctrl;
  final bool fromLink;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DonyTextField(
          controller: ctrl,
          label: l.authReferralCodeLabel,
          hint: l.authReferralCodeHint,
          suffixIcon: fromLink
              ? Padding(
                  padding: const EdgeInsets.all(DonySpacing.md),
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.success,
                      shape: BoxShape.circle,
                    ),
                    child: const DonyIcon(
                      'check',
                      size: 14,
                      color: DonyColors.textOnBrand,
                    ),
                  ),
                )
              : null,
        ),
        if (fromLink) ...[
          const SizedBox(height: DonySpacing.sm),
          Text(
            l.authReferralPrefilledHint,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: cs.success),
          ),
        ],
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
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthFlowHeader.gauge(
          segments: progress.segments,
          label: l.authReferralGaugeLabel,
        ),
        const SizedBox(height: DonySpacing.md),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: DonySpacing.base),
            child:
                AuthIntroCard(
                      iconAsset: 'circle-check',
                      title: l.authReferralSuccessTitle,
                      body: l.authReferralSuccessBody,
                      footnote: l.authReferralSuccessFootnote,
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
            label: l.authReferralContinueHome,
            iconAsset: 'arrow-right',
            onPressed: onContinue,
            variant: DonyButtonVariant.success,
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
      ],
    );
  }
}
