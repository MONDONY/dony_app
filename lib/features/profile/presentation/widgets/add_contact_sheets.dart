import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/phone/phone_country.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/widgets/dial_code_picker.dart';
import 'package:dony/features/auth/presentation/widgets/otp_code_field.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:dony/l10n/rich_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constante interne : étape de la sheet (saisie → OTP)
// ─────────────────────────────────────────────────────────────────────────────

enum _ContactStep { input, otp }

// ─────────────────────────────────────────────────────────────────────────────
// EditPhoneScreen / EditEmailScreen — écrans plein écran, même flow OTP que les
// sheets ci-dessous. Le numéro et l'email exigent une preuve de possession
// (code reçu par SMS/email) : contrairement aux autres champs de « Modifier le
// profil », ils ne peuvent jamais être des champs de saisie libre au milieu
// d'un formulaire — d'où un écran dédié, poussé au tap sur leur ligne.
// ─────────────────────────────────────────────────────────────────────────────

class EditPhoneScreen extends StatelessWidget {
  const EditPhoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stepNotifier = ValueNotifier(_ContactStep.input);
    VoidCallback? submit;

    return Scaffold(
      appBar: DonyAppBar(title: context.l10n.contactEditPhoneTitle),
      body: Column(
        children: [
          Expanded(
            child: _AddPhoneContent(
              onSubmitReady: (fn) => submit = fn,
              stepNotifier: stepNotifier,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.sm,
                DonySpacing.lg,
                DonySpacing.base,
              ),
              child: ValueListenableBuilder<_ContactStep>(
                valueListenable: stepNotifier,
                builder: (_, step, _) => BlocBuilder<AuthBloc, AuthState>(
                  builder: (ctx, state) => DonyButton(
                    label: step == _ContactStep.input
                        ? ctx.l10n.contactSendCodeAction
                        : ctx.l10n.contactVerifyAction,
                    isLoading: state is AuthLoading,
                    onPressed: state is AuthLoading
                        ? null
                        : () => submit?.call(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EditEmailScreen extends StatelessWidget {
  const EditEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stepNotifier = ValueNotifier(_ContactStep.input);
    VoidCallback? submit;

    return Scaffold(
      appBar: DonyAppBar(title: context.l10n.contactEditEmailTitle),
      body: Column(
        children: [
          Expanded(
            child: _AddEmailContent(
              onSubmitReady: (fn) => submit = fn,
              stepNotifier: stepNotifier,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.sm,
                DonySpacing.lg,
                DonySpacing.base,
              ),
              child: ValueListenableBuilder<_ContactStep>(
                valueListenable: stepNotifier,
                builder: (_, step, _) => BlocBuilder<AuthBloc, AuthState>(
                  builder: (ctx, state) => DonyButton(
                    label: step == _ContactStep.input
                        ? ctx.l10n.contactSendCodeAction
                        : ctx.l10n.contactVerifyAction,
                    isLoading: state is AuthLoading,
                    onPressed: state is AuthLoading
                        ? null
                        : () => submit?.call(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AddPhoneSheet — ajouter / mettre à jour le numéro depuis le profil
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AddPhoneSheet {
  static Future<void> show(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    VoidCallback? submit;
    final stepNotifier = ValueNotifier(_ContactStep.input);

    return DonyBottomSheet.show<void>(
      context,
      title: context.l10n.contactAddPhoneTitle,
      wrapper: (child) => BlocProvider.value(value: authBloc, child: child),
      stickyBottom: ValueListenableBuilder<_ContactStep>(
        valueListenable: stepNotifier,
        builder: (_, step, _) => BlocBuilder<AuthBloc, AuthState>(
          builder: (ctx, state) => DonyButton(
            label: step == _ContactStep.input
                ? ctx.l10n.contactSendCodeAction
                : ctx.l10n.contactVerifyAction,
            isLoading: state is AuthLoading,
            onPressed: state is AuthLoading ? null : () => submit?.call(),
          ),
        ),
      ),
      child: _AddPhoneContent(
        onSubmitReady: (fn) => submit = fn,
        stepNotifier: stepNotifier,
      ),
    ).whenComplete(stepNotifier.dispose);
  }
}

class _AddPhoneContent extends StatefulWidget {
  const _AddPhoneContent({
    required this.onSubmitReady,
    required this.stepNotifier,
  });

  final void Function(VoidCallback) onSubmitReady;
  final ValueNotifier<_ContactStep> stepNotifier;

  @override
  State<_AddPhoneContent> createState() => _AddPhoneContentState();
}

class _AddPhoneContentState extends State<_AddPhoneContent> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  PhoneCountry _country = kDefaultPhoneCountry;
  String _pendingPhone = '';

  /// Vrai entre l'envoi du code de vérification et sa réponse.
  bool _verifySubmitted = false;

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady(_handleSubmit);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (widget.stepNotifier.value == _ContactStep.input) {
      _sendOtp();
    } else {
      _verifyOtp();
    }
  }

  void _sendOtp() {
    final number = _phoneCtrl.text.trim();
    if (number.isEmpty) return;
    _pendingPhone = toE164(_country.dialCode, number);
    context.read<AuthBloc>().add(AuthSendOtpRequested(_pendingPhone));
  }

  void _verifyOtp() {
    final code = _otpCtrl.text;
    if (code.length != 6) return;
    _verifySubmitted = true;
    context.read<AuthBloc>().add(
      AuthAddPhoneFromProfileRequested(phoneNumber: _pendingPhone, code: code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          widget.stepNotifier.value = _ContactStep.otp;
          widget.onSubmitReady(_handleSubmit);
        } else if (state is AuthProfileUpdated) {
          // AuthProfileUpdated part aussi d'une resynchronisation du profil
          // en arrière-plan : seule la vérification lancée ici ferme l'écran
          // (FLUTTER-BX). `true` signale à l'appelant que le contact a changé.
          if (!_verifySubmitted) return;
          _verifySubmitted = false;
          DonySnackbar.show(
            context,
            message: context.l10n.contactPhoneAddedSuccess,
            type: DonySnackbarType.success,
          );
          Navigator.of(context, rootNavigator: true).pop(true);
        } else if (state is AuthError) {
          _verifySubmitted = false;
          ErrorPresenter.show(context, state.error);
        }
      },
      child: ValueListenableBuilder<_ContactStep>(
        valueListenable: widget.stepNotifier,
        builder: (_, step, _) {
          if (step == _ContactStep.input) {
            return _PhoneInputStep(
              controller: _phoneCtrl,
              country: _country,
              onCountryChanged: (c) => setState(() => _country = c),
              tt: tt,
              cs: cs,
            );
          }
          return _OtpStep(
            controller: _otpCtrl,
            onCompleted: (_) => _verifyOtp(),
            readSms: true,
            contact: _pendingPhone,
            tt: tt,
            cs: cs,
          );
        },
      ),
    );
  }
}

class _PhoneInputStep extends StatelessWidget {
  const _PhoneInputStep({
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    required this.tt,
    required this.cs,
  });

  final TextEditingController controller;
  final PhoneCountry country;
  final void Function(PhoneCountry) onCountryChanged;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.lg,
        DonySpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.contactPhoneNumberLabel,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(DonyRadius.md),
              color: cs.surface,
            ),
            child: Row(
              children: [
                // Sélecteur indicatif
                // `opaque` : sans lui, seuls les pixels du drapeau, de
                // l'indicatif et du chevron réagissaient, pas la marge de la
                // case (rage clicks PostHog du 27/09).
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showCodePicker(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.md,
                      vertical: DonySpacing.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          country.flag,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        Text(
                          country.dialCode,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        DonyIcon(
                          'chevron-down',
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 40, color: cs.outline),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: country.hint,
                      hintStyle: tt.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.md,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            context.l10n.contactPhoneOtpNotice,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showCodePicker(BuildContext context) {
    DonyBottomSheet.show<void>(
      context,
      title: context.l10n.contactDialCodeTitle,
      child: Builder(
        builder: (innerContext) => DialCodePicker(
          selectedCode: country.code,
          onSelected: (c) {
            onCountryChanged(c);
            Navigator.of(innerContext).pop();
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AddEmailSheet — ajouter / mettre à jour l'email depuis le profil
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AddEmailSheet {
  static Future<void> show(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    VoidCallback? submit;
    final stepNotifier = ValueNotifier(_ContactStep.input);

    return DonyBottomSheet.show<void>(
      context,
      title: context.l10n.contactAddEmailTitle,
      wrapper: (child) => BlocProvider.value(value: authBloc, child: child),
      stickyBottom: ValueListenableBuilder<_ContactStep>(
        valueListenable: stepNotifier,
        builder: (_, step, _) => BlocBuilder<AuthBloc, AuthState>(
          builder: (ctx, state) => DonyButton(
            label: step == _ContactStep.input
                ? ctx.l10n.contactSendCodeAction
                : ctx.l10n.contactVerifyAction,
            isLoading: state is AuthLoading,
            onPressed: state is AuthLoading ? null : () => submit?.call(),
          ),
        ),
      ),
      child: _AddEmailContent(
        onSubmitReady: (fn) => submit = fn,
        stepNotifier: stepNotifier,
      ),
    ).whenComplete(stepNotifier.dispose);
  }
}

class _AddEmailContent extends StatefulWidget {
  const _AddEmailContent({
    required this.onSubmitReady,
    required this.stepNotifier,
  });

  final void Function(VoidCallback) onSubmitReady;
  final ValueNotifier<_ContactStep> stepNotifier;

  @override
  State<_AddEmailContent> createState() => _AddEmailContentState();
}

class _AddEmailContentState extends State<_AddEmailContent> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String _pendingEmail = '';

  /// Vrai entre l'envoi du code de vérification et sa réponse.
  bool _verifySubmitted = false;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady(_handleSubmit);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (widget.stepNotifier.value == _ContactStep.input) {
      _sendOtp();
    } else {
      _verifyOtp();
    }
  }

  void _sendOtp() {
    final email = _emailCtrl.text.trim();
    if (!_emailRegex.hasMatch(email)) return;
    _pendingEmail = email;
    context.read<AuthBloc>().add(AuthEmailOtpSendRequested(email));
  }

  void _verifyOtp() {
    final code = _otpCtrl.text;
    if (code.length != 6) return;
    _verifySubmitted = true;
    context.read<AuthBloc>().add(
      AuthAddEmailFromProfileRequested(email: _pendingEmail, code: code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthEmailOtpSent) {
          widget.stepNotifier.value = _ContactStep.otp;
          widget.onSubmitReady(_handleSubmit);
        } else if (state is AuthProfileUpdated) {
          // AuthProfileUpdated part aussi d'une resynchronisation du profil
          // en arrière-plan : seule la vérification lancée ici ferme l'écran
          // (FLUTTER-BX). `true` signale à l'appelant que le contact a changé.
          if (!_verifySubmitted) return;
          _verifySubmitted = false;
          DonySnackbar.show(
            context,
            message: context.l10n.contactEmailVerifiedSuccess,
            type: DonySnackbarType.success,
          );
          Navigator.of(context, rootNavigator: true).pop(true);
        } else if (state is AuthError) {
          _verifySubmitted = false;
          ErrorPresenter.show(context, state.error);
        }
      },
      child: ValueListenableBuilder<_ContactStep>(
        valueListenable: widget.stepNotifier,
        builder: (_, step, _) {
          if (step == _ContactStep.input) {
            return _EmailInputStep(controller: _emailCtrl, tt: tt, cs: cs);
          }
          return _OtpStep(
            controller: _otpCtrl,
            onCompleted: (_) => _verifyOtp(),
            contact: _pendingEmail,
            tt: tt,
            cs: cs,
          );
        },
      ),
    );
  }
}

class _EmailInputStep extends StatelessWidget {
  const _EmailInputStep({
    required this.controller,
    required this.tt,
    required this.cs,
  });

  final TextEditingController controller;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.lg,
        DonySpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.contactEmailAddressLabel,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(DonyRadius.md),
              color: cs.surface,
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: tt.bodyLarge?.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'exemple@email.com',
                hintStyle: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                border: InputBorder.none,
                prefixIcon: DonyIcon(
                  'mail',
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.md,
                  vertical: DonySpacing.md,
                ),
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            context.l10n.contactEmailOtpNotice,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget partagé : saisie du code OTP à 6 chiffres
// ─────────────────────────────────────────────────────────────────────────────

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.controller,
    required this.onCompleted,
    required this.contact,
    this.readSms = false,
    required this.tt,
    required this.cs,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final String contact;

  /// Vrai pour un code reçu par SMS (numéro), faux par e-mail.
  final bool readSms;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final message = context.l10n.contactCodeSentTo(contact);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.lg,
        DonySpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
              children: emphasizedSpans(
                message,
                contact,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.xl),
          Center(
            child: OtpCodeField(
              controller: controller,
              onCompleted: onCompleted,
              readSms: readSms,
              boxWidth: 44,
              boxHeight: 52,
            ),
          ),
        ],
      ),
    );
  }
}
