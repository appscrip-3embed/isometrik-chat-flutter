part of '../isometrik_chat_flutter.dart';

/// Media storage quota operations for [IsmChat].
///
/// The public surface host apps use to read storage usage, list and delete a
/// user's charged media, and open the built-in "Manage Storage" screen. Usage
/// is always server-authoritative — read it after uploads/deletes rather than
/// tracking bytes on-device.
///
/// ```dart
/// // Show a storage meter
/// final usage = await IsmChat.i.getStorageUsage();
/// if (usage?.quotaEnabled == true) {
///   print('${usage!.usedBytes} / ${usage.quotaBytes}');
/// }
///
/// // Open the ready-made management screen
/// await IsmChat.i.openStorageManagement();
/// ```
mixin IsmChatStorageOperationsMixin {
  /// Gets the delegate instance.
  IsmChatDelegate get _delegate =>
      (this as dynamic)._delegate as IsmChatDelegate;

  /// The cached usage snapshot, or `null` before the first read. Prefer
  /// [getStorageUsage] to guarantee a value.
  IsmChatStorageUsageModel? get storageUsage => _delegate.storageUsage;

  /// Reads server-authoritative storage usage. With [forceRefresh] it always
  /// re-reads from the server; otherwise it returns the cached snapshot when
  /// one exists.
  Future<IsmChatStorageUsageModel?> getStorageUsage({
    bool forceRefresh = false,
  }) =>
      _delegate.getStorageUsage(forceRefresh: forceRefresh);

  /// Lists the user's charged media (newest first). [conversationId] scopes to
  /// one conversation; omit it for all. [limit] is clamped to `1..20`, [skip]
  /// pages. Stop paging when the result is empty or shorter than [limit].
  Future<IsmChatQuotaMediaResponseModel?> getStorageMedia({
    String? conversationId,
    int limit = 20,
    int skip = 0,
  }) =>
      _delegate.getStorageMedia(
        conversationId: conversationId,
        limit: limit,
        skip: skip,
      );

  /// Deletes the messages owning [mediaIds] (1..50) for everyone and frees the
  /// bytes. Returns `{ freedBytes, usedBytes, quotaBytes }` or `null` on
  /// failure. Also refreshes the cached usage used by upload enforcement.
  Future<IsmChatMediaDeleteResultModel?> deleteStorageMedia(
    List<String> mediaIds,
  ) =>
      _delegate.deleteStorageMedia(mediaIds);

  /// Deletes every file this user sent in [conversationId] (for everyone).
  Future<IsmChatMediaDeleteResultModel?> deleteConversationStorageMedia(
    String conversationId,
  ) =>
      _delegate.deleteConversationStorageMedia(conversationId);

  /// Opens the built-in, themeable "Manage Storage" screen. [conversationId]
  /// pre-scopes the list to one conversation.
  Future<void> openStorageManagement({String? conversationId}) =>
      _delegate.openStorageManagement(conversationId: conversationId);
}
