part of '../isometrik_chat_flutter.dart';

/// Media storage quota mixin for [IsmChatDelegate].
///
/// Implements the per-user media storage quota surface: reading usage, listing
/// and deleting charged media, and opening the built-in "Manage Storage"
/// screen. All work is delegated to the permanent
/// [IsmChatStorageQuotaController] so UI and enforcement share one source of
/// truth.
mixin IsmChatDelegateStorageMixin {
  /// Returns the storage controller, registering the binding first if the SDK
  /// has initialised far enough for GetX to be available. Returns `null` only
  /// if registration is not yet possible.
  IsmChatStorageQuotaController? get _storageController {
    if (!Get.isRegistered<IsmChatStorageQuotaController>()) {
      IsmChatStorageQuotaBinding().dependencies();
    }
    return Get.isRegistered<IsmChatStorageQuotaController>()
        ? Get.find<IsmChatStorageQuotaController>()
        : null;
  }

  /// The last cached usage snapshot, or `null` before the first read.
  IsmChatStorageUsageModel? get storageUsage => _storageController?.usage;

  /// Reads server-authoritative usage. With [forceRefresh] it always re-reads;
  /// otherwise it returns the cached snapshot when present.
  Future<IsmChatStorageUsageModel?> getStorageUsage({
    bool forceRefresh = false,
  }) async {
    final controller = _storageController;
    if (controller == null) return null;
    if (!forceRefresh && controller.usage != null) return controller.usage;
    return controller.loadUsage();
  }

  /// Lists the user's charged media (newest first). [conversationId] scopes to
  /// one conversation; [limit] is clamped to `1..20`.
  Future<IsmChatQuotaMediaResponseModel?> getStorageMedia({
    String? conversationId,
    int limit = 20,
    int skip = 0,
  }) async {
    final controller = _storageController;
    if (controller == null) return null;
    return controller.fetchMedia(
      conversationId: conversationId,
      limit: limit,
      skip: skip,
    );
  }

  /// Deletes the messages owning [mediaIds] (for everyone) and frees the bytes.
  /// Updates cached usage and the storage list. Returns the freed-bytes result.
  Future<IsmChatMediaDeleteResultModel?> deleteStorageMedia(
    List<String> mediaIds,
  ) async {
    final controller = _storageController;
    if (controller == null) return null;
    return controller.deleteMedia(mediaIds);
  }

  /// Deletes all of the user's media in [conversationId] (for everyone).
  Future<IsmChatMediaDeleteResultModel?> deleteConversationStorageMedia(
    String conversationId,
  ) async {
    final controller = _storageController;
    if (controller == null) return null;
    return controller.deleteAllInConversation(conversationId);
  }

  /// Opens the built-in "Manage Storage" screen. [conversationId] pre-scopes
  /// the list to one conversation. No-op if quota is off? No — the screen
  /// itself renders a quota-off state, so this always opens.
  Future<void> openStorageManagement({String? conversationId}) async {
    IsmChatStorageQuotaBinding().dependencies();
    await IsmChatRoute.goToRoute<void>(
      IsmChatStorageView(conversationId: conversationId),
    );
  }
}
