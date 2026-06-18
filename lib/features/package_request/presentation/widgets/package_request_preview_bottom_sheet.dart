import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ouvre le **détail plein écran** d'une demande d'envoi.
///
/// Historiquement un bottom sheet, désormais une navigation vers
/// `/package-requests/:id/public` (écran complet avec carousel photos,
/// sections, signalement et CTA « Proposer mon trajet »). Le nom est conservé
/// pour ne pas toucher les nombreux appelants.
class PackageRequestPreviewBottomSheet {
  const PackageRequestPreviewBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required PackageRequestSearchItem item,
    bool isOwnRequest = false,
  }) async {
    await context.push('/package-requests/${item.id}/public');
  }
}
