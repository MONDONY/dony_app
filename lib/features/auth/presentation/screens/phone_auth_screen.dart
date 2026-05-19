import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
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

  static const _codes = [
    ('+33', '🇫🇷', 'France'),
    ('+44', '🇬🇧', 'Royaume-Uni'),
    ('+1', '🇺🇸', 'États-Unis'),
    ('+221', '🇸🇳', 'Sénégal'),
    ('+225', '🇨🇮', 'Côte d\'Ivoire'),
    ('+223', '🇲🇱', 'Mali'),
    ('+237', '🇨🇲', 'Cameroun'),
    ('+241', '🇬🇦', 'Gabon'),
    ('+242', '🇨🇬', 'Congo'),
    ('+243', '🇨🇩', 'RD Congo'),
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AuthBloc>().state;
    final dialCode = state is AuthInitial ? state.dialCode : '+33';
    String local = _phoneController.text.trim();
    if (local.startsWith('0')) local = local.substring(1);
    context.read<AuthBloc>().add(AuthSendOtpRequested('$dialCode$local'));
  }

  void _showCodePicker() {
    final authBloc = context.read<AuthBloc>();
    DonyBottomSheet.show<void>(
      context,
      title: 'Indicatif pays',
      child: Builder(builder: (innerContext) {
        final currentState = authBloc.state;
        final selectedCode =
            currentState is AuthInitial ? currentState.dialCode : '+33';
        final cs = Theme.of(innerContext).colorScheme;
        final tt = Theme.of(innerContext).textTheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: _codes
              .map((c) => ListTile(
                    leading:
                        Text(c.$2, style: const TextStyle(fontSize: 22)),
                    title: Text('${c.$3} (${c.$1})', style: tt.titleMedium),
                    trailing: selectedCode == c.$1
                        ? Icon(Icons.check_rounded, color: cs.primary)
                        : null,
                    onTap: () {
                      authBloc
                          .add(AuthDialCodeChanged(code: c.$1, flag: c.$2));
                      innerContext.pop();
                    },
                  ))
              .toList(),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (previous, current) {
          if (current is AuthOtpSent) return previous is! AuthOtpSent;
          return true;
        },
        listener: (context, state) {
          if (state is AuthOtpSent) {
            context.push('/auth/otp', extra: {
              'fromProfile': widget.fromProfile,
              'contact': state.phoneNumber,
            });
          } else if (state is AuthError) {
            ErrorPresenter.show(context, state.error);
          } else if (state is AuthOAuthNewUser) {
            context.go('/onboarding/role', extra: {
              'initialRole': 'SENDER',
              'pendingEmail': state.email,
            });
          }
        },
        builder: (context, state) {
          final dialCode =
              state is AuthInitial ? state.dialCode : '+33';
          final dialFlag =
              state is AuthInitial ? state.dialFlag : '🇫🇷';
          final isLoading = state is AuthLoading;
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          final h = DonyLayout.hPadding(context);
          final bottom = MediaQuery.paddingOf(context).bottom;

          return SafeArea(
            bottom: false,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Top bar ────────────────────────────────────
                  if (!widget.fromProfile) Padding(
                    padding: EdgeInsets.fromLTRB(h, DonySpacing.md, h, 0),
                    child: Row(children: [
                      DonyBackCircle(onTap: () => context.pop()),
                      const Spacer(),
                      const DonyStepPill(current: 1, total: 3, label: 'Téléphone'),
                    ]),
                  ),

                  // ── Scrollable content ─────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          h, DonySpacing.xl, h, DonySpacing.xl),
                      child: DonyLayout.constrained(
                        context,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(child: DonyHeroAvatar(emoji: '📱', size: 72)),
                            const SizedBox(height: DonySpacing.xl),
                            Text(
                              'Ton numéro',
                              style: tt.displayLarge?.copyWith(
                                color: cs.onSurface,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.sm),
                            Text(
                              'On t\'envoie un code à 6 chiffres par SMS pour vérifier que c\'est bien toi.',
                              style: tt.bodyLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.xxl),
                            Text(
                              'NUMÉRO DE TÉLÉPHONE',
                              style: tt.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.sm),
                            // Phone input row
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: cs.outline),
                                borderRadius:
                                    BorderRadius.circular(DonyRadius.md),
                                color: cs.surface,
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: _showCodePicker,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: DonySpacing.base,
                                          vertical: DonySpacing.md),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(dialFlag,
                                              style: const TextStyle(
                                                  fontSize: 20)),
                                          const SizedBox(
                                              width: DonySpacing.sm),
                                          Text(dialCode,
                                              style: tt.titleLarge?.copyWith(
                                                  color: cs.onSurface)),
                                          const SizedBox(
                                              width: DonySpacing.xxs),
                                          Icon(
                                            Icons
                                                .keyboard_arrow_down_rounded,
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
                                      color: cs.outline),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      scrollPadding: const EdgeInsets.only(bottom: 120),
                                      inputFormatters: [
                                        FilteringTextInputFormatter
                                            .digitsOnly,
                                      ],
                                      style: tt.titleLarge?.copyWith(
                                          color: cs.onSurface),
                                      decoration: InputDecoration(
                                        hintText: '06 12 34 56 78',
                                        hintStyle: tt.bodyLarge?.copyWith(
                                            color: cs.onSurfaceVariant),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        focusedErrorBorder:
                                            InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: DonySpacing.base,
                                                vertical: DonySpacing.md),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Entrez votre numéro';
                                        }
                                        final digits = v
                                            .trim()
                                            .replaceAll(
                                                RegExp(r'[^0-9]'), '');
                                        if (digits.length < 6) {
                                          return 'Numéro trop court';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: DonySpacing.sm),
                            Center(
                              child: TextButton(
                                onPressed: () => context.push('/auth/email'),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: DonySpacing.base,
                                      vertical: DonySpacing.sm),
                                ),
                                child: Text(
                                  'Continuer avec une adresse email',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: cs.primary,
                                  ),
                                ),
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
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(top: BorderSide(color: cs.outline)),
                    ),
                    padding: EdgeInsets.fromLTRB(
                        h, DonySpacing.base, h, DonySpacing.base + bottom),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DonyButton(
                          label: 'Recevoir le code SMS',
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
                            'Le SMS n\'arrive pas ? Essaie par email',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              decoration: TextDecoration.underline,
                              decorationColor: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

