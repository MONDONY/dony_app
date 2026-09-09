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
            // Activation refusée faute de numéro : la vue « non configuré »
            // affiche de toute façon déjà le formulaire de saisie (voir
            // _NotConfiguredView) — cet état ne fait donc que garder le
            // compte courant sans jamais déclencher de snackbar (le
            // listener ci-dessus ne réagit qu'à MobileMoneyAccountError,
            // pas à cet état dédié).
            MobileMoneyAccountPhoneRequired(:final account) => _AccountBody(
              account: account,
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
  const _AccountBody({required this.account, this.isLoading = false});

  final MobileMoneyAccount account;
  final bool isLoading;

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
        ),
        MobileMoneyAccountStatus.active => _ActiveView(
          account: account,
          isLoading: isLoading,
        ),
        // Réactivation : même formulaire que l'activation initiale (voir
        // _DisabledView), avec un rappel du numéro précédent quand connu.
        MobileMoneyAccountStatus.disabled => _DisabledView(
          account: account,
          isLoading: isLoading,
        ),
      },
    );
  }
}

/// Aucun versement configuré : demande le numéro de versement (voir
/// [_PayoutNumberForm]).
///
/// Le numéro mobile money est TOUJOURS demandé pour activer le versement,
/// qu'il y ait ou non un numéro sur le profil Yadony : il peut légitimement
/// en différer (le backend privilégie le numéro fourni ici, puis à défaut
/// le numéro Firebase, puis répond 422 `mobile-money-phone-required`).
class _NotConfiguredView extends StatelessWidget {
  const _NotConfiguredView({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) => _PayoutNumberForm(
    isLoading: isLoading,
    explanation:
        'Indique le numéro mobile money qui recevra tes versements. Il '
        'peut être différent de ton numéro Yadony (zone CFA : Orange '
        'Money, Wave, MTN, Free).',
    buttonLabel: 'Activer le versement mobile money',
  );
}

/// Formulaire de saisie du numéro de versement, affiché par
/// [_NotConfiguredView] (activation) et [_DisabledView] (réactivation) :
/// dans les deux cas le numéro mobile money est TOUJOURS demandé, jamais
/// seulement en repli d'un profil sans téléphone — il peut légitimement
/// différer du numéro Yadony (Firebase).
///
/// Deux champs identiques (numéro + confirmation) évitent une faute de
/// frappe silencieuse : un numéro de versement erroné ferait échouer un
/// versement bien plus tard, sans recours simple pour le voyageur. Le
/// premier champ est pré-rempli avec le numéro de l'utilisateur connecté
/// quand `AuthBloc` est accessible (toujours vrai dans l'app réelle ; en son
/// absence, certains harnais de test, `ProviderNotFoundException` est
/// rattrapée et le champ démarre vide, jamais de plantage — même principe
/// que `_initialPayerPhone` dans `CreateBidBottomSheet`), mais reste
/// modifiable : la confirmation, elle, part toujours vide et doit être
/// ressaisie. Aucun `setState` : un [ValueNotifier] recalculé à chaque
/// frappe porte le numéro normalisé, seulement quand les deux saisies
/// normalisées coïncident et ne sont pas vides — le bouton collant s'y
/// abonne via [ValueListenableBuilder].
class _PayoutNumberForm extends StatefulWidget {
  const _PayoutNumberForm({
    required this.isLoading,
    required this.explanation,
    required this.buttonLabel,
  });

  final bool isLoading;

  /// Texte affiché au-dessus des champs, propre au contexte (première
  /// activation vs réactivation avec rappel du numéro précédent).
  final String explanation;

  /// Libellé du bouton collant (« Activer le versement mobile money » vs
  /// « Réactiver ») : les deux envoient le même event, seul le texte change.
  final String buttonLabel;

  @override
  State<_PayoutNumberForm> createState() => _PayoutNumberFormState();
}

class _PayoutNumberFormState extends State<_PayoutNumberForm> {
  late final TextEditingController _phoneCtrl;
  final _confirmCtrl = TextEditingController();

  /// Numéro normalisé quand les deux champs coïncident, `null` sinon (l'un
  /// des deux est vide, invalide, ou ils diffèrent) : porte à la fois la
  /// validité du formulaire et la valeur à envoyer, jamais recalculé via
  /// `setState`.
  final ValueNotifier<String?> _normalizedPhone = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: _profilePhone());
    _phoneCtrl.addListener(_syncNormalizedPhone);
    _confirmCtrl.addListener(_syncNormalizedPhone);
  }

  /// Numéro de l'utilisateur connecté, pour pré-remplir le premier champ.
  /// Peut différer du numéro finalement envoyé (le champ reste modifiable) :
  /// le backend accepte un numéro mobile money distinct du numéro Yadony.
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
                    widget.explanation,
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
            label: widget.buttonLabel,
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

/// Versement désactivé : redemande un numéro pour réactiver (même
/// formulaire que la première activation), avec un rappel du numéro
/// précédent quand il est connu — le numéro fourni peut différer de celui
/// utilisé avant la désactivation.
class _DisabledView extends StatelessWidget {
  const _DisabledView({required this.account, required this.isLoading});

  final MobileMoneyAccount account;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final masked = account.msisdnMasked;
    return _PayoutNumberForm(
      isLoading: isLoading,
      explanation: masked == null
          ? 'Ton versement est désactivé. Indique le numéro mobile money '
                'pour le réactiver.'
          : 'Ton versement est désactivé. Indique le numéro mobile money '
                'pour le réactiver (précédent : $masked).',
      buttonLabel: 'Réactiver',
    );
  }
}
