import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  DateTime? _birthDate;
  bool _initialized = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _initFromUser(UserModel user) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _firstNameCtrl.text = user.firstName ?? '';
    _lastNameCtrl.text = user.lastName ?? '';
    _emailCtrl.text = user.email ?? '';
    _cityCtrl.text = user.city ?? '';
    _birthDate = user.birthDate;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 16),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  void _save() {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final city = _cityCtrl.text.trim();

    context.read<AuthBloc>().add(AuthUpdateProfileRequested(
          firstName: firstName.isNotEmpty ? firstName : null,
          lastName: lastName.isNotEmpty ? lastName : null,
          email: email.isNotEmpty ? email : null,
          birthDate: _birthDate,
          city: city.isNotEmpty ? city : null,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthProfileUpdated) {
          context.pop();
          DonySnackbar.show(
            context,
            message: 'Profil mis à jour avec succès',
            type: DonySnackbarType.success,
          );
        }
        if (state is AuthError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        UserModel? user;
        if (state is AuthAuthenticated) {
          user = state.user;
        }
        if (state is AuthProfileUpdated) {
          user = state.user;
        }
        if (user != null) {
          _initFromUser(user);
        }

        final isLoading = state is AuthLoading;

        return Scaffold(
          appBar: const DonyAppBar(title: 'Compléter mon profil'),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg, DonySpacing.xl, DonySpacing.lg, DonySpacing.huge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(DonySpacing.md),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    border: Border.all(
                        color: cs.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: cs.primary, size: 18),
                      const SizedBox(width: DonySpacing.md),
                      Expanded(
                        child: Text(
                          'Ces informations inspirent confiance aux autres membres de la communauté.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DonySpacing.xxl),

                // ── Section Identité ────────────────────────────────
                _SectionLabel(label: 'Identité', tt: tt, cs: cs),
                const SizedBox(height: DonySpacing.md),
                DonyTextField(
                  controller: _firstNameCtrl,
                  label: 'Prénom',
                  prefixIcon: Icons.person_outline_rounded,
                  enabled: !isLoading,
                ),
                const SizedBox(height: DonySpacing.md),
                DonyTextField(
                  controller: _lastNameCtrl,
                  label: 'Nom de famille',
                  prefixIcon: Icons.person_outline_rounded,
                  enabled: !isLoading,
                ),
                const SizedBox(height: DonySpacing.xxl),

                // ── Section Contact ─────────────────────────────────
                _SectionLabel(label: 'Contact', tt: tt, cs: cs),
                const SizedBox(height: DonySpacing.md),
                DonyTextField(
                  controller: _emailCtrl,
                  label: 'Email (optionnel)',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                ),
                const SizedBox(height: DonySpacing.xxl),

                // ── Section Infos personnelles ──────────────────────
                _SectionLabel(label: 'Informations personnelles', tt: tt, cs: cs),
                const SizedBox(height: DonySpacing.md),
                GestureDetector(
                  onTap: isLoading ? null : _pickBirthDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.base,
                      vertical: DonySpacing.base,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                      border: Border.all(color: cs.outline),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cake_outlined,
                            color: cs.onSurfaceVariant, size: 20),
                        const SizedBox(width: DonySpacing.md),
                        Expanded(
                          child: Text(
                            _birthDate != null
                                ? DateFormat('dd/MM/yyyy')
                                    .format(_birthDate!)
                                : 'Date de naissance',
                            style: tt.bodyLarge?.copyWith(
                              color: _birthDate != null
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                              fontWeight: _birthDate != null
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: cs.onSurfaceVariant, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: DonySpacing.md),
                DonyTextField(
                  controller: _cityCtrl,
                  label: "Ville / lieu d'habitation",
                  prefixIcon: Icons.location_city_outlined,
                  enabled: !isLoading,
                ),
                const SizedBox(height: DonySpacing.huge - DonySpacing.sm),

                // ── Bouton sauvegarder ──────────────────────────────
                DonyButton(
                  label: 'Enregistrer',
                  onPressed: isLoading ? null : _save,
                  isLoading: isLoading,
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.tt,
    required this.cs,
  });
  final String label;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: tt.labelMedium?.copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }
}
