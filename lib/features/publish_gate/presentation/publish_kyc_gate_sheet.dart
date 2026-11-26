import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/presentation/kyc_return_route.dart';
import 'package:dony/features/kyc/presentation/kyc_session_error.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_status_bottom_sheet.dart';
import 'package:dony/features/publish_gate/bloc/publish_kyc_gate_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Feuille « Dernière étape : vérifiez votre identité », ouverte au clic sur
/// « Publier » quand l'identité n'est pas vérifiée.
///
/// La saisie est déjà gardée en brouillon local ([PublishKycGateCubit.open]) :
/// la vérification quitte le formulaire (`go` vers `/kyc/verify`), puis
/// [returnTo] le rouvre rempli une fois l'identité vérifiée.
///
/// Vérification envoyée et en attente (`PENDING`) : rien à démarrer, la
/// feuille explique qu'on préviendra l'utilisateur et que sa saisie l'attend.
///
/// [onVerificationReady] : l'appelant ouvre lui-même la vérification avec
/// l'URL du fournisseur, au lieu du `go` qui vide la pile. Sert au formulaire
/// d'une demande sur un trajet, qui doit rester ouvert dessous.
abstract final class PublishKycGateSheet {
  static const analyticsName = 'publish/kyc-gate';

  /// Nom de la feuille ouverte au moment d'envoyer une demande sur un trajet.
  static const bidAnalyticsName = 'bid/kyc-gate';

  static Future<void> show(
    BuildContext context, {
    required PublishKycGateCubit gate,
    String? returnTo,
    Future<void> Function(String verificationUrl)? onVerificationReady,
  }) async {
    final analyticsName = gate.subject == KycGateSubject.bid
        ? bidAnalyticsName
        : PublishKycGateSheet.analyticsName;
    if (gate.state.pending) {
      var openStatus = false;
      await DonyBottomSheet.show<void>(
        context,
        analyticsName: analyticsName,
        maskReplay: true,
        stickyBottom: _Actions(
          primary: DonyButton(
            key: const Key('publish-kyc-gate-status'),
            label: context.l10n.publishKycGatePendingStatusAction,
            onPressed: () {
              openStatus = true;
              gate.verifyTapped();
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
        ),
        child: _GateContent(state: gate.state, subject: gate.subject),
      );
      if (openStatus && context.mounted) {
        await KycStatusBottomSheet.show(
          context,
          onVerificationReady: onVerificationReady,
        );
      }
      return;
    }

    final kycBloc = context.read<KycBloc>()..add(const KycReset());
    final url = await DonyBottomSheet.show<String>(
      context,
      analyticsName: analyticsName,
      maskReplay: true,
      wrapper: (child) => BlocProvider.value(value: kycBloc, child: child),
      stickyBottom: BlocBuilder<KycBloc, KycState>(
        builder: (ctx, kyc) {
          final loading = kyc is KycLoading;
          return _Actions(
            primary: DonyButton(
              key: const Key('publish-kyc-gate-verify'),
              label: ctx.l10n.publishKycGateVerifyAction,
              isLoading: loading,
              onPressed: loading
                  ? null
                  : () {
                      gate.verifyTapped();
                      ctx.read<KycBloc>().add(const KycSessionRequested());
                    },
            ),
          );
        },
      ),
      child: BlocListener<KycBloc, KycState>(
        listener: (ctx, kyc) {
          if (kyc is KycSessionCreated) {
            Navigator.of(ctx, rootNavigator: true).pop(kyc.stripeUrl);
          } else if (kyc is KycError) {
            showKycError(ctx, kyc.error, draftSaved: gate.state.draftSaved);
          }
        },
        child: _GateContent(state: gate.state, subject: gate.subject),
      ),
    );
    if (url != null && context.mounted) {
      if (onVerificationReady != null) {
        await onVerificationReady(url);
        return;
      }
      GoRouter.of(
        context,
      ).go(kycVerifyLocation(returnTo: returnTo), extra: url);
    }
  }
}

/// Bouton principal et « Plus tard », empilés en pleine largeur.
class _Actions extends StatelessWidget {
  const _Actions({required this.primary});

  final Widget primary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primary,
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          key: const Key('publish-kyc-gate-later'),
          label: context.l10n.commonLater,
          variant: DonyButtonVariant.ghost,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }
}

class _GateContent extends StatelessWidget {
  const _GateContent({required this.state, required this.subject});

  final PublishKycGateState state;
  final KycGateSubject subject;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final trip = subject == KycGateSubject.trip;

    final title = state.pending
        ? l.publishKycGatePendingTitle
        : l.publishKycGateTitle;
    // Demande sur un trajet : la saisie reste dans le formulaire, ouvert sous
    // la feuille, qu'il y ait brouillon ou non.
    final body = subject == KycGateSubject.bid
        ? (state.pending ? l.bidKycGatePendingBody : l.bidKycGateBody)
        : switch ((state.pending, state.draftSaved)) {
            (true, true) =>
              trip
                  ? l.publishKycGatePendingBodyTrip
                  : l.publishKycGatePendingBodyRequest,
            (true, false) => l.publishKycGatePendingBodyUnsaved,
            (false, true) =>
              trip ? l.publishKycGateBodyTrip : l.publishKycGateBodyRequest,
            (false, false) => l.publishKycGateBodyUnsaved,
          };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: state.pending ? cs.warningLight : cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: DonyIcon(
                state.pending ? 'hourglass' : 'id-card',
                size: 34,
                color: state.pending ? cs.warning : cs.primary,
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.lg),
          Text(
            title,
            key: const Key('publish-kyc-gate-title'),
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            body,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (state.kycStatus == 'REJECTED') ...[
            const SizedBox(height: DonySpacing.sm),
            Text(
              l.publishKycGateRejectedNote,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: DonySpacing.lg),
        ],
      ),
    );
  }
}
