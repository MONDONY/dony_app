import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Construit le bouton qui ouvre la conversation : [onPressed] est `null`
/// pendant le chargement, [isLoading] permet d'afficher un indicateur.
typedef RecipientConversationButtonBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback? onPressed,
      bool isLoading,
    );

/// Ouvre la conversation séparée voyageur ↔ destinataire du bid [bidId]
/// (lot 3C), puis pousse `/conversations/:id` comme le détail d'un envoi.
///
/// Porte son propre [ConversationOpenBloc] : le bouton vit aussi bien dans
/// une feuille (« Prévenir les destinataires », hors de l'arbre de l'écran)
/// que dans une carte ou une barre fixe, sans que l'écran hôte ait à le
/// fournir.
///
/// Un refus (403 lien non confirmé, 404 back antérieur sans la route) ou une
/// panne affiche un snackbar d'erreur générique : rien d'autre ne bouge.
class RecipientConversationLauncher extends StatelessWidget {
  const RecipientConversationLauncher({
    super.key,
    required this.bidId,
    required this.role,
    required this.builder,
  });

  final String bidId;
  final RecipientConversationRole role;
  final RecipientConversationButtonBuilder builder;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ConversationOpenBloc>(),
      child: BlocConsumer<ConversationOpenBloc, ConversationOpenState>(
        listener: (context, state) {
          if (state is ConversationOpenSuccess) {
            context.push(
              '/conversations/${state.conversation.id}',
              extra: state.conversation,
            );
          } else if (state is ConversationOpenError) {
            DonySnackbar.show(
              context,
              message: context.l10n.recipientConversationOpenError,
              type: DonySnackbarType.error,
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is ConversationOpenLoading;
          return builder(
            context,
            isLoading
                ? null
                : () => context.read<ConversationOpenBloc>().add(
                    RecipientConversationOpenRequested(bidId, role: role),
                  ),
            isLoading,
          );
        },
      ),
    );
  }
}
