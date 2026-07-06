import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/contact_picker_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/recipient_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Bottom sheet de sélection d'un destinataire enregistré.
/// Même mécanique que [PickupAddressPickerSheet] (dans `matching/`) :
/// recherche locale, liste radio avec défaut présélectionné, actions
/// « Nouveau » et « Choisir dans mes contacts », bouton confirmer.
class RecipientPickerSheet extends StatefulWidget {
  const RecipientPickerSheet({super.key, this.currentPhone});

  final String? currentPhone;

  static Future<Recipient?> show(BuildContext context, {String? currentPhone}) {
    return showModalBottomSheet<Recipient>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => getIt<RecipientBloc>()..add(const RecipientLoaded()),
        child: RecipientPickerSheet(currentPhone: currentPhone),
      ),
    );
  }

  @override
  State<RecipientPickerSheet> createState() => _RecipientPickerSheetState();
}

class _RecipientPickerSheetState extends State<RecipientPickerSheet> {
  final _searchCtrl = TextEditingController();
  String? _selectedId;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.recipientPickerOpened,
        ),
      );
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Recipient? _selected(List<Recipient> recipients) {
    if (recipients.isEmpty) {
      return null;
    }
    if (_selectedId != null) {
      return recipients.where((r) => r.id == _selectedId).firstOrNull;
    }
    final current = widget.currentPhone?.trim();
    if (current != null && current.isNotEmpty) {
      final match = recipients.where((r) => r.phoneE164 == current).firstOrNull;
      if (match != null) {
        return match;
      }
    }
    return recipients.where((r) => r.isDefault).firstOrNull ?? recipients.first;
  }

  /// Nouveau destinataire (optionnellement pré-rempli depuis un contact) :
  /// push l'écran d'édition, puis recharge et sélectionne le plus récent.
  Future<void> _createNew({
    String? fullName,
    String? phone,
    required String source,
  }) async {
    final bloc = context.read<RecipientBloc>();
    final created = await context.push<bool>(
      '/profile/recipients/new',
      extra: {'fullName': fullName, 'phone': phone},
    );
    if ((created ?? false) && mounted) {
      bloc
        ..add(const RecipientLoaded())
        ..add(RecipientPicked(source));
      // La liste est triée par updatedAt desc → le nouveau est en tête.
      // On vide la sélection manuelle pour que _selected retombe dessus
      // via le stream du bloc (voir BlocListener ci-dessous).
      setState(() => _selectedId = null);
      _pendingSelectNewest = true;
    }
  }

  bool _pendingSelectNewest = false;

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
    await _createNew(
      fullName: contact.fullName,
      phone: contact.phone,
      source: 'phone_contact',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DonyRadius.sheet),
            ),
          ),
          padding: EdgeInsets.only(bottom: keyboard),
          // Material(transparency) : le Container ci-dessus peint un fond
          // opaque entre le Material ancêtre (Scaffold) et les ListTile de
          // la liste, ce qui rend leurs splashes/tileColor invisibles sans
          // ce Material intermédiaire (cf. warning ListTile du framework).
          child: Material(
            type: MaterialType.transparency,
            child: BlocConsumer<RecipientBloc, RecipientState>(
              listener: (context, state) {
                if (_pendingSelectNewest &&
                    state.status == RecipientStatus.success &&
                    state.recipients.isNotEmpty) {
                  _pendingSelectNewest = false;
                  setState(() => _selectedId = state.recipients.first.id);
                }
              },
              builder: (context, state) {
                final filtered = filterRecipients(
                  state.recipients,
                  _searchCtrl.text,
                );
                final selected = _selected(state.recipients);
                return Column(
                  children: [
                    // Handle + header — identiques au picker d'adresses.
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.lg,
                        vertical: DonySpacing.md,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '👤  Destinataire',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const DonyIcon('x'),
                            onPressed: () => Navigator.of(context).pop(),
                            style: IconButton.styleFrom(
                              backgroundColor: cs.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (state.recipients.length > 3)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DonySpacing.lg,
                          0,
                          DonySpacing.lg,
                          DonySpacing.md,
                        ),
                        child: _SearchField(controller: _searchCtrl),
                      ),
                    const Divider(height: 1),
                    Expanded(
                      child:
                          state.status == RecipientStatus.loading &&
                              state.recipients.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.only(
                                bottom: DonySpacing.sm,
                              ),
                              children: [
                                _ActionTile(
                                  icon: 'plus',
                                  label: 'Nouveau destinataire',
                                  onTap: () => _createNew(source: 'new'),
                                ),
                                _ActionTile(
                                  icon: 'contact',
                                  label: 'Choisir dans mes contacts',
                                  loading: _importing,
                                  onTap: _importing ? null : _pickFromPhone,
                                ),
                                const Divider(
                                  indent: 20,
                                  endIndent: 20,
                                  height: 1,
                                ),
                                if (filtered.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      DonySpacing.lg,
                                      DonySpacing.md,
                                      DonySpacing.lg,
                                      4,
                                    ),
                                    child: Text(
                                      'MES DESTINATAIRES',
                                      style: tt.labelSmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        letterSpacing: 0.08,
                                      ),
                                    ),
                                  ),
                                  ...filtered.map(
                                    (r) => _RecipientRow(
                                      recipient: r,
                                      isSelected: selected?.id == r.id,
                                      onTap: () =>
                                          setState(() => _selectedId = r.id),
                                    ),
                                  ),
                                ] else if (state.recipients.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(
                                      DonySpacing.xl,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Aucun résultat',
                                        style: tt.bodyMedium?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DonySpacing.lg,
                          DonySpacing.sm,
                          DonySpacing.lg,
                          DonySpacing.md,
                        ),
                        child: DonyButton(
                          label: 'Confirmer ce destinataire',
                          onPressed: selected == null
                              ? null
                              : () {
                                  context.read<RecipientBloc>().add(
                                    const RecipientPicked('saved'),
                                  );
                                  Navigator.of(context).pop(selected);
                                },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.loading = false,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
        child: loading
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : DonyIcon(icon, size: 18, color: cs.primary),
      ),
      title: Text(
        label,
        style: tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.primary,
        ),
      ),
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.recipient,
    required this.isSelected,
    required this.onTap,
  });

  final Recipient recipient;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = recipient.relationship?.isNotEmpty == true
        ? recipient.relationship!
        : recipient.fullName;
    return ListTile(
      onTap: onTap,
      tileColor: isSelected ? cs.primary.withValues(alpha: 0.05) : null,
      leading: DonyAvatar(name: recipient.fullName, size: DonyAvatarSize.sm),
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (recipient.isDefault) ...[
            const SizedBox(width: DonySpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'Par défaut',
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${recipient.fullName} · ${recipient.phoneE164} · ${recipient.city}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? cs.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline,
            width: 2,
          ),
        ),
        child: isSelected
            ? const DonyIcon('check', color: Colors.white, size: 12)
            : null,
      ),
    );
  }
}

// ── Champ de recherche ────────────────────────────────────────────────────
// Copié de `pickup_address_picker_sheet.dart` (`_SearchField`), simplifié :
// pas de `focusNode`/`loading` — la recherche ici est locale et synchrone
// (`filterRecipients`), pas d'appel réseau à débouncer.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Rechercher un destinataire…',
        hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(
            left: DonySpacing.md,
            right: DonySpacing.sm,
          ),
          child: DonyIcon('search', size: 18, color: cs.onSurfaceVariant),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const DonyIcon('x', size: 16),
                onPressed: () => controller.clear(),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
      ),
    );
  }
}
