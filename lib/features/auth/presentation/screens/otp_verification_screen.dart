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

  void _resend() {
    for (final c in _controllers) {
      c.clear();
    }
    final state = context.read<AuthBloc>().state;
    final phoneNumber = state is AuthOtpSent ? state.phoneNumber : '';
    context.read<AuthBloc>().add(AuthSendOtpRequested(phoneNumber));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthOtpVerified) {
            context.go('/auth/role');
          } else if (state is AuthAuthenticated) {
            context.go('/auth/local');
          } else if (state is AuthError) {
            DonySnackbar.show(
              context,
              message: state.message,
              type: DonySnackbarType.error,
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          final secondsLeft =
              state is AuthOtpSent ? state.secondsLeft : 60;

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.sm, DonySpacing.sm, DonySpacing.sm, 0,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 20,
                      color: cs.onSurface,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(height: DonySpacing.base),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: DonySpacing.xl),
                  child: Text(
                    'Entrez le code',
                    style: tt.displayLarge?.copyWith(
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: DonySpacing.xl),
                  child: RichText(
                    text: TextSpan(
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      children: [
                        const TextSpan(text: 'Code envoyé au '),
                        TextSpan(
                          text: state is AuthOtpSent ? state.phoneNumber : '',
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: DonySpacing.xl),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 48,
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
                              borderRadius:
                                  BorderRadius.circular(DonyRadius.md),
                              borderSide: BorderSide(color: cs.outline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(DonyRadius.md),
                              borderSide: BorderSide(color: cs.outline),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(DonyRadius.md),
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
                ),
                const SizedBox(height: DonySpacing.xl),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: DonySpacing.xl),
                  child: secondsLeft > 0
                      ? Text(
                          'Renvoyer le code ($secondsLeft s)',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : GestureDetector(
                          onTap: _resend,
                          child: Text(
                            'Renvoyer le code',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.xl, 0, DonySpacing.xl, DonySpacing.xxl,
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
