import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/phone_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// E.164 phone regex — see [kRecipientPhoneE164].
final _phoneRegex = kRecipientPhoneE164;

const _kCountries = [
  _Country('SN', 'Sénégal'),
  _Country('CI', "Côte d'Ivoire"),
  _Country('ML', 'Mali'),
  _Country('CM', 'Cameroun'),
];

class RecipientEditScreen extends StatefulWidget {
  const RecipientEditScreen({
    super.key,
    this.recipientId,
    this.initialFullName,
    this.initialPhoneE164,
  });

  final String? recipientId;
  final String? initialFullName;
  final String? initialPhoneE164;

  @override
  State<RecipientEditScreen> createState() => _RecipientEditScreenState();
}

class _RecipientEditScreenState extends State<RecipientEditScreen> {
  final _fullNameCtrl = TextEditingController();
  final _relationshipCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String _country = 'SN';
  final _notesCtrl = TextEditingController();
  bool _initialized = false;
  bool _submitted = false;
  String? _phoneError;
  String? _whatsappError;
  bool _isDefault = false;

  bool get _isEditing => widget.recipientId != null;

  bool get _isValid =>
      _fullNameCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty &&
      _phoneRegex.hasMatch(_phoneCtrl.text.trim()) &&
      _cityCtrl.text.trim().isNotEmpty;

  void _validatePhone(String value) {
    final v = value.trim();
    setState(() {
      _phoneError =
          v.isEmpty || _phoneRegex.hasMatch(v) ? null : 'Format invalide (+33612345678)';
    });
  }

  void _validateWhatsapp(String value) {
    final v = value.trim();
    setState(() {
      _whatsappError = v.isEmpty || _phoneRegex.hasMatch(v)
          ? null
          : 'Format invalide (+22177123456)';
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialFullName != null) _fullNameCtrl.text = widget.initialFullName!;
    if (widget.initialPhoneE164 != null) {
      _phoneCtrl.text = widget.initialPhoneE164!;
      _validatePhone(widget.initialPhoneE164!);
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _relationshipCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _prefill(Recipient r) {
    _fullNameCtrl.text = r.fullName;
    _relationshipCtrl.text = r.relationship ?? '';
    _phoneCtrl.text = r.phoneE164;
    _whatsappCtrl.text = r.whatsappE164 ?? '';
    _streetCtrl.text = r.street ?? '';
    _cityCtrl.text = r.city;
    _country = r.country;
    _notesCtrl.text = r.notes ?? '';
    _isDefault = r.isDefault;
  }

  void _submit(BuildContext context) {
    if (!_isValid) {
      return;
    }
    _submitted = true;
    final phone = _phoneCtrl.text.trim();
    final whatsapp = _whatsappCtrl.text.trim();

    if (_isEditing) {
      context.read<RecipientBloc>().add(RecipientUpdated(
            id: widget.recipientId!,
            fullName: _fullNameCtrl.text.trim(),
            relationship: _relationshipCtrl.text.trim().isEmpty
                ? null
                : _relationshipCtrl.text.trim(),
            phoneE164: phone,
            whatsappE164: whatsapp.isEmpty ? null : whatsapp,
            street: _streetCtrl.text.trim().isEmpty
                ? null
                : _streetCtrl.text.trim(),
            city: _cityCtrl.text.trim(),
            country: _country,
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            isDefault: _isDefault,
          ));
    } else {
      context.read<RecipientBloc>().add(RecipientCreated(
            fullName: _fullNameCtrl.text.trim(),
            relationship: _relationshipCtrl.text.trim().isEmpty
                ? null
                : _relationshipCtrl.text.trim(),
            phoneE164: phone,
            whatsappE164: whatsapp.isEmpty ? null : whatsapp,
            street: _streetCtrl.text.trim().isEmpty
                ? null
                : _streetCtrl.text.trim(),
            city: _cityCtrl.text.trim(),
            country: _country,
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            isDefault: _isDefault,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecipientBloc, RecipientState>(
      listener: (context, state) {
        if (!_initialized && _isEditing && state.status == RecipientStatus.success) {
          final found = state.recipients
              .where((r) => r.id == widget.recipientId)
              .firstOrNull;
          if (found != null) {
            _prefill(found);
            _initialized = true;
          }
        }
        if (_submitted && state.status == RecipientStatus.success) {
          DonySnackbar.show(
            context,
            message: _isEditing
                ? 'Destinataire mis à jour'
                : 'Destinataire ajouté',
            type: DonySnackbarType.success,
          );
          context.pop(true);
        }
        if (state.status == RecipientStatus.error && state.error != null) {
          DonySnackbar.show(
            context,
            message: state.error!,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isLoading = state.status == RecipientStatus.loading;
        final tt = Theme.of(context).textTheme;

        return DonyPageScaffold(
          title: _isEditing ? 'Modifier le destinataire' : 'Nouveau destinataire',
          stickyBottom: DonyButton(
            label: 'Enregistrer',
            onPressed: isLoading ? null : () => _submit(context),
            isLoading: isLoading,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyTextField(
                controller: _fullNameCtrl,
                label: 'Nom complet',
                hint: 'Mamadou Diallo',
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              DonyTextField(
                controller: _relationshipCtrl,
                label: 'Lien (optionnel)',
                hint: 'Ex : Mère, Frère, Ami…',
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(delay: 40.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              DonyTextField(
                controller: _phoneCtrl,
                label: 'Téléphone (E.164)',
                hint: '+22177123456',
                keyboardType: TextInputType.phone,
                onChanged: (v) {
                  _validatePhone(v);
                  setState(() {});
                },
                errorText: _phoneError,
              ).animate().fadeIn(delay: 80.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              DonyTextField(
                controller: _whatsappCtrl,
                label: 'WhatsApp (optionnel, E.164)',
                hint: '+22177123456',
                keyboardType: TextInputType.phone,
                onChanged: (v) {
                  _validateWhatsapp(v);
                  setState(() {});
                },
                errorText: _whatsappError,
              ).animate().fadeIn(delay: 120.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.xl),
              Text(
                'Adresse de livraison',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ).animate().fadeIn(delay: 140.ms, duration: 280.ms),
              const SizedBox(height: DonySpacing.sm),
              DonyTextField(
                controller: _streetCtrl,
                label: 'Rue (optionnel)',
                hint: '12 rue Blaise Diagne',
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(delay: 160.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              DonyTextField(
                controller: _cityCtrl,
                label: 'Ville',
                hint: 'Dakar',
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn(delay: 200.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              _CountryDropdown(
                value: _country,
                onChanged: (v) => setState(() => _country = v ?? _country),
              ).animate().fadeIn(delay: 240.ms, duration: 280.ms),
              const SizedBox(height: DonySpacing.base),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Notes (optionnel)',
                  hintText: 'Informations utiles pour la livraison…',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: DonySpacing.md,
                  ),
                ),
              ).animate().fadeIn(delay: 280.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              SwitchListTile.adaptive(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Destinataire par défaut'),
                subtitle: const Text('Présélectionné lors de tes prochains envois'),
              ).animate().fadeIn(delay: 320.ms, duration: 280.ms),
            ],
          ),
        );
      },
    );
  }
}

class _CountryDropdown extends StatelessWidget {
  const _CountryDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          onChanged: onChanged,
          style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          hint: Text(
            'Pays de destination',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          items: _kCountries
              .map((c) => DropdownMenuItem(
                    value: c.code,
                    child: Text(c.label),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _Country {
  const _Country(this.code, this.label);
  final String code;
  final String label;
}
