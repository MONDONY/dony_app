import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran facultatif « Parrainage » de l'inscription, juste après « Faisons
/// connaissance » (`profileBasicsRoute`) et avant la fin d'inscription
/// (`firstStepsRoute`).
///
/// Placé après le prénom pour que le serveur le connaisse quand il crée le
/// code de bienvenue. Hors du préfixe `/onboarding`, que le routeur traite
/// comme public : cet écran suppose un compte connecté.
const String referralCodeRoute = '/auth/referral-code';

/// Un code, une validation, « Passer » toujours visible (aussi après un
/// refus). Le code passe par [ReferralBloc] (`POST /me/referral/redeem`) :
/// jamais de logique réseau dans l'écran.
///
/// Un code venu d'un lien d'invitation est déjà appliqué en quittant
/// « Faisons connaissance » : l'écran n'est alors pas montré (voir
/// `ProfileBasicsScreen`).
class ReferralCodeScreen extends StatefulWidget {
  const ReferralCodeScreen({super.key, required this.analytics});

  /// Mesure : aucune propriété ne porte le code saisi.
  final AnalyticsService analytics;

  @override
  State<ReferralCodeScreen> createState() => _ReferralCodeScreenState();
}

class _ReferralCodeScreenState extends State<ReferralCodeScreen> {
  final _ctrl = TextEditingController();
  final _hasText = ValueNotifier<bool>(false);

  /// Dernier refus, tant que la personne n'a pas touché au champ.
  final _error = ValueNotifier<AppException?>(null);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        widget.analytics.logEvent(AnalyticsEvents.referralSignupViewed),
      );
    });
  }

  void _onChanged() {
    _hasText.value = _ctrl.text.trim().isNotEmpty;
    if (_error.value != null) _error.value = null;
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    _hasText.dispose();
    _error.dispose();
    super.dispose();
  }

  void _apply(BuildContext context) {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    _error.value = null;
    context.read<ReferralBloc>().add(ReferralRedeemRequested(code));
  }

  void _skip(BuildContext context) {
    unawaited(widget.analytics.logEvent(AnalyticsEvents.referralSignupSkipped));
    context.go(firstStepsRoute);
  }

  void _onState(BuildContext context, ReferralState state) {
    if (state is ReferralRedeemed) {
      unawaited(
        widget.analytics.logEvent(AnalyticsEvents.referralSignupApplied),
      );
      DonySnackbar.show(
        context,
        message: context.l10n.referralAutoAppliedMessage,
        type: DonySnackbarType.success,
      );
      context.go(firstStepsRoute);
    } else if (state is ReferralRedeemError) {
      _error.value = state.error;
      unawaited(
        widget.analytics.logEvent(
          AnalyticsEvents.referralSignupRejected,
          properties: {'error_code': state.error.code ?? 'unknown'},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final l = context.l10n;

    return BlocConsumer<ReferralBloc, ReferralState>(
      listener: _onState,
      builder: (context, state) {
        final isLoading = state is ReferralRedeemLoading;
        return Scaffold(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthFlowHeader.plain(),
                        const SizedBox(height: DonySpacing.md),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: DonyBadge(
                                    label: l.referralSignupEyebrow,
                                  ),
                                ),
                                const SizedBox(height: DonySpacing.sm),
                                AuthIntroCard.compact(
                                      iconAsset: 'gift',
                                      title: l.referralSignupTitle,
                                      body: l.referralSignupBody,
                                      footnote: l.referralSignupFootnote,
                                    )
                                    .animate()
                                    .fadeIn(duration: 300.ms)
                                    .slideY(begin: 0.04),
                                const SizedBox(height: DonySpacing.md),
                                DonyCard(
                                  padding: const EdgeInsets.all(
                                    DonySpacing.base,
                                  ),
                                  child: ValueListenableBuilder<AppException?>(
                                    valueListenable: _error,
                                    builder: (context, error, _) => _CodeField(
                                      ctrl: _ctrl,
                                      enabled: !isLoading,
                                      error: error,
                                      onSubmitted: () => _apply(context),
                                    ),
                                  ),
                                ).animate().fadeIn(
                                  delay: 120.ms,
                                  duration: 300.ms,
                                ),
                              ],
                            ),
                          ),
                        ),
                        AuthFlowActions(
                          skipKey: const Key('referral-code-skip'),
                          skipLabel: l.referralSignupSkip,
                          skipEnabled: !isLoading,
                          onSkip: () => _skip(context),
                          primary: ValueListenableBuilder<bool>(
                            valueListenable: _hasText,
                            builder: (context, hasText, _) => DonyButton(
                              key: const Key('referral-code-apply'),
                              label: l.referralSignupApply,
                              iconAsset: 'gift',
                              isLoading: isLoading,
                              onPressed: hasText && !isLoading
                                  ? () => _apply(context)
                                  : null,
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

/// Champ du code et, sous lui, le motif du dernier refus (reste affiché
/// jusqu'à la prochaine frappe, contrairement à un snackbar).
class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.ctrl,
    required this.enabled,
    required this.error,
    required this.onSubmitted,
  });

  final TextEditingController ctrl;
  final bool enabled;
  final AppException? error;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DonyTextField(
          key: const Key('referral-code-field'),
          controller: ctrl,
          enabled: enabled,
          label: l.referralSignupCodeLabel,
          hint: l.referralSignupCodeHint,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmitted(),
        ),
        if (error != null) ...[
          const SizedBox(height: DonySpacing.sm),
          Text(
            ErrorPresenter.resolve(error, l10n: l).message,
            key: const Key('referral-code-error'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.error),
          ),
        ],
      ],
    );
  }
}
