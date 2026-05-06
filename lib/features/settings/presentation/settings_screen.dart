import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DonyAppBar(title: 'Paramètres'),
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
                  onTap: () => context.push('/settings/delete-account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
