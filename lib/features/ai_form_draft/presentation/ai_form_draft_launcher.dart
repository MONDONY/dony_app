import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/ai_consent_service.dart';
import 'package:dony/core/widgets/ai_consent_sheet.dart';
import 'package:dony/features/ai_form_draft/data/ai_city_resolver.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/package_request_ai_draft_resolver.dart';
import 'package:dony/features/ai_form_draft/data/trip_ai_draft_resolver.dart';
import 'package:dony/features/ai_form_draft/presentation/ai_form_draft_sheet.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:flutter/widgets.dart';

/// Point d'entrée des formulaires : construit le résolveur du formulaire et
/// ouvre la feuille. Enregistré dans GetIt pour que les tests d'écran le
/// remplacent sans monter la feuille.
class AiFormDraftLauncher {
  const AiFormDraftLauncher();

  /// [isCardReady] : paiements par carte du voyageur prêts (trajet seulement).
  ///
  /// Rend `null` sans ouvrir la feuille si l'utilisateur refuse l'envoi à
  /// l'IA tierce.
  Future<AiResolvedDraft?> open(
    BuildContext context, {
    required AiFormKind kind,
    required String? defaultCurrency,
    bool Function()? isCardReady,
  }) async {
    final consented = await AiConsentSheet.ensure(
      context,
      entry: switch (kind) {
        AiFormKind.trip => AiConsentEntry.formTrip,
        AiFormKind.packageRequest => AiConsentEntry.formPackageRequest,
      },
    );
    if (!consented || !context.mounted) return null;
    final cities = AiCityResolver(getIt<CityRepository>());
    final AiDraftResolver resolver = switch (kind) {
      AiFormKind.trip => TripAiDraftResolver(
        cities: cities,
        priceGrid: getIt<PriceGridRepository>(),
        isCardReady: isCardReady ?? _cardNeverReady,
        fallbackCurrency: defaultCurrency,
      ),
      AiFormKind.packageRequest => PackageRequestAiDraftResolver(
        cities: cities,
        fallbackCurrency: defaultCurrency,
      ),
    };
    return AiFormDraftSheet.show(
      context,
      session: AiFormDraftSession(
        kind: kind,
        resolver: resolver,
        defaultCurrency: defaultCurrency,
      ),
    );
  }

  static bool _cardNeverReady() => false;
}
