import 'dart:async';

import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/currency_selector.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
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
    final l = context.l10n;

    return Scaffold(
      appBar: DonyAppBar(title: l.prefsTitle),
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
                    if (state.hasSyncError) ...[
                      _ErrorBanner(message: l.settingsSyncFailed),
                      const SizedBox(height: DonySpacing.lg),
                    ],
                    SettingsSectionHeader(l.prefsSectionUnits),
                    SettingsFlatGroup(
                      children: [
                        DonyListTile(
                          iconAsset: 'scale',
                          iconColor: cs.primary,
                          iconBgColor: cs.primaryContainer,
                          label: l.prefsWeightUnitLabel,
                          trailing: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value:
                                    'kg', // i18n-ignore: code d'unité stocké/envoyé, identique en anglais
                                label: Text(
                                  'kg',
                                ), // i18n-ignore: unité identique en anglais
                              ),
                              ButtonSegment(
                                value:
                                    'lbs', // i18n-ignore: code d'unité stocké/envoyé, identique en anglais
                                label: Text(
                                  'lbs',
                                ), // i18n-ignore: unité identique en anglais
                              ),
                            ],
                            selected: {state.weightUnit},
                            onSelectionChanged: (s) => context
                                .read<BusinessPrefsBloc>()
                                .add(WeightUnitChanged(s.first)),
                          ),
                        ),
                      ],
                    ),
                    SettingsSectionHeader(l.prefsSectionCurrency),
                    SettingsFlatGroup(
                      children: [
                        DonyListTile(
                          iconAsset: 'globe',
                          iconColor: cs.primary,
                          iconBgColor: cs.primaryContainer,
                          label: l.prefsCountryLabel,
                          subtitle: state.countryLocked
                              ? l.prefsCountryLockedSubtitle
                              : null,
                          trailing: Text(
                            CountryCatalog.byCode(state.country) != null
                                ? countryName(l, state.country!)
                                : l.prefsCountryPlaceholder,
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
                          label: l.prefsCurrencyLabel,
                          subtitle: state.currencyLocked
                              ? l.prefsCurrencyLockedSubtitle
                              : null,
                          trailing: Text(
                            state.currencyCode,
                            style: tt.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          enabled: !state.currencyLocked,
                          onTap: () =>
                              unawaited(_openCurrencySelector(context, state)),
                        ),
                        DonyListTile(
                          iconAsset: 'eye',
                          iconColor: cs.primary,
                          iconBgColor: cs.primaryContainer,
                          label: l.prefsDisplayCurrencyLabel,
                          subtitle: l.prefsDisplayCurrencySubtitle,
                          trailing: Text(
                            state.displayCurrencyCode == 'AUTO'
                                ? l.prefsAutoLabel
                                : state.displayCurrencyCode,
                            style: tt.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          showDivider: false,
                          onTap: () => unawaited(
                            _openDisplayCurrencyPicker(context, state),
                          ),
                        ),
                      ],
                    ),
                    SettingsSectionHeader(l.prefsSectionGeolocation),
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
                                    l.prefsPickupRadiusLabel,
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
    title: context.l10n.prefsCountryLabel,
    heightFraction: 0.85,
    child: _CountryPickerList(selectedCode: state.country),
  );
  if (selected == null || !context.mounted) {
    return;
  }
  bloc.add(CountryChanged(selected));
}

// ── Sélecteur de devise ──────────────────────────────────────────────────────

/// Ouvre le sélecteur de devise partagé et, si l'utilisateur en choisit une
/// nouvelle, envoie [CurrencyChanged] au [BusinessPrefsBloc]. Aucun voyageur
/// précis n'est engagé à ce stade des Réglages : le rail carte prévisualisé
/// dépend seulement de [SupportedCurrency.isStripeEligible], pas d'un compte
/// Connect (même approximation que le wizard de demande de colis). Le
/// serveur reste seul décideur au paiement réel.
Future<void> _openCurrencySelector(
  BuildContext context,
  BusinessPrefsState state,
) async {
  final bloc = context.read<BusinessPrefsBloc>();
  final selected = await CurrencySelector.show(
    context,
    options: [
      for (final currency in SupportedCurrency.values)
        CurrencyPaymentOption(
          currency: currency,
          availablePaymentMethods: {
            BidPaymentMethod.cash,
            if (currency.isStripeEligible) BidPaymentMethod.stripe,
            if (currency.isMobileMoneyEligible) BidPaymentMethod.mobileMoney,
          },
        ),
    ],
    initialCurrency: SupportedCurrency.fromCodeOrDefault(state.currencyCode),
  );
  if (selected == null || !context.mounted) {
    return;
  }
  bloc.add(CurrencyChanged(selected.code));
}

// ── Sélecteur de devise d'affichage (presentment, lot 8) ─────────────────────

/// Contrairement à la devise de paiement ci-dessus, ce choix n'engage aucun
/// rail de paiement et n'est jamais verrouillé : « Automatique » suit la
/// devise active, une devise concrète fige les équivalents convertis que le
/// backend sert sur les annonces et demandes publiées dans une autre devise.
Future<void> _openDisplayCurrencyPicker(
  BuildContext context,
  BusinessPrefsState state,
) async {
  final bloc = context.read<BusinessPrefsBloc>();
  final selected = await DonyBottomSheet.show<String>(
    context,
    title: context.l10n.prefsDisplayCurrencyLabel,
    child: _DisplayCurrencyPickerList(selectedCode: state.displayCurrencyCode),
  );
  if (selected == null || !context.mounted) {
    return;
  }
  bloc.add(DisplayCurrencyChanged(selected));
}

class _DisplayCurrencyPickerList extends StatelessWidget {
  const _DisplayCurrencyPickerList({required this.selectedCode});

  final String selectedCode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    Widget tile({
      required String code,
      required String label,
      String? subtitle,
      bool showDivider = true,
    }) {
      final isSelected = selectedCode == code;
      return DonyListTile(
        iconAsset: code == 'AUTO'
            ? 'refresh-cw'
            : 'euro', // i18n-ignore: code de devise technique (R49)
        iconColor: cs.primary,
        iconBgColor: cs.primaryContainer,
        label: label,
        subtitle: subtitle,
        trailing: isSelected
            ? DonyIcon('check', color: cs.primary, size: 20)
            : null,
        showDivider: showDivider,
        onTap: () => Navigator.of(context).pop(code),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile(
          code: 'AUTO', // i18n-ignore: code de devise technique (R49)
          label: l.prefsAutoLabel,
          subtitle: l.prefsAutoCurrencySubtitle,
        ),
        for (final (index, currency) in SupportedCurrency.values.indexed)
          tile(
            code: currency.code,
            label: '${currency.name(l)} (${currency.symbol})',
            showDivider: index < SupportedCurrency.values.length - 1,
          ),
        SizedBox(height: tt.bodySmall?.fontSize ?? 12),
      ],
    );
  }
}

class _CountryPickerList extends StatefulWidget {
  const _CountryPickerList({required this.selectedCode});

  final String? selectedCode;

  @override
  State<_CountryPickerList> createState() => _CountryPickerListState();
}

class _CountryPickerListState extends State<_CountryPickerList> {
  final _controller = TextEditingController();
  List<CountryZoneGroup> _results = CountryCatalog.groupedSearch('');

  // `l` n'est connu qu'à partir de `didChangeDependencies` (les délégués ne
  // sont pas prêts en `initState`) : on le garde ici pour que la recherche
  // trouve aussi le nom localisé, et on relance le calcul si la langue change.
  AppLocalizations? _l;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refreshResults);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l = context.l10n;
    _refreshResults();
  }

  void _refreshResults() {
    final l = _l;
    setState(() {
      _results = CountryCatalog.groupedSearch(
        _controller.text,
        localizedName: l == null ? null : (c) => countryName(l, c.code),
      );
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
    final l = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyTextField(
          controller: _controller,
          hint: l.prefsCountrySearchHint,
          prefixIcon: Icons.search,
        ),
        const SizedBox(height: DonySpacing.md),
        if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.xl),
            child: Text(
              l.prefsCountryNotFound,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          )
        else
          for (final group in _results) ...[
            // Les pays sont groupés par zone : 38 entrées à plat seraient
            // illisibles, et la zone explique la devise affichée dessous.
            Semantics(
              header: true,
              container: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.base,
                  DonySpacing.md,
                  DonySpacing.base,
                  DonySpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    countryZoneLabel(l, group.zone).toUpperCase(),
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
            for (final country in group.countries)
              ListTile(
                title: Text(countryName(l, country.code)),
                subtitle: Text(
                  '${country.currency.code} · ${country.currency.symbol}',
                ),
                trailing: widget.selectedCode == country.code
                    ? DonyIcon('check', color: cs.primary)
                    : null,
                onTap: () => context.pop(country.code),
              ),
          ],
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
    final l = context.l10n;
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
                l.prefsSectionMyTrips,
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
                  l.prefsTravelerBadge,
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
              label: l.prefsDefaultWeightLabel,
              subtitle: l.prefsDefaultWeightSubtitle,
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
              label: l.prefsMinPriceLabel,
              subtitle: l.prefsMinPriceNone(
                SupportedCurrency.symbolOf(state.currencyCode),
              ),
              trailing: Text(
                state.minBidPriceEur == 0
                    ? l.prefsMinPriceValueNone
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
              label: l.prefsContactModeLabel,
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
                segments: [
                  ButtonSegment(
                    value:
                        'call', // i18n-ignore: code contact_mode envoyé au serveur
                    label: Text(l.prefsContactModeCall),
                  ),
                  ButtonSegment(
                    value:
                        'message', // i18n-ignore: code contact_mode envoyé au serveur
                    label: Text(l.prefsContactModeMessage),
                  ),
                  ButtonSegment(
                    value:
                        'both', // i18n-ignore: code contact_mode envoyé au serveur
                    label: Text(l.prefsContactModeBoth),
                  ),
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
              label: l.prefsResponseDelayLabel,
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
                        hintText: l.prefsResponseDelayHint,
                        suffixText:
                            'h', // i18n-ignore: unité, identique en anglais
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
