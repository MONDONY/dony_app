import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/country_onboarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CountrySelectionScreen extends StatelessWidget {
  const CountrySelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hPadding = DonyLayout.hPadding(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return BlocConsumer<CountryOnboardingCubit, CountryOnboardingState>(
      listener: (context, state) {
        if (state is CountryOnboardingSuccess) {
          context.go('/auth/referral-code');
        } else if (state is CountryOnboardingError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isSaving = state is CountryOnboardingSaving;
        final selectedCode = isSaving ? state.countryCode : null;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: DonyLayout.constrained(
              context,
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                child: Column(
                  children: [
                    const SizedBox(height: DonySpacing.md),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: DonyStepPill(current: 3, total: 4, label: 'Pays'),
                    ),
                    const SizedBox(height: DonySpacing.xxl),
                    _Entrance(
                      delay: Duration.zero,
                      reduceMotion: reduceMotion,
                      child: Text(
                        'Dans quel pays es-tu ?',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    _Entrance(
                      delay: const Duration(milliseconds: 70),
                      reduceMotion: reduceMotion,
                      child: Text(
                        'On adapte ta devise et tes trajets selon ton pays. Tu pourras le modifier plus tard dans Réglages.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xl),
                    Expanded(
                      child: _CountryList(
                        isSaving: isSaving,
                        selectedCode: selectedCode,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.md),
                    DonyButton(
                      label: 'Passer pour l’instant',
                      variant: DonyButtonVariant.ghost,
                      isLoading: isSaving && selectedCode == null,
                      onPressed: isSaving
                          ? null
                          : () => context.read<CountryOnboardingCubit>().skip(),
                    ),
                    SizedBox(
                      height:
                          DonySpacing.xl + MediaQuery.paddingOf(context).bottom,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CountryList extends StatefulWidget {
  const _CountryList({required this.isSaving, required this.selectedCode});

  final bool isSaving;
  final String? selectedCode;

  @override
  State<_CountryList> createState() => _CountryListState();
}

class _CountryListState extends State<_CountryList> {
  final _controller = TextEditingController();

  /// Groupes aplatis en une seule liste d'entrées (`CountryZone` pour une
  /// en-tête, `Country` pour un pays) : le groupement ne doit pas coûter la
  /// virtualisation des 38 entrées.
  List<Object> _entries = _flatten(CountryCatalog.groupedSearch(''));

  static List<Object> _flatten(List<CountryZoneGroup> groups) => [
    for (final group in groups) ...[group.zone, ...group.countries],
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(
        () =>
            _entries = _flatten(CountryCatalog.groupedSearch(_controller.text)),
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
    return Column(
      children: [
        DonyTextField(
          controller: _controller,
          hint: 'Rechercher un pays',
          prefixIcon: Icons.search,
        ),
        const SizedBox(height: DonySpacing.md),
        Expanded(
          child: _entries.isEmpty
              ? const _EmptyCountryResults()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: DonySpacing.base),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    if (entry is CountryZone) {
                      return _ZoneHeader(zone: entry);
                    }
                    final country = entry as Country;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                      child: _CountryTile(
                        country: country,
                        isSelected: widget.selectedCode == country.code,
                        enabled: !widget.isSaving,
                        onTap: () => context
                            .read<CountryOnboardingCubit>()
                            .select(country.code),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// En-tête de section : la zone regroupe les pays partageant une même devise,
/// ce qui rend les 38 entrées lisibles au lieu d'une liste à plat.
class _ZoneHeader extends StatelessWidget {
  const _ZoneHeader({required this.zone});

  final CountryZone zone;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      header: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.xxs,
          DonySpacing.sm,
          DonySpacing.xxs,
          DonySpacing.sm,
        ),
        child: Text(
          zone.label.toUpperCase(),
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _EmptyCountryResults extends StatelessWidget {
  const _EmptyCountryResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Aucun pays trouvé',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.country,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final Country country;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final label = isSelected
        ? 'Pays sélectionné : ${country.name}, devise ${country.currency.code}. Enregistrement en cours.'
        : 'Sélectionner ${country.name}, devise ${country.currency.code}';

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: enabled,
      label: label,
      child: DonyCard(
        onTap: enabled ? onTap : null,
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country.name,
                      style: tt.titleLarge?.copyWith(color: cs.onSurface),
                    ),
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      '${country.currency.code} · ${country.currency.symbol}',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.base),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                child: isSelected
                    ? Row(
                        key: const ValueKey('saving'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: DonySpacing.xs),
                          Text(
                            'Enregistrement',
                            style: tt.labelMedium?.copyWith(color: cs.primary),
                          ),
                        ],
                      )
                    : Icon(
                        Icons.radio_button_unchecked,
                        key: const ValueKey('choose'),
                        color: cs.onSurfaceVariant,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.child,
    required this.delay,
    required this.reduceMotion,
  });

  final Widget child;
  final Duration delay;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return child
        .animate(delay: delay)
        .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.035,
          end: 0,
          duration: 280.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
