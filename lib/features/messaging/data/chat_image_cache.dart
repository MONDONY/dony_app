import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:flutter/foundation.dart';

/// État de chargement d'une photo du chat (FLUTTER-B4).
sealed class ChatImageLoad {
  const ChatImageLoad();
}

class ChatImageLoading extends ChatImageLoad {
  const ChatImageLoading();
}

class ChatImageReady extends ChatImageLoad {
  final Uint8List bytes;
  const ChatImageReady(this.bytes);
}

/// Photo supprimée ou purgée par le back (410), ou introuvable (404) : le
/// message reste, l'image est affichée « Photo expirée ». Définitif.
class ChatImageExpired extends ChatImageLoad {
  const ChatImageExpired();
}

/// Échec réseau ou serveur : un tap relance ([ChatImageCache.retry]).
class ChatImageFailed extends ChatImageLoad {
  const ChatImageFailed();
}

/// Photos du chat en mémoire, par clé stable `messageId:variant`.
///
/// Les photos ne se lisent que par l'API du back, avec le jeton Firebase :
/// le chargement passe par [ConversationRepository.fetchImage] (Dio
/// d'`ApiClient`, jeton injecté et rafraîchi par l'intercepteur), jamais par
/// une URL publique ou signée.
///
/// Mémoire seulement, délibérément : une photo purgée côté serveur (7 jours
/// après la remise, ou suppression des deux côtés) ne doit pas survivre sur
/// le disque du téléphone. Les octets sont immuables pour une clé donnée,
/// d'où aucune revalidation tant que l'entrée est en mémoire.
///
/// Chaque entrée est un [ValueNotifier] que les bulles écoutent : l'état vit
/// ici, pas dans un `State` de widget, et une même photo affichée deux fois
/// (bulle + citation, liste + visionneuse) ne se télécharge qu'une fois.
class ChatImageCache {
  ChatImageCache(this._repository, {this.maxEntries = 120});

  final ConversationRepository _repository;

  /// Nombre d'entrées gardées (une miniature pèse ~30 Ko, une photo pleine
  /// ~250 Ko). Au-delà, la plus anciennement consultée est oubliée.
  final int maxEntries;

  final LinkedHashMap<String, ValueNotifier<ChatImageLoad>> _entries =
      LinkedHashMap();

  static String keyFor(String messageId, ChatImageVariant variant) =>
      '$messageId:${variant.apiValue}';

  /// État de la photo, chargée au premier appel. Un échec n'est pas relancé
  /// automatiquement : seul [retry] le fait, au tap de l'utilisateur.
  ValueListenable<ChatImageLoad> watch({
    required String conversationId,
    required String messageId,
    required ChatImageVariant variant,
  }) {
    final key = keyFor(messageId, variant);
    final existing = _entries.remove(key);
    if (existing != null) {
      _entries[key] = existing; // plus récemment consultée
      return existing;
    }
    final notifier = ValueNotifier<ChatImageLoad>(const ChatImageLoading());
    _entries[key] = notifier;
    _evict();
    _load(notifier, conversationId, messageId, variant);
    return notifier;
  }

  /// Relance une photo en échec ; sans effet sur une photo prête, en cours
  /// ou expirée.
  void retry({
    required String conversationId,
    required String messageId,
    required ChatImageVariant variant,
  }) {
    final notifier = _entries[keyFor(messageId, variant)];
    if (notifier == null) {
      watch(
        conversationId: conversationId,
        messageId: messageId,
        variant: variant,
      );
      return;
    }
    if (notifier.value is! ChatImageFailed) return;
    notifier.value = const ChatImageLoading();
    _load(notifier, conversationId, messageId, variant);
  }

  /// Oublie toutes les photos (déconnexion).
  void clear() => _entries.clear();

  @visibleForTesting
  int get length => _entries.length;

  void _evict() {
    while (_entries.length > maxEntries) {
      // Les écouteurs en cours gardent leur notifier : seule la référence du
      // cache est lâchée, jamais un notifier encore affiché.
      _entries.remove(_entries.keys.first);
    }
  }

  Future<void> _load(
    ValueNotifier<ChatImageLoad> notifier,
    String conversationId,
    String messageId,
    ChatImageVariant variant,
  ) async {
    ChatImageLoad result;
    try {
      final bytes = await _repository.fetchImage(
        conversationId,
        messageId,
        variant: variant,
      );
      result = bytes.isEmpty ? const ChatImageFailed() : ChatImageReady(bytes);
    } catch (e) {
      result = isUnavailable(e)
          ? const ChatImageExpired()
          : const ChatImageFailed();
    }
    notifier.value = result;
  }

  /// 410 (supprimée ou purgée) ou 404 (aucune photo pour ce message) : la
  /// photo ne reviendra pas, inutile de proposer « Réessayer ».
  @visibleForTesting
  static bool isUnavailable(Object e) {
    final status = e is DioException ? e.response?.statusCode : null;
    if (status == 410 || status == 404) return true;
    final app = e is DioException && e.error is AppException
        ? e.error! as AppException
        : e is AppException
        ? e
        : null;
    if (app == null) return false;
    return app is NotFoundException ||
        app.code == '410' ||
        app.code == 'image-unavailable' ||
        app.code == 'image-not-found';
  }
}
