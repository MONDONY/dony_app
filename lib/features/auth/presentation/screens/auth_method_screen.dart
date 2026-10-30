import 'dart:async';
import 'dart:ui';

import 'package:dony/core/config/google_auth_flag.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/post_signup_route.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthMethodScreen extends StatelessWidget {
  const AuthMethodScreen({super.key});

  bool get _showAppleButton => defaultTargetPlatform == TargetPlatform.iOS;

  bool get _showGoogleButton => googleSignInAvailable;

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthNewAccountAuthenticated) {
            context.go(resolvePostSignupRoute(state.user));
          } else if (state is AuthAuthenticated) {
            context.go('/auth/local');
          } else if (state is AuthOAuthNewUser) {
            // OAuth user not yet registered → auto-register (backend forces SENDER)
            context.read<AuthBloc>().add(
              AuthRegisterWithEmailRequested(email: state.email),
            );
          } else if (state is AuthGuestSessionReady) {
            context.go('/home');
          } else if (state is AuthError) {
            ErrorPresenter.show(context, state.error);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _LoginBackground(),
            SafeArea(
              child: DonyLayout.constrained(
                context,
                // FLUTTER-RG : tout le panneau (téléphone, Apple, Google,
                // e-mail et « Parcourir sans compte ») tient à l'écran dès
                // l'arrivée, iPhone SE compris. L'espace libre se place entre
                // la barre du haut et l'accroche (Spacer) au lieu d'une hauteur
                // fixe ; la densité suit la hauteur disponible. Le défilement
                // reste en secours (très petit écran, grande police).
                LayoutBuilder(
                  builder: (context, constraints) {
                    final density = _LoginDensity.forHeight(
                      constraints.maxHeight,
                    );
                    return CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            h,
                            density.topPadding,
                            h,
                            density.bottomPadding,
                          ),
                          sliver: SliverFillRemaining(
                            hasScrollBody: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _LoginTopBar(),
                                const Spacer(),
                                SizedBox(height: density.introGap),
                                _LoginIntro(density: density)
                                    .animate()
                                    .fadeIn(delay: 60.ms)
                                    .slideY(
                                      begin: 0.04,
                                      curve: Curves.easeOutCubic,
                                    ),
                                SizedBox(height: density.introGap),
                                _AuthActionsPanel(
                                      showAppleButton: _showAppleButton,
                                      showGoogleButton: _showGoogleButton,
                                      density: density,
                                    )
                                    .animate()
                                    .fadeIn(delay: 120.ms)
                                    .slideY(
                                      begin: 0.04,
                                      curve: Curves.easeOutCubic,
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Densité de l'écran selon la hauteur disponible (zone sûre déduite).
///
/// - large (≥ 820 pt, iPhone Pro Max) : l'écran d'origine ;
/// - compacte (iPhone 12/13/14, 763 pt) : titre plus court, boutons de 48 ;
/// - serrée (< 660 pt, iPhone SE 647 pt) : sans le sous-titre, boutons de 44,
///   la cible tactile minimale.
@immutable
class _LoginDensity {
  const _LoginDensity({
    required this.titleSize,
    required this.showSubtitle,
    required this.introGap,
    required this.panelPadding,
    required this.gap,
    required this.primaryHeight,
    required this.buttonHeight,
    required this.topPadding,
    required this.bottomPadding,
  });

  factory _LoginDensity.forHeight(double height) {
    if (height >= 820) {
      return const _LoginDensity(
        titleSize: 32,
        showSubtitle: true,
        introGap: DonySpacing.lg,
        panelPadding: DonySpacing.base,
        gap: DonySpacing.sm,
        primaryHeight: 56,
        buttonHeight: 52,
        topPadding: DonySpacing.base,
        bottomPadding: DonySpacing.xl,
      );
    }
    if (height >= 660) {
      return const _LoginDensity(
        titleSize: 26,
        showSubtitle: true,
        introGap: DonySpacing.base,
        panelPadding: DonySpacing.md,
        gap: DonySpacing.sm,
        primaryHeight: 48,
        buttonHeight: 48,
        topPadding: DonySpacing.sm,
        bottomPadding: DonySpacing.md,
      );
    }
    return const _LoginDensity(
      titleSize: 24,
      showSubtitle: false,
      introGap: DonySpacing.md,
      panelPadding: DonySpacing.md,
      gap: DonySpacing.xs + DonySpacing.xxs,
      primaryHeight: 44,
      buttonHeight: 44,
      topPadding: DonySpacing.xs,
      bottomPadding: DonySpacing.sm,
    );
  }

  final double titleSize;
  final bool showSubtitle;
  final double introGap;
  final double panelPadding;
  final double gap;
  final double primaryHeight;
  final double buttonHeight;
  final double topPadding;
  final double bottomPadding;
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/illustrations/auth-login-security.png',
          fit: BoxFit.cover,
          semanticLabel: context.l10n.authMethodIllustrationLabel,
          opacity: AlwaysStoppedAnimation(isLight ? 0.32 : 1),
        ),
        // Voile uni : lisibilité du contenu posé sur l'illustration.
        ColoredBox(
          color: isLight
              ? Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.86)
              : DonyColors.ink900.withValues(alpha: 0.72),
        ),
      ],
    );
  }
}

class _LoginTopBar extends StatelessWidget {
  const _LoginTopBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DonyRadius.full),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
              decoration: BoxDecoration(
                color: cs.surface.withValues(
                  alpha: cs.brightness == Brightness.light ? 0.92 : 0.82,
                ),
                borderRadius: BorderRadius.circular(DonyRadius.full),
                border: Border.all(
                  color: cs.outline.withValues(
                    alpha: cs.brightness == Brightness.light ? 0.42 : 0.28,
                  ),
                ),
              ),
              child: const Center(child: DonyLogo(fontSize: 28)),
            ),
          ),
        ),
        const Spacer(),
        const _SecureBadge(),
        const DonyFeedbackButton(),
      ],
    );
  }
}

class _SecureBadge extends StatelessWidget {
  const _SecureBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isLight = cs.brightness == Brightness.light;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.full),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
          decoration: BoxDecoration(
            color: isLight
                ? cs.primaryContainer.withValues(alpha: 0.92)
                : DonyColors.ink900.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(DonyRadius.full),
            border: Border.all(
              color: isLight
                  ? cs.primary.withValues(alpha: 0.18)
                  : DonyColors.neutral0.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyIcon('shield-check', size: 18, color: cs.success),
              const SizedBox(width: DonySpacing.xs),
              Text(
                context.l10n.authMethodSecureBadge,
                style: tt.labelLarge?.copyWith(
                  color: isLight ? cs.primary : DonyColors.neutral0,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginIntro extends StatelessWidget {
  const _LoginIntro({required this.density});

  final _LoginDensity density;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isLight = cs.brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.authMethodTitle,
          style: tt.displayLarge?.copyWith(
            color: isLight ? cs.onSurface : DonyColors.neutral0,
            fontWeight: FontWeight.w900,
            fontSize: density.titleSize,
            height: 1.05,
          ),
        ),
        if (density.showSubtitle) ...[
          const SizedBox(height: DonySpacing.sm),
          Text(
            context.l10n.authMethodSubtitle,
            style: (density.titleSize < 32 ? tt.bodyMedium : tt.bodyLarge)
                ?.copyWith(
                  color: isLight
                      ? cs.onSurfaceVariant
                      : DonyColors.neutral0.withValues(alpha: 0.84),
                  height: 1.4,
                ),
          ),
        ],
      ],
    );
  }
}

/// Méthode de connexion lancée depuis cet écran, pour savoir quel bouton
/// porte le spinner pendant que l'`AuthBloc` travaille.
enum _PendingAuth { apple, google, guest }

class _AuthActionsPanel extends StatefulWidget {
  const _AuthActionsPanel({
    required this.showAppleButton,
    required this.showGoogleButton,
    required this.density,
  });

  final bool showAppleButton;
  final bool showGoogleButton;
  final _LoginDensity density;

  @override
  State<_AuthActionsPanel> createState() => _AuthActionsPanelState();
}

/// Pendant une connexion Apple, Google ou invitée, les boutons restaient
/// actifs et muets : aucun retour visuel entre le toucher et la réponse du
/// fournisseur. Les testeurs iOS tapaient alors à répétition (rage clicks
/// PostHog du 27/09). Le bouton touché affiche désormais un spinner et les
/// autres se désactivent tant que le bloc est occupé.
///
/// L'occupation ne se lit pas seulement sur `AuthLoading` : l'`AuthBloc` est
/// global et peut être en chargement pour une autre raison à l'arrivée sur
/// l'écran. On ne bloque que si l'utilisateur a lancé une méthode d'ici.
class _AuthActionsPanelState extends State<_AuthActionsPanel> {
  final _pending = ValueNotifier<_PendingAuth?>(null);

  /// Acceptation explicite des CGU avant toute création de compte ou
  /// connexion (guideline Apple 1.2 : contenu publié par les utilisateurs).
  /// La simple mention « En continuant vous acceptez… » ne suffit pas. Le
  /// mode invité reste libre : il ne permet de rien publier.
  final _terms = ValueNotifier<_TermsState>(_TermsState.unchecked);

  /// Un `TapGestureRecognizer` se libère à la main : construit dans `build()`,
  /// il fuirait à chaque reconstruction de l'écran.
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => unawaited(context.push('/legal/terms'));
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => unawaited(context.push('/legal/privacy'));

  @override
  void dispose() {
    _pending.dispose();
    _terms.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  /// Lance [action] si les conditions sont acceptées ; sinon signale la case
  /// à cocher plutôt que de griser des boutons qui sembleraient en panne.
  VoidCallback _withTerms(VoidCallback action) => () {
    if (_terms.value == _TermsState.accepted) {
      action();
    } else {
      _terms.value = _TermsState.missing;
    }
  };

  static bool _isBusy(AuthState state) =>
      state is AuthLoading || state is AuthOAuthNewUser;

  void _start(_PendingAuth method, AuthEvent event) {
    _pending.value = method;
    context.read<AuthBloc>().add(event);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, state) => !_isBusy(state),
      // Annulation (Google revient à `AuthInitial`), erreur ou succès : le
      // bouton touché n'a plus rien à attendre.
      listener: (_, _) => _pending.value = null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DonyRadius.sheet),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.all(widget.density.panelPadding),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<_TermsState>(
                  valueListenable: _terms,
                  builder: (context, terms, _) => _TermsCheckbox(
                    state: terms,
                    termsTap: _termsTap,
                    privacyTap: _privacyTap,
                    onChanged: (accepted) => _terms.value = accepted
                        ? _TermsState.accepted
                        : _TermsState.unchecked,
                  ),
                ),
                SizedBox(height: widget.density.gap),
                ValueListenableBuilder<_PendingAuth?>(
                  valueListenable: _pending,
                  builder: (context, pending, _) {
                    final authState = context.watch<AuthBloc>().state;
                    final active = pending != null && _isBusy(authState)
                        ? pending
                        : null;
                    final locked = active != null;
                    return _buildActions(
                      context,
                      active: active,
                      locked: locked,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context, {
    required _PendingAuth? active,
    required bool locked,
  }) {
    final d = widget.density;
    final gap = SizedBox(height: d.gap);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: smsAuthEnabledListenable,
          builder: (_, phoneEnabled, _) {
            if (!phoneEnabled) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PhoneCta(
                  height: d.primaryHeight,
                  onTap: locked
                      ? null
                      : _withTerms(() => context.push('/auth/phone')),
                ),
                gap,
              ],
            );
          },
        ),
        if (widget.showAppleButton) ...[
          _AppleCta(
            label: context.l10n.authMethodContinueWithApple,
            height: d.buttonHeight,
            isLoading: active == _PendingAuth.apple,
            onTap: locked
                ? null
                : _withTerms(
                    () => _start(
                      _PendingAuth.apple,
                      const AuthAppleSignInRequested(),
                    ),
                  ),
          ),
          gap,
        ],
        if (widget.showGoogleButton) ...[
          _GoogleCta(
            height: d.buttonHeight,
            isLoading: active == _PendingAuth.google,
            onTap: locked
                ? null
                : _withTerms(
                    () => _start(
                      _PendingAuth.google,
                      const AuthGoogleSignInRequested(),
                    ),
                  ),
          ),
          gap,
        ],
        _SocialCta(
          iconAsset: 'mail',
          label: context.l10n.authMethodContinueWithEmail,
          height: d.buttonHeight,
          onTap: locked ? null : _withTerms(() => context.push('/auth/email')),
        ),
        gap,
        const _OrDivider(),
        gap,
        _GuestCta(
          key: const Key('auth-guest-cta'),
          buttonHeight: d.buttonHeight,
          compact: d.primaryHeight < 56,
          isLoading: active == _PendingAuth.guest,
          onTap: locked
              ? null
              : () => _start(
                  _PendingAuth.guest,
                  const AuthGuestSessionRequested(),
                ),
        ),
      ],
    );
  }
}

enum _TermsState { unchecked, accepted, missing }

/// Case « J'accepte les CGU et la politique de confidentialité », avec la
/// clause de tolérance zéro exigée par Apple. Les deux documents restent
/// ouvrables depuis le libellé, avant toute création de compte : les
/// relecteurs Apple et Google les ouvrent depuis cet écran (route publique
/// `/legal/…`).
class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.state,
    required this.termsTap,
    required this.privacyTap,
    required this.onChanged,
  });

  final _TermsState state;
  final TapGestureRecognizer termsTap;
  final TapGestureRecognizer privacyTap;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final accepted = state == _TermsState.accepted;
    final missing = state == _TermsState.missing;
    final linkStyle = tt.bodySmall?.copyWith(
      color: cs.primary,
      decoration: TextDecoration.underline,
      decorationColor: cs.primary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => onChanged(!accepted),
          borderRadius: BorderRadius.circular(DonyRadius.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Checkbox(
                  value: accepted,
                  onChanged: (value) => onChanged(value ?? false),
                  isError: missing,
                  semanticLabel: l10n.authTermsCheckboxSemantics,
                ),
              ),
              const SizedBox(width: DonySpacing.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: DonySpacing.sm),
                  child: Text.rich(
                    TextSpan(
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(text: l10n.authLegalPrefix),
                        TextSpan(
                          text: l10n.authLegalTermsLink,
                          style: linkStyle,
                          recognizer: termsTap,
                        ),
                        TextSpan(text: l10n.authLegalMiddle),
                        TextSpan(
                          text: l10n.authLegalPrivacyLink,
                          style: linkStyle,
                          recognizer: privacyTap,
                        ),
                        TextSpan(text: l10n.authLegalZeroTolerance),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (missing)
          Padding(
            padding: const EdgeInsets.only(left: 44 + DonySpacing.xs),
            child: Text(
              l10n.authTermsRequired,
              style: tt.bodySmall?.copyWith(color: cs.error),
            ),
          ),
      ],
    );
  }
}

/// Spinner des boutons contour pendant la connexion, à la taille de l'icône
/// qu'il remplace pour que le bouton ne bouge pas.
class _CtaSpinner extends StatelessWidget {
  const _CtaSpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _PhoneCta extends StatelessWidget {
  const _PhoneCta({required this.onTap, required this.height});
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DonyButton(
        label: context.l10n.authMethodContinueWithPhone,
        onPressed: onTap,
      ),
    );
  }
}

class _SocialCta extends StatelessWidget {
  const _SocialCta({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    required this.height,
  });
  final String iconAsset;
  final String label;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: DonyIcon(iconAsset, size: 20, color: cs.onSurface),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outline.withValues(alpha: 0.72)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
        ),
      ),
    );
  }
}

/// Bouton officiel Sign in with Apple (logo et typographie fournis par le
/// package, conformes aux Apple Design Resources — guideline 4).
class _AppleCta extends StatelessWidget {
  const _AppleCta({
    required this.label,
    required this.onTap,
    required this.height,
    this.isLoading = false,
  });
  final String label;
  final VoidCallback? onTap;
  final double height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(DonyRadius.lg);
    final background = isDark ? Colors.white : Colors.black;
    final button = SignInWithAppleButton(
      text: label,
      height: height,
      borderRadius: radius,
      style: isDark
          ? SignInWithAppleButtonStyle.white
          : SignInWithAppleButtonStyle.black,
      onPressed: isLoading ? () {} : (onTap ?? () {}),
    );
    return Opacity(
      opacity: onTap == null && !isLoading ? 0.5 : 1,
      child: IgnorePointer(
        ignoring: onTap == null && !isLoading,
        child: Stack(
          children: [
            button,
            if (isLoading)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: radius,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.black : Colors.white,
                      ),
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

class _GoogleCta extends StatelessWidget {
  const _GoogleCta({
    required this.onTap,
    required this.height,
    this.isLoading = false,
  });
  final VoidCallback? onTap;
  final double height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: isLoading ? () {} : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outline.withValues(alpha: 0.72)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) const _CtaSpinner() else const _GoogleLogo(),
            const SizedBox(width: DonySpacing.sm),
            Text(context.l10n.authMethodContinueWithGoogle),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final sectors = [
      (0.0, 0.5236, const Color(0xFF4285F4)), // blue
      (0.5236, 1.0472, const Color(0xFFEA4335)), // red top-right
      (1.0472, 2.6180, const Color(0xFFFBBC05)), // yellow
      (2.6180, 3.6652, const Color(0xFF34A853)), // green
      (3.6652, 6.2832, const Color(0xFF4285F4)), // blue (remainder)
    ];

    for (final (start, end, color) in sectors) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(cx, cy)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          start,
          end - start,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }

    // White inner circle
    canvas.drawCircle(Offset(cx, cy), r * 0.6, Paint()..color = Colors.white);

    // Blue right notch (Google "G" opening)
    final notchPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.12, r * 0.95, r * 0.24),
      notchPaint,
    );
    canvas.drawCircle(Offset(cx + r * 0.95, cy), r * 0.12, notchPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Divider(color: cs.outline.withValues(alpha: 0.52), height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
          child: Text(
            context.l10n.authMethodOr,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: cs.outline.withValues(alpha: 0.52), height: 1),
        ),
      ],
    );
  }
}

class _GuestCta extends StatelessWidget {
  const _GuestCta({
    super.key,
    required this.onTap,
    required this.buttonHeight,
    required this.compact,
    this.isLoading = false,
  });

  final VoidCallback? onTap;
  final double buttonHeight;
  final bool compact;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: context.l10n.authMethodGuestSemantics,
      child: Container(
        padding: EdgeInsets.all(compact ? DonySpacing.sm : DonySpacing.md),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(
            alpha: cs.brightness == Brightness.light ? 0.62 : 0.10,
          ),
          borderRadius: BorderRadius.circular(DonyRadius.xl),
          border: Border.all(
            color: cs.primary.withValues(
              alpha: cs.brightness == Brightness.light ? 0.18 : 0.28,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: buttonHeight,
              child: DonyButton(
                label: context.l10n.authMethodBrowseWithoutAccount,
                iconAsset: 'search',
                variant: DonyButtonVariant.secondary,
                isLoading: isLoading,
                onPressed: onTap,
              ),
            ),
            SizedBox(height: compact ? DonySpacing.xs + 2 : DonySpacing.sm),
            Text(
              context.l10n.authMethodGuestNotice,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
