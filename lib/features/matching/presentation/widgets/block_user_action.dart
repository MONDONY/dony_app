import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/settings/bloc/blocked_users_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

/// Affiche le menu ⋯ (feuille à une seule entrée « Bloquer ») puis, au tap,
/// le dialog de confirmation de blocage.
///
/// À appeler depuis un point d'entrée qui n'a pas déjà son propre menu — les
/// fiches profil (`sender_profile_sheet.dart`, `traveler_profile_sheet.dart`),
/// où c'est le bouton « Plus d'options » qui l'ouvre. Un appelant qui a déjà
/// un menu contextuel avec une entrée « Bloquer » (le `PopupMenuButton` de
/// `chat_screen.dart`) doit appeler [showBlockConfirmDialog] directement, pour
/// ne pas ouvrir un menu dans un menu.
void showBlockMenu(
  BuildContext context, {
  required String userId,
  required String displayName,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE9ECEF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const DonyIcon('ban', color: Color(0xFFE53935)),
            title: Text(
              'Bloquer $displayName',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE53935),
              ),
            ),
            onTap: () {
              Navigator.of(ctx, rootNavigator: true).pop();
              showBlockConfirmDialog(
                context,
                userId: userId,
                displayName: displayName,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Dialog de confirmation du blocage, réutilisable depuis tout point d'entrée
/// affichant un autre utilisateur (fiches profil, profil public, conversation).
///
/// Fournit sa propre instance de [BlockedUsersBloc] : les écrans appelants n'ont
/// pas à en exposer une, et le blocage passe malgré tout par un BLoC plutôt que
/// par un appel repository depuis le widget.
void showBlockConfirmDialog(
  BuildContext context, {
  required String userId,
  required String displayName,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => BlocProvider<BlockedUsersBloc>(
      create: (_) => getIt<BlockedUsersBloc>(),
      child: _BlockConfirmDialog(userId: userId, displayName: displayName),
    ),
  );
}

class _BlockConfirmDialog extends StatelessWidget {
  const _BlockConfirmDialog({required this.userId, required this.displayName});

  final String userId;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BlockedUsersBloc, BlockedUsersState>(
      listener: (context, state) {
        if (state is BlockedUserBlockSuccess) {
          Navigator.of(context, rootNavigator: true).pop();
          DonySnackbar.show(context, message: '$displayName a été bloqué(e)');
        }
      },
      builder: (context, state) => _BlockConfirmDialogView(
        userId: userId,
        displayName: displayName,
        loading: state is BlockedUserBlocking,
        errorMessage: state is BlockedUserBlockFailure ? state.message : null,
      ),
    );
  }
}

class _BlockConfirmDialogView extends StatelessWidget {
  const _BlockConfirmDialogView({
    required this.userId,
    required this.displayName,
    required this.loading,
    required this.errorMessage,
  });

  final String userId;
  final String displayName;
  final bool loading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final firstName = displayName.split(' ').first;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bloquer $firstName ?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D1B2A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Il·elle ne pourra plus voir tes annonces ni t\'envoyer d\'offre. '
              'Tu ne verras plus les siennes non plus. '
              'Tu pourras le·la débloquer à tout moment dans Confidentialité.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF6B7A8D),
                height: 1.6,
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Text(
                  errorMessage!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFFE53935),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: loading
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFFE9ECEF)),
                    ),
                    child: Text(
                      'Annuler',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D1B2A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: loading
                        ? null
                        : () => context.read<BlockedUsersBloc>().add(
                            BlockedUserBlockRequested(userId),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Bloquer',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
