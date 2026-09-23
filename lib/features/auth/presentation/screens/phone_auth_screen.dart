import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/phone/phone_country.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/bloc/dial_code_cubit.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:dony/features/auth/presentation/widgets/dial_code_picker.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, this.fromProfile = false});

  final bool fromProfile;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  /// Détenu par l'écran, pas par `AuthBloc` : le pays choisi doit survivre aux
  /// échecs d'envoi et aux erreurs serveur, qui réinitialisent l'état d'auth.
  final _dialCodeCubit = DialCodeCubit();

  @override
  void dispose() {
    _phoneController.dispose();
    _dialCodeCubit.close();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final country = _dialCodeCubit.state;
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.signupStarted,
        properties: {'method': 'phone'},
      ),
    );
    context.read<AuthBloc>().add(
      AuthSendOtpRequested(
        toE164(country.dialCode, _phoneController.text.trim()),
      ),
    );
  }

  void _showCodePicker() {
    DonyBottomSheet.show<void>(
      context,
      title: context.l10n.authPhoneDialCodeTitle,
      child: Builder(
        builder: (innerContext) => DialCodePicker(
          selectedCode: _dialCodeCubit.state.code,
          onSelected: (country) {
            _dialCodeCubit.select(country);
            innerContext.pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _dialCodeCubit,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (previous, current) {
            if (current is AuthOtpSent) return previous is! AuthOtpSent;
            return true;
          },
          listener: (context, state) {
            if (state is AuthOtpSent) {
              context.push(
                '/auth/otp',
                extra: {
                  'fromProfile': widget.fromProfile,
                  'contact': state.phoneNumber,
                },
              );
            } else if (state is AuthError) {
              ErrorPresenter.show(context, state.error);
            }
          },
          builder: (context, state) {
            final country = context.watch<DialCodeCubit>().state;
            final dialCode = country.dialCode;
            final dialFlag = country.flag;
            final isLoading = state is AuthLoading;
            final cs = Theme.of(context).colorScheme;
            final tt = Theme.of(context).textTheme;
            final h = DonyLayout.hPadding(context);
            final bottom = MediaQuery.paddingOf(context).bottom;

            return Stack(
              fit: StackFit.expand,
              children: [
                const AuthFlowBackground(),
                SafeArea(
                  bottom: false,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(h, DonySpacing.md, h, 0),
                          child: AuthFlowHeader(
                            current: 1,
                            total: 3,
                            label: context.l10n.authPhoneStepLabel,
                            showBack: !widget.fromProfile,
                          ),
                        ),

                        // ── Scrollable content ─────────────────────────
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              h,
                              DonySpacing.xl,
                              h,
                              DonySpacing.xl,
                            ),
                            child: DonyLayout.constrained(
                              context,
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AuthIntroCard(
                                    iconAsset: 'smartphone',
                                    title: context.l10n.authPhoneTitle,
                                    body: context.l10n.authPhoneBody,
                                    footnote: context.l10n.authPhoneFootnote,
                                  ),
                                  const SizedBox(height: DonySpacing.xxl),
                                  Text(
                                    context.l10n.authPhoneNumberLabel,
                                    style: tt.labelMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: DonySpacing.sm),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: cs.outline),
                                      borderRadius: BorderRadius.circular(
                                        DonyRadius.md,
                                      ),
                                      color: cs.surface,
                                    ),
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: _showCodePicker,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: DonySpacing.base,
                                              vertical: DonySpacing.md,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  dialFlag,
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: DonySpacing.sm,
                                                ),
                                                Text(
                                                  dialCode,
                                                  style: tt.titleLarge
                                                      ?.copyWith(
                                                        color: cs.onSurface,
                                                      ),
                                                ),
                                                const SizedBox(
                                                  width: DonySpacing.xxs,
                                                ),
                                                DonyIcon(
                                                  'chevron-down',
                                                  size: 16,
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 28,
                                          color: cs.outline,
                                        ),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _phoneController,
                                            keyboardType: TextInputType.phone,
                                            scrollPadding:
                                                const EdgeInsets.only(
                                                  bottom: 120,
                                                ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            style: tt.titleLarge?.copyWith(
                                              color: cs.onSurface,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: country.hint,
                                              hintStyle: tt.bodyLarge?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              focusedErrorBorder:
                                                  InputBorder.none,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal:
                                                        DonySpacing.base,
                                                    vertical: DonySpacing.md,
                                                  ),
                                            ),
                                            validator: (v) {
                                              if (v == null ||
                                                  v.trim().isEmpty) {
                                                return context
                                                    .l10n
                                                    .authPhoneEnterNumber;
                                              }
                                              final digits = v
                                                  .trim()
                                                  .replaceAll(
                                                    RegExp(r'[^0-9]'),
                                                    '',
                                                  );
                                              if (digits.length < 6) {
                                                return context
                                                    .l10n
                                                    .authPhoneNumberTooShort;
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: DonySpacing.base),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── Pinned bottom CTA ───────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).scaffoldBackgroundColor.withValues(alpha: 0.96),
                            border: Border(
                              top: BorderSide(
                                color: cs.outline.withValues(alpha: 0.64),
                              ),
                            ),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            h,
                            DonySpacing.base,
                            h,
                            DonySpacing.base + bottom,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DonyButton(
                                label: context.l10n.authPhoneGetSmsCode,
                                onPressed: isLoading ? null : _submit,
                                isLoading: isLoading,
                              ),
                              const SizedBox(height: DonySpacing.sm),
                              TextButton(
                                onPressed: () => context.push('/auth/email'),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: DonySpacing.base,
                                    vertical: DonySpacing.sm,
                                  ),
                                ),
                                child: Text(
                                  context.l10n.authPhoneContinueWithEmail,
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: cs.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}
