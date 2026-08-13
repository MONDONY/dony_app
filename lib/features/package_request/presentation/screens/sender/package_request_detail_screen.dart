import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_detail_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PackageRequestDetailScreen extends StatefulWidget {
  const PackageRequestDetailScreen({required this.requestId, super.key});
  final String requestId;

  @override
  State<PackageRequestDetailScreen> createState() =>
      _PackageRequestDetailScreenState();
}

class _PackageRequestDetailScreenState
    extends State<PackageRequestDetailScreen> {
  PackageRequest? _request;
  List<NegotiationThread> _threads = const [];
  String? _error;
  bool _loading = true;
  bool _actionInFlight = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = getIt<PackageRequestRepository>();
      final r = await repo.getById(widget.requestId);
      List<NegotiationThread> threads = const [];
      try {
        threads = await repo.listThreadsForRequest(widget.requestId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _request = r;
          _threads = threads;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Erreur');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Retourne `true` si `action` a réussi (et l'écran a rechargé), `false`
  /// si elle a levé — l'appelant conditionne sur ce résultat toute suite qui
  /// suppose le succès (ex: fermer l'écran après annulation).
  Future<bool> _runAction(Future<void> Function() action) async {
    setState(() => _actionInFlight = true);
    var success = false;
    try {
      await action();
      success = true;
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        DonySnackbar.show(
          context,
          message: 'Une erreur est survenue. Veuillez réessayer.',
          type: DonySnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
    return success;
  }

  Future<void> _edit() async {
    final changed = await PackageRequestCreateWizard.showEditing(
      context,
      _request!,
    );
    if ((changed ?? false) && mounted) await _load();
  }

  Future<void> _publish() async {
    final success = await _runAction(
      () => getIt<PackageRequestRepository>().publish(widget.requestId),
    );
    if (success) {
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.packageRequestPublished,
        ),
      );
    }
  }

  Future<void> _unpublish() async {
    final success = await _runAction(
      () => getIt<PackageRequestRepository>().unpublish(widget.requestId),
    );
    if (success) {
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.packageRequestUnpublished,
        ),
      );
    }
  }

  Future<void> _cancel() async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Annuler cette demande ?',
      message:
          'Cette action est irréversible. Les voyageurs ne pourront '
          'plus y répondre.',
      confirmLabel: 'Annuler la demande',
      variant: DonyDialogVariant.destructive,
      iconAsset: 'circle-x',
    );
    if (confirmed != true || !mounted) return;
    final success = await _runAction(
      () => getIt<PackageRequestRepository>().cancel(widget.requestId),
    );
    // Ne ferme l'écran que si l'annulation a réellement abouti — sinon
    // l'utilisateur verrait le snackbar d'erreur pendant que l'écran se
    // ferme, en croyant l'annulation faite alors qu'elle a échoué.
    if (success && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const DonyAppBar(title: 'Ma demande'),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : _request == null
          ? const SizedBox.shrink()
          : BlocProvider<NegotiationBloc>(
              create: (_) => getIt<NegotiationBloc>(),
              child: BlocListener<NegotiationBloc, NegotiationState>(
                listenWhen: (prev, curr) =>
                    curr is NegotiationLoaded && prev is! NegotiationLoaded,
                listener: (_, _) => _load(),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.xl,
                    DonySpacing.lg,
                    MediaQuery.of(context).padding.bottom + DonySpacing.xl,
                  ),
                  child: PackageRequestDetailBody(
                    request: _request!,
                    threads: _threads,
                    actionInFlight: _actionInFlight,
                    onEdit: _edit,
                    onPublish: _publish,
                    onUnpublish: _unpublish,
                    onCancel: _cancel,
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Bottom sheet detail ───────────────────────────────────────────────────────

abstract final class PackageRequestDetailBottomSheet {
  static Future<void> show(BuildContext context, String requestId) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetFrame(requestId: requestId),
    );
  }
}

class _SheetFrame extends StatefulWidget {
  const _SheetFrame({required this.requestId});
  final String requestId;

  @override
  State<_SheetFrame> createState() => _SheetFrameState();
}

class _SheetFrameState extends State<_SheetFrame> {
  PackageRequest? _request;
  List<NegotiationThread> _threads = const [];
  String? _error;
  bool _loading = true;
  bool _actionInFlight = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repo = getIt<PackageRequestRepository>();
      final r = await repo.getById(widget.requestId);
      List<NegotiationThread> threads = const [];
      try {
        threads = await repo.listThreadsForRequest(widget.requestId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _request = r;
          _threads = threads;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Erreur');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Retourne `true` si `action` a réussi (et la sheet a rechargé), `false`
  /// si elle a levé — l'appelant conditionne sur ce résultat toute suite qui
  /// suppose le succès (ex: fermer la sheet après annulation).
  Future<bool> _runAction(Future<void> Function() action) async {
    setState(() => _actionInFlight = true);
    var success = false;
    try {
      await action();
      success = true;
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        DonySnackbar.show(
          context,
          message: 'Une erreur est survenue. Veuillez réessayer.',
          type: DonySnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
    return success;
  }

  Future<void> _edit() async {
    final changed = await PackageRequestCreateWizard.showEditing(
      context,
      _request!,
    );
    if ((changed ?? false) && mounted) await _load();
  }

  Future<void> _publish() async {
    final success = await _runAction(
      () => getIt<PackageRequestRepository>().publish(widget.requestId),
    );
    if (success) {
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.packageRequestPublished,
        ),
      );
    }
  }

  Future<void> _unpublish() async {
    final success = await _runAction(
      () => getIt<PackageRequestRepository>().unpublish(widget.requestId),
    );
    if (success) {
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.packageRequestUnpublished,
        ),
      );
    }
  }

  Future<void> _cancel() async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Annuler cette demande ?',
      message:
          'Cette action est irréversible. Les voyageurs ne pourront '
          'plus y répondre.',
      confirmLabel: 'Annuler la demande',
      variant: DonyDialogVariant.destructive,
      iconAsset: 'circle-x',
    );
    if (confirmed != true || !mounted) return;
    final success = await _runAction(
      () => getIt<PackageRequestRepository>().cancel(widget.requestId),
    );
    // Ne ferme la sheet que si l'annulation a réellement abouti — sinon
    // l'utilisateur verrait le snackbar d'erreur pendant que la sheet se
    // ferme, en croyant l'annulation faite alors qu'elle a échoué.
    if (success && mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom + mq.viewPadding.bottom;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      height: mq.size.height * 0.92,
      decoration: BoxDecoration(
        color: cs.surfaceWarm,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DonyColors.neutral300,
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.sm,
              DonySpacing.base,
              0,
            ),
            child: Row(
              children: [
                Expanded(child: Text('Ma demande', style: tt.headlineSmall)),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const DonyIcon('x', size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: DonySpacing.base, color: cs.outline),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: cs.primary))
                : _error != null
                ? _ErrorView(message: _error!, onRetry: _load)
                : _request == null
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      DonySpacing.lg,
                      0,
                      DonySpacing.lg,
                      DonySpacing.xl + bottomInset,
                    ),
                    child: PackageRequestDetailBody(
                      request: _request!,
                      threads: _threads,
                      actionInFlight: _actionInFlight,
                      onEdit: _edit,
                      onPublish: _publish,
                      onUnpublish: _unpublish,
                      onCancel: _cancel,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DonyIcon(
              'circle-alert',
              size: 48,
              color: DonyColors.danger500,
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DonySpacing.base),
            DonyButton(label: 'Réessayer', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
