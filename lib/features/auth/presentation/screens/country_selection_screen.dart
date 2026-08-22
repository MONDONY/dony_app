import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/country_onboarding_cubit.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CountrySelectionScreen extends StatefulWidget {
  const CountrySelectionScreen({super.key});

  @override
  State<CountrySelectionScreen> createState() => _CountrySelectionScreenState();
}

class _CountrySelectionScreenState extends State<CountrySelectionScreen> {
  // Cet écran a trois sorties : `select` (un pays choisi), `skip` et
  // `continueAsSenderOnly` (aucun pays). Les deux dernières n'ont rien à
  // faire préparer sur `/auth/residence-address` (adresse de résidence
  // = préparer le compte de paiement voyageur) : elles doivent filer
  // directement au parrainage. `CountryOnboardingSuccess` ne porte aucune
  // information permettant de distinguer ces trois chemins, mais
  // `CountryOnboardingSaving.countryCode` — toujours émis juste avant — si :
  // non nul pour `select`, nul pour les deux autres. `listenWhen` capture ce
  // code à chaque transition, avant que `listener` ne route sur le succès.
  String? _lastAttemptedCountryCode;

  @override
  Widget build(BuildContext context) {
    final hPadding = DonyLayout.hPadding(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final media = MediaQuery.of(context);

    return BlocConsumer<CountryOnboardingCubit, CountryOnboardingState>(
      listenWhen: (previous, current) {
        if (current is CountryOnboardingSaving) {
          _lastAttemptedCountryCode = current.countryCode;
        }
        return true;
      },
      listener: (context, state) {
        if (state is CountryOnboardingSuccess) {
          context.go(
            _lastAttemptedCountryCode != null
                ? '/auth/residence-address'
                : '/auth/referral-code',
          );
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
          body: Stack(
            fit: StackFit.expand,
            children: [
              const AuthFlowBackground(),
              SafeArea(
                child: DonyLayout.constrained(
                  context,
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      hPadding,
                      DonySpacing.base,
                      hPadding,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthFlowHeader(
                          current: 2,
                          total: 4,
                          label: 'Pays',
                          showBack: false,
                        ),
                        SizedBox(
                          height: (media.size.height * 0.018).clamp(
                            DonySpacing.sm,
                            DonySpacing.lg,
                          ),
                        ),
                        _Entrance(
                          delay: Duration.zero,
                          reduceMotion: reduceMotion,
                          child: const _CountryIntroCard(),
                        ),
                        const SizedBox(height: DonySpacing.md),
                        Expanded(
                          child: _CountryList(
                            isSaving: isSaving,
                            selectedCode: selectedCode,
                          ),
                        ),
                        SizedBox(
                          height:
                              DonySpacing.base +
                              MediaQuery.paddingOf(context).bottom,
                        ),
                      ],
                    ),
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

class _CountryIntroCard extends StatelessWidget {
  const _CountryIntroCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isLight = cs.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: isLight
            ? cs.surface.withValues(alpha: 0.94)
            : DonyColors.ink900.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(DonyRadius.sheet),
        border: Border.all(
          color: isLight
              ? cs.outline.withValues(alpha: 0.42)
              : DonyColors.neutral0.withValues(alpha: 0.18),
        ),
        boxShadow: DonyShadow.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.card),
            ),
            child: DonyIcon('globe', color: cs.primary),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dans quel pays es-tu ?',
                  style: tt.titleLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  'Devise, trajets et disponibilité seront adaptés à ton pays.',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
  final _query = ValueNotifier<String>('');

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isLight = cs.brightness == Brightness.light;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        bottom: DonySpacing.base + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Autocomplete<Country>(
            displayStringForOption: (country) => country.name,
            optionsBuilder: (value) {
              if (widget.isSaving) {
                return const Iterable<Country>.empty();
              }
              return CountryCatalog.search(value.text).take(8);
            },
            onSelected: (country) =>
                context.read<CountryOnboardingCubit>().select(country.code),
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  return DonyTextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !widget.isSaving,
                    label: 'Pays',
                    hint: 'Ex : Sénégal, France, Canada',
                    prefixIcon: Icons.search,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => _query.value = value,
                    onSubmitted: (_) => onFieldSubmitted(),
                  );
                },
            optionsViewBuilder: (context, onSelected, options) {
              final countries = options.toList(growable: false);
              return Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: DonySpacing.xs),
                  child: Material(
                    elevation: 10,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(DonyRadius.sheet),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 310),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isLight
                              ? cs.surface.withValues(alpha: 0.98)
                              : DonyColors.ink900.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(DonyRadius.sheet),
                          border: Border.all(
                            color: cs.outline.withValues(alpha: 0.34),
                          ),
                          boxShadow: DonyShadow.lg,
                        ),
                        // Empêche le scroll de la liste de remonter jusqu'au
                        // `SingleChildScrollView` de l'écran (keyboardDismissBehavior:
                        // onDrag) : sans ça, l'`onDrag` extérieur unfocus le champ dès
                        // qu'on drag pour scroller ici, ce qui referme l'Autocomplete
                        // en plein geste — la liste semblait "se fermer au toucher".
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (_) => true,
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(DonySpacing.xs),
                            itemCount: countries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: DonySpacing.xxs),
                            itemBuilder: (context, index) {
                              final country = countries[index];
                              return _CountryOptionTile(
                                country: country,
                                isSelected: widget.selectedCode == country.code,
                                onTap: () => onSelected(country),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Tape ton pays puis choisis une suggestion.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (widget.isSaving && widget.selectedCode != null) ...[
            const SizedBox(height: DonySpacing.sm),
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    'Enregistrement du pays...',
                    style: tt.labelMedium?.copyWith(color: cs.primary),
                  ),
                ),
              ],
            ),
          ],
          ValueListenableBuilder<String>(
            valueListenable: _query,
            builder: (context, query, _) {
              final hasNoResult =
                  query.trim().isNotEmpty &&
                  CountryCatalog.search(query).isEmpty;
              if (!hasNoResult) {
                return const SizedBox(height: DonySpacing.md);
              }
              return const Padding(
                padding: EdgeInsets.only(top: DonySpacing.md),
                child: _EmptyCountryResults(),
              );
            },
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            label: 'Passer pour l’instant',
            variant: DonyButtonVariant.ghost,
            isLoading: widget.isSaving && widget.selectedCode == null,
            onPressed: widget.isSaving
                ? null
                : () => context.read<CountryOnboardingCubit>().skip(),
          ),
        ],
      ),
    );
  }
}

class _EmptyCountryResults extends StatelessWidget {
  const _EmptyCountryResults();

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Supprimer définitivement le compte ?',
      message:
          'Ton compte Yadony et tes données associées seront supprimés. Cette action est irréversible.',
      confirmLabel: 'Confirmer la suppression',
      variant: DonyDialogVariant.destructive,
      iconAsset: 'circle-alert',
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(const AuthDeleteAccountRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          0,
          DonySpacing.xs,
          0,
          DonySpacing.base,
        ),
        child: DonyCard(
          padding: const EdgeInsets.all(DonySpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.warningLight,
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                ),
                child: Icon(
                  Icons.public_off_rounded,
                  color: cs.warning,
                  size: 20,
                ),
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                'Yadony n’est pas encore disponible dans ce pays',
                textAlign: TextAlign.center,
                style: tt.titleLarge?.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                'Tu peux continuer pour envoyer des colis. Les trajets et la prise de colis resteront indisponibles depuis ce compte.',
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              DonyButton(
                label: 'Je souhaite continuer et envoyer des colis',
                onPressed: () => context
                    .read<CountryOnboardingCubit>()
                    .continueAsSenderOnly(),
              ),
              const SizedBox(height: DonySpacing.xxs),
              DonyButton(
                label: 'Supprimer mon compte',
                variant: DonyButtonVariant.destructive,
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryOptionTile extends StatelessWidget {
  const _CountryOptionTile({
    required this.country,
    required this.isSelected,
    required this.onTap,
  });

  final Country country;
  final bool isSelected;
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
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primaryContainer.withValues(alpha: 0.74)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DonyRadius.card),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: DonyIcon('globe', size: 18, color: cs.primary),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        country.name,
                        style: tt.titleMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        '${country.zone.label} · ${country.currency.code} · ${country.currency.symbol}',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
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
                      ? SizedBox(
                          key: const ValueKey('saving'),
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      : DonyIcon(
                          'chevron-right',
                          key: const ValueKey('choose'),
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                ),
              ],
            ),
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
