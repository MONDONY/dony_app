import 'dart:async';

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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Compte de versement mobile money du voyageur (Wave / Orange Money via
/// pawaPay) : consultation, activation et désactivation.
///
/// Accessible depuis « Moi » → section ARGENT → « Versement mobile money ».
/// Style d'AppBar identique à `MobileMoneyAwaitingScreen`.
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
      // Le bouton collant ne doit pas passer sous la barre de navigation
      // Android (constaté sur un Redmi à trois boutons) : le haut est déjà
      // couvert par l'AppBar.
      body: SafeArea(
        top: false,
        child: BlocConsumer<MobileMoneyAccountBloc, MobileMoneyAccountState>(
          listener: (context, state) {
            if (state is MobileMoneyAccountError) {
              // Jamais state.error brut : toujours passer par ErrorPresenter,
              // qui résout le code métier via ErrorCatalog et retombe sur un
              // message générique français.
              unawaited(ErrorPresenter.show(context, state.error));
            }
          },
          builder: (context, state) => switch (state) {
            MobileMoneyAccountInitial() || MobileMoneyAccountLoading() =>
              Center(child: CircularProgressIndicator(color: cs.primary)),
            MobileMoneyAccountLoaded(:final account) => _AccountBody(
              account: account,
            ),
            MobileMoneyAccountUpdating(:final account) => _AccountBody(
              account: account,
              isLoading: true,
            ),
            // Activation refusée faute de numéro disponible : la vue « non
            // configuré » bascule sur le formulaire de saisie, jamais une
            // snackbar (le listener ci-dessus ne réagit qu'à
            // MobileMoneyAccountError, pas à cet état dédié).
            MobileMoneyAccountPhoneRequired(:final account) => _AccountBody(
              account: account,
              phoneRequired: true,
            ),
            // Échec d'activation/désactivation : le dernier compte connu reste
            // affiché (le listener ci-dessus a déjà notifié l'erreur).
            MobileMoneyAccountError(:final account) when account != null =>
              _AccountBody(account: account),
            // Échec du premier chargement : aucun compte connu à afficher.
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

/// Contenu selon le statut du compte, commun aux états `Loaded`, `Updating`
/// et `Error` (avec compte conservé).
class _AccountBody extends StatelessWidget {
  const _AccountBody({
    required this.account,
    this.isLoading = false,
    this.phoneRequired = false,
  });

  final MobileMoneyAccount account;
  final bool isLoading;

  /// Vrai sur `MobileMoneyAccountPhoneRequired` : force le formulaire de
  /// saisie dans [_NotConfiguredView], même si le profil semble avoir un
  /// numéro (le backend fait autorité sur ce refus).
  final bool phoneRequired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.xl,
        DonySpacing.lg,
        DonySpacing.xl,
      ),
      child: switch (account.status) {
        MobileMoneyAccountStatus.notConfigured => _NotConfiguredView(
          isLoading: isLoading,
          phoneRequired: phoneRequired,
        ),
        MobileMoneyAccountStatus.active => _ActiveView(
          account: account,
          isLoading: isLoading,
        ),
        // La désactivation ne repose jamais sur un numéro saisi ici : le
        // backend conserve celui qu'il avait avant la désactivation.
        MobileMoneyAccountStatus.disabled => _DisabledView(
          isLoading: isLoading,
        ),
      },
    );
  }
}

/// Aucun versement configuré : explique le principe et propose l'activation,
/// ou demande le numéro de versement quand aucun n'est disponible (voir
/// [_missingProfilePhone] et [MobileMoneyAccountPhoneRequired]).
class _NotConfiguredView extends StatelessWidget {
  const _NotConfiguredView({
    required this.isLoading,
    required this.phoneRequired,
  });

  final bool isLoading;

  /// Vrai quand le backend a déjà refusé une activation faute de numéro
  /// (`MobileMoneyAccountPhoneRequired`) : force le formulaire même si
  /// [_missingProfilePhone] ne le déclencherait pas à lui seul.
  final bool phoneRequired;

  /// Vrai quand l'utilisateur connecté n'a pas de numéro de téléphone Yadony
  /// (compte sans vérification SMS Twilio configurée). `AuthBloc` est
  /// toujours fourni dans l'app réelle ; en son absence (certains harnais de
  /// test), impossible de savoir : on retombe alors sur le comportement
  /// historique (pas de formulaire), jamais de plantage — même principe que
  /// `_initialPayerPhone` dans `CreateBidBottomSheet`.
  bool _missingProfilePhone(BuildContext context) {
    try {
      final phone = context.read<AuthBloc>().state.currentUser?.phoneNumber;
      return phone == null || phone.isEmpty;
    } on ProviderNotFoundException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (phoneRequired || _missingProfilePhone(context)) {
      return _PayoutNumberForm(isLoading: isLoading);
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: DonyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonyIcon('smartphone', color: cs.primary, size: 32),
                  const SizedBox(height: DonySpacing.base),
                  Text(
                    'Ton numéro de téléphone Yadony devient ton compte de '
                    'versement. Le montant net de chaque envoi t\'est versé '
                    'dessus à la livraison.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.lg),
                  Text(
                    'Opérateurs disponibles',
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text('Orange Money, Wave, MTN, Free…', style: tt.bodyMedium),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        DonyButton(
          label: 'Activer le versement mobile money',
          isLoading: isLoading,
          onPressed: () => context.read<MobileMoneyAccountBloc>().add(
            const MobileMoneyAccountActivateRequested(),
          ),
        ),
      ],
    );
  }
}

/// Formulaire de saisie du numéro de versement, affiché par
/// [_NotConfiguredView] à la place de la carte explicative quand aucun
/// numéro n'est disponible côté profil ou que le backend l'a explicitement
/// demandé (`MobileMoneyAccountPhoneRequired`).
///
/// Deux champs identiques (numéro + confirmation) évitent une faute de
/// frappe silencieuse : un numéro de versement erroné ferait échouer un
/// versement bien plus tard, sans recours simple pour le voyageur. Aucun
/// `setState` : un [ValueNotifier] recalculé à chaque frappe porte le
/// numéro normalisé, seulement quand les deux saisies normalisées
/// coïncident et ne sont pas vides — le bouton collant s'y abonne via
/// [ValueListenableBuilder].
class _PayoutNumberForm extends StatefulWidget {
  const _PayoutNumberForm({required this.isLoading});

  final bool isLoading;

  @override
  State<_PayoutNumberForm> createState() => _PayoutNumberFormState();
}

class _PayoutNumberFormState extends State<_PayoutNumberForm> {
  final _phoneCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  /// Numéro normalisé quand les deux champs coïncident, `null` sinon (l'un
  /// des deux est vide, invalide, ou ils diffèrent) : porte à la fois la
  /// validité du formulaire et la valeur à envoyer, jamais recalculé via
  /// `setState`.
  final ValueNotifier<String?> _normalizedPhone = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_syncNormalizedPhone);
    _confirmCtrl.addListener(_syncNormalizedPhone);
  }

  void _syncNormalizedPhone() {
    final phone = normalizePayerPhone(_phoneCtrl.text);
    final confirm = normalizePayerPhone(_confirmCtrl.text);
    _normalizedPhone.value = (phone != null && phone == confirm) ? phone : null;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _confirmCtrl.dispose();
    _normalizedPhone.dispose();
    super.dispose();
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
            child: DonyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonyIcon('smartphone', color: cs.primary, size: 32),
                  const SizedBox(height: DonySpacing.base),
                  Text(
                    "Ton compte Yadony n'a pas de numéro de téléphone : "
                    'indique le numéro mobile money qui recevra tes '
                    'versements (zone CFA : Orange Money, Wave, MTN, '
                    'Free).',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.lg),
                  DonyTextField(
                    key: const Key('payout-phone-field'),
                    controller: _phoneCtrl,
                    label: 'Numéro qui recevra tes versements',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: DonySpacing.base),
                  DonyTextField(
                    key: const Key('payout-phone-confirm-field'),
                    controller: _confirmCtrl,
                    label: 'Confirme le numéro',
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        ValueListenableBuilder<String?>(
          valueListenable: _normalizedPhone,
          builder: (context, phone, _) => DonyButton(
            label: 'Activer le versement mobile money',
            isLoading: widget.isLoading,
            onPressed: phone == null
                ? null
                : () => context.read<MobileMoneyAccountBloc>().add(
                    MobileMoneyAccountActivateRequested(phoneNumber: phone),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Versement actif : détail du compte et désactivation.
class _ActiveView extends StatelessWidget {
  const _ActiveView({required this.account, required this.isLoading});

  final MobileMoneyAccount account;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: DonyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          account.providerLabel ?? 'Mobile money',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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
                    label: 'Devise',
                    value: account.currency ?? 'Non renseigné',
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
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

/// Versement désactivé : les informations sont conservées, on peut réactiver.
class _DisabledView extends StatelessWidget {
  const _DisabledView({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: DonyCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonyIcon('smartphone', color: cs.onSurfaceVariant, size: 28),
                  const SizedBox(width: DonySpacing.base),
                  Expanded(
                    child: Text(
                      'Versement désactivé. Tes informations sont '
                      'conservées.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        DonyButton(
          label: 'Réactiver',
          isLoading: isLoading,
          onPressed: () => context.read<MobileMoneyAccountBloc>().add(
            const MobileMoneyAccountActivateRequested(),
          ),
        ),
      ],
    );
  }
}
