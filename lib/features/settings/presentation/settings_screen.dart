import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/presentation/widgets/delete_account_bottom_sheet.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DonyAppBar(title: 'Paramètres'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.lg,
          vertical: DonySpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DonyListSection(
              title: 'Compte',
              tiles: [
                DonyListTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Supprimer mon compte',
                  destructive: true,
                  showDivider: false,
                  onTap: () => DeleteAccountBottomSheet.show(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
