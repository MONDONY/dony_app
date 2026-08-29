import 'package:dony/features/billing/bloc/subscription_bloc.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les deux règles pures qui décident où mène une action du portail, et si
/// elle doit être proposée. Elles vivent hors des widgets précisément pour que
/// les deux hôtes du bandeau (écran Profil et écran PRO) tranchent
/// identiquement : c'est la duplication de ces règles qui avait produit un
/// impayé de source inconnue à qui « Régler » était offert alors que
/// « Gérer mon abonnement » lui était masqué, pour la même page.
///
/// Testées ici directement, sans monter le moindre widget : un test d'écran
/// prouve qu'un hôte les applique, jamais que les règles elles-mêmes sont
/// justes.
ProSubscriptionModel _sub({
  required ProSubscriptionStatus status,
  ProSubscriptionSource? source,
  bool active = true,
}) => ProSubscriptionModel(
  active: active,
  status: status,
  source: source,
  billingCycle: null,
  currentPeriodEnd: null,
  cancelAtPeriodEnd: false,
  graceExpiresAt: null,
);

void main() {
  group('proPortalTargetFor', () {
    test('seule la grâce historique mène à la page de vente', () {
      // Un bénéficiaire de grâce n'a jamais payé : il n'a rien à gérer, et
      // l'envoyer sur la page de gestion le poserait devant un espace vide.
      expect(
        proPortalTargetFor(ProSubscriptionStatus.legacyGrace),
        ProPortalTarget.upgrade,
      );

      for (final status in ProSubscriptionStatus.values.where(
        (s) => s != ProSubscriptionStatus.legacyGrace,
      )) {
        expect(
          proPortalTargetFor(status),
          ProPortalTarget.manage,
          reason: '$status doit mener à la gestion',
        );
      }
    });
  });

  group('proPortalManageIsLegitimate', () {
    test('la gestion exige une source Stripe, et elle seule', () {
      expect(
        proPortalManageIsLegitimate(
          _sub(
            status: ProSubscriptionStatus.active,
            source: ProSubscriptionSource.stripe,
          ),
        ),
        isTrue,
      );

      // `null` compris : le serveur n'expose aucun identifiant Stripe, donc
      // rien n'établit qu'un espace de gestion existe.
      for (final source in <ProSubscriptionSource?>[
        null,
        ProSubscriptionSource.adminGrant,
        ProSubscriptionSource.legacyFree,
        ProSubscriptionSource.unknown,
      ]) {
        expect(
          proPortalManageIsLegitimate(
            _sub(status: ProSubscriptionStatus.active, source: source),
          ),
          isFalse,
          reason: 'source $source ne donne accès à aucune gestion',
        );
      }
    });
  });

  group('proPortalActionIsLegitimate', () {
    test('une action vers la vente est légitime quelle que soit la source', () {
      // La page de vente est publique : rien à établir avant d'y envoyer
      // quelqu'un.
      for (final source in <ProSubscriptionSource?>[
        null,
        ProSubscriptionSource.stripe,
        ProSubscriptionSource.adminGrant,
        ProSubscriptionSource.legacyFree,
        ProSubscriptionSource.unknown,
      ]) {
        expect(
          proPortalActionIsLegitimate(
            _sub(status: ProSubscriptionStatus.legacyGrace, source: source),
          ),
          isTrue,
          reason: 'grâce historique de source $source mène à la vente',
        );
      }
    });

    test('une action vers la gestion suit la règle de la gestion', () {
      expect(
        proPortalActionIsLegitimate(
          _sub(
            status: ProSubscriptionStatus.pastDue,
            source: ProSubscriptionSource.stripe,
          ),
        ),
        isTrue,
      );
      // Le cas exact du défaut : impayé (donc destination « gestion ») dont
      // la source n'est pas reconnue.
      expect(
        proPortalActionIsLegitimate(
          _sub(
            status: ProSubscriptionStatus.pastDue,
            source: ProSubscriptionSource.unknown,
          ),
        ),
        isFalse,
      );
    });
  });
}
