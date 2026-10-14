import 'dart:async';

import 'package:dony/core/currency/country_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/stripe_account/presentation/residence_country_settings.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Écran plein quand Stripe n'ouvre pas de compte connecté pour le pays de
/// résidence déclaré.
///
/// Ce n'est pas le pays où se trouve le voyageur qui compte, mais le pays de
/// résidence de son profil (Réglages › Préférences). Les zones XOF et XAF ne
/// sont pas couvertes ; l'Europe, les États-Unis et le Canada le sont. Un
/// pays mal déclaré à l'inscription (cas réel : une résidente américaine
/// inscrite en Côte d'Ivoire) mène donc ici à tort : l'écran nomme le pays
/// déclaré et propose de le corriger, ce qui débloque la carte. Au retour,
/// `openResidenceCountrySettings` redemande le statut Connect, et l'écran
/// parent bascule de lui-même sur le parcours normal si le nouveau pays est
/// couvert.
///
/// Pays verrouillé (compte Stripe déjà créé) : seul le support peut le
/// changer, l'écran n'offre donc pas de bouton. Qui vit réellement dans un
/// pays non couvert continue d'encaisser en espèces ou par mobile money.
///
/// Partagé par les deux parcours d'onboarding Connect
/// (`ConnectOnboardingIntroScreen` et `PayoutOnboardingScreen`) : la même
/// impasse doit donner le même écran, quel que soit le chemin emprunté.
class ConnectUnavailableView extends StatelessWidget {
  const ConnectUnavailableView({super.key, required this.title});

  /// Titre de l'app bar, repris de l'écran remplacé pour que la barre ne
  /// change pas de libellé sous les pieds de l'utilisateur.
  final String title;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);

    // Lecture tolérante : les préférences sont fournies à l'échelle de l'app
    // (`app.dart`), mais un écran monté isolément (tests) peut s'en passer.
    final prefs = context.watch<BusinessPrefsBloc?>()?.state;
    final country = prefs?.country?.trim().toUpperCase() ?? '';
    final locked = prefs?.countryLocked ?? false;
    final hasCountry = country.isNotEmpty;

    final bodyStyle = tt.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.5,
    );

    final String body;
    if (locked) {
      body = l.stripeAccountUnavailableBody;
    } else if (hasCountry) {
      body = l.stripeAccountUnavailableCountryBody;
    } else {
      body = l.stripeAccountUnavailableNoCountryBody;
    }

    return DonyPageScaffold(
      title: title,
      padding: EdgeInsets.fromLTRB(h, DonySpacing.xxl, h, DonySpacing.xxl),
      stickyBottom: locked
          ? null
          : DonyButton(
              key: const Key('connect-unavailable-change-country-cta'),
              label: l.stripeAccountUnavailableChangeCountryCta,
              iconAsset: 'globe',
              onPressed: () => _changeCountry(context, hasCountry: hasCountry),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DonyMascotteAnimated(
            type: DonyMascotteType.securise,
            size: DonyMascotteSize.lg,
          ),
          const SizedBox(height: DonySpacing.xl),
          Text(l.stripeAccountUnavailableHeading, style: tt.headlineSmall),
          if (hasCountry) ...[
            const SizedBox(height: DonySpacing.lg),
            _ResidenceCountryCard(code: country),
          ],
          const SizedBox(height: DonySpacing.lg),
          Text(body, style: bodyStyle),
          if (locked) ...[
            const SizedBox(height: DonySpacing.md),
            Text(l.stripeAccountUnavailableLockedNote, style: bodyStyle),
          ] else if (hasCountry) ...[
            const SizedBox(height: DonySpacing.md),
            Text(
              l.stripeAccountUnavailableCashNote,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _changeCountry(BuildContext context, {required bool hasCountry}) {
    if (getIt.isRegistered<AnalyticsService>()) {
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.connectUnavailableChangeCountryTapped,
          properties: {'country_set': hasCountry},
        ),
      );
    }
    unawaited(openResidenceCountrySettings(context));
  }
}

/// Pays de résidence déclaré, drapeau et nom : l'utilisatrice voit d'un coup
/// d'œil le pays que l'application a retenu pour elle.
class _ResidenceCountryCard extends StatelessWidget {
  const _ResidenceCountryCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final flag = countryFlagEmoji(code);

    return DonyCard(
      key: const Key('connect-unavailable-residence-country'),
      child: Row(
        children: [
          if (flag != null)
            Padding(
              padding: const EdgeInsets.only(right: DonySpacing.md),
              child: Text(flag, style: tt.headlineSmall),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: DonySpacing.md),
              child: DonyIcon('globe', color: cs.primary),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.stripeAccountUnavailableResidenceLabel,
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(countryName(l, code), style: tt.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
