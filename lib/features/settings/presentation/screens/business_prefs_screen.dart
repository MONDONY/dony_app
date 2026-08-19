import 'dart:async';

import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BusinessPrefsScreen extends StatefulWidget {
  const BusinessPrefsScreen({super.key});

  @override
  State<BusinessPrefsScreen> createState() => _BusinessPrefsScreenState();
}

class _BusinessPrefsScreenState extends State<BusinessPrefsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<BusinessPrefsBloc>().add(const BusinessPrefsSyncRequested());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Préférences'),
      body: BlocBuilder<BusinessPrefsBloc, BusinessPrefsState>(
        builder: (context, state) =>
            ListView(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.lg,
                    DonySpacing.lg,
                    DonySpacing.huge,
                  ),
                  children: [
                    if (state.errorMessage != null) ...[
                      _ErrorBanner(message: state.errorMessage!),
                      const SizedBox(height: DonySpacing.lg),
                    ],
                    const SettingsSectionHeader('UNITÉS'),
                    SettingsFlatGroup(
                      children: [
                        DonyListTile(
                          iconAsset: 'scale',
                          iconColor: cs.primary,
                          iconBgColor: cs.primaryContainer,
                          label: 'Unité de poids',
                          trailing: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'kg', label: Text('kg')),
                              ButtonSegment(value: 'lbs', label: Text('lbs')),
                            ],
                            selected: {state.weightUnit},
                            onSelectionChanged: (s) => context
                                .read<BusinessPrefsBloc>()
                                .add(WeightUnitChanged(s.first)),
                          ),
                        ),
                      ],
                    ),
                    const SettingsSectionHeader('DEVISE'),
                    SettingsFlatGroup(
                      children: [
                        DonyListTile(
                          iconAsset: 'globe',
                          iconColor: cs.primary,
                          iconBgColor: cs.primaryContainer,
                          label: 'Pays',
                          subtitle: state.countryLocked
                              ? 'Verrouillé : un envoi est en cours ou votre compte de paiement est créé'
                              : null,
                          trailing: Text(
                            CountryCatalog.byCode(state.country)?.name ??
                                'Choisir mon pays',
                            style: tt.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          enabled: !state.countryLocked,
                          onTap: () =>
                              unawaited(_openCountryPicker(context, state)),
                        ),
                        DonyListTile(
                          iconAsset: 'euro',
                          iconColor: cs.primary,
                          iconBgColor: cs.primaryContainer,
                          label: 'Devise',
                          subtitle: 'Définie par votre pays',
                          trailing: Text(
                            state.currencyCode,
                            style: tt.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          enabled: false,
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SettingsSectionHeader('GÉOLOCALISATION'),
                    SettingsFlatGroup(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(DonySpacing.base),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Rayon de collecte',
                                    style: tt.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${state.pickupRadiusKm} km',
                                    style: tt.labelMedium?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: state.pickupRadiusKm.toDouble(),
                                min: 1,
                                max: 50,
                                divisions: 49,
                                activeColor: cs.primary,
                                onChanged: (v) => context
                                    .read<BusinessPrefsBloc>()
                                    .add(PickupRadiusChanged(v.round())),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DonySpacing.lg),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, authState) {
                        if (authState is! AuthAuthenticated) {
                          return const SizedBox.shrink();
                        }
                        if (!authState.user.isTraveler) {
                          return const SizedBox.shrink();
                        }
                        return _TravelerSection(state: state);
                      },
                    ),
                  ],
                )
                .animate()
                .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
                .slideY(
                  begin: 0.04,
                  duration: 280.ms,
                  curve: Curves.easeOutCubic,
                ),
      ),
    );
  }
}

// ── Sélecteur de pays ────────────────────────────────────────────────────────

/// Ouvre la liste des pays desservis et, si l'utilisateur en choisit un
/// nouveau, envoie [CountryChanged] au [BusinessPrefsBloc]. La devise n'est
/// jamais calculée ici : elle revient recalculée par le serveur dans la
/// réponse du `PUT`.
Future<void> _openCountryPicker(
  BuildContext context,
  BusinessPrefsState state,
) async {
  final bloc = context.read<BusinessPrefsBloc>();
  final selected = await DonyBottomSheet.show<String>(
    context,
    title: 'Pays',
    heightFraction: 0.85,
    child: _CountryPickerList(selectedCode: state.country),
  );
  if (selected == null || !context.mounted) {
    return;
  }
  bloc.add(CountryChanged(selected));
}

class _CountryPickerList extends StatefulWidget {
  const _CountryPickerList({required this.selectedCode});

  final String? selectedCode;

  @override
  State<_CountryPickerList> createState() => _CountryPickerListState();
}

class _CountryPickerListState extends State<_CountryPickerList> {
  final _controller = TextEditingController();
  List<Country> _results = CountryCatalog.all;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _results = CountryCatalog.search(_controller.text));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyTextField(
          controller: _controller,
          hint: 'Rechercher un pays',
          prefixIcon: Icons.search,
        ),
        const SizedBox(height: DonySpacing.md),
        if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.xl),
            child: Text(
              'Aucun pays trouvé',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          )
        else
          for (final country in _results)
            ListTile(
              title: Text(country.name),
              subtitle: Text(
                '${country.currency.code} · ${country.currency.symbol}',
              ),
              trailing: widget.selectedCode == country.code
                  ? DonyIcon('check', color: cs.primary)
                  : null,
              onTap: () => context.pop(country.code),
            ),
      ],
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

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
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Row(
        children: [
          DonyIcon('wifi-off', color: cs.onErrorContainer, size: 18),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              message,
              style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Traveler section ──────────────────────────────────────────────────────────

class _TravelerSection extends StatefulWidget {
  const _TravelerSection({required this.state});

  final BusinessPrefsState state;

  @override
  State<_TravelerSection> createState() => _TravelerSectionState();
}

class _TravelerSectionState extends State<_TravelerSection> {
  late final TextEditingController _delayController;

  @override
  void initState() {
    super.initState();
    _delayController = TextEditingController(
      text: widget.state.responseDelayHours != null
          ? '${widget.state.responseDelayHours}'
          : '',
    );
  }

  @override
  void didUpdateWidget(_TravelerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newHours = widget.state.responseDelayHours;
    final oldHours = oldWidget.state.responseDelayHours;
    if (newHours != oldHours) {
      final newText = newHours != null ? '$newHours' : '';
      if (_delayController.text != newText) {
        _delayController.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _delayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final state = widget.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with badge
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.sm,
            DonySpacing.lg,
            DonySpacing.sm,
            DonySpacing.sm,
          ),
          child: Row(
            children: [
              Text(
                'MES TRAJETS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  'Voyageur',
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Flat group container
        SettingsFlatGroup(
          children: [
            // ── Poids par défaut ──────────────────────────────────────────
            DonyListTile(
              iconAsset: 'package',
              iconColor: cs.primary,
              iconBgColor: cs.primaryContainer,
              label: 'Poids par défaut',
              subtitle: 'Pré-remplit vos annonces',
              trailing: Text(
                '${state.defaultPackageWeightKg} kg',
                style: tt.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              showDivider: false,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.base,
                0,
                DonySpacing.base,
                DonySpacing.sm,
              ),
              child: Slider(
                value: state.defaultPackageWeightKg.toDouble(),
                min: 1,
                max: 50,
                divisions: 49,
                activeColor: cs.primary,
                onChanged: (v) => context.read<BusinessPrefsBloc>().add(
                  DefaultWeightChanged(v.round()),
                ),
              ),
            ),
            Divider(height: 1, color: cs.outline),

            // ── Prix minimum ──────────────────────────────────────────────
            DonyListTile(
              iconAsset: 'euro',
              iconColor: cs.primary,
              iconBgColor: cs.primaryContainer,
              label: 'Prix minimum',
              subtitle:
                  '0 ${SupportedCurrency.symbolOf(state.currencyCode)} = aucun filtre',
              trailing: Text(
                state.minBidPriceEur == 0
                    ? 'Aucun'
                    : formatPriceIn(
                        state.minBidPriceEur.toDouble(),
                        state.currencyCode,
                      ),
                style: tt.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              showDivider: false,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.base,
                0,
                DonySpacing.base,
                DonySpacing.sm,
              ),
              child: Slider(
                value: state.minBidPriceEur.toDouble(),
                max: 50,
                divisions: 50,
                activeColor: cs.primary,
                onChanged: (v) => context.read<BusinessPrefsBloc>().add(
                  MinBidPriceChanged(v.round()),
                ),
              ),
            ),
            Divider(height: 1, color: cs.outline),

            // ── Mode de contact ───────────────────────────────────────────
            DonyListTile(
              iconAsset: 'phone',
              iconColor: cs.primary,
              iconBgColor: cs.primaryContainer,
              label: 'Mode de contact',
              showDivider: false,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.base,
                0,
                DonySpacing.base,
                DonySpacing.base,
              ),
              child: SegmentedButton<String>(
                emptySelectionAllowed: true,
                segments: const [
                  ButtonSegment(value: 'call', label: Text('Appel')),
                  ButtonSegment(value: 'message', label: Text('Message')),
                  ButtonSegment(value: 'both', label: Text('Les deux')),
                ],
                selected: state.contactMode != null
                    ? {state.contactMode!}
                    : const <String>{},
                onSelectionChanged: (s) => context
                    .read<BusinessPrefsBloc>()
                    .add(ContactModeChanged(s.isEmpty ? null : s.first)),
              ),
            ),
            Divider(height: 1, color: cs.outline),

            // ── Délai de réponse ──────────────────────────────────────────
            DonyListTile(
              iconAsset: 'timer',
              iconColor: cs.primary,
              iconBgColor: cs.primaryContainer,
              label: 'Délai de réponse',
              showDivider: false,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.base,
                0,
                DonySpacing.base,
                DonySpacing.base,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: DonySpacing.xs,
                      runSpacing: DonySpacing.xs,
                      children: [
                        for (final h in [1, 2, 6, 24])
                          ChoiceChip(
                            label: Text('${h}h'),
                            selected: state.responseDelayHours == h,
                            onSelected: (selected) {
                              context.read<BusinessPrefsBloc>().add(
                                ResponseDelayChanged(selected ? h : null),
                              );
                              if (selected) {
                                _delayController.text = '$h';
                              } else {
                                _delayController.clear();
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _delayController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: 'ex. 3',
                        suffixText: 'h',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.sm,
                          vertical: DonySpacing.sm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DonyRadius.md),
                        ),
                      ),
                      onChanged: (v) {
                        if (v.isEmpty) {
                          context.read<BusinessPrefsBloc>().add(
                            const ResponseDelayChanged(null),
                          );
                        } else {
                          final parsed = int.tryParse(v);
                          if (parsed != null && parsed >= 1) {
                            context.read<BusinessPrefsBloc>().add(
                              ResponseDelayChanged(parsed),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 280.ms, curve: Curves.easeOutCubic);
  }
}
