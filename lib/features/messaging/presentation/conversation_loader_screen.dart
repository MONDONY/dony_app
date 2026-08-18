import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Charge une [ConversationModel] par son id avant d'ouvrir [ChatScreen].
///
/// `/conversations/:id` s'appuie normalement sur un [ConversationModel]
/// complet passé en `extra` (navigation interne, depuis la liste ou une fiche
/// bid). Une notification (push ou boîte de réception) n'a qu'un
/// `conversationId` en string — ce wrapper comble l'écart en le récupérant
/// via l'API avant de construire le vrai écran de chat.
class ConversationLoaderScreen extends StatefulWidget {
  final String conversationId;
  const ConversationLoaderScreen({super.key, required this.conversationId});

  @override
  State<ConversationLoaderScreen> createState() =>
      _ConversationLoaderScreenState();
}

class _ConversationLoaderScreenState extends State<ConversationLoaderScreen> {
  late Future<ConversationModel> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<ConversationRepository>().getConversation(
      widget.conversationId,
    );
  }

  void _retry() {
    setState(() {
      _future = getIt<ConversationRepository>().getConversation(
        widget.conversationId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<ConversationModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: cs.surface,
              elevation: 0,
              leading: const DonyAppBarBackButton(),
            ),
            body: const DonyChatSkeleton(),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: cs.surface,
              elevation: 0,
              leading: const DonyAppBarBackButton(),
            ),
            body: DonyEmptyState(
              mascotte: DonyMascotteType.erreurLegere,
              type: DonyEmptyStateType.error,
              iconAsset: 'wifi-off',
              title: 'Conversation introuvable',
              description: 'Impossible de charger cette conversation.',
              actionLabel: 'Réessayer',
              onAction: _retry,
            ),
          );
        }

        final conversation = snapshot.data!;
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => getIt<ChatBloc>()),
            BlocProvider(create: (_) => getIt<ContactRevealBloc>()),
          ],
          child: ChatScreen(conversation: conversation),
        );
      },
    );
  }
}
