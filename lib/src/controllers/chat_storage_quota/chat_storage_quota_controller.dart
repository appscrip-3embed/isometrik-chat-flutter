// coverage:ignore-file
// Unreachable under VM tests: UI, platform plugins, or network I/O.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Reactive state + actions for the media storage quota feature.
///
/// Backs the "Manage Storage" surface and the upload-enforcement checks. All
/// figures come from the server ([IsmChatStorageUsageModel]) — nothing is
/// computed on-device — so the UI stays correct across devices.
///
/// Typical flow:
/// 1. [loadUsage] on opening chat or the storage screen.
/// 2. [loadMedia] to page through the user's charged files.
/// 3. [deleteSelected] / [deleteAllInConversation] to free space; both refresh
///    usage from the server response.
///
/// Registered permanently by [IsmChatCommonBinding] so enforcement can read
/// cached [usage] anywhere; the storage screen uses [IsmChatStorageQuotaBinding].
class IsmChatStorageQuotaController extends GetxController {
  IsmChatStorageQuotaController(this._viewModel);

  final IsmChatStorageQuotaViewModel _viewModel;

  /// Server page size. The API caps `limit` at 20.
  static const int pageLimit = 20;

  // ----------------------------------------------------------------- usage

  final _usage = Rx<IsmChatStorageUsageModel?>(null);

  /// Latest server-authoritative usage snapshot, or `null` until first load.
  IsmChatStorageUsageModel? get usage => _usage.value;
  set usage(IsmChatStorageUsageModel? value) => _usage.value = value;

  /// Whether media quotas are switched on for this project. Defaults to
  /// `false` until [loadUsage] resolves.
  bool get quotaEnabled => _usage.value?.quotaEnabled ?? false;

  /// Whether the user may upload new media right now (always `true` when quota
  /// is off or usage hasn't loaded).
  bool get canUpload => _usage.value?.canUpload ?? true;

  // ------------------------------------------------------------------ media

  final _media = <IsmChatQuotaMediaModel>[].obs;

  /// Raw charged-media rows loaded so far, newest-first (server order).
  List<IsmChatQuotaMediaModel> get media => _media;

  // ------------------------------------------------------------- selection

  final _selectedMediaIds = <String>{}.obs;

  /// Media ids currently selected for a bulk delete.
  Set<String> get selectedMediaIds => _selectedMediaIds;

  final _selectionMode = false.obs;

  /// Whether the UI is in multi-select mode.
  bool get isSelectionMode => _selectionMode.value;
  set isSelectionMode(bool value) => _selectionMode.value = value;

  // --------------------------------------------------------------- filters

  final _conversationFilter = Rx<String?>(null);

  /// When set, the list is scoped to one conversation (server-side filter).
  String? get conversationFilter => _conversationFilter.value;

  final _typeFilter = Rx<IsmChatMediaType?>(null);

  /// Optional client-side filter by attachment kind (applied to [visibleMedia]).
  IsmChatMediaType? get typeFilter => _typeFilter.value;

  final _sortBySizeDesc = false.obs;

  /// When `true`, [visibleMedia] is sorted largest→smallest (client-side).
  /// The server returns rows newest-first; this re-sorts what is loaded.
  bool get sortBySizeDesc => _sortBySizeDesc.value;

  // ------------------------------------------------------------- lifecycle

  final _isLoadingUsage = false.obs;
  bool get isLoadingUsage => _isLoadingUsage.value;

  final _isLoadingMedia = false.obs;
  bool get isLoadingMedia => _isLoadingMedia.value;

  final _isPaginating = false.obs;
  bool get isPaginating => _isPaginating.value;

  final _hasMore = true.obs;

  /// Whether another page of media may exist on the server.
  bool get hasMore => _hasMore.value;

  int _skip = 0;

  /// Media after applying the client-side type filter and optional size sort.
  /// This is what the UI renders.
  List<IsmChatQuotaMediaModel> get visibleMedia {
    var list = _media.toList();
    final type = _typeFilter.value;
    if (type != null) {
      list = list.where((e) => e.attachmentType == type).toList();
    }
    if (_sortBySizeDesc.value) {
      list.sort((a, b) => b.size.compareTo(a.size));
    }
    return list;
  }

  /// Total bytes of the currently selected rows (best-effort, from loaded data).
  int get selectedBytes => _media
      .where((e) => _selectedMediaIds.contains(e.mediaId))
      .fold(0, (sum, e) => sum + e.size);

  // ------------------------------------------- conversation-list banner

  final _listBannerDismissed = false.obs;

  /// Session-only dismiss for [IsmChatStorageQuotaListBanner]. Cleared when
  /// usage drops below [IsmChatConversationProperties.storageQuotaWarningThreshold].
  bool get listBannerDismissed => _listBannerDismissed.value;

  void dismissStorageQuotaListBanner() => _listBannerDismissed.value = true;

  void _syncListBannerDismissWithUsage(IsmChatStorageUsageModel? usage) {
    final threshold =
        IsmChatProperties.conversationProperties.storageQuotaWarningThreshold;
    if (usage == null || !usage.shouldWarnNearQuota(threshold: threshold)) {
      _listBannerDismissed.value = false;
    }
  }

  // --------------------------------------------------------------- actions

  /// Loads server-authoritative usage. Safe to call often; set [isLoading] to
  /// show the blocking loader. Returns the snapshot (also stored in [usage]).
  Future<IsmChatStorageUsageModel?> loadUsage({bool isLoading = false}) async {
    _isLoadingUsage.value = true;
    try {
      final result = await _viewModel.getStorageUsage(isLoading: isLoading);
      if (result != null) {
        _usage.value = result;
        _syncListBannerDismissWithUsage(result);
      }
      return result;
    } finally {
      _isLoadingUsage.value = false;
    }
  }

  /// Loads the first page of media (and refreshes usage). Call on screen open.
  /// Uses the in-screen spinner by default rather than a blocking loader.
  Future<void> initialize({bool isLoading = false}) async {
    await loadUsage();
    await loadMedia(reset: true, isLoading: isLoading);
  }

  /// Loads media. With [reset] it restarts paging from the top and replaces the
  /// list; otherwise it appends the next page. Respects [conversationFilter].
  Future<void> loadMedia({
    bool reset = false,
    bool isLoading = false,
  }) async {
    if (reset) {
      _skip = 0;
      _hasMore.value = true;
      _isLoadingMedia.value = true;
    } else {
      if (!_hasMore.value || _isPaginating.value) return;
      _isPaginating.value = true;
    }
    try {
      final response = await _viewModel.getStorageMedia(
        conversationId: _conversationFilter.value,
        limit: pageLimit,
        skip: _skip,
        isLoading: isLoading,
      );
      final rows = response?.media ?? const <IsmChatQuotaMediaModel>[];
      if (reset) {
        _media
          ..clear()
          ..addAll(rows);
      } else {
        _media.addAll(rows);
      }
      _skip += rows.length;
      // Stop paging when the server returns fewer than a full page.
      _hasMore.value = rows.length >= pageLimit;
    } finally {
      _isLoadingMedia.value = false;
      _isPaginating.value = false;
    }
  }

  /// Convenience for infinite-scroll: loads the next page if any.
  Future<void> loadMore() => loadMedia();

  /// One-off media fetch that does NOT touch the screen's paginated list or
  /// selection. For programmatic facade access (`IsmChat.i.getStorageMedia`).
  Future<IsmChatQuotaMediaResponseModel?> fetchMedia({
    String? conversationId,
    int limit = pageLimit,
    int skip = 0,
  }) =>
      _viewModel.getStorageMedia(
        conversationId: conversationId,
        limit: limit,
        skip: skip,
      );

  /// Re-reads usage and reloads the first page (pull-to-refresh).
  Future<void> reloadAll() async {
    await loadUsage();
    await loadMedia(reset: true);
  }

  /// Scopes the list to [conversationId] (or clears the scope with `null`) and
  /// reloads from the top.
  Future<void> setConversationFilter(String? conversationId) async {
    if (_conversationFilter.value == conversationId) return;
    _conversationFilter.value =
        (conversationId == null || conversationId.isEmpty)
            ? null
            : conversationId;
    clearSelection();
    // Use the in-screen spinner (isLoadingMedia), not a blocking loader dialog.
    await loadMedia(reset: true);
  }

  /// Sets the client-side attachment-kind filter (`null` = all).
  void setTypeFilter(IsmChatMediaType? type) => _typeFilter.value = type;

  /// Toggles largest→smallest client-side sort.
  void toggleSortBySize() => _sortBySizeDesc.toggle();

  // ------------------------------------------------------------- selection

  /// Enables multi-select and selects [mediaId] if provided.
  void enterSelectionMode([String? mediaId]) {
    _selectionMode.value = true;
    if (mediaId != null) _selectedMediaIds.add(mediaId);
  }

  /// Toggles a row's selection. Entering/leaving selection mode is automatic.
  void toggleSelection(String mediaId) {
    if (_selectedMediaIds.contains(mediaId)) {
      _selectedMediaIds.remove(mediaId);
    } else {
      _selectedMediaIds.add(mediaId);
    }
    _selectionMode.value = _selectedMediaIds.isNotEmpty;
  }

  /// Whether [mediaId] is currently selected.
  bool isSelected(String mediaId) => _selectedMediaIds.contains(mediaId);

  /// Selects every currently visible row.
  void selectAllVisible() {
    _selectedMediaIds.addAll(visibleMedia.map((e) => e.mediaId));
    _selectionMode.value = _selectedMediaIds.isNotEmpty;
  }

  /// Clears the selection and leaves selection mode.
  void clearSelection() {
    _selectedMediaIds.clear();
    _selectionMode.value = false;
  }

  // --------------------------------------------------------------- deletes

  /// Deletes the selected rows (for everyone) via `DELETE /chat/quota/media`,
  /// updates [usage] and removes the rows locally. Returns the freed-bytes
  /// result, or `null` on failure. Shows a toast with the outcome.
  Future<IsmChatMediaDeleteResultModel?> deleteSelected() async {
    final ids = _selectedMediaIds.toList();
    if (ids.isEmpty) return null;
    return deleteMedia(ids);
  }

  /// Deletes [mediaIds] (for everyone). Shared by [deleteSelected] and single
  /// swipe-to-delete.
  Future<IsmChatMediaDeleteResultModel?> deleteMedia(
    List<String> mediaIds,
  ) async {
    if (mediaIds.isEmpty) return null;
    final outcome = await _viewModel.deleteMedia(
      mediaIds: mediaIds,
      isLoading: true,
    );
    final result = outcome.result;
    if (result == null) {
      IsmChatUtility.showToast(
        outcome.response.apiErrorMessage(fallback: 'Could not delete media'),
      );
      return null;
    }
    _applyDeleteResult(result, removedMediaIds: mediaIds);
    IsmChatUtility.showToast(
      result.freedBytes > 0
          ? 'Freed ${IsmChatUtility.formatBytesDecimal(result.freedBytes)}'
          : 'Media removed',
    );
    return result;
  }

  /// Deletes every file this user sent in [conversationId] (for everyone) via
  /// `DELETE /chat/quota/storage/conversation/{id}/media`.
  Future<IsmChatMediaDeleteResultModel?> deleteAllInConversation(
    String conversationId,
  ) async {
    if (conversationId.isEmpty) return null;
    final outcome = await _viewModel.deleteConversationMedia(
      conversationId: conversationId,
      isLoading: true,
    );
    final result = outcome.result;
    if (result == null) {
      IsmChatUtility.showToast(
        outcome.response
            .apiErrorMessage(fallback: 'Could not delete conversation media'),
      );
      return null;
    }
    // Drop every loaded row for that conversation.
    final removed = _media
        .where((e) => e.conversationId == conversationId)
        .map((e) => e.mediaId)
        .toList();
    _applyDeleteResult(result, removedMediaIds: removed);
    IsmChatUtility.showToast(
      result.freedBytes > 0
          ? 'Freed ${IsmChatUtility.formatBytesDecimal(result.freedBytes)}'
          : 'No media to remove',
    );
    return result;
  }

  /// Applies a delete result: removes rows, keeps skip-based paging aligned,
  /// refreshes [usage] from the reported used/quota figures, and clears the
  /// selection.
  void _applyDeleteResult(
    IsmChatMediaDeleteResultModel result, {
    required List<String> removedMediaIds,
  }) {
    final removed = removedMediaIds.toSet();
    final before = _media.length;
    _media.removeWhere((e) => removed.contains(e.mediaId));
    // The server list shrank by the same rows, so pull the paging cursor back
    // by however many loaded rows we dropped — otherwise the next page would
    // skip unseen rows (gap) after a mid-scroll delete.
    final removedCount = before - _media.length;
    if (removedCount > 0) {
      final next = _skip - removedCount;
      _skip = next < 0 ? 0 : next;
    }
    if (result.usedBytes != null) {
      applyUsageFigures(
        usedBytes: result.usedBytes,
        quotaBytes: result.quotaBytes,
      );
    } else {
      // Fall back to a server re-read when figures weren't reported.
      unawaited(loadUsage());
    }
    clearSelection();
  }

  /// Updates the cached [usage] from server-reported figures (e.g. the
  /// freed-bytes payload of a media or message delete). No-op when usage hasn't
  /// loaded or [usedBytes] is absent. Recomputes `remainingBytes` and re-enables
  /// `canUpload` once usage drops below the allowance.
  void applyUsageFigures({int? usedBytes, int? quotaBytes}) {
    final current = _usage.value;
    if (current == null || usedBytes == null) return;
    final quota = quotaBytes ?? current.quotaBytes;
    final int? remaining;
    if (quota == null) {
      remaining = current.remainingBytes;
    } else {
      final diff = quota - usedBytes;
      remaining = diff < 0 ? 0 : diff;
    }
    _usage.value = current.copyWith(
      usedBytes: usedBytes,
      quotaBytes: quota,
      remainingBytes: remaining,
      canUpload: quota == null ? current.canUpload : usedBytes < quota,
    );
    _syncListBannerDismissWithUsage(_usage.value);
  }

  /// A confirm dialog + delete for the selected rows. UI convenience.
  Future<void> confirmDeleteSelected(BuildContext context) async {
    final count = _selectedMediaIds.length;
    if (count == 0) return;
    final ok = await _confirm(
      context,
      title: 'Delete $count item${count == 1 ? '' : 's'}?',
      message:
          'This removes the message for everyone in the conversation and frees your storage.',
      confirmLabel: 'Delete',
    );
    if (ok) await deleteSelected();
  }

  /// A confirm dialog + delete for all media in [conversationId].
  Future<void> confirmDeleteAllInConversation(
    BuildContext context,
    String conversationId,
  ) async {
    final ok = await _confirm(
      context,
      title: 'Delete all media in this conversation?',
      message:
          'Every file you sent here is removed for everyone. Text messages stay.',
      confirmLabel: 'Delete all',
    );
    if (ok) await deleteAllInConversation(conversationId);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: IsmChatColors.redColor),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
