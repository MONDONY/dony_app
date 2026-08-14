import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/widgets/profile_sections.dart'
    show profileCompletionTierColor;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// EditProfileScreen — s'ouvre en lecture (présentation du profil), pas en
/// édition : le bouton du bas dit « Modifier » et fait basculer les champs
/// texte en `TextField`. Email et téléphone restent des lignes de lecture
/// même une fois basculé — leur modification exige une preuve OTP, jamais
/// une simple saisie, donc elle vit sur un écran séparé (voir
/// `add_contact_sheets.dart` → `EditEmailScreen`/`EditPhoneScreen`).
///
/// Uses StatefulWidget only for TextEditingController lifecycle and local
/// picker state (birth date, languages, transport mode, vue/édition). All
/// business state (loading, error, success) is driven by AuthBloc — no
/// setState for business logic.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    @visibleForTesting DonyMediaService? mediaService,
  }) : _mediaService = mediaService;

  /// Seam for widget-testing: inject a mock [DonyMediaService] to avoid
  /// hitting platform channels. Defaults to the GetIt singleton.
  final DonyMediaService? _mediaService;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  DateTime? _birthDate;
  List<String> _selectedLanguages = [];
  String? _selectedTransport;
  bool _initialized = false;
  // Keeps the last known user so the form stays visible during AuthLoading.
  UserModel? _lastUser;

  /// Vue (présentation, par défaut) vs édition (champs actifs). Purement
  /// local : ne dépend d'aucun état métier, jamais persisté.
  bool _editing = false;

  /// True when the user has tapped "Enregistrer" — used to distinguish a
  /// profile-save update from an avatar-upload update (both emit
  /// [AuthProfileUpdated]). Only pop the screen on a save, not on avatar upload.
  bool _saving = false;
  bool _pickingAvatar = false;

  DonyMediaService get _mediaService =>
      widget._mediaService ?? getIt<DonyMediaService>();

  static const _kAvailableLanguages = [
    'Français',
    'Wolof',
    'Bambara',
    'Anglais',
    'Espagnol',
    'Arabe',
  ];

  static const _kTransportModes = ['AVION', 'VOITURE', 'TRAIN'];

  static const _kTransportLabels = {
    'AVION': 'Avion',
    'VOITURE': 'Voiture',
    'TRAIN': 'Train',
  };

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _bioCtrl.dispose();
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
    _bioCtrl.text = user.bio ?? '';
    _cityCtrl.text = user.city ?? '';
    _birthDate = user.birthDate;
    _selectedLanguages = List<String>.from(user.languages);
    _selectedTransport = user.transportMode;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 16),
    );
    if (picked != null && mounted) {
      // setState is intentional here: pure local picker state, not business state
      setState(() => _birthDate = picked);
    }
  }

  void _toggleLanguage(String lang) {
    setState(() {
      if (_selectedLanguages.contains(lang)) {
        _selectedLanguages = List.from(_selectedLanguages)..remove(lang);
      } else {
        _selectedLanguages = List.from(_selectedLanguages)..add(lang);
      }
    });
  }

  void _selectTransport(String mode) {
    setState(() => _selectedTransport = mode);
  }

  void _save(bool isTraveler) {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final bio = _bioCtrl.text.trim();
    final city = _cityCtrl.text.trim();

    setState(() => _saving = true);
    context.read<AuthBloc>().add(
      AuthUpdateProfileRequested(
        firstName: firstName.isNotEmpty ? firstName : null,
        lastName: lastName.isNotEmpty ? lastName : null,
        birthDate: _birthDate,
        city: city.isNotEmpty ? city : null,
        bio: bio.isEmpty ? null : bio,
        languages: isTraveler ? _selectedLanguages : null,
        transportMode: isTraveler ? _selectedTransport : null,
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_pickingAvatar) {
      return;
    }
    _pickingAvatar = true;
    try {
      // Upload direct sans recadrage : DonyMediaService redimensionne toute
      // image a 1920x1920 (qualite 85, JPEG). Une photo de 20 Mo est donc
      // resizee, pas rejetee ; seul un fichier > 50 Mo (garde anti-OOM) leve
      // MediaFileTooLargeException.
      final xfile = await _mediaService.pick(source: ImageSource.gallery);
      if (xfile == null || !mounted) {
        return;
      }
      context.read<AuthBloc>().add(AuthAvatarUploadRequested(xfile.path));
    } on UnsupportedMediaTypeException {
      if (!mounted) {
        return;
      }
      DonySnackbar.show(
        context,
        message: 'Seules les images sont acceptées (pas de vidéo).',
        type: DonySnackbarType.error,
      );
    } on MediaFileTooLargeException catch (e) {
      if (!mounted) {
        return;
      }
      DonySnackbar.show(
        context,
        message: 'Photo trop lourde (max ${e.maxMb} Mo).',
        type: DonySnackbarType.error,
      );
    } finally {
      _pickingAvatar = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthProfileUpdated) {
          // Pop only when the user explicitly tapped "Enregistrer".
          // Avatar uploads also produce AuthProfileUpdated but must NOT close
          // the screen — they just refresh the avatar in the builder.
          if (_saving) {
            _saving = false;
            context.pop(true);
          }
        }
        if (state is AuthError) {
          _saving = false;
          ErrorPresenter.show(context, state.error);
        }
      },
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          _lastUser = state.user;
        }
        if (state is AuthProfileUpdated) {
          _lastUser = state.user;
        }
        final user = _lastUser;
        if (user != null) {
          _initFromUser(user);
        }

        if (user == null) {
          return const Scaffold(
            appBar: DonyAppBar(title: 'Modifier le profil'),
            body: SizedBox.shrink(),
          );
        }

        final isTraveler = user.isTraveler;
        final isLoading = state is AuthLoading;
        // Distingue la sauvegarde (verrouille le form) de l'upload photo (overlay
        // avatar uniquement — le reste du form reste éditable).
        final isSaving = isLoading && _saving;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: const DonyAppBar(title: 'Modifier le profil'),
          // Bouton du bas dans `body` (pas `bottomNavigationBar`) :
          // Flutter ne remonte pas fiablement `bottomNavigationBar` au-dessus
          // du clavier, ce qui le cachait derrière avec plusieurs champs texte
          // sur cet écran. Même fix que phone_auth_screen.dart.
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.xl,
                    DonySpacing.lg,
                    DonySpacing.huge,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Jauge de complétion — masquée une fois à 100% ────────
                      ValueListenableBuilder<bool>(
                        valueListenable: smsAuthEnabledListenable,
                        builder: (context, phoneAuthEnabled, _) {
                          final steps = user.profileCompletionSteps(
                            countPhone: phoneAuthEnabled,
                          );
                          final total = UserModel.profileTotalSteps(
                            countPhone: phoneAuthEnabled,
                          );
                          if (steps >= total) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CompletionGauge(
                                user: user,
                                countPhone: phoneAuthEnabled,
                              ),
                              const SizedBox(height: DonySpacing.xxl),
                            ],
                          );
                        },
                      ),

                      // ── Avatar header — toujours actif, hors vue/édition ─────
                      Center(
                        child: Column(
                          children: [
                            Semantics(
                              button: true,
                              container: true,
                              excludeSemantics: true,
                              enabled: !isLoading,
                              label: 'Changer la photo de profil',
                              child: GestureDetector(
                                key: const ValueKey('avatar_pick_gesture'),
                                onTap: isLoading ? null : _pickAndUploadAvatar,
                                child: SizedBox(
                                  // Enforce min 44pt touch target around the 72pt avatar.
                                  width: 88,
                                  height: 88,
                                  child: Center(
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        // Avatar (possibly with loading overlay)
                                        Stack(
                                          children: [
                                            DonyAvatar(
                                              name: user.displayName,
                                              imageUrl: user.avatarUrl,
                                              size: DonyAvatarSize.xl,
                                            ),
                                            if (isLoading && !_saving)
                                              Positioned.fill(
                                                child: ClipOval(
                                                  child: ColoredBox(
                                                    color: Colors.black38,
                                                    child: Center(
                                                      child: SizedBox(
                                                        width: 28,
                                                        height: 28,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        // Camera badge at bottom-right
                                        Positioned(
                                          right: -4,
                                          bottom: -4,
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                                width: 2,
                                              ),
                                            ),
                                            child: DonyIcon(
                                              'camera',
                                              size: 14,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: DonySpacing.sm),
                            Text(
                              'Modifier la photo',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xxl),

                      // ── Section Identité ─────────────────────────────────────
                      const _SectionLabel(label: 'Identité'),
                      const SizedBox(height: DonySpacing.md),
                      if (!_editing)
                        _NameView(user: user)
                      else ...[
                        DonyTextField(
                          textInputAction: TextInputAction.next,
                          controller: _firstNameCtrl,
                          label: 'Prénom',
                          prefixWidget: DonyIcon(
                            'user',
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          enabled: !isSaving,
                        ),
                        const SizedBox(height: DonySpacing.md),
                        DonyTextField(
                          textInputAction: TextInputAction.next,
                          controller: _lastNameCtrl,
                          label: 'Nom de famille',
                          prefixWidget: DonyIcon(
                            'user',
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          enabled: !isSaving,
                        ),
                      ],
                      const SizedBox(height: DonySpacing.xxl),

                      // ── Section À propos ─────────────────────────────────────
                      const _SectionLabel(label: 'À propos'),
                      const SizedBox(height: DonySpacing.md),
                      if (!_editing)
                        _StaticInfoRow(
                          label: null,
                          value: user.bio,
                          placeholder: 'Aucune présentation',
                          bodyStyle: true,
                        )
                      else
                        TextFormField(
                          controller: _bioCtrl,
                          enabled: !isSaving,
                          maxLines: 4,
                          maxLength: 280,
                          decoration: const InputDecoration(
                            labelText: 'Présentation',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: DonySpacing.base,
                              vertical: DonySpacing.md,
                            ),
                          ),
                        ),
                      const SizedBox(height: DonySpacing.xxl),

                      // ── Section Coordonnées ──────────────────────────────────
                      // Email et téléphone restent des lignes de lecture même en
                      // édition : leur modification exige un code OTP, jamais une
                      // saisie libre — le tap ouvre un écran dédié (preuve de
                      // possession avant écriture), sans passer par "Enregistrer".
                      const _SectionLabel(label: 'Coordonnées'),
                      const SizedBox(height: DonySpacing.md),
                      ValueListenableBuilder<bool>(
                        valueListenable: smsAuthEnabledListenable,
                        builder: (_, phoneEnabled, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ContactInfoRow(
                              iconAsset: 'mail',
                              label: 'EMAIL',
                              value: user.email,
                              editing: _editing,
                              onTap: () => context.push('/profile/edit/email'),
                            ),
                            if (phoneEnabled) ...[
                              const SizedBox(height: DonySpacing.md),
                              _ContactInfoRow(
                                iconAsset: 'phone',
                                label: 'TÉLÉPHONE',
                                value: user.phoneNumber,
                                editing: _editing,
                                onTap: () =>
                                    context.push('/profile/edit/phone'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xxl),

                      // ── Section Informations personnelles ────────────────────
                      const _SectionLabel(label: 'Informations personnelles'),
                      const SizedBox(height: DonySpacing.md),
                      if (!_editing) ...[
                        _StaticInfoRow(
                          label: 'DATE DE NAISSANCE',
                          value: _birthDate != null
                              ? DateFormat('dd/MM/yyyy').format(_birthDate!)
                              : null,
                          placeholder: 'Non renseignée',
                        ),
                        const SizedBox(height: DonySpacing.md),
                        _StaticInfoRow(
                          label: 'VILLE',
                          value: user.city,
                          placeholder: 'Non renseignée',
                        ),
                      ] else ...[
                        _BirthDatePicker(
                          birthDate: _birthDate,
                          isLoading: isSaving,
                          onTap: _pickBirthDate,
                        ),
                        const SizedBox(height: DonySpacing.md),
                        DonyTextField(
                          textInputAction: TextInputAction.done,
                          controller: _cityCtrl,
                          label: "Ville / lieu d'habitation",
                          prefixWidget: DonyIcon(
                            'building-2',
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          enabled: !isSaving,
                        ),
                      ],
                      const SizedBox(height: DonySpacing.xxl),

                      // ── Section Préférences (voyageurs uniquement) ───────────
                      if (isTraveler) ...[
                        const _SectionLabel(label: 'Préférences'),
                        const SizedBox(height: DonySpacing.md),

                        if (!_editing) ...[
                          _StaticInfoRow(
                            label: 'LANGUES PARLÉES',
                            value: _selectedLanguages.isEmpty
                                ? null
                                : _selectedLanguages.join(', '),
                            placeholder: 'Non renseignées',
                          ),
                          const SizedBox(height: DonySpacing.md),
                          _StaticInfoRow(
                            label: 'MODE DE TRANSPORT',
                            value: _selectedTransport != null
                                ? _kTransportLabels[_selectedTransport]
                                : null,
                            placeholder: 'Non renseigné',
                          ),
                        ] else ...[
                          // Langues parlées
                          Text(
                            'Langues parlées',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: DonySpacing.sm),
                          Wrap(
                            spacing: DonySpacing.sm,
                            runSpacing: DonySpacing.sm,
                            children: _kAvailableLanguages.map((lang) {
                              final selected = _selectedLanguages.contains(
                                lang,
                              );
                              return FilterChip(
                                label: Text(lang),
                                selected: selected,
                                onSelected: isSaving
                                    ? null
                                    : (_) => _toggleLanguage(lang),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: DonySpacing.xl),

                          // Mode de transport
                          Text(
                            'Mode de transport',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: DonySpacing.sm),
                          _TransportModeSelector(
                            modes: _kTransportModes,
                            labels: _kTransportLabels,
                            selected: _selectedTransport,
                            isLoading: isSaving,
                            onSelect: _selectTransport,
                          ),
                        ],
                        const SizedBox(height: DonySpacing.xxl),
                      ],
                    ],
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
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
                  child: DonyButton(
                    label: _editing ? 'Enregistrer' : 'Modifier',
                    isLoading: isSaving,
                    onPressed: isLoading
                        ? null
                        : () => _editing
                              ? _save(isTraveler)
                              : setState(() => _editing = true),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Extracted sub-widgets ─────────────────────────────────────────────────────

/// Jauge de complétion du profil — 8 champs d'identité (`UserModel.
/// profileCompletionSteps` / `profileTotalSteps`). Vit ici plutôt que sur
/// l'écran « Moi » : c'est l'écran où on agit, pas juste où on regarde.
///
/// N'est jamais rendu une fois le profil complet — l'appelant conditionne
/// déjà son affichage sur `steps < total`, donc le seul état possible ici
/// est "en cours".
class _CompletionGauge extends StatelessWidget {
  const _CompletionGauge({required this.user, required this.countPhone});
  final UserModel user;
  final bool countPhone;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final steps = user.profileCompletionSteps(countPhone: countPhone);
    final total = UserModel.profileTotalSteps(countPhone: countPhone);
    final pct = steps / total;
    final tier = profileCompletionTierColor(cs, pct);

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Profil complet',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).round()}%',
                style: tt.bodyMedium?.copyWith(
                  color: tier.base,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.full),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: cs.outline.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(tier.base),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Photo, identité, coordonnées et informations complètent votre profil',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Vue (lecture) du nom — grand titre centré, avec repli si prénom/nom
/// manquent encore.
class _NameView extends StatelessWidget {
  const _NameView({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasName = user.displayName.trim().isNotEmpty;

    return Text(
      hasName ? user.displayName : 'Ajoutez votre prénom et nom',
      style: tt.titleLarge?.copyWith(
        color: hasName ? cs.onSurface : cs.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        fontStyle: hasName ? FontStyle.normal : FontStyle.italic,
      ),
    );
  }
}

/// Ligne « label / valeur » en lecture seule — informations personnelles et
/// préférences en mode vue. `label` null = pas de sur-titre (cas bio, en
/// simple paragraphe).
class _StaticInfoRow extends StatelessWidget {
  const _StaticInfoRow({
    required this.label,
    required this.value,
    required this.placeholder,
    this.bodyStyle = false,
  });

  final String? label;
  final String? value;
  final String placeholder;
  final bool bodyStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasValue = value != null && value!.isNotEmpty;
    final display = hasValue ? value! : placeholder;

    if (bodyStyle) {
      return Text(
        display,
        style: tt.bodyMedium?.copyWith(
          color: hasValue ? cs.onSurfaceVariant : cs.onSurfaceVariant,
          fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
          height: 1.5,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: DonySpacing.xxs),
        ],
        Text(
          display,
          style: tt.bodyLarge?.copyWith(
            color: hasValue ? cs.onSurface : cs.onSurfaceVariant,
            fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
            fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

/// Ligne email/téléphone : simple lecture (`_StaticInfoRow`) hors édition ;
/// en édition, devient une carte cliquable avec badge « Modifier »/« Ajouter »
/// qui ouvre l'écran OTP dédié — jamais un champ de saisie directe.
class _ContactInfoRow extends StatelessWidget {
  const _ContactInfoRow({
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.editing,
    required this.onTap,
  });

  final String iconAsset;
  final String label;
  final String? value;
  final bool editing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    if (!editing) {
      return _StaticInfoRow(
        label: label,
        value: value,
        placeholder: 'Non ajouté',
      );
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '$label, ${hasValue ? value : 'non ajouté'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.md),
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
              DonyIcon(iconAsset, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      hasValue ? value! : 'Non ajouté',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        color: hasValue ? cs.onSurface : cs.onSurfaceVariant,
                        fontWeight: hasValue
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.sm,
                  vertical: DonySpacing.xxs + 1,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  hasValue ? 'Modifier' : 'Ajouter',
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _BirthDatePicker extends StatelessWidget {
  const _BirthDatePicker({
    required this.birthDate,
    required this.isLoading,
    required this.onTap,
  });

  final DateTime? birthDate;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
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
            DonyIcon('cake', color: cs.onSurfaceVariant, size: 20),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Text(
                birthDate != null
                    ? DateFormat('dd/MM/yyyy').format(birthDate!)
                    : 'Date de naissance',
                style: tt.bodyLarge?.copyWith(
                  color: birthDate != null ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: birthDate != null
                      ? FontWeight.w500
                      : FontWeight.w400,
                ),
              ),
            ),
            DonyIcon('chevron-right', color: cs.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TransportModeSelector extends StatelessWidget {
  const _TransportModeSelector({
    required this.modes,
    required this.labels,
    required this.selected,
    required this.isLoading,
    required this.onSelect,
  });

  final List<String> modes;
  final Map<String, String> labels;
  final String? selected;
  final bool isLoading;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: modes.map((mode) {
        final isSelected = selected == mode;
        final cs = Theme.of(context).colorScheme;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: mode != modes.last ? DonySpacing.sm : 0,
            ),
            child: GestureDetector(
              onTap: isLoading ? null : () => onSelect(mode),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: DonySpacing.sm,
                  horizontal: DonySpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? cs.primaryContainer : cs.surface,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  border: Border.all(
                    color: isSelected ? cs.primary : cs.outline,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    labels[mode] ?? mode,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
