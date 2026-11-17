// coverage:ignore-file
// Dialog path needs Flutter binding; core branches are unit-tested via injectors.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// User choice after presign returns `duplicate: true` (storage quota on).
enum SameNameUploadChoice { reshare, uploadCopy, cancelled }

/// Outcome of presign + optional PUT + duplicate handling for one attachment.
class SameNameUploadOutcome {
  const SameNameUploadOutcome({
    required this.presigned,
    this.forceUploadOnMessage = false,
    this.cancelled = false,
  });

  const SameNameUploadOutcome.cancelled()
      : presigned = null,
        forceUploadOnMessage = false,
        cancelled = true;

  final PresignedUrlModel? presigned;
  final bool forceUploadOnMessage;
  final bool cancelled;

  /// User chose **Reshare older file** after `duplicate: true` (no new PUT).
  bool get isReshareExistingFile =>
      !cancelled &&
      (presigned?.duplicate ?? false) &&
      !forceUploadOnMessage;

  /// `mediaId` for `POST /chat/message` — see `docs/SAME_NAME_UPLOAD_FRONTEND_1_1.md`.
  String? resolveOutgoingMediaId({required String clientMediaId}) {
    if (cancelled || presigned == null) return null;
    if (isReshareExistingFile) {
      final existing = presigned!.existingMediaId?.trim() ?? '';
      return existing.isNotEmpty ? existing : null;
    }
    return (presigned!.mediaId?.trim().isNotEmpty == true)
        ? presigned!.mediaId!.trim()
        : clientMediaId;
  }
}

/// Same-name upload flow for `POST /chat/messages/presignedurls` — see
/// `docs/SAME_NAME_UPLOAD_FRONTEND_1_1.md`.
///
/// Presign `nameWithExtension` must be stable across re-picks of the same asset
/// (not an iOS `image_picker_<uuid>` temp name). Set at pick time via
/// [IsmChatUtility.resolveOutboundPresignFileName] (content-hash for ephemeral
/// picker names).
///
/// Centralizes: presign → branch on `duplicate` → optional PUT → message flags.
class IsmChatSameNameAttachmentUpload {
  const IsmChatSameNameAttachmentUpload._();

  static const String defaultDuplicateWarning =
      'A file with the same name is already in your storage.';

  /// Presign, handle duplicates when quota is on, PUT when required.
  ///
  /// [presign] must call the message presign API (`forceUpload` on retry).
  /// [putBytes] performs the S3 PUT; return `200` on success.
  /// [duplicateChoicePrompt] optional injector for tests (skips UI).
  static Future<SameNameUploadOutcome?> resolveAndUpload({
    required int fileBytes,
    required bool isThumbnailPresign,
    required Future<PresignedUrlModel?> Function({required bool forceUpload})
        presign,
    required Future<int?> Function(String presignedPutUrl, Uint8List bytes)
        putBytes,
    required Uint8List mediaBytes,
    SameNameDuplicateChoicePrompt? duplicateChoicePrompt,
  }) async {
    final first = await presign(forceUpload: false);
    if (first == null) {
      return null;
    }

    final quotaOn = IsmChatStorageQuotaGuard.quotaEnabled;
    if (!quotaOn || !first.isDuplicate) {
      final putUrl = isThumbnailPresign
          ? first.thumbnailPresignedUrl
          : first.mediaPresignedUrl;
      if (putUrl == null || putUrl.isEmpty) {
        // Quota off still expects PUT urls; malformed response.
        if ((first.mediaUrl ?? '').isEmpty) {
          return null;
        }
        return SameNameUploadOutcome(presigned: first);
      }
      final status = await putBytes(putUrl, mediaBytes);
      if (status != 200) {
        return null;
      }
      return SameNameUploadOutcome(presigned: first);
    }

    final warning =
        first.warning?.trim().isNotEmpty == true ? first.warning!.trim() : defaultDuplicateWarning;
    final choice = duplicateChoicePrompt != null
        ? await duplicateChoicePrompt(warning)
        : await _showDuplicateDialog(warning);

    if (choice == null || choice == SameNameUploadChoice.cancelled) {
      return const SameNameUploadOutcome.cancelled();
    }

    if (choice == SameNameUploadChoice.reshare) {
      if ((first.mediaUrl ?? '').isEmpty) {
        return null;
      }
      return SameNameUploadOutcome(presigned: first);
    }

    // Upload a copy.
    final allowed = await IsmChatStorageQuotaGuard.ensureCanUpload(
      totalBytes: fileBytes,
    );
    if (!allowed) {
      return const SameNameUploadOutcome.cancelled();
    }

    final second = await presign(forceUpload: true);
    if (second == null) {
      return null;
    }

    final putUrl = isThumbnailPresign
        ? second.thumbnailPresignedUrl
        : second.mediaPresignedUrl;
    if (putUrl == null || putUrl.isEmpty) {
      return null;
    }
    final status = await putBytes(putUrl, mediaBytes);
    if (status != 200) {
      return null;
    }
    return SameNameUploadOutcome(
      presigned: second,
      forceUploadOnMessage: true,
    );
  }

  static Future<SameNameUploadChoice?> _showDuplicateDialog(
    String warning,
  ) async {
    SameNameUploadChoice? choice;
    await IsmChatContextWidget.showDialogContext(
      content: IsmChatAlertDialogBox(
        title: IsmChatStrings.sameNameUploadTitle,
        content: Text(warning),
        actionLabels: [
          IsmChatStrings.reshareOlderFile,
          IsmChatStrings.uploadACopy,
        ],
        callbackActions: [
          () => choice = SameNameUploadChoice.reshare,
          () => choice = SameNameUploadChoice.uploadCopy,
        ],
        cancelLabel: IsmChatStrings.cancel,
        onCancel: () => choice = SameNameUploadChoice.cancelled,
      ),
    );
    return choice ?? SameNameUploadChoice.cancelled;
  }
}

/// Test hook — replaces the duplicate banner dialog.
typedef SameNameDuplicateChoicePrompt = Future<SameNameUploadChoice?> Function(
  String warning,
);