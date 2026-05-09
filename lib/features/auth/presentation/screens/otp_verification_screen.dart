import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _verify() {
    if (_otpCode.length != 6) {
      DonySnackbar.show(context,
          message: 'Entrez le code à 6 chiffres',
          type: DonySnackbarType.error);
      return;
    }
    final state = context.read<AuthBloc>().state;
    if (state is! AuthOtpSent) {
      DonySnackbar.show(context,
          message: 'Session expirée, veuillez recommencer',
          type: DonySnackbarType.error);
      return;
    }
    context.read<AuthBloc>().add(AuthPhoneVerified(
          verificationId: state.verificationId,
          smsCode: _otpCode,
        ));
  }

  void _resend() {
    for (final c in _controllers) c.clear();
    final state = context.read<AuthBloc>().state;
    final phoneNumber = state is AuthOtpSent ? state.phoneNumber : '';
    context.read<AuthBloc>().add(AuthSendOtpRequested(phoneNumber));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: DonyColors.bgApp,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthOtpVerified) {
            context.read<AuthBloc>().add(const AuthRegisterRequested());
          } else if (state is AuthAuthenticated) {
            context.go('/auth/local');
          } else if (state is AuthError) {
            DonySnackbar.show(context,
                message: state.message, type: DonySnackbarType.error);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          final secondsLeft = state is AuthOtpSent ? state.secondsLeft : 60;
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          final h = DonyLayout.hPadding(context);
          final bottom = MediaQuery.paddingOf(context).bottom;

          return SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Back button ──────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      DonySpacing.sm, DonySpacing.sm, DonySpacing.sm, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_rounded,
                          size: 20, color: DonyColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),

                // ── Scrollable content ───────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                        h, DonySpacing.lg, h, DonySpacing.xl),
                    child: DonyLayout.constrained(
                      context,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Entrez le code',
                            style: tt.displayLarge?.copyWith(
                              color: DonyColors.textPrimary,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: DonySpacing.sm),
                          Text.rich(
                            TextSpan(
                              style: tt.bodyLarge?.copyWith(
                                  color: DonyColors.textMuted, height: 1.5),
                              children: [
                                const TextSpan(text: 'Code envoyé au '),
                                TextSpan(
                                  text: state is AuthOtpSent
                                      ? state.phoneNumber
                                      : '',
                                  style: tt.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: DonyColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: DonySpacing.xxl),

                          // OTP 6-digit input
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                              return SizedBox(
                                width: (DonyLayout.screenWidth(context) -
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
                                    color: DonyColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    filled: true,
                                    fillColor: DonyColors.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                          DonyRadius.md),
                                      borderSide: const BorderSide(
                                          color: DonyColors.borderDefault),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                          DonyRadius.md),
                                      borderSide: const BorderSide(
                                          color: DonyColors.borderDefault),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                          DonyRadius.md),
                                      borderSide: BorderSide(
                                          color: cs.primary, width: 2),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (value) {
                                    if (value.isNotEmpty && index < 5) {
                                      _focusNodes[index + 1]
                                          .requestFocus();
                                    } else if (value.isEmpty && index > 0) {
                                      _focusNodes[index - 1]
                                          .requestFocus();
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
                                    ? DonyColors.textSubtle
                                    : DonyColors.primary,
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
                  decoration: const BoxDecoration(
                    color: DonyColors.bgApp,
                    border: Border(
                        top: BorderSide(color: DonyColors.borderDefault)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                      h, DonySpacing.base, h, DonySpacing.base + bottom),
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
