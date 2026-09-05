import 'package:dony/core/design/widgets/dony_app_bar.dart';
import 'package:dony/core/design/widgets/dony_badge.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_card.dart';
import 'package:dony/core/design/widgets/dony_empty_state.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:dony/core/design/widgets/dony_text_field.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Libellés français des catégories et statuts backend. Énumérations
/// fermées côté serveur (`SupportCategory`, `SupportTicketStatus`).
abstract final class SupportLabels {
  static const categories = <String, String>{
    'ACCOUNT': 'Compte',
    'KYC': "Vérification d'identité",
    'PAYMENT': 'Paiement',
    'TRIP': 'Trajet',
    'PACKAGE': 'Colis',
    'DELIVERY': 'Livraison',
    'OTHER': 'Autre',
  };

  static String category(String code) => categories[code] ?? code;

  static String status(String code) => switch (code) {
        SupportTicketStatuses.newTicket => 'Nouveau',
        SupportTicketStatuses.assigned => 'Pris en charge',
        SupportTicketStatuses.waitingUser => 'Réponse reçue',
        SupportTicketStatuses.waitingSupport => 'En attente du support',
        SupportTicketStatuses.resolved => 'Résolu',
        _ => code,
      };

  static DonyBadgeType statusBadge(String code) => switch (code) {
        SupportTicketStatuses.waitingUser => DonyBadgeType.warning,
        SupportTicketStatuses.resolved => DonyBadgeType.success,
        _ => DonyBadgeType.info,
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
        leading: const DonyAppBarBackButton(),
        title: const Text('Support'),
      ),
      body: BlocConsumer<SupportBloc, SupportState>(
        listener: (context, state) async {
          if (state.createStatus == SupportActionStatus.failure &&
              state.errorMessage != null) {
            DonySnackbar.show(
              context,
              message: state.errorMessage!,
              type: DonySnackbarType.error,
            );
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
          SupportViewStatus.initial ||
          SupportViewStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          SupportViewStatus.failure => DonyEmptyState(
              type: DonyEmptyStateType.error,
              title: 'Impossible de charger le support',
              description:
                  state.errorMessage ?? 'Vérifiez votre connexion et réessayez.',
              actionLabel: 'Réessayer',
              onAction: () => context
                  .read<SupportBloc>()
                  .add(const SupportHomeRequested()),
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
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (state.replies.isNotEmpty) ...[
          Text(
            'Questions fréquentes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'La réponse est peut-être déjà là. Sinon, ouvrez un ticket.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ...state.replies.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PredefinedReplyTile(reply: entry.value)
                      .animate()
                      .fadeIn(duration: 250.ms, delay: (40 * entry.key).ms),
                ),
              ),
          const SizedBox(height: 24),
        ],
        Text('Mes tickets', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (state.tickets.isEmpty)
          DonyCard(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                'Aucun ticket pour le moment. Un problème non résolu par '
                "l'assistant ? Ouvrez un ticket, l'équipe Yadony vous répond.",
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
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
          label: 'Contacter le support',
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
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                reply.answer,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              DonyBadge(
                label: SupportLabels.status(ticket.status),
                type: SupportLabels.statusBadge(ticket.status),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            SupportLabels.category(ticket.category),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Sheet de création : le bloc de l'écran est partagé via `wrapper` pour que
/// le `stickyBottom` suive `createStatus` et que le listener de l'écran
/// referme la sheet après succès.
Future<void> _openCreateTicketSheet(BuildContext context) {
  final bloc = context.read<SupportBloc>();
  final subjectController = TextEditingController();
  final messageController = TextEditingController();
  final selectedCategory = ValueNotifier<String?>(null);
  final canSubmit = ValueNotifier<bool>(false);

  void recompute() {
    canSubmit.value = selectedCategory.value != null &&
        subjectController.text.trim().isNotEmpty &&
        messageController.text.trim().isNotEmpty;
  }

  selectedCategory.addListener(recompute);

  return DonyBottomSheet.show<void>(
    context,
    title: 'Contacter le support',
    wrapper: (child) => BlocProvider.value(value: bloc, child: child),
    stickyBottom: ValueListenableBuilder<bool>(
      valueListenable: canSubmit,
      builder: (context, ready, _) =>
          BlocBuilder<SupportBloc, SupportState>(
        builder: (context, state) => DonyButton(
          label: 'Envoyer',
          isLoading: state.createStatus == SupportActionStatus.submitting,
          onPressed: ready
              ? () => context.read<SupportBloc>().add(
                    SupportTicketCreateRequested(
                      category: selectedCategory.value!,
                      subject: subjectController.text.trim(),
                      message: messageController.text.trim(),
                    ),
                  )
              : null,
        ),
      ),
    ),
    child: _CreateTicketForm(
      subjectController: subjectController,
      messageController: messageController,
      selectedCategory: selectedCategory,
      onChanged: recompute,
    ),
  ).whenComplete(() {
    selectedCategory.dispose();
    canSubmit.dispose();
    subjectController.dispose();
    messageController.dispose();
  });
}

class _CreateTicketForm extends StatelessWidget {
  const _CreateTicketForm({
    required this.subjectController,
    required this.messageController,
    required this.selectedCategory,
    required this.onChanged,
  });

  final TextEditingController subjectController;
  final TextEditingController messageController;
  final ValueNotifier<String?> selectedCategory;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Catégorie', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ValueListenableBuilder<String?>(
          valueListenable: selectedCategory,
          builder: (context, selected, _) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SupportLabels.categories.entries
                .map(
                  (entry) => ChoiceChip(
                    label: Text(entry.value),
                    selected: selected == entry.key,
                    onSelected: (_) => selectedCategory.value = entry.key,
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        DonyTextField(
          controller: subjectController,
          label: 'Sujet',
          hint: 'Résumez votre problème',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 12),
        DonyTextField(
          controller: messageController,
          label: 'Message',
          hint: 'Décrivez ce qui vous arrive',
          maxLines: 5,
          minLines: 3,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
