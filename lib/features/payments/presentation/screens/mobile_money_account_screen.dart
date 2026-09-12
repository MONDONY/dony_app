import 'dart:async';

import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid/payer_phone.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_networks_checklist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Compte de versement mobile money du voyageur : numéro de versement et
/// réseaux acceptés sur ce numéro (Orange Money, Wave, MTN...). Accessible
/// depuis « Moi » → section ARGENT → « Versement mobile money ».
///
/// Règle produit (spec du 2026-09-11) : l'expéditeur ne paie qu'avec l'un
/// des réseaux cochés ici, et le voyageur est versé sur ce même réseau.
class MobileMoneyAccountScreen extends StatelessWidget {
  const MobileMoneyAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        title: Text('Versement mobile money', style: tt.headlineMedium),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      body: SafeArea(
        top: false,
        child: BlocConsumer<MobileMoneyAccountBloc, MobileMoneyAccountState>(
          listener: (context, state) {
            // Seul MobileMoneyAccountError passe par une snackbar : les
            // erreurs de catalogue s'affichent dans l'écran.
            if (state is MobileMoneyAccountError) {
              unawaited(ErrorPresenter.show(context, state.error));
            }
          },
          builder: (context, state) => switch (state) {
            MobileMoneyAccountInitial() || MobileMoneyAccountLoading() =>
              Center(child: CircularProgressIndicator(color: cs.primary)),
            MobileMoneyAccountLoaded(:final account, :final editingNumber) =>
              _AccountBody(account: account, editingNumber: editingNumber),
            MobileMoneyAccountUpdating(:final account, :final editingNumber) =>
              _AccountBody(
                account: account,
                editingNumber: editingNumber,
                isLoading: true,
              ),
            MobileMoneyAccountPhoneRequired(
              :final account,
              :final editingNumber,
            ) =>
              _AccountBody(account: account, editingNumber: editingNumber),
            MobileMoneyAccountProvidersLoading(
              :final account,
              :final editingNumber,
            ) =>
              _AccountBody(
                account: account,
                editingNumber: editingNumber,
                catalogLoading: true,
              ),
            MobileMoneyAccountProvidersLoaded(
              :final account,
              :final catalog,
              :final editingNumber,
            ) =>
              _AccountBody(
                account: account,
                editingNumber: editingNumber,
                catalog: catalog,
              ),
            MobileMoneyAccountProvidersError(
              :final account,
              :final error,
              :final editingNumber,
            ) =>
              _AccountBody(
                account: account,
                editingNumber: editingNumber,
                catalogError: error,
              ),
            MobileMoneyAccountError(:final account, :final editingNumber)
                when account != null =>
              _AccountBody(account: account, editingNumber: editingNumber),
            MobileMoneyAccountError() => DonyEmptyState(
              type: DonyEmptyStateType.error,
              title: 'Impossible de charger ton compte',
              actionLabel: 'Réessayer',
              onAction: () => context.read<MobileMoneyAccountBloc>().add(
                const MobileMoneyAccountRequested(),
              ),
            ),
          },
        ),
      ),
    );
  }
}

/// Nom lisible d'un pays alpha-2, repli sur le code.
String _countryName(String? code) =>
    CountryCatalog.byCode(code)?.name ?? code ?? '';

/// Vue active ou formulaire, selon le statut et l'édition en cours.
class _AccountBody extends StatelessWidget {
  const _AccountBody({
    required this.account,
    this.editingNumber = false,
    this.isLoading = false,
    this.catalog,
    this.catalogLoading = false,
    this.catalogError,
  });

  final MobileMoneyAccount account;
  final bool editingNumber;
  final bool isLoading;
  final MobileMoneyProviderCatalog? catalog;
  final bool catalogLoading;
  final Object? catalogError;

  @override
  Widget build(BuildContext context) {
    final showForm = !account.isActive || editingNumber;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.xl,
        DonySpacing.lg,
        DonySpacing.xl,
      ),
      child: showForm
          ? _PayoutNumberForm(
              // Une clé par mode : changer de mode repart d'un formulaire vierge.
              key: ValueKey(editingNumber ? 'change' : account.status),
              mode: editingNumber
                  ? _FormMode.changeNumber
                  : account.status == MobileMoneyAccountStatus.disabled
                  ? _FormMode.reactivate
                  : _FormMode.activate,
              previousMasked: account.msisdnMasked,
              preselect: account.providers.map((p) => p.code).toSet(),
              isLoading: isLoading,
              catalog: catalog,
              catalogLoading: catalogLoading,
              catalogError: catalogError,
            )
          : _ActiveView(account: account, isLoading: isLoading),
    );
  }
}

enum _FormMode { activate, reactivate, changeNumber }

/// Formulaire : numéro en double saisie, puis réseaux du numéro à cocher.
///
/// Le catalogue part 400 ms après que les deux saisies normalisées
/// coïncident ([MobileMoneyAccountProvidersRequested]) et s'efface dès
/// qu'elles divergent ([MobileMoneyAccountProvidersCleared]). La sélection
/// vit dans un [ValueNotifier] ; à l'arrivée du catalogue elle est
/// pré-remplie avec le réseau détecté et les réseaux déjà acceptés présents
/// dans ce catalogue ([preselect]). Aucun `setState`.
class _PayoutNumberForm extends StatefulWidget {
  const _PayoutNumberForm({
    super.key,
    required this.mode,
    required this.isLoading,
    required this.preselect,
    this.previousMasked,
    this.catalog,
    this.catalogLoading = false,
    this.catalogError,
  });

  final _FormMode mode;
  final bool isLoading;
  final Set<String> preselect;
  final String? previousMasked;
  final MobileMoneyProviderCatalog? catalog;
  final bool catalogLoading;
  final Object? catalogError;

  @override
  State<_PayoutNumberForm> createState() => _PayoutNumberFormState();
}

class _PayoutNumberFormState extends State<_PayoutNumberForm> {
  static const _debounce = Duration(milliseconds: 400);

  late final TextEditingController _phoneCtrl;
  final _confirmCtrl = TextEditingController();
  final ValueNotifier<String?> _normalizedPhone = ValueNotifier(null);
  final ValueNotifier<Set<String>> _selection = ValueNotifier({});

  /// Dernier catalogue non nul reçu via [widget.catalog].
  ///
  /// `Updating` et `Error` (round 1, Ruling A5) ne portent pas de catalogue
  /// dans leurs props : sans cette rétention, la checklist disparaîtrait et
  /// le bouton resterait mort après un échec d'activation, alors que le
  /// numéro confirmé et la sélection restent valides. Remis à nul dès que le
  /// numéro normalisé diverge ([MobileMoneyAccountProvidersCleared]) ou
  /// change pour un numéro pas encore chargé : un catalogue affiché doit
  /// toujours correspondre au numéro confirmé à l'écran.
  final ValueNotifier<MobileMoneyProviderCatalog?> _retainedCatalog =
      ValueNotifier(null);
  Timer? _timer;

  /// Numéro pour lequel le catalogue a été demandé, pour ne pas le redemander
  /// à chaque frappe qui laisse les deux champs égaux.
  String? _requestedPhone;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: _profilePhone());
    _phoneCtrl.addListener(_syncNormalizedPhone);
    _confirmCtrl.addListener(_syncNormalizedPhone);
    // Présélectionne dès le premier build, pas seulement sur une transition
    // ultérieure (didUpdateWidget) : un formulaire monté directement sur un
    // catalogue déjà chargé (ex. la feuille « Modifier ») doit lui aussi
    // partir avec le réseau détecté et les réseaux déjà acceptés cochés.
    _applyCatalog(widget.catalog);
  }

  @override
  void didUpdateWidget(covariant _PayoutNumberForm old) {
    super.didUpdateWidget(old);
    final catalog = widget.catalog;
    if (catalog != null && catalog != old.catalog) {
      _applyCatalog(catalog);
    }
  }

  /// Retient [catalog] et pré-coche le réseau détecté ainsi que les réseaux
  /// déjà acceptés présents dans ce catalogue ([_PayoutNumberForm.preselect]).
  void _applyCatalog(MobileMoneyProviderCatalog? catalog) {
    if (catalog == null) return;
    _retainedCatalog.value = catalog;
    final codes = catalog.providers.map((p) => p.code).toSet();
    _selection.value = {
      ...widget.preselect.where(codes.contains),
      if (catalog.detected != null) catalog.detected!,
    };
  }

  String _profilePhone() {
    try {
      return context.read<AuthBloc>().state.currentUser?.phoneNumber ?? '';
    } on ProviderNotFoundException {
      return '';
    }
  }

  void _syncNormalizedPhone() {
    final phone = normalizePayerPhone(_phoneCtrl.text);
    final confirm = normalizePayerPhone(_confirmCtrl.text);
    final matched = (phone != null && phone == confirm) ? phone : null;
    _normalizedPhone.value = matched;
    _timer?.cancel();
    if (matched == null) {
      if (_requestedPhone != null) {
        _requestedPhone = null;
        _selection.value = {};
        _retainedCatalog.value = null;
        context.read<MobileMoneyAccountBloc>().add(
          const MobileMoneyAccountProvidersCleared(),
        );
      }
      return;
    }
    if (matched == _requestedPhone) return;
    // Un catalogue affiché doit toujours correspondre au numéro confirmé :
    // celui déjà retenu pour un AUTRE numéro (_requestedPhone non nul) ne
    // vaut plus, avant même que le débounce ci-dessous n'aboutisse. Si aucune
    // demande n'a encore été faite par ce formulaire (_requestedPhone nul),
    // le catalogue en props vient d'un montage direct sur un état déjà
    // chargé : il reste valable tant qu'aucune autre demande ne l'a supplanté.
    if (_requestedPhone != null) {
      _retainedCatalog.value = null;
    }
    _timer = Timer(_debounce, () {
      if (!mounted) return;
      _requestedPhone = matched;
      _selection.value = {};
      context.read<MobileMoneyAccountBloc>().add(
        MobileMoneyAccountProvidersRequested(phoneNumber: matched),
      );
    });
  }

  /// Réémet la demande de catalogue pour le numéro confirmé, depuis le
  /// bandeau d'erreur (« Réessayer ») du formulaire.
  void _retryCatalog() {
    final phone = _normalizedPhone.value;
    if (phone == null) return;
    context.read<MobileMoneyAccountBloc>().add(
      MobileMoneyAccountProvidersRequested(phoneNumber: phone),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _confirmCtrl.dispose();
    _normalizedPhone.dispose();
    _selection.dispose();
    _retainedCatalog.dispose();
    super.dispose();
  }

  String get _explanation => switch (widget.mode) {
    _FormMode.activate =>
      'Indique le numéro mobile money qui recevra tes versements. Il peut '
          'être différent de ton numéro Yadony.',
    _FormMode.reactivate =>
      widget.previousMasked == null
          ? 'Ton versement est désactivé. Indique le numéro mobile money '
                'pour le réactiver.'
          : 'Ton versement est désactivé. Indique le numéro mobile money '
                'pour le réactiver (précédent : ${widget.previousMasked}).',
    _FormMode.changeNumber =>
      'Indique le nouveau numéro de versement. Les réseaux seront à '
          'cocher de nouveau pour ce numéro.',
  };

  String get _buttonLabel => switch (widget.mode) {
    _FormMode.activate => 'Activer le versement mobile money',
    _FormMode.reactivate => 'Réactiver',
    _FormMode.changeNumber => 'Enregistrer le nouveau numéro',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bloc = context.read<MobileMoneyAccountBloc>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DonyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DonyIcon('smartphone', color: cs.primary, size: 32),
                      const SizedBox(height: DonySpacing.base),
                      Text(
                        _explanation,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.lg),
                      DonyTextField(
                        key: const Key('payout-phone-field'),
                        controller: _phoneCtrl,
                        label: 'Numéro de versement',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: DonySpacing.base),
                      ValueListenableBuilder<String?>(
                        valueListenable: _normalizedPhone,
                        builder: (context, phone, _) => DonyTextField(
                          key: const Key('payout-phone-confirm-field'),
                          controller: _confirmCtrl,
                          label: 'Confirme le numéro',
                          keyboardType: TextInputType.phone,
                          suffixIcon: phone == null
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.all(DonySpacing.md),
                                  child: DonyIcon(
                                    'check',
                                    size: 20,
                                    color: cs.success,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DonySpacing.base),
                ValueListenableBuilder<MobileMoneyProviderCatalog?>(
                  valueListenable: _retainedCatalog,
                  builder: (context, catalog, _) => _NetworksSection(
                    catalog: catalog,
                    loading: widget.catalogLoading,
                    error: widget.catalogError,
                    selection: _selection,
                    onChanged: (s) => _selection.value = s,
                    onRetry: _retryCatalog,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        ListenableBuilder(
          listenable: Listenable.merge([
            _normalizedPhone,
            _selection,
            _retainedCatalog,
          ]),
          builder: (context, _) {
            final phone = _normalizedPhone.value;
            final catalog = _retainedCatalog.value;
            final ready =
                phone != null &&
                catalog != null &&
                !catalog.isEmpty &&
                _selection.value.isNotEmpty;
            return DonyButton(
              label: _buttonLabel,
              isLoading: widget.isLoading,
              onPressed: !ready
                  ? null
                  : () => bloc.add(
                      MobileMoneyAccountActivateRequested(
                        phoneNumber: phone,
                        providers: catalog.ordered(_selection.value),
                      ),
                    ),
            );
          },
        ),
        if (widget.mode == _FormMode.changeNumber) ...[
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            label: 'Annuler',
            variant: DonyButtonVariant.ghost,
            onPressed: widget.isLoading
                ? null
                : () =>
                      bloc.add(const MobileMoneyAccountChangeNumberCancelled()),
          ),
        ],
      ],
    );
  }
}

/// Section « Réseaux sur ce numéro » : invite, squelette, bandeau d'erreur
/// ou liste à cocher suivie du rappel de la règle de couplage.
class _NetworksSection extends StatelessWidget {
  const _NetworksSection({
    required this.catalog,
    required this.loading,
    required this.error,
    required this.selection,
    required this.onChanged,
    required this.onRetry,
  });

  final MobileMoneyProviderCatalog? catalog;
  final bool loading;
  final Object? error;
  final ValueNotifier<Set<String>> selection;
  final ValueChanged<Set<String>> onChanged;

  /// Réémet la demande de catalogue pour le numéro confirmé (bandeau
  /// d'erreur, bouton « Réessayer »).
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final catalog = this.catalog;
    final trailing = catalog == null
        ? null
        : [
            _countryName(catalog.country),
            catalog.currency,
          ].whereType<String>().where((s) => s.isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text('Réseaux sur ce numéro', style: tt.titleLarge),
            ),
            if (trailing != null && trailing.isNotEmpty)
              Text(
                trailing,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: DonySpacing.md),
        if (loading)
          const MobileMoneyNetworksSkeleton()
        else if (error != null)
          DonyStatusBanner(
            type: DonyStatusBannerType.error,
            message: ErrorPresenter.resolve(error).message,
            action: TextButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          )
        else if (catalog != null && catalog.isEmpty)
          Text(
            'Aucun réseau disponible sur ce numéro.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          )
        else if (catalog != null) ...[
          MobileMoneyNetworksChecklist(
            catalog: catalog,
            selection: selection,
            onChanged: onChanged,
          ),
          const SizedBox(height: DonySpacing.base),
          const DonyStatusBanner(
            type: DonyStatusBannerType.info,
            message:
                "L'expéditeur paie avec l'un des réseaux cochés. Tu reçois "
                'sur ce même réseau.',
          ),
        ] else
          Text(
            'Confirme ton numéro pour voir les réseaux disponibles.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// Versement actif : compte, réseaux acceptés (avec la feuille « Modifier »),
/// changement de numéro, désactivation.
class _ActiveView extends StatelessWidget {
  const _ActiveView({required this.account, required this.isLoading});

  final MobileMoneyAccount account;
  final bool isLoading;

  Future<void> _showProvidersSheet(BuildContext context) {
    final bloc = context.read<MobileMoneyAccountBloc>();
    final selection = ValueNotifier<Set<String>>(
      account.providers.map((p) => p.code).toSet(),
    );
    bloc.add(const MobileMoneyAccountProvidersRequested());
    return DonyBottomSheet.show<void>(
      context,
      title: 'Réseaux acceptés',
      subtitle: [
        account.msisdnMasked,
        _countryName(account.country),
      ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: ValueListenableBuilder<Set<String>>(
        valueListenable: selection,
        builder: (context, selected, _) =>
            BlocBuilder<MobileMoneyAccountBloc, MobileMoneyAccountState>(
              builder: (context, state) {
                final catalog = state is MobileMoneyAccountProvidersLoaded
                    ? state.catalog
                    : null;
                return DonyButton(
                  label: 'Enregistrer',
                  isLoading: state is MobileMoneyAccountUpdating,
                  onPressed:
                      catalog == null || catalog.isEmpty || selected.isEmpty
                      ? null
                      : () {
                          bloc.add(
                            MobileMoneyAccountProvidersUpdateRequested(
                              catalog.ordered(selected),
                            ),
                          );
                          Navigator.of(context, rootNavigator: true).pop();
                        },
                );
              },
            ),
      ),
      child: _ProvidersSheetContent(
        selection: selection,
        onChanged: (s) => selection.value = s,
      ),
    ).whenComplete(selection.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DonyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Versement mobile money',
                              style: tt.titleLarge,
                            ),
                          ),
                          const SizedBox(width: DonySpacing.sm),
                          const DonyBadge(
                            label: 'ACTIF',
                            type: DonyBadgeType.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: DonySpacing.base),
                      DonyInfoRow(
                        label: 'Numéro',
                        value: account.msisdnMasked ?? 'Non renseigné',
                      ),
                      const DonyInfoRow.divider(),
                      DonyInfoRow(
                        label: 'Pays',
                        value: _countryName(account.country).isEmpty
                            ? 'Non renseigné'
                            : _countryName(account.country),
                      ),
                      const DonyInfoRow.divider(),
                      DonyInfoRow(
                        label: 'Devise',
                        value: account.currency ?? 'Non renseigné',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DonySpacing.base),
                DonyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Réseaux acceptés',
                              style: tt.titleLarge,
                            ),
                          ),
                          TextButton.icon(
                            key: const Key('edit-networks'),
                            onPressed: isLoading
                                ? null
                                : () => _showProvidersSheet(context),
                            icon: DonyIcon(
                              'square-pen',
                              size: 16,
                              color: cs.primary,
                            ),
                            label: const Text('Modifier'),
                          ),
                        ],
                      ),
                      const SizedBox(height: DonySpacing.sm),
                      Wrap(
                        spacing: DonySpacing.sm,
                        runSpacing: DonySpacing.sm,
                        children: [
                          for (final p in account.providers)
                            Container(
                              padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: cs.outline),
                                borderRadius: BorderRadius.circular(
                                  DonyRadius.full,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DonyBrandMark(brand: p.brand, size: 24),
                                  const SizedBox(width: DonySpacing.sm),
                                  Text(
                                    p.label,
                                    style: tt.titleSmall?.copyWith(
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: DonySpacing.md),
                      Text(
                        "L'expéditeur choisit l'un de ces réseaux pour payer. "
                        'Tu reçois sur le même.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        DonyButton(
          label: 'Changer de numéro',
          variant: DonyButtonVariant.secondary,
          onPressed: isLoading
              ? null
              : () => context.read<MobileMoneyAccountBloc>().add(
                  const MobileMoneyAccountChangeNumberRequested(),
                ),
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          label: 'Désactiver',
          variant: DonyButtonVariant.ghost,
          isLoading: isLoading,
          onPressed: () => context.read<MobileMoneyAccountBloc>().add(
            const MobileMoneyAccountDisableRequested(),
          ),
        ),
      ],
    );
  }
}

/// Contenu de la feuille « Réseaux acceptés » : squelette, bandeau ou liste
/// à cocher selon l'état du catalogue. Aucun bouton ici (règle bottom
/// sheet : le bouton vit dans `stickyBottom`).
class _ProvidersSheetContent extends StatelessWidget {
  const _ProvidersSheetContent({
    required this.selection,
    required this.onChanged,
  });

  final ValueNotifier<Set<String>> selection;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.lg,
        DonySpacing.base,
      ),
      child: BlocBuilder<MobileMoneyAccountBloc, MobileMoneyAccountState>(
        builder: (context, state) => switch (state) {
          MobileMoneyAccountProvidersLoaded(:final catalog) =>
            catalog.isEmpty
                ? Text(
                    'Aucun réseau disponible sur ce numéro.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  )
                : MobileMoneyNetworksChecklist(
                    catalog: catalog,
                    selection: selection,
                    onChanged: onChanged,
                  ),
          MobileMoneyAccountProvidersError(:final error) => DonyStatusBanner(
            type: DonyStatusBannerType.error,
            message: ErrorPresenter.resolve(error).message,
            action: TextButton(
              onPressed: () => context.read<MobileMoneyAccountBloc>().add(
                const MobileMoneyAccountProvidersRequested(),
              ),
              child: const Text('Réessayer'),
            ),
          ),
          _ => const MobileMoneyNetworksSkeleton(),
        },
      ),
    );
  }
}
