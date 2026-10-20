import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/phone/phone_country.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Code du 409 rendu quand un colis payé sur le compte attend encore son
/// versement : ni retrait ni changement de numéro.
const payoutAccountLockedCode = 'mobile-money-account-locked';

/// L'erreur [error] est-elle le refus d'un compte bloqué par un versement en
/// attente ?
bool isPayoutAccountLocked(Object? error) =>
    error is ConflictException && error.code == payoutAccountLockedCode;

/// Présente l'échec d'une écriture sur un compte de versement : la feuille
/// « compte bloqué » pour un 409 `mobile-money-account-locked` (avec
/// [pendingPayouts], au moins 1 : le back a refusé, un colis attend donc
/// bien), sinon `ErrorPresenter`.
Future<void> presentPayoutAccountFailure(
  BuildContext context,
  Object error, {
  required int pendingPayouts,
}) async {
  if (isPayoutAccountLocked(error)) {
    await PayoutAccountLockedSheet.show(
      context,
      pendingPayouts: math.max(1, pendingPayouts),
    );
    return;
  }
  await ErrorPresenter.show(context, error);
}

/// Numéro complet lisible : indicatif, puis chiffres groupés (« +225 07 48
/// 84 08 56 »). Le Sénégal suit son usage (« +221 77 123 45 67 ») ; ailleurs,
/// groupes de deux, le premier de trois quand le compte est impair. Un
/// numéro qui ne commence pas par l'indicatif de [countryCode] est rendu
/// tel quel.
String groupPayoutNumber(String countryCode, String e164) {
  final dial = phoneCountryForCode(countryCode.toUpperCase())?.dialCode;
  if (dial == null || !e164.startsWith(dial)) return e164;
  final local = e164.substring(dial.length);
  if (local.isEmpty) return e164;
  final sizes = countryCode.toUpperCase() == 'SN' && local.length == 9
      ? const [2, 3, 2, 2]
      : _pairs(local.length);
  final groups = <String>[];
  var i = 0;
  for (final size in sizes) {
    if (i >= local.length) break;
    final end = math.min(local.length, i + size);
    groups.add(local.substring(i, end));
    i = end;
  }
  return '$dial ${groups.join(' ')}';
}

List<int> _pairs(int length) {
  if (length <= 3) return [length];
  final sizes = <int>[if (length.isOdd) 3];
  var rest = length - (length.isOdd ? 3 : 0);
  while (rest > 0) {
    sizes.add(2);
    rest -= 2;
  }
  return sizes;
}

/// Relecture du numéro avant d'ajouter un compte de versement ou d'en changer
/// le numéro : une seule saisie, relue ici en grand. Rend `true` sur « Oui,
/// c'est mon numéro » ; « Corriger » (`false`) ou la fermeture (`null`)
/// laissent l'écran tel quel, saisie comprise.
abstract final class PayoutNumberReviewSheet {
  static Future<bool?> show(
    BuildContext context, {
    required MobileMoneyOperator operator,
    required String countryCode,
    required String e164,
  }) {
    final l = context.l10n;
    return DonyBottomSheet.show<bool>(
      context,
      title: l.mobileMoneyPayoutReviewTitle,
      analyticsName: 'payout-account/review',
      stickyBottom: _TwoButtons(
        primaryKey: const Key('payout-review-confirm'),
        primaryLabel: l.mobileMoneyPayoutReviewConfirm,
        secondaryKey: const Key('payout-review-edit'),
        secondaryLabel: l.mobileMoneyPayoutReviewEdit,
      ),
      child: _ReviewBody(
        operator: operator,
        countryCode: countryCode,
        e164: e164,
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.operator,
    required this.countryCode,
    required this.e164,
  });

  final MobileMoneyOperator operator;
  final String countryCode;
  final String e164;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.mobileMoneyPayoutReviewBody,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.lg),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.lg,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(DonyRadius.card),
          ),
          child: Column(
            children: [
              ExcludeSemantics(
                child: DonyBrandMark(brand: operator.brand, size: 48),
              ),
              const SizedBox(height: DonySpacing.md),
              Text(
                groupPayoutNumber(countryCode, e164),
                key: const Key('payout-review-number'),
                textAlign: TextAlign.center,
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                l.mobileMoneyPayoutReviewOperatorCountry(
                  operator.label,
                  countryName(l, countryCode.toUpperCase()),
                ),
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Confirmation du retrait d'un compte de versement. Rend `true` sur
/// « Retirer ce compte » : l'appelant envoie alors l'event au BLoC de
/// l'écran, qui porte le chargement et l'erreur. [label] remplace le libellé
/// de l'opérateur quand la liste en distingue deux de même marque
/// (« Orange CI »).
abstract final class PayoutAccountRemoveSheet {
  static Future<bool?> show(
    BuildContext context, {
    required MobileMoneyPayoutAccount account,
    String? label,
  }) {
    final l = context.l10n;
    final name = label ?? account.providerLabel;
    return DonyBottomSheet.show<bool>(
      context,
      title: l.mobileMoneyPayoutRemoveTitle(name),
      analyticsName: 'payout-account/remove',
      isDanger: true,
      stickyBottom: _TwoButtons(
        primaryKey: const Key('payout-remove-confirm'),
        primaryLabel: l.mobileMoneyPayoutRemoveConfirm,
        primaryVariant: DonyButtonVariant.destructive,
        secondaryKey: const Key('payout-remove-cancel'),
        secondaryLabel: l.commonCancel,
      ),
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          return Text(
            l.mobileMoneyPayoutRemoveBody(name),
            style: tt.bodyLarge?.copyWith(color: cs.onSurface),
          );
        },
      ),
    );
  }
}

/// Compte bloqué : un ou plusieurs colis payés sur ce compte attendent
/// encore leur versement, il ne peut être ni retiré ni changé de numéro.
abstract final class PayoutAccountLockedSheet {
  static Future<void> show(
    BuildContext context, {
    required int pendingPayouts,
  }) {
    final l = context.l10n;
    return DonyBottomSheet.show<void>(
      context,
      analyticsName: 'payout-account/locked',
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          key: const Key('payout-locked-ok'),
          label: l.mobileMoneyPayoutLockedConfirm,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.mobileMoneyPayoutLockedCount(pendingPayouts),
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              Text(
                l.mobileMoneyPayoutLockedHint,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bouton principal (rend `true`) et bouton discret (rend `false`), dans le
/// `stickyBottom` de la feuille.
class _TwoButtons extends StatelessWidget {
  const _TwoButtons({
    required this.primaryKey,
    required this.primaryLabel,
    required this.secondaryKey,
    required this.secondaryLabel,
    this.primaryVariant = DonyButtonVariant.primary,
  });

  final Key primaryKey;
  final String primaryLabel;
  final DonyButtonVariant primaryVariant;
  final Key secondaryKey;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(
          key: primaryKey,
          label: primaryLabel,
          variant: primaryVariant,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          key: secondaryKey,
          label: secondaryLabel,
          variant: DonyButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
