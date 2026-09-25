import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Libellés des catégories et statuts backend. Énumérations fermées côté
/// serveur (`SupportCategory`, `SupportTicketStatus`) : les codes restent les
/// clés, seul l'affichage est traduit.
abstract final class SupportLabels {
  /// Codes de catégorie, dans l'ordre d'affichage du sélecteur de création.
  static const categoryCodes = <String>[
    'ACCOUNT',
    'KYC',
    'PAYMENT',
    'TRIP',
    'PACKAGE',
    'DELIVERY',
    'OTHER',
  ];

  static String category(AppLocalizations l, String code) => switch (code) {
    'ACCOUNT' => l.supportCategoryAccount,
    'KYC' => l.supportCategoryKyc,
    'PAYMENT' => l.supportCategoryPayment,
    'TRIP' => l.supportCategoryTrip,
    'PACKAGE' => l.supportCategoryPackage,
    'DELIVERY' => l.supportCategoryDelivery,
    'OTHER' => l.supportCategoryOther,
    _ => code,
  };

  static String status(AppLocalizations l, String code) => switch (code) {
    SupportTicketStatuses.newTicket => l.supportStatusNew,
    SupportTicketStatuses.assigned => l.supportStatusAssigned,
    SupportTicketStatuses.waitingUser => l.supportStatusWaitingUser,
    SupportTicketStatuses.waitingSupport => l.supportStatusWaitingSupport,
    SupportTicketStatuses.resolved => l.supportStatusResolved,
    _ => code,
  };

  static DonyBadgeType statusBadge(String code) => switch (code) {
    SupportTicketStatuses.waitingUser => DonyBadgeType.warning,
    SupportTicketStatuses.resolved => DonyBadgeType.success,
    _ => DonyBadgeType.info,
  };
}

/// Message d'erreur à afficher : le `detail` serveur relayé tel quel s'il
/// existe (donnée, jamais traduite), sinon un texte fixe selon la cause de
/// l'échec. `null` hors échec.
String? supportErrorMessage(AppLocalizations l, SupportState state) {
  final detail = state.serverDetail;
  if (detail != null) return detail; // i18n-ignore
  return switch (state.failure) {
    SupportFailure.ticketResolved => l.supportTicketResolvedError,
    SupportFailure.generic => l.supportGenericError,
    null => null,
  };
}

/// Accueil du support : assistant (réponses prédéfinies), tickets de
/// l'utilisateur et création d'un nouveau ticket via bottom sheet.
class SupportHomeScreen extends StatelessWidget {
  const SupportHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        actions: const [DonyFeedbackButton()],
        leading: const DonyAppBarBackButton(),
        title: Text(context.l10n.supportScreenTitle),
      ),
      body: BlocConsumer<SupportBloc, SupportState>(
        listener: (context, state) async {
          if (state.createStatus == SupportActionStatus.failure) {
            final message = supportErrorMessage(context.l10n, state);
            if (message != null) {
              DonySnackbar.show(
                context,
                message: message,
                type: DonySnackbarType.error,
              );
            }
          }
          if (state.createStatus == SupportActionStatus.success &&
              state.createdTicketId != null) {
            final ticketId = state.createdTicketId!;
            context.pop(); // referme la sheet de création
            await context.push('/support/tickets/$ticketId');
            if (context.mounted) {
              context.read<SupportBloc>().add(const SupportHomeRequested());
            }
          }
        },
        builder: (context, state) => switch (state.homeStatus) {
          SupportViewStatus.initial || SupportViewStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          SupportViewStatus.failure => DonyEmptyState(
            type: DonyEmptyStateType.error,
            title: context.l10n.supportHomeLoadErrorTitle,
            description:
                supportErrorMessage(context.l10n, state) ??
                context.l10n.supportConnectionCheckFallback,
            actionLabel: context.l10n.commonRetry,
            onAction: () =>
                context.read<SupportBloc>().add(const SupportHomeRequested()),
          ),
          SupportViewStatus.ready => _SupportHomeBody(state: state),
        },
      ),
    );
  }
}

class _SupportHomeBody extends StatelessWidget {
  const _SupportHomeBody({required this.state});

  final SupportState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (state.replies.isNotEmpty) ...[
          Text(
            l.supportHomeFaqTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l.supportHomeFaqSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ...state.replies.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PredefinedReplyTile(
                reply: entry.value,
              ).animate().fadeIn(duration: 250.ms, delay: (40 * entry.key).ms),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          l.supportHomeMyTicketsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (state.tickets.isEmpty)
          DonyCard(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                l.supportHomeNoTicketsMessage,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else
          ...state.tickets.map(
            (ticket) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TicketCard(ticket: ticket),
            ),
          ),
        const SizedBox(height: 24),
        DonyButton(
          label: l.supportContactCta,
          iconAsset: 'mail',
          onPressed: () => _openCreateTicketSheet(context),
        ),
      ],
    );
  }
}

class _PredefinedReplyTile extends StatelessWidget {
  const _PredefinedReplyTile({required this.reply});

  final SupportPredefinedReply reply;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DonyCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            reply.question,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                reply.answer,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DonyCard(
      onTap: () async {
        await context.push('/support/tickets/${ticket.id}');
        if (context.mounted) {
          context.read<SupportBloc>().add(const SupportHomeRequested());
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              DonyBadge(
                label: SupportLabels.status(context.l10n, ticket.status),
                type: SupportLabels.statusBadge(ticket.status),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            SupportLabels.category(context.l10n, ticket.category),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Sheet de création : le bloc de l'écran est partagé via `wrapper` pour que
/// le `stickyBottom` suive `createStatus` et que le listener de l'écran
/// referme la sheet après succès.
///
/// Les contrôleurs de texte appartiennent au [State] du formulaire, pas à
/// cette fonction : `whenComplete` se déclenche dès le `pop`, alors que la
/// sheet reste affichée le temps de son animation de sortie. Le clavier qui
/// se replie à ce moment rebâtit les champs, et des contrôleurs déjà disposés
/// faisaient planter la frame (Sentry FLUTTER-18, puis 17/19/1A en cascade).
/// Le [State] n'est disposé qu'au retrait effectif de la route.
Future<void> _openCreateTicketSheet(BuildContext context) {
  final bloc = context.read<SupportBloc>();
  final title = context.l10n.supportContactCta;
  final sendLabel = context.l10n.commonSend;
  final canSubmit = ValueNotifier<bool>(false);
  VoidCallback? submit;

  return DonyBottomSheet.show<void>(
    context,
    title: title,
    wrapper: (child) => BlocProvider.value(value: bloc, child: child),
    stickyBottom: ValueListenableBuilder<bool>(
      valueListenable: canSubmit,
      builder: (context, ready, _) => BlocBuilder<SupportBloc, SupportState>(
        builder: (context, state) => DonyButton(
          label: sendLabel,
          isLoading: state.createStatus == SupportActionStatus.submitting,
          onPressed: ready ? () => submit?.call() : null,
        ),
      ),
    ),
    child: _CreateTicketForm(
      canSubmit: canSubmit,
      onSubmitReady: (fn) => submit = fn,
    ),
  ).whenComplete(canSubmit.dispose);
}

class _CreateTicketForm extends StatefulWidget {
  const _CreateTicketForm({
    required this.canSubmit,
    required this.onSubmitReady,
  });

  /// Validité du formulaire, lue par le bouton du `stickyBottom`.
  final ValueNotifier<bool> canSubmit;

  /// Remet au parent la fonction d'envoi, pour que le bouton du
  /// `stickyBottom` déclenche la soumission avec les valeurs saisies ici.
  final ValueChanged<VoidCallback> onSubmitReady;

  @override
  State<_CreateTicketForm> createState() => _CreateTicketFormState();
}

class _CreateTicketFormState extends State<_CreateTicketForm> {
  final subjectController = TextEditingController();
  final messageController = TextEditingController();
  final selectedCategory = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    selectedCategory.addListener(_recompute);
    widget.onSubmitReady(_submit);
  }

  @override
  void dispose() {
    selectedCategory.dispose();
    subjectController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void _recompute() {
    widget.canSubmit.value =
        selectedCategory.value != null &&
        subjectController.text.trim().isNotEmpty &&
        messageController.text.trim().isNotEmpty;
  }

  void _submit() {
    if (!mounted) return;
    context.read<SupportBloc>().add(
      SupportTicketCreateRequested(
        category: selectedCategory.value!,
        subject: subjectController.text.trim(),
        message: messageController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.supportCreateTicketCategoryLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<String?>(
          valueListenable: selectedCategory,
          builder: (context, selected, _) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SupportLabels.categoryCodes
                .map(
                  (code) => ChoiceChip(
                    label: Text(SupportLabels.category(l, code)),
                    selected: selected == code,
                    onSelected: (_) => selectedCategory.value = code,
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        DonyTextField(
          controller: subjectController,
          label: l.supportCreateTicketSubjectLabel,
          hint: l.supportCreateTicketSubjectHint,
          onChanged: (_) => _recompute(),
        ),
        const SizedBox(height: 12),
        DonyTextField(
          controller: messageController,
          label: l.supportCreateTicketMessageLabel,
          hint: l.supportCreateTicketMessageHint,
          maxLines: 5,
          minLines: 3,
          onChanged: (_) => _recompute(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
