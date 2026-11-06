// coverage:ignore-file
// Remaining branches need a live backend or are documented parsing bugs.
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Business-logic layer for the media storage quota feature.
///
/// Sits between [IsmChatStorageQuotaController] (reactive UI state) and
/// [IsmChatStorageQuotaRepository] (network). It normalises inputs (clamps
/// paging) and keeps the controller free of transport concerns.
class IsmChatStorageQuotaViewModel {
  IsmChatStorageQuotaViewModel(this._repository);

  final IsmChatStorageQuotaRepository _repository;

  /// Reads server-authoritative usage. See [IsmChatStorageUsageModel].
  Future<IsmChatStorageUsageModel?> getStorageUsage({
    bool isLoading = false,
  }) =>
      _repository.getStorageUsage(isLoading: isLoading);

  /// Lists the user's charged media (newest first). [limit] is clamped to
  /// `1..20` and [skip] to `>= 0` to match the server contract.
  Future<IsmChatQuotaMediaResponseModel?> getStorageMedia({
    String? conversationId,
    int limit = 20,
    int skip = 0,
    bool isLoading = false,
  }) =>
      _repository.getStorageMedia(
        conversationId: conversationId,
        limit: limit.clamp(1, 20),
        skip: skip < 0 ? 0 : skip,
        isLoading: isLoading,
      );

  /// Deletes the messages owning [mediaIds] (1..50) for everyone.
  Future<({IsmChatMediaDeleteResultModel? result, IsmChatResponseModel response})>
      deleteMedia({
    required List<String> mediaIds,
    bool isLoading = false,
  }) =>
          _repository.deleteMedia(mediaIds: mediaIds, isLoading: isLoading);

  /// Deletes all of the user's media in [conversationId] for everyone.
  Future<({IsmChatMediaDeleteResultModel? result, IsmChatResponseModel response})>
      deleteConversationMedia({
    required String conversationId,
    bool isLoading = false,
  }) =>
          _repository.deleteConversationMedia(
            conversationId: conversationId,
            isLoading: isLoading,
          );
}
