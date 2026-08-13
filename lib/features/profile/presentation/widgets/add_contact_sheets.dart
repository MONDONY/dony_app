import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
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
      appBar: const DonyAppBar(title: 'Modifier le numéro'),
      body: Column(
        children: [
          Expanded(
            child: _AddPhoneContent(
              codes: AddPhoneSheet._codes,
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
                        ? 'Envoyer le code'
                        : 'Vérifier',
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
      appBar: const DonyAppBar(title: "Modifier l'email"),
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
                        ? 'Envoyer le code'
                        : 'Vérifier',
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
  static const _codes = [
    ('+33', '🇫🇷'),
    ('+44', '🇬🇧'),
    ('+1', '🇺🇸'),
    ('+221', '🇸🇳'),
    ('+225', '🇨🇮'),
    ('+223', '🇲🇱'),
    ('+237', '🇨🇲'),
    ('+241', '🇬🇦'),
    ('+242', '🇨🇬'),
    ('+243', '🇨🇩'),
  ];

  static Future<void> show(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    VoidCallback? submit;
    final stepNotifier = ValueNotifier(_ContactStep.input);

    return DonyBottomSheet.show<void>(
      context,
      title: 'Ajouter un numéro',
      wrapper: (child) => BlocProvider.value(value: authBloc, child: child),
      stickyBottom: ValueListenableBuilder<_ContactStep>(
        valueListenable: stepNotifier,
        builder: (_, step, _) => BlocBuilder<AuthBloc, AuthState>(
          builder: (ctx, state) => DonyButton(
            label: step == _ContactStep.input ? 'Envoyer le code' : 'Vérifier',
            isLoading: state is AuthLoading,
            onPressed: state is AuthLoading ? null : () => submit?.call(),
          ),
        ),
      ),
      child: _AddPhoneContent(
        codes: _codes,
        onSubmitReady: (fn) => submit = fn,
        stepNotifier: stepNotifier,
      ),
    ).whenComplete(stepNotifier.dispose);
  }
}

class _AddPhoneContent extends StatefulWidget {
  const _AddPhoneContent({
    required this.codes,
    required this.onSubmitReady,
    required this.stepNotifier,
  });

  final List<(String, String)> codes;
  final void Function(VoidCallback) onSubmitReady;
  final ValueNotifier<_ContactStep> stepNotifier;

  @override
  State<_AddPhoneContent> createState() => _AddPhoneContentState();
}

class _AddPhoneContentState extends State<_AddPhoneContent> {
  final _phoneCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrl = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());
  String _dialCode = '+33';
  String _pendingPhone = '';

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady(_handleSubmit);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrl) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
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
    _pendingPhone = '$_dialCode$number';
    context.read<AuthBloc>().add(AuthSendOtpRequested(_pendingPhone));
  }

  void _verifyOtp() {
    final code = _otpCtrl.map((c) => c.text).join();
    if (code.length != 6) return;
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
          DonySnackbar.show(
            context,
            message: 'Numéro ajouté avec succès !',
            type: DonySnackbarType.success,
          );
          Navigator.of(context, rootNavigator: true).pop();
        } else if (state is AuthError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      child: ValueListenableBuilder<_ContactStep>(
        valueListenable: widget.stepNotifier,
        builder: (_, step, _) {
          if (step == _ContactStep.input) {
            return _PhoneInputStep(
              controller: _phoneCtrl,
              dialCode: _dialCode,
              codes: widget.codes,
              onDialCodeChanged: (code) => setState(() => _dialCode = code),
              tt: tt,
              cs: cs,
            );
          }
          return _OtpStep(
            controllers: _otpCtrl,
            focusNodes: _otpFocus,
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
    required this.dialCode,
    required this.codes,
    required this.onDialCodeChanged,
    required this.tt,
    required this.cs,
  });

  final TextEditingController controller;
  final String dialCode;
  final List<(String, String)> codes;
  final void Function(String) onDialCodeChanged;
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
            'NUMÉRO DE TÉLÉPHONE',
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
                GestureDetector(
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
                          codes
                              .firstWhere(
                                (c) => c.$1 == dialCode,
                                orElse: () => codes.first,
                              )
                              .$2,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        Text(
                          dialCode,
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
                      hintText: '6 12 34 56 78',
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
            'Un code de vérification sera envoyé par SMS.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showCodePicker(BuildContext context) {
    DonyBottomSheet.show<void>(
      context,
      title: 'Indicatif',
      child: ListView(
        shrinkWrap: true,
        children: codes
            .map(
              (c) => ListTile(
                leading: Text(c.$2, style: const TextStyle(fontSize: 22)),
                title: Text(c.$1),
                trailing: c.$1 == dialCode
                    ? DonyIcon(
                        'check',
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  onDialCodeChanged(c.$1);
                  Navigator.of(context).pop();
                },
              ),
            )
            .toList(),
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
      title: 'Ajouter un email',
      wrapper: (child) => BlocProvider.value(value: authBloc, child: child),
      stickyBottom: ValueListenableBuilder<_ContactStep>(
        valueListenable: stepNotifier,
        builder: (_, step, _) => BlocBuilder<AuthBloc, AuthState>(
          builder: (ctx, state) => DonyButton(
            label: step == _ContactStep.input ? 'Envoyer le code' : 'Vérifier',
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
  final List<TextEditingController> _otpCtrl = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());
  String _pendingEmail = '';

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady(_handleSubmit);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final c in _otpCtrl) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
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
    final code = _otpCtrl.map((c) => c.text).join();
    if (code.length != 6) return;
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
          DonySnackbar.show(
            context,
            message: 'Email vérifié avec succès !',
            type: DonySnackbarType.success,
          );
          Navigator.of(context, rootNavigator: true).pop();
        } else if (state is AuthError) {
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
            controllers: _otpCtrl,
            focusNodes: _otpFocus,
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
            'ADRESSE EMAIL',
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
            'Un code de vérification sera envoyé à cet email.',
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
    required this.controllers,
    required this.focusNodes,
    required this.contact,
    required this.tt,
    required this.cs,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final String contact;
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
          Text.rich(
            TextSpan(
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'Code envoyé à '),
                TextSpan(
                  text: contact,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return SizedBox(
                width: 44,
                height: 52,
                child: TextFormField(
                  controller: controllers[i],
                  focusNode: focusNodes[i],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: cs.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                      borderSide: BorderSide(color: cs.primary, width: 2),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && i < 5) {
                      focusNodes[i + 1].requestFocus();
                    } else if (value.isEmpty && i > 0) {
                      focusNodes[i - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
