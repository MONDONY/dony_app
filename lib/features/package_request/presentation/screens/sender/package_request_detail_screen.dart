import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_form_sheet.dart';
import 'package:dony/features/package_request/bloc/package_request_detail_cubit.dart';
import 'package:dony/features/package_request/bloc/package_request_detail_state.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_detail_bottom_bar.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_detail_skeleton.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_detail_view.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_owner_menu_sheet.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class PackageRequestDetailScreen extends StatelessWidget {
  const PackageRequestDetailScreen({required this.requestId, super.key});
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<PackageRequestDetailCubit>(param1: requestId)..load()),
        BlocProvider(create: (_) => getIt<RatingBloc>()),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: const DonyAppBar(title: 'Ma demande', actions: [_MenuButton()]),
          body: const _DetailBody(),
          bottomNavigationBar: const _DetailBottomBar(),
        ),
      ),
    );
  }
}

abstract final class PackageRequestDetailBottomSheet {
  static Future<void> show(BuildContext context, String requestId) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => getIt<PackageRequestDetailCubit>(param1: requestId)..load()),
          BlocProvider(create: (_) => getIt<RatingBloc>()),
        ],
        child: const _SheetFrame(),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: mq.size.height * 0.92,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceWarm,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: DonySpacing.md),
              width: 40, height: 4,
              // Même formule que la poignée standard `DonyBottomSheet`
              // (lib/core/design/widgets/dony_bottom_sheet.dart) : couleur du
              // thème, jamais `DonyColors.neutral300` (light-only).
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DonySpacing.lg, DonySpacing.sm, DonySpacing.sm, 0),
            child: Row(
              children: [
                Expanded(child: Text('Ma demande', style: Theme.of(context).textTheme.headlineSmall)),
                const _MenuButton(),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const DonyIcon('x', size: 20),
                ),
              ],
            ),
          ),
          Divider(height: DonySpacing.base, color: cs.outline),
          const Expanded(child: _DetailBody()),
          const _DetailBottomBar(),
        ],
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PackageRequestDetailCubit, PackageRequestDetailState>(
      listenWhen: (prev, curr) =>
          curr is PackageRequestDetailLoaded && curr.notice != null &&
          (prev is! PackageRequestDetailLoaded || prev.notice != curr.notice),
      listener: (context, state) {
        final notice = (state as PackageRequestDetailLoaded).notice!;
        DonySnackbar.show(
          context,
          message: switch (notice.kind) {
            RequestDetailNoticeKind.actionFailed => 'Une erreur est survenue. Réessaie dans un instant.',
            RequestDetailNoticeKind.invitationSent => 'Invitation envoyée. Le voyageur est prévenu.',
            RequestDetailNoticeKind.invitationRefused => 'Ce voyageur ne peut pas être invité.',
            RequestDetailNoticeKind.invitationNotInvitable => 'Cette demande n\'accepte plus d\'invitations.',
            RequestDetailNoticeKind.invitationLimitReached => 'Limite d\'invitations atteinte pour cette demande.',
          },
          type: notice.kind == RequestDetailNoticeKind.invitationSent
              ? DonySnackbarType.success
              : DonySnackbarType.error,
        );
      },
      builder: (context, state) => switch (state) {
        // Scrollables (comme l'état chargé) : dans la sheet, hauteur fixe à
        // 92 % de l'écran — sans scroll, le squelette ou l'erreur peuvent
        // dépasser l'espace laissé par l'entête et la barre fixe.
        PackageRequestDetailLoading() => const SingleChildScrollView(child: RequestDetailSkeleton()),
        // LayoutBuilder + ConstrainedBox(minHeight) : reste centrée quand
        // l'espace disponible dépasse son contenu, mais peut aussi scroller
        // (sheet à hauteur fixe) sans jamais déborder. Widget de feature, pas
        // du design system : LayoutBuilder y est autorisé.
        PackageRequestDetailError(notFound: final notFound) => LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: _ErrorView(notFound: notFound, onRetry: context.read<PackageRequestDetailCubit>().load),
            ),
          ),
        ),
        final PackageRequestDetailLoaded loaded => RefreshIndicator(
          onRefresh: context.read<PackageRequestDetailCubit>().load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(DonySpacing.lg, DonySpacing.lg, DonySpacing.lg, DonySpacing.xl),
            child: RequestDetailView(state: loaded, callbacks: _callbacks(context, loaded)),
          ),
        ),
      },
    );
  }

  RequestDetailCallbacks _callbacks(BuildContext context, PackageRequestDetailLoaded s) {
    final cubit = context.read<PackageRequestDetailCubit>();
    return RequestDetailCallbacks(
      onOpenThread: (threadId) => _openThread(context, threadId),
      onOpenTrip: (trip) => context.push('/traveler/${trip.id}'),
      onInvite: cubit.invite,
      onCreateAlert: () => CorridorAlertFormSheet.show(
        context,
        isSender: true,
        prefill: CorridorAlertDraft(
          departureCity: s.request.departureCity,
          arrivalCity: s.request.arrivalCity,
          dateFrom: s.request.desiredDate.subtract(Duration(days: s.request.dateToleranceDays)),
          dateTo: s.request.desiredDate.add(Duration(days: s.request.dateToleranceDays)),
          minWeightKg: s.request.weightKg,
          direction: AlertDirection.senderWantsTrips,
        ),
      ),
      onWidenDates: () => _edit(context, s),
    );
  }
}

Future<void> _edit(BuildContext context, PackageRequestDetailLoaded s) async {
  final cubit = context.read<PackageRequestDetailCubit>();
  final changed = await PackageRequestCreateWizard.showEditing(context, s.request);
  if ((changed ?? false) && context.mounted) unawaited(cubit.load());
}

/// La date vidée à la duplication : « republier » vide toujours la date, et
/// dupliquer une demande dont la date souhaitée est déjà passée fait de même
/// — elle ne pourrait plus être publiée telle quelle. Comparaison au jour, en
/// heure locale (jamais UTC : une date à minuit UTC peut déjà être « hier »
/// pour un fuseau africain).
bool clearDateForDuplicate(String source, DateTime desiredDate, {DateTime? now}) {
  if (source == 'republish') return true;
  final today = (now ?? DateTime.now()).toLocal();
  final desiredDay = DateTime(desiredDate.toLocal().year, desiredDate.toLocal().month, desiredDate.toLocal().day);
  final todayDay = DateTime(today.year, today.month, today.day);
  return desiredDay.isBefore(todayDay);
}

Future<void> _duplicate(BuildContext context, PackageRequestDetailLoaded s, String source) async {
  context.read<PackageRequestDetailCubit>().trackDuplicateStarted(source);
  // Dupliquer/republier/publier une demande similaire créent toujours une
  // NOUVELLE demande ailleurs — la source affichée ici n'est jamais modifiée,
  // donc pas de rechargement à son retour.
  await PackageRequestCreateWizard.showDuplicate(
    context,
    s.request,
    clearDate: clearDateForDuplicate(source, s.request.desiredDate),
  );
}

class _DetailBottomBar extends StatelessWidget {
  const _DetailBottomBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PackageRequestDetailCubit, PackageRequestDetailState>(
      builder: (context, state) {
        if (state is! PackageRequestDetailLoaded) return const SizedBox.shrink();
        final focus = focusThreadFor(state.screenCase, state.threads);
        final amount = focus == null
            ? null
            : PriceDisplay.money(focus.grossPriceEur ?? PriceDisplay.grossFromNet(focus.currentPriceEur), focus.currency);
        // Le bid matérialisé (fetch dédié du cubit) prime sur celui porté par
        // le fil : c'est la même donnée, mais elle peut manquer côté fil si le
        // fetch a échoué. Sans identifiant, « Suivre mon colis »/« Noter »
        // seraient des boutons actifs qui ne font rien au tap.
        final bidId = state.materializedBid?.id ?? focus?.materializedBidId;
        final needsBidId = state.actions.primary == RequestPrimaryAction.trackParcel ||
            state.actions.primary == RequestPrimaryAction.rate;
        return RequestDetailBottomBar(
          actions: state.actions,
          busy: state.actionInFlight,
          travelerName: focus?.travelerName,
          amount: amount,
          primaryEnabled: !needsBidId || bidId != null,
          onEdit: () => _edit(context, state),
          onMessage: focus == null ? null : () => _openThread(context, focus.id),
          onPrimary: () => _onPrimary(context, state, focus?.id, bidId, focus?.travelerName),
        );
      },
    );
  }

  Future<void> _onPrimary(BuildContext context, PackageRequestDetailLoaded s, String? threadId,
      String? bidId, String? travelerName) async {
    final cubit = context.read<PackageRequestDetailCubit>();
    switch (s.actions.primary) {
      case RequestPrimaryAction.publish:
        await cubit.publish();
      case RequestPrimaryAction.share:
        final r = s.request;
        final date = DateFormat('d MMMM', 'fr').format(r.desiredDate);
        cubit.trackShared();
        unawaited(Share.share(
          'J\'envoie un colis de ${r.weightKg.toStringAsFixed(0)} kg ${r.departureCity} → ${r.arrivalCity} '
          'autour du $date. Tu voyages sur cet axe ? Réponds à ma demande sur Yadony.',
          sharePositionOrigin: sharePositionOriginFor(context),
        ));
      case RequestPrimaryAction.openThread || RequestPrimaryAction.pay:
        if (threadId == null) return;
        await _openThread(context, threadId);
      case RequestPrimaryAction.waitTrip:
        return;
      case RequestPrimaryAction.trackParcel:
        if (bidId == null) return;
        await context.push('/bids/$bidId');
        if (context.mounted) unawaited(cubit.load());
      case RequestPrimaryAction.rate:
        if (bidId == null) return;
        await RatingBottomSheet.show(context, bidId: bidId, travelerName: travelerName ?? 'le voyageur');
        if (context.mounted) unawaited(cubit.load());
      case RequestPrimaryAction.republish:
        await _duplicate(context, s, 'republish');
      case RequestPrimaryAction.publishSimilar:
        await _duplicate(context, s, 'similar');
    }
  }
}

/// Ouvre un fil de négociation et recharge au retour — partagé par « Ouvrir la
/// discussion »/« Payer » (bouton principal) et « Message » (bouton secondaire).
Future<void> _openThread(BuildContext context, String threadId) async {
  final cubit = context.read<PackageRequestDetailCubit>();
  await context.push('/negotiations/$threadId');
  if (context.mounted) unawaited(cubit.load());
}

class _MenuButton extends StatelessWidget {
  const _MenuButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PackageRequestDetailCubit, PackageRequestDetailState>(
      builder: (context, state) {
        if (state is! PackageRequestDetailLoaded || state.actions.menu.isEmpty) return const SizedBox.shrink();
        return IconButton(
          tooltip: 'Plus d\'actions',
          icon: const DonyIcon('ellipsis', size: 22),
          onPressed: state.actionInFlight ? null : () => _open(context, state),
        );
      },
    );
  }

  Future<void> _open(BuildContext context, PackageRequestDetailLoaded s) async {
    final cubit = context.read<PackageRequestDetailCubit>()..trackMenuOpened();
    final picked = await RequestOwnerMenuSheet.show(context, items: s.actions.menu);
    if (picked == null || !context.mounted) return;
    switch (picked) {
      case RequestMenuAction.unpublish:
        await cubit.unpublish();
      case RequestMenuAction.duplicate:
        await _duplicate(context, s, 'duplicate');
      case RequestMenuAction.cancel:
        final confirmed = await DonyDialog.show(
          context,
          title: 'Annuler cette demande ?',
          message: 'Cette action est irréversible. Les voyageurs ne pourront plus y répondre.',
          confirmLabel: 'Annuler la demande',
          variant: DonyDialogVariant.destructive,
          iconAsset: 'circle-x',
        );
        if (confirmed == true) await cubit.cancel();
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry, this.notFound = false});
  final Future<void> Function() onRetry;

  /// 404 (demande annulée/supprimée entre-temps, ex. lien de notification
  /// périmé) : message dédié, sans bouton Réessayer (un nouvel essai
  /// échouerait de la même façon, la ressource n'existe plus).
  final bool notFound;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              // errorLight/error : équivalents theme-aware des primitives
              // danger50/danger500 (voir lib/core/design/CLAUDE.md).
              decoration: BoxDecoration(color: cs.errorLight, borderRadius: BorderRadius.circular(16)),
              child: Center(child: DonyIcon(notFound ? 'circle-x' : 'wifi-off', color: cs.error)),
            ),
            const SizedBox(height: DonySpacing.base),
            Text(notFound ? 'Cette demande n\'existe plus' : 'Impossible de charger ta demande',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: DonySpacing.xs),
            Text(
              notFound
                  ? 'Elle a peut-être été annulée ou supprimée.'
                  : 'Vérifie ta connexion, puis réessaie. Ta demande n\'a pas été modifiée.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            if (!notFound) ...[
              const SizedBox(height: DonySpacing.lg),
              DonyButton(label: 'Réessayer', iconAsset: 'refresh-cw', fullWidth: false, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
