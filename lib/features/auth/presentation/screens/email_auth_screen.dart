import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

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
              extra: {'email': state.email},
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
                  // ── Back button row ─────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        h - DonySpacing.sm, DonySpacing.md, h, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: cs.onSurface,
                          onPressed: () => context.pop(),
                          tooltip: 'Retour',
                        ),
                      ],
                    ),
                  ),

                  // ── Scrollable content ──────────────────────────
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
                            // Mascotte
                            const DonyMascotteAnimated(
                              type: DonyMascotteType.confiant,
                              size: DonyMascotteSize.sm,
                            ),
                            const SizedBox(height: DonySpacing.xl),

                            // Title
                            Text(
                              'Connexion par email',
                              style: tt.displayLarge?.copyWith(
                                color: cs.onSurface,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.sm),

                            // Subtitle
                            Text(
                              'Saisis ton adresse email pour recevoir un code de connexion.',
                              style: tt.bodyLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.xxl),

                            // Email label
                            Text(
                              'ADRESSE EMAIL',
                              style: tt.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.sm),

                            // Email input
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: cs.outline),
                                borderRadius:
                                    BorderRadius.circular(DonyRadius.md),
                                color: cs.surface,
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                scrollPadding:
                                    const EdgeInsets.only(bottom: 120),
                                style: tt.bodyLarge?.copyWith(
                                    color: cs.onSurface),
                                decoration: InputDecoration(
                                  hintText: 'exemple@email.com',
                                  hintStyle: tt.bodyLarge?.copyWith(
                                      color: cs.onSurfaceVariant),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: cs.onSurfaceVariant,
                                    size: 20,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: DonySpacing.base,
                                          vertical: DonySpacing.md),
                                ),
                              ),
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
                      border:
                          Border(top: BorderSide(color: cs.outline)),
                    ),
                    padding: EdgeInsets.fromLTRB(
                        h, DonySpacing.base, h, DonySpacing.base + bottom),
                    child: ElevatedButton(
                      onPressed: (_isValid && !isLoading) ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DonyRadius.lg),
                        ),
                      ),
                      child: isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : Text(
                              'Envoyer le code',
                              style: tt.labelLarge?.copyWith(
                                  color: cs.onPrimary),
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
