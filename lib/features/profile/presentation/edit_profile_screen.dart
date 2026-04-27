import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    if (_initialized) return;
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: DonyColors.green400),
        ),
        child: child!,
      ),
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
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthProfileUpdated) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Profil mis à jour avec succès',
                style: GoogleFonts.sora(fontWeight: FontWeight.w500),
              ),
              backgroundColor: DonyColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.message,
                style: GoogleFonts.sora(fontWeight: FontWeight.w500),
              ),
              backgroundColor: DonyColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      builder: (context, state) {
        UserModel? user;
        if (state is AuthAuthenticated) user = state.user;
        if (state is AuthProfileUpdated) user = state.user;
        if (user != null) _initFromUser(user);

        final isLoading = state is AuthLoading;

        return Scaffold(
          backgroundColor: DonyColors.grey50,
          appBar: AppBar(
            title: Text(
              'Compléter mon profil',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: DonyColors.ink900,
              ),
            ),
            centerTitle: false,
            backgroundColor: DonyColors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  size: 20, color: DonyColors.green400),
              onPressed: () => context.pop(),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: DonyColors.green400.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: DonyColors.green400.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: DonyColors.green400, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ces informations inspirent confiance aux autres membres de la communauté.',
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            color: DonyColors.green400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Section Identité ────────────────────────────────
                _SectionLabel('Identité'),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _firstNameCtrl,
                  label: 'Prénom',
                  prefixIcon: Icons.person_outline_rounded,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _lastNameCtrl,
                  label: 'Nom de famille',
                  prefixIcon: Icons.person_outline_rounded,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 28),

                // ── Section Contact ─────────────────────────────────
                _SectionLabel('Contact'),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _emailCtrl,
                  label: 'Email (optionnel)',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 28),

                // ── Section Infos personnelles ──────────────────────
                _SectionLabel('Informations personnelles'),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: isLoading ? null : _pickBirthDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: DonyColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DonyColors.grey100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake_outlined,
                            color: DonyColors.grey400, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _birthDate != null
                                ? DateFormat('dd/MM/yyyy')
                                    .format(_birthDate!)
                                : 'Date de naissance',
                            style: GoogleFonts.sora(
                              fontSize: 15,
                              color: _birthDate != null
                                  ? DonyColors.ink900
                                  : DonyColors.grey200,
                              fontWeight: _birthDate != null
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: DonyColors.grey200, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _cityCtrl,
                  label: "Ville / lieu d'habitation",
                  prefixIcon: Icons.location_city_outlined,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 40),

                // ── Bouton sauvegarder ──────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DonyColors.green400,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          DonyColors.green400.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Enregistrer',
                            style: GoogleFonts.sora(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: GoogleFonts.sora(fontSize: 15, color: DonyColors.ink900),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.sora(color: DonyColors.grey400, fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: DonyColors.grey400, size: 20),
        filled: true,
        fillColor: DonyColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DonyColors.grey100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DonyColors.grey100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DonyColors.green400, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DonyColors.grey100.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.sora(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: DonyColors.grey400,
        letterSpacing: 0.8,
      ),
    );
  }
}
