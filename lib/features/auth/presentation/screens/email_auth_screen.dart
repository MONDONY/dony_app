import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key, this.fromProfile = false});

  final bool fromProfile;

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isValid = false;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    final valid = _emailRegex.hasMatch(_emailController.text.trim());
    if (valid != _isValid) {
      setState(() {
        _isValid = valid;
      });
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_isValid) {
      return;
    }
    context.read<AuthBloc>().add(
      AuthEmailOtpSendRequested(_emailController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (previous, current) {
          if (current is AuthEmailOtpSent) {
            return previous is! AuthEmailOtpSent;
          }
          return current is AuthError;
        },
        listener: (context, state) {
          if (state is AuthEmailOtpSent) {
            context.push(
              '/auth/email-otp',
              extra: {'email': state.email, 'fromProfile': widget.fromProfile},
            );
          } else if (state is AuthError) {
            ErrorPresenter.show(context, state.error);
          }
        },
        builder: (context, state) {
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
                  // ── Top bar ─────────────────────────────────────
                  if (!widget.fromProfile)
                    Padding(
                      padding: EdgeInsets.fromLTRB(h, DonySpacing.md, h, 0),
                      child: Row(
                        children: [
                          DonyBackCircle(onTap: () => context.pop()),
                          const Spacer(),
                          const DonyStepPill(
                            current: 1,
                            total: 3,
                            label: 'Email',
                          ),
                        ],
                      ),
                    ),

                  // ── Scrollable content ──────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
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
                            Center(
                              child: DonyHeroAvatar(emoji: '✉️', size: 72),
                            ),
                            const SizedBox(height: DonySpacing.xl),

                            Text(
                              'Ton adresse email',
                              style: tt.displayLarge?.copyWith(
                                color: cs.onSurface,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.sm),

                            Text(
                              'Saisis ton adresse email pour recevoir un code de connexion.',
                              style: tt.bodyLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.xxl),

                            // Email input
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _isValid ? cs.primary : cs.outline,
                                  width: _isValid ? 1.5 : 1.0,
                                ),
                                borderRadius: BorderRadius.circular(
                                  DonyRadius.md,
                                ),
                                color: cs.surface,
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                scrollPadding: const EdgeInsets.only(
                                  bottom: 120,
                                ),
                                style: tt.bodyLarge?.copyWith(
                                  color: cs.onSurface,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'exemple@email.com',
                                  hintStyle: tt.bodyLarge?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(DonySpacing.md),
                                    child: DonyIcon(
                                      'mail',
                                      color: _isValid
                                          ? cs.primary
                                          : cs.onSurfaceVariant,
                                      size: 20,
                                    ),
                                  ),
                                  suffixIcon: _isValid
                                      ? Padding(
                                          padding: const EdgeInsets.all(
                                              DonySpacing.md),
                                          child: DonyIcon(
                                            'circle-check',
                                            color: cs.primary,
                                            size: 20,
                                          ),
                                        )
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: DonySpacing.base,
                                    vertical: DonySpacing.md,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: DonySpacing.sm),
                            Row(
                              children: [
                                DonyIcon(
                                  'info',
                                  size: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: DonySpacing.xs),
                                Expanded(
                                  child: Text(
                                    'Vérifie tes spams si tu ne reçois pas le code.',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                      h,
                      DonySpacing.base,
                      h,
                      DonySpacing.base + bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DonyButton(
                          label: 'Envoyer le code',
                          onPressed: (_isValid && !isLoading) ? _submit : null,
                          isLoading: isLoading,
                        ),
                        const SizedBox(height: DonySpacing.sm),
                        TextButton(
                          onPressed: () => context.pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(
                              horizontal: DonySpacing.base,
                              vertical: DonySpacing.sm,
                            ),
                          ),
                          child: Text(
                            'Préfères le SMS ?',
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
