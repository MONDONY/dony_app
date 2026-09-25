import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/contact_picker_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/phone_validation.dart';
import 'package:dony/features/recipients/presentation/widgets/recipient_section.dart'
    show countryFromPhone;
import 'package:dony/l10n/l10n.dart';
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
  // Le texte traduit ne se calcule qu'au build (jamais dans initState) : on
  // ne garde ici que le fait générateur, pas un texte figé dans une langue.
  bool _phoneInvalid = false;
  bool _isDefault = false;
  bool _importing = false;

  bool get _isEditing => widget.recipientId != null;

  bool get _isValid =>
      _fullNameCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty &&
      _phoneRegex.hasMatch(_phoneCtrl.text.trim());

  void _validatePhone(String value) {
    final v = value.trim();
    setState(() {
      _phoneInvalid = v.isNotEmpty && !_phoneRegex.hasMatch(v);
    });
  }

  Future<void> _pickFromPhone() async {
    setState(() => _importing = true);
    final contact = await getIt<ContactPickerService>().pick();
    if (!mounted) {
      return;
    }
    setState(() => _importing = false);
    if (contact == null) {
      return;
    }
    if (contact.fullName != null && contact.fullName!.isNotEmpty) {
      _fullNameCtrl.text = contact.fullName!;
    }
    if (contact.phone != null && contact.phone!.isNotEmpty) {
      _phoneCtrl.text = contact.phone!;
      _validatePhone(contact.phone!);
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialFullName != null) {
      _fullNameCtrl.text = widget.initialFullName!;
    }
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
      context.read<RecipientBloc>().add(
        RecipientUpdated(
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
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          isDefault: _isDefault,
        ),
      );
    } else {
      context.read<RecipientBloc>().add(
        RecipientCreated(
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
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          isDefault: _isDefault,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecipientBloc, RecipientState>(
      listener: (context, state) {
        if (!_initialized &&
            _isEditing &&
            state.status == RecipientStatus.success) {
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
                ? context.l10n.recipientUpdatedMessage
                : context.l10n.recipientAddedMessage,
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
        final cs = Theme.of(context).colorScheme;
        final l = context.l10n;

        return DonyPageScaffold(
          title: _isEditing ? l.recipientEditTitle : l.recipientCreateTitle,
          stickyBottom: DonyButton(
            label: l.commonSave,
            onPressed: isLoading ? null : () => _submit(context),
            isLoading: isLoading,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isEditing) ...[
                _ContactImportButton(
                  loading: _importing,
                  onTap: _importing ? null : _pickFromPhone,
                ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.03),
                const SizedBox(height: DonySpacing.base),
              ],
              DonyTextField(
                    controller: _fullNameCtrl,
                    label: l.recipientFullNameFieldLabel,
                    hint: 'Mamadou Diallo', // i18n-ignore: exemple de saisie
                    onChanged: (_) => setState(() {}),
                  )
                  .animate()
                  .fadeIn(delay: 40.ms, duration: 280.ms)
                  .slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              DonyTextField(
                    controller: _phoneCtrl,
                    label: l.recipientPhoneFieldLabel,
                    hint: '+22177123456', // i18n-ignore: exemple de saisie
                    keyboardType: TextInputType.phone,
                    onChanged: (v) {
                      _validatePhone(v);
                      setState(() {});
                    },
                    errorText: _phoneInvalid
                        ? l.recipientPhoneInvalidFormat(
                            '+33612345678', // i18n-ignore: exemple de saisie
                          )
                        : null,
                  )
                  .animate()
                  .fadeIn(delay: 80.ms, duration: 280.ms)
                  .slideY(begin: 0.03),
              const SizedBox(height: DonySpacing.base),
              SwitchListTile.adaptive(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                tileColor: cs.primary.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.base,
                ),
                title: Text(l.recipientDefaultToggleTitle),
                subtitle: Text(l.recipientDefaultToggleSubtitle),
              ).animate().fadeIn(delay: 120.ms, duration: 280.ms),
            ],
          ),
        );
      },
    );
  }
}

class _ContactImportButton extends StatelessWidget {
  const _ContactImportButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.md,
          ),
          child: Row(
            children: [
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                )
              else
                DonyIcon('contact', size: 18, color: cs.primary),
              const SizedBox(width: DonySpacing.sm),
              Text(
                context.l10n.recipientImportContactsAction,
                style: tt.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
