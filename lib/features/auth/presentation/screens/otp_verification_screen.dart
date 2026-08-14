import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/post_signup_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum OtpMode { phone, email }

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    this.mode = OtpMode.phone,
    this.contact = '',
    this.fromProfile = false,
  });

  final OtpMode mode;
  final String contact;
  final bool fromProfile;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _attemptCount = 0;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _verify() {
    if (_otpCode.length != 6) {
      DonySnackbar.show(
        context,
        message: 'Entrez le code à 6 chiffres',
        type: DonySnackbarType.error,
      );
      return;
    }
    _attemptCount++;
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.otpSubmitted,
        properties: {'attempt_count': _attemptCount},
      ),
    );
    if (widget.mode == OtpMode.email) {
      context.read<AuthBloc>().add(
        AuthEmailOtpVerifyRequested(email: widget.contact, code: _otpCode),
      );
    } else {
      final state = context.read<AuthBloc>().state;
      if (state is! AuthOtpSent) {
        DonySnackbar.show(
          context,
          message: 'Session expirée, veuillez recommencer',
          type: DonySnackbarType.error,
        );
        return;
      }
      context.read<AuthBloc>().add(
        AuthPhoneVerified(
          verificationId: state.verificationId,
          smsCode: _otpCode,
        ),
      );
    }
  }

  void _resend() {
    for (final c in _controllers) {
      c.clear();
    }
    if (widget.mode == OtpMode.email) {
      context.read<AuthBloc>().add(AuthEmailOtpSendRequested(widget.contact));
    } else {
      final state = context.read<AuthBloc>().state;
      final phoneNumber = state is AuthOtpSent ? state.phoneNumber : '';
      context.read<AuthBloc>().add(AuthSendOtpRequested(phoneNumber));
    }
  }

  /// Compte créé : on enchaîne sur la suite de l'inscription.
  ///
  /// L'étape « code PIN » a quitté ce parcours, le verrouillage étant devenu un
  /// réglage facultatif (Réglages › Sécurité). C'est donc ici que l'inscription
  /// est considérée comme terminée.
  Future<void> _continueAfterSignup(BuildContext context) async {
    unawaited(
      getIt<AnalyticsService>().logEvent(AnalyticsEvents.signupCompleted),
    );
    final route = await resolvePostSignupRoute(
      getIt<AnalyticsService>(),
      getIt<HiveService>().userPrefs,
    );
    if (context.mounted) {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (widget.fromProfile) {
            // ── Mode profil : après vérif → retour au profil ────────────
            if (state is AuthAuthenticated) {
              if (widget.mode == OtpMode.phone && widget.contact.isNotEmpty) {
                // Sauvegarde du numéro dans le backend
                context.read<AuthBloc>().add(
                  AuthUpdateProfileRequested(phoneNumber: widget.contact),
                );
              } else {
                // Email vérifié via OTP — déjà sauvegardé côté backend
                DonySnackbar.show(
                  context,
                  message: 'Email vérifié avec succès !',
                  type: DonySnackbarType.success,
                );
                context.go('/profile');
              }
            } else if (state is AuthProfileUpdated) {
              DonySnackbar.show(
                context,
                message: 'Numéro ajouté avec succès !',
                type: DonySnackbarType.success,
              );
              context.go('/profile');
            } else if (state is AuthError) {
              ErrorPresenter.show(context, state.error);
            }
            return;
          }
          // ── Mode inscription (comportement existant) ─────────────────
          if (widget.mode == OtpMode.email) {
            if (state is AuthEmailOtpVerified) {
              // Email vérifié → auto-register (backend force SENDER)
              context.read<AuthBloc>().add(
                AuthRegisterWithEmailRequested(email: state.email),
              );
            } else if (state is AuthAuthenticated) {
              unawaited(_continueAfterSignup(context));
            } else if (state is AuthError) {
              ErrorPresenter.show(context, state.error);
            }
          } else {
            if (state is AuthOtpVerified) {
              context.read<AuthBloc>().add(const AuthRegisterRequested());
            } else if (state is AuthAuthenticated) {
              unawaited(_continueAfterSignup(context));
            } else if (state is AuthError) {
              ErrorPresenter.show(context, state.error);
            }
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          final secondsLeft = state is AuthOtpSent
              ? state.secondsLeft
              : (state is AuthEmailOtpSent ? state.secondsLeft : 60);
          final contact = widget.mode == OtpMode.email
              ? widget.contact
              : (state is AuthOtpSent ? state.phoneNumber : '');
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          final h = DonyLayout.hPadding(context);
          final bottom = MediaQuery.paddingOf(context).bottom;

          return SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top bar ──────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(h, DonySpacing.md, h, 0),
                  child: Row(
                    children: [
                      const DonyAppBarBackButton(),
                      const Spacer(),
                      DonyStepPill(
                        current: 2,
                        total: 3,
                        label: widget.mode == OtpMode.email
                            ? 'Code email'
                            : 'Code SMS',
                      ),
                    ],
                  ),
                ),

                // ── Scrollable content ───────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      h,
                      DonySpacing.lg,
                      h,
                      DonySpacing.xl,
                    ),
                    child: DonyLayout.constrained(
                      context,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: DonyHeroAvatar(
                              emoji: widget.mode == OtpMode.email ? '📧' : '🔢',
                              size: 72,
                            ),
                          ),
                          const SizedBox(height: DonySpacing.xl),
                          Text(
                            widget.mode == OtpMode.email
                                ? 'Code reçu ?'
                                : 'Entrez le code',
                            style: tt.displayLarge?.copyWith(
                              color: cs.onSurface,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: DonySpacing.sm),
                          Text.rich(
                            TextSpan(
                              style: tt.bodyLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.5,
                              ),
                              children: [
                                TextSpan(
                                  text: widget.mode == OtpMode.email
                                      ? 'Code envoyé à '
                                      : 'Code envoyé au ',
                                ),
                                TextSpan(
                                  text: contact,
                                  style: tt.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: DonySpacing.xxl),

                          // OTP 6-digit input
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                              return SizedBox(
                                width:
                                    (DonyLayout.screenWidth(context) -
                                        h * 2 -
                                        DonySpacing.sm * 5) /
                                    6,
                                height: 56,
                                child: TextFormField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: tt.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    filled: true,
                                    fillColor: cs.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        DonyRadius.md,
                                      ),
                                      borderSide: BorderSide(color: cs.outline),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        DonyRadius.md,
                                      ),
                                      borderSide: BorderSide(color: cs.outline),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        DonyRadius.md,
                                      ),
                                      borderSide: BorderSide(
                                        color: cs.primary,
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (value) {
                                    if (value.isNotEmpty && index < 5) {
                                      _focusNodes[index + 1].requestFocus();
                                    } else if (value.isEmpty && index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                  },
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: DonySpacing.xl),

                          // Resend
                          GestureDetector(
                            onTap: secondsLeft <= 0 ? _resend : null,
                            child: Text(
                              secondsLeft > 0
                                  ? 'Renvoyer le code ($secondsLeft s)'
                                  : 'Renvoyer le code',
                              style: tt.bodyMedium?.copyWith(
                                color: secondsLeft > 0
                                    ? cs.onSurfaceVariant
                                    : cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Pinned CTA ───────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(top: BorderSide(color: cs.outline)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    h,
                    DonySpacing.base,
                    h,
                    DonySpacing.base + bottom,
                  ),
                  child: DonyButton(
                    label: 'Vérifier',
                    onPressed: isLoading ? null : _verify,
                    isLoading: isLoading,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
