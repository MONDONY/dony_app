import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/phone_validation.dart';
import 'package:dony/features/recipients/presentation/widgets/recipient_section.dart'
    show countryFromPhone;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// E.164 phone regex — see [kRecipientPhoneE164].
final _phoneRegex = kRecipientPhoneE164;

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
  bool _isDefault = false;

  bool get _isEditing => widget.recipientId != null;

  bool get _isValid =>
      _fullNameCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty &&
      _phoneRegex.hasMatch(_phoneCtrl.text.trim());

  void _validatePhone(String value) {
    final v = value.trim();
    setState(() {
      _phoneError =
          v.isEmpty || _phoneRegex.hasMatch(v) ? null : 'Format invalide (+33612345678)';
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
    _cityCtrl.text = r.city ?? '';
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
    final city = _cityCtrl.text.trim();
    // No country UI in this trimmed-down form — preserve the prefilled
    // value when editing, infer it from the phone prefix when creating.
    final country = _isEditing ? _country : countryFromPhone(phone);

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
            city: city.isEmpty ? null : city,
            country: country,
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
            city: city.isEmpty ? null : city,
            country: country,
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
                controller: _phoneCtrl,
                label: 'Téléphone (E.164)',
                hint: '+22177123456',
                keyboardType: TextInputType.phone,
                onChanged: (v) {
                  _validatePhone(v);
                  setState(() {});
                },
                errorText: _phoneError,
              ).animate().fadeIn(delay: 40.ms, duration: 280.ms).slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              SwitchListTile.adaptive(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Destinataire par défaut'),
                subtitle: const Text('Présélectionné lors de tes prochains envois'),
              ).animate().fadeIn(delay: 80.ms, duration: 280.ms),
            ],
          ),
        );
      },
    );
  }
}
