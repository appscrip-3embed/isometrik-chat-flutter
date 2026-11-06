// coverage:ignore-file
// Remaining branches need a live backend or are documented parsing bugs.
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Network access for the per-user media storage quota feature.
///
/// Thin wrapper over [IsmChatApiWrapper] that maps the `/chat/quota/*`
/// endpoints onto typed models. All calls use the standard user auth headers
/// ([IsmChatUtility.tokenCommonHeader]).
///
/// See also:
/// - [IsmChatStorageQuotaViewModel] — business logic layer.
/// - [IsmChatStorageQuotaController] — reactive state for the UI.
class IsmChatStorageQuotaRepository {
  /// `apiWrapper` is optional and exists for test injection.
  IsmChatStorageQuotaRepository({IsmChatApiWrapper? apiWrapper})
      : _apiWrapper = apiWrapper ?? IsmChatApiWrapper();

  final IsmChatApiWrapper _apiWrapper;

  /// `GET /chat/quota/storage/usage`.
  ///
  /// Returns the server-authoritative usage snapshot, or `null` on a transport
  /// error. A quota-off project still returns a valid (non-error) body.
  Future<IsmChatStorageUsageModel?> getStorageUsage({
    bool isLoading = false,
  }) async {
    try {
      final response = await _apiWrapper.get(
        IsmChatAPI.storageQuotaUsage,
        headers: IsmChatUtility.tokenCommonHeader(),
        showLoader: isLoading,
      );
      if (response.hasError) {
        return null;
      }
      return IsmChatStorageUsageModel.fromJson(response.data);
    } catch (e, st) {
      IsmChatLog.error('getStorageUsage $e', st);
      return null;
    }
  }

  /// `GET /chat/quota/storage/media`.
  ///
  /// [conversationId] (24 hex chars) scopes the list to one conversation; omit
  /// it to list every conversation. [limit] is clamped to `1..20` and [skip] to
  /// `>= 0` by the caller. Rows arrive newest-charged-first.
  Future<IsmChatQuotaMediaResponseModel?> getStorageMedia({
    String? conversationId,
    int limit = 20,
    int skip = 0,
    bool isLoading = false,
  }) async {
    try {
      final query = <String, String>{
        'limit': '$limit',
        'skip': '$skip',
        if (conversationId != null && conversationId.isNotEmpty)
          'conversationId': conversationId,
      };
      final uri = Uri.parse(IsmChatAPI.storageQuotaMedia)
          .replace(queryParameters: query);
      final response = await _apiWrapper.get(
        uri.toString(),
        headers: IsmChatUtility.tokenCommonHeader(),
        showLoader: isLoading,
      );
      if (response.hasError) {
        return null;
      }
      return IsmChatQuotaMediaResponseModel.fromJson(response.data);
    } catch (e, st) {
      IsmChatLog.error('getStorageMedia $e', st);
      return null;
    }
  }

  /// `DELETE /chat/quota/media` with `{ mediaIds: [...] }`.
  ///
  /// Removes the messages that own [mediaIds] for everyone and frees their
  /// bytes. [mediaIds] must hold 1..50 ids. Returns the freed-bytes/usage
  /// result, or `null` when the server rejects the call (quota off → 404,
  /// none owned → 404, invalid body → 422). The raw [IsmChatResponseModel] is
  /// returned alongside so callers can surface the server error text.
  Future<({IsmChatMediaDeleteResultModel? result, IsmChatResponseModel response})>
      deleteMedia({
    required List<String> mediaIds,
    bool isLoading = false,
  }) async {
    final response = await _apiWrapper.delete(
      IsmChatAPI.deleteQuotaMedia,
      payload: {'mediaIds': mediaIds},
      headers: IsmChatUtility.tokenCommonHeader(),
      showLoader: isLoading,
    );
    if (response.hasError) {
      return (result: null, response: response);
    }
    try {
      return (
        result: IsmChatMediaDeleteResultModel.fromJson(response.data),
        response: response,
      );
    } catch (e, st) {
      IsmChatLog.error('deleteMedia parse $e', st);
      return (result: null, response: response);
    }
  }

  /// `DELETE /chat/quota/storage/conversation/{conversationId}/media`.
  ///
  /// Removes every message in [conversationId] that carries media this user
  /// sent (for everyone) and frees their bytes. A conversation with no media
  /// from this user still returns success with `freedBytes = 0`.
  Future<({IsmChatMediaDeleteResultModel? result, IsmChatResponseModel response})>
      deleteConversationMedia({
    required String conversationId,
    bool isLoading = false,
  }) async {
    final response = await _apiWrapper.delete(
      IsmChatAPI.deleteConversationQuotaMedia(conversationId),
      payload: const <String, dynamic>{},
      headers: IsmChatUtility.tokenCommonHeader(),
      showLoader: isLoading,
    );
    if (response.hasError) {
      return (result: null, response: response);
    }
    try {
      return (
        result: IsmChatMediaDeleteResultModel.fromJson(response.data),
        response: response,
      );
    } catch (e, st) {
      IsmChatLog.error('deleteConversationMedia parse $e', st);
      return (result: null, response: response);
    }
  }
}
