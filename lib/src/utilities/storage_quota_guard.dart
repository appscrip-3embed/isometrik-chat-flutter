// coverage:ignore-file
// Unreachable under VM tests: UI, GetX DI, or network I/O.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Upload enforcement for the media storage quota feature.
///
/// One place that decides whether a media upload is allowed and that turns a
/// server quota rejection into a user-facing prompt. Used by the SDK's own send
/// path and available to host apps.
///
/// The app-level quota error code returned by presign/send when a user is over
/// quota (HTTP 403 body `{ "errorCode": 6, "error": "Storage quota exceeded." }`).
class IsmChatStorageQuotaGuard {
  const IsmChatStorageQuotaGuard._();

  /// App-level error code for "storage quota exceeded" (distinct from the HTTP
  /// 403 status carried on [IsmChatResponseModel.errorCode]).
  static const int quotaExceededCode = 6;

  /// The permanent storage controller, or `null` if the SDK isn't initialised.
  static IsmChatStorageQuotaController? get _controller =>
      Get.isRegistered<IsmChatStorageQuotaController>()
          ? Get.find<IsmChatStorageQuotaController>()
          : null;

  /// The last known usage snapshot (may be stale/`null`).
  static IsmChatStorageUsageModel? get cachedUsage => _controller?.usage;

  /// Whether quotas are known to be on. `false` when unknown or off.
  static bool get quotaEnabled => cachedUsage?.quotaEnabled ?? false;

  /// Ensures a usage snapshot exists, fetching once if needed. Pass
  /// [forceRefresh] to always re-read from the server.
  static Future<IsmChatStorageUsageModel?> ensureUsage({
    bool forceRefresh = false,
  }) async {
    final controller = _controller;
    if (controller == null) return null;
    if (!forceRefresh && controller.usage != null) return controller.usage;
    return controller.loadUsage();
  }

  /// Returns `true` when an upload totalling [totalBytes] is allowed.
  ///
  /// Allows by default when the feature is dormant (SDK not initialised or
  /// quota off). Fetches usage once if not cached. This is a client-side
  /// pre-check; the server remains the final authority (see
  /// [handleResponseIfQuota]).
  static Future<bool> canUpload({required int totalBytes}) async {
    final controller = _controller;
    if (controller == null) return true;
    final usage = await ensureUsage();
    if (usage == null || !usage.quotaEnabled) return true;
    return usage.canUploadBytes(totalBytes);
  }

  /// Pre-check for an upload of [totalBytes]. When blocked and [showPrompt] is
  /// `true`, shows the "storage full" prompt. Returns `true` when the upload
  /// may proceed.
  static Future<bool> ensureCanUpload({
    required int totalBytes,
    bool showPrompt = true,
  }) async {
    final allowed = await canUpload(totalBytes: totalBytes);
    if (!allowed && showPrompt) {
      await showQuotaExceededDialog();
    }
    return allowed;
  }

  /// Returns `true` when a single file of [fileBytes] is within the server
  /// per-file cap ([IsmChatStorageUsageModel.maxFileSizeBytes] when quota is on).
  static Future<bool> canUploadFileSize(int fileBytes) async {
    final usage = await ensureUsage();
    if (usage == null) return true;
    return usage.isWithinMaxFileSize(fileBytes);
  }

  /// Pre-check for a single file against [maxFileSizeBytes]. When blocked and
  /// [showPrompt] is `true`, shows a "file too large" dialog.
  static Future<bool> ensureCanUploadFileSize({
    required int fileBytes,
    bool showPrompt = true,
  }) async {
    final allowed = await canUploadFileSize(fileBytes);
    if (!allowed && showPrompt) {
      final max = cachedUsage?.maxFileSizeBytes;
      await showMaxFileSizeExceededDialog(maxBytes: max);
    }
    return allowed;
  }

  /// Pre-check for one attachment before send. When quota is on and the server
  /// sets [maxFileSizeBytes], enforces that cap; otherwise uses the legacy
  /// formatted-size limit ([SizeOfMedia.size], default 100 MB).
  static Future<bool> ensureAttachmentSizeAllowed({
    required int fileBytes,
    bool showPrompt = true,
  }) async {
    final usage = await ensureUsage();
    if (usage != null && usage.quotaEnabled && usage.maxFileSizeBytes != null) {
      return ensureCanUploadFileSize(
        fileBytes: fileBytes,
        showPrompt: showPrompt,
      );
    }
    if (IsmChatUtility.formatBytes(fileBytes).size()) {
      return true;
    }
    if (showPrompt) {
      await IsmChatContextWidget.showDialogContext(
        content: IsmChatAlertDialogBox(
          title: IsmChatStrings.youCanNotSend,
          cancelLabel: IsmChatStrings.okay,
        ),
      );
    }
    return false;
  }

  /// Parses `usedBytes` / `quotaBytes` from a successful API response that may
  /// carry freed-storage figures — e.g. the delete-message response when quota
  /// is on (`{ freedBytes, usedBytes, quotaBytes }`) — and updates the cached
  /// usage so upload enforcement and any open storage screen stay in sync.
  ///
  /// No-op when the SDK is dormant, the body is not JSON, or the figures are
  /// absent (quota off). Safe to call after any delete/clear response.
  static void syncUsageFromResponse(IsmChatResponseModel response) {
    final controller = _controller;
    if (controller == null || response.hasError) return;
    final body = response.data.trim();
    if (body.isEmpty) return;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return;
      final used = _asInt(decoded['usedBytes']);
      if (used == null) return; // no quota figures in this response
      controller.applyUsageFigures(
        usedBytes: used,
        quotaBytes: _asInt(decoded['quotaBytes']),
      );
    } catch (_) {
      // Non-JSON body — nothing to sync.
    }
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Whether [response] is a storage-quota rejection (app `errorCode` 6).
  static bool isQuotaError(IsmChatResponseModel response) {
    if (!response.hasError) return false;
    return response.applicationErrorCode == quotaExceededCode;
  }

  /// If [response] is a quota rejection, refreshes usage, shows the prompt and
  /// returns `true`. Otherwise returns `false` and does nothing. Call this on
  /// the failure branch of any presign/send that can be blocked by quota.
  static Future<bool> handleResponseIfQuota(
    IsmChatResponseModel response,
  ) async {
    if (!isQuotaError(response)) return false;
    // Server said over-limit — pull a fresh snapshot so the UI reflects it.
    await ensureUsage(forceRefresh: true);
    await showQuotaExceededDialog(
      message: response.apiErrorMessage(fallback: _defaultMessage),
    );
    return true;
  }

  static const String _defaultMessage =
      'Your media storage is full. Delete some files to upload new media. '
      'Text messages are not affected.';

  /// Shows a "storage full" dialog with a "Manage storage" action that opens
  /// the storage screen, and an OK to dismiss.
  static Future<void> showQuotaExceededDialog({String? message}) async {
    await IsmChatContextWidget.showDialogContext(
      content: IsmChatAlertDialogBox(
        title: 'Storage full',
        content: Text(message ?? _defaultMessage),
        actionLabels: const ['Manage storage'],
        callbackActions: [
          () {
            IsmChatRoute.goBack<void>();
            IsmChat.i.openStorageManagement();
          },
        ],
        cancelLabel: IsmChatStrings.okay,
      ),
    );
  }

  /// Shows a dialog when an attachment exceeds [maxFileSizeBytes].
  static Future<void> showMaxFileSizeExceededDialog({int? maxBytes}) async {
    final limitText = maxBytes != null
        ? IsmChatUtility.formatBytesDecimal(maxBytes)
        : 'the allowed limit';
    await IsmChatContextWidget.showDialogContext(
      content: IsmChatAlertDialogBox(
        title: 'File too large',
        content: Text(
          'This file exceeds the maximum upload size of $limitText. '
          'Choose a smaller file or send multiple smaller attachments.',
        ),
        cancelLabel: IsmChatStrings.okay,
      ),
    );
  }
}
