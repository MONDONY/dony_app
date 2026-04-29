import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

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
      child: Builder(
        builder: (innerContext) {
          final currentState = authBloc.state;
          final selectedCode =
              currentState is AuthInitial ? currentState.dialCode : '+33';
          final cs = Theme.of(innerContext).colorScheme;
          final tt = Theme.of(innerContext).textTheme;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: _codes
                .map(
                  (c) => ListTile(
                    leading: Text(c.$2, style: const TextStyle(fontSize: 22)),
                    title: Text(
                      '${c.$3} (${c.$1})',
                      style: tt.titleMedium,
                    ),
                    trailing: selectedCode == c.$1
                        ? Icon(Icons.check_rounded, color: cs.primary)
                        : null,
                    onTap: () {
                      authBloc.add(AuthDialCodeChanged(code: c.$1, flag: c.$2));
                      innerContext.pop();
                    },
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (previous, current) {
          if (current is AuthOtpSent) return previous is! AuthOtpSent;
          return true;
        },
        listener: (context, state) {
          if (state is AuthOtpSent) {
            context.push('/auth/otp');
          } else if (state is AuthError) {
            DonySnackbar.show(
              context,
              message: state.message,
              type: DonySnackbarType.error,
            );
          }
        },
        builder: (context, state) {
          final dialCode = state is AuthInitial ? state.dialCode : '+33';
          final dialFlag = state is AuthInitial ? state.dialFlag : '🇫🇷';
          final isLoading = state is AuthLoading;
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;

          return SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: DonySpacing.huge),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: DonySpacing.xl),
                    child: const DonyLogo(fontSize: 59),
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: DonySpacing.xl),
                    child: Text(
                      'Bienvenue',
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
                    child: Text(
                      'Entrez votre numéro pour continuer. Nous vous enverrons un code par SMS.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: DonySpacing.xl),
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
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: cs.outline),
                            borderRadius: BorderRadius.circular(DonyRadius.md),
                            color: cs.surface,
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _showCodePicker,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 15,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        dialFlag,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(width: DonySpacing.sm),
                                      Text(
                                        dialCode,
                                        style: tt.titleLarge?.copyWith(
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: DonySpacing.xs),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(width: 1, height: 28, color: cs.outline),
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: tt.titleLarge?.copyWith(
                                    color: cs.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '06 12 34 56 78',
                                    hintStyle: tt.bodyLarge?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 15,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Entrez votre numéro';
                                    }
                                    final digits = v
                                        .trim()
                                        .replaceAll(RegExp(r'[^0-9]'), '');
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
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: DonySpacing.xl),
                    child: DonyButton(
                      label: 'Recevoir le code',
                      onPressed: isLoading ? null : _submit,
                      isLoading: isLoading,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.base),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DonySpacing.xl, 0, DonySpacing.xl, DonySpacing.xl,
                    ),
                    child: Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.6,
                          ),
                          children: [
                            const TextSpan(
                                text: 'En continuant, vous acceptez les\n'),
                            TextSpan(
                              text: 'Conditions',
                              style: tt.bodySmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' et la '),
                            TextSpan(
                              text: 'Politique de confidentialité',
                              style: tt.bodySmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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
