part of '../chat_page_controller.dart';

/// Mixin for handling document message sending in the chat page controller.
///
/// This mixin provides functionality for sending document (PDF) messages.
/// It depends on:
/// - `createConversation()` from send_message_core mixin
/// - `ismPostMediaUrl()` from send_message_media mixin
mixin IsmChatPageSendMessageDocumentMixin {
  /// Gets the controller instance.
  IsmChatPageController get _controller => this as IsmChatPageController;

  /// Sends a document (PDF) message.
  ///
  /// [conversationId] - ID of the conversation
  /// [userId] - ID of the user
  ///
  /// Opens a file picker to select PDF files and sends them as messages.
  /// Note: This method requires `createConversation` and `ismPostMediaUrl`
  /// to be available through other mixins on the controller.
  void sendDocument({
    required String conversationId,
    required String userId,
  }) async {
    final allowed = await IsmChatProperties
        .chatPageProperties.messageAllowedConfig
        .shouldAllowOutboundSend(
      context:
          IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context,
      conversation: _controller.conversation,
      customType: IsmChatCustomMessageType.file,
      messageText: _controller.chatInputController.text.trim(),
    );
    if (!allowed) {
      return;
    }

    // Resolve the conversation immediately after the allow-check and before
    // the file picker. Reuse this pattern in other attachment send paths:
    // never send against the inbound/stale id if creation fails or returns ''.
    final resolvedConversationId = await _controller.createConversation(
      conversationId: conversationId,
      userId: userId,
    );
    if (resolvedConversationId.isEmpty) {
      IsmChatLog.error(
        'sendDocument aborted: conversation creation returned an empty id',
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result?.files.isNotEmpty ?? false) {
      final files = IsmChatUtility.clampOutboundPickerSelection(result!.files);
      if (files.length == 1) {
        await _sendPickedDocumentFile(
          conversationId: resolvedConversationId,
          file: files.first,
        );
      } else {
        await _sendMultiplePickedDocuments(
          conversationId: resolvedConversationId,
          files: files,
        );
      }
    }
  }

  /// Uploads several documents and sends one [AttachmentMessage:Multiple].
  Future<void> _sendMultiplePickedDocuments({
    required String conversationId,
    required List<PlatformFile> files,
  }) async {
    if (_controller.isreplying) {
      for (final file in files) {
        await _sendPickedDocumentFile(
          conversationId: conversationId,
          file: file,
        );
      }
      return;
    }

    for (final file in files) {
      final bytes = file.bytes;
      final sizeMedia = kIsWeb
          ? IsmChatUtility.formatBytes(
              int.parse((bytes?.length ?? 0).toString()),
            )
          : await IsmChatUtility.fileToSize(File(file.path ?? ''));
      if (!sizeMedia.size()) {
        await IsmChatContextWidget.showDialogContext(
          content: IsmChatAlertDialogBox(
            title: IsmChatStrings.youCanNotSend,
            cancelLabel: IsmChatStrings.okay,
          ),
        );
        return;
      }
    }

    final sentAt = DateTime.now().millisecondsSinceEpoch;
    final localAttachments = <AttachmentModel>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final bytes = file.bytes;
      final mediaId = '${sentAt}_$i';
      localAttachments.add(
        AttachmentModel(
          attachmentType: IsmChatMediaType.file,
          size: bytes?.length,
          name: file.name,
          // Real MIME, not the bare extension. Web reads mimeType with mediaType 3.
          mimeType: mimeTypeForAttachmentExtension(
            file.extension,
            mediaType: IsmChatMediaType.file,
          ),
          mediaUrl: kIsWeb ? (bytes).toString() : file.path,
          mediaId: mediaId,
          extension: file.extension,
        ),
      );
    }

    // Same wire rule as photos: body is the caption, or this placeholder.
    const multipleBody = 'AttachmentMessage:Multiple';
    final caption = _controller.chatInputController.text.trim();
    final body = caption.isNotEmpty ? caption : multipleBody;
    if (caption.isNotEmpty) {
      _controller.chatInputController.clear();
    }
    final documentMessage = IsmChatMessageModel(
      body: body,
      conversationId: conversationId,
      senderInfo: _controller.currentUser,
      customType: IsmChatCustomMessageType.multipleAttachments,
      attachments: localAttachments,
      deliveredToAll: false,
      messageId: '',
      deviceId: IsmChatConfig.communicationConfig.projectConfig.deviceId,
      messageType: IsmChatMessageType.normal,
      messagingDisabled: false,
      parentMessageId: '',
      readByAll: false,
      sentAt: sentAt,
      sentByMe: true,
      isUploading: true,
      metaData: IsmChatMetaData(
        messageSentAt: sentAt,
        isDownloaded: true,
        caption: caption.isEmpty ? null : caption,
      ),
    );

    _controller.messages.add(documentMessage);
    unawaited(_controller.scrollDown());

    if (!_controller.isBroadcast) {
      await IsmChatConfig.dbWrapper!
          .saveMessage(documentMessage, IsmChatDbBox.pending);
      if (kIsWeb &&
          IsmChatResponsive.isWeb(IsmChatConfig.kNavigatorKey.currentContext ??
              IsmChatConfig.context)) {
        _controller.updateLastMessagOnCurrentTime(documentMessage);
      }
    }

    final notificationTitle =
        IsmChatConfig.communicationConfig.userConfig.userName ??
            _controller.conversationController.userDetails?.userName ??
            '';

    final outgoingAttachments = <Map<String, dynamic>>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final map = await _uploadDocumentAttachmentMap(
        conversationId: conversationId,
        file: file,
        mediaId: localAttachments[i].mediaId ?? '${sentAt}_$i',
      );
      if (map == null) {
        _markMultipleDocumentUploadFailed(sentAt);
        return;
      }
      outgoingAttachments.add(map);
    }

    await _controller.sendMessage(
      body: body,
      conversationId: conversationId,
      createdAt: sentAt,
      deviceId: documentMessage.deviceId ?? '',
      messageType: documentMessage.messageType?.value ?? 0,
      notificationBody: IsmChatStrings.sentDoc,
      notificationTitle: notificationTitle,
      attachments: outgoingAttachments,
      customType: IsmChatCustomMessageType.multipleAttachments.value,
      metaData: documentMessage.metaData,
      isBroadcast: _controller.isBroadcast,
    );
    _clearMultipleDocumentUploadState(sentAt);
  }

  void _clearMultipleDocumentUploadState(int createdAt) {
    final index = _controller.messages.indexWhere(
      (message) => message.sentAt == createdAt,
    );
    if (index == -1) {
      return;
    }
    final current = _controller.messages[index];
    if (current.isUploading != true) {
      return;
    }
    current.isUploading = false;
    _controller.messages[index] = current;
    if (_controller.messages is RxList<IsmChatMessageModel>) {
      (_controller.messages as RxList<IsmChatMessageModel>).refresh();
    }
    _controller.update();
  }

  void _markMultipleDocumentUploadFailed(int createdAt) {
    final index = _controller.messages.indexWhere(
      (message) => message.sentAt == createdAt,
    );
    if (index == -1) {
      return;
    }
    final current = _controller.messages[index];
    current
      ..isUploading = false
      ..isInvalidMessage = true
      ..messageId = '';
    _controller.messages[index] = current;
    if (_controller.messages is RxList<IsmChatMessageModel>) {
      (_controller.messages as RxList<IsmChatMessageModel>).refresh();
    }
    _controller.update();
  }

  /// Presigned upload for one document; returns API attachment map.
  Future<Map<String, dynamic>?> _uploadDocumentAttachmentMap({
    required String conversationId,
    required PlatformFile file,
    required String mediaId,
  }) async {
    try {
      final bytes = file.bytes ?? Uint8List(0);
      final bytesForPdf = Uint8List.fromList(bytes);
      final document = kIsWeb
          ? await PdfDocument.openData(bytesForPdf)
          : await PdfDocument.openFile(file.path ?? '');
      final page = await document.getPage(1);
      final pdfImage = await page.render(
        width: page.width,
        height: page.height,
        backgroundColor: '#ffffff',
      );
      await page.close();
      await document.close();

      final thumbnailBytes = pdfImage?.bytes ?? Uint8List(0);
      final thumbnailNameWithExtension = pdfImage?.format.toString() ?? 'png';
      final nameWithExtension = file.name;

      PresignedUrlModel? presignedUrlModel;
      if (_controller.isBroadcast) {
        presignedUrlModel = await _controller.commonController.getPresignedUrl(
          isLoading: false,
          mediaExtension: file.extension ?? 'pdf',
          userIdentifier:
              IsmChatConfig.communicationConfig.userConfig.userEmail ?? '',
          bytes: bytesForPdf,
        );
      } else {
        presignedUrlModel = await _controller.commonController.postMediaUrl(
          conversationId: conversationId,
          nameWithExtension: nameWithExtension,
          mediaType: IsmChatMediaType.file.value,
          mediaId: mediaId,
          bytes: bytesForPdf,
          isLoading: false,
        );
      }

      var mediaUrlPath = presignedUrlModel?.mediaUrl ?? '';
      final resolvedMediaId =
          _controller.isBroadcast ? mediaId : presignedUrlModel?.mediaId ?? '';

      if (mediaUrlPath.isEmpty) {
        return null;
      }

      final mediaResponse =
          await _controller.commonController.updatePresignedUrl(
        presignedUrl: _controller.isBroadcast
            ? presignedUrlModel?.presignedUrl
            : presignedUrlModel?.mediaPresignedUrl,
        bytes: bytesForPdf,
        isLoading: false,
      );
      if (mediaResponse != 200) {
        return null;
      }

      var thumbnailUrlPath = '';
      PresignedUrlModel? thumbPresigned;
      if (_controller.isBroadcast) {
        thumbPresigned = await _controller.commonController.getPresignedUrl(
          isLoading: false,
          mediaExtension: thumbnailNameWithExtension.split('.').last,
          userIdentifier:
              IsmChatConfig.communicationConfig.userConfig.userEmail ?? '',
          bytes: thumbnailBytes,
        );
        thumbnailUrlPath = thumbPresigned?.mediaUrl ?? '';
      } else {
        thumbPresigned = await _controller.commonController.postMediaUrl(
          conversationId: conversationId,
          nameWithExtension: thumbnailNameWithExtension,
          mediaType: IsmChatMediaType.image.value,
          mediaId: mediaId,
          bytes: thumbnailBytes,
          isLoading: false,
          isUpdateThumbnail: true,
        );
        thumbnailUrlPath = thumbPresigned?.thumbnailUrl ?? '';
      }

      if (thumbnailUrlPath.isNotEmpty) {
        await _controller.commonController.updatePresignedUrl(
          presignedUrl: _controller.isBroadcast
              ? thumbPresigned?.presignedUrl
              : thumbPresigned?.thumbnailPresignedUrl,
          bytes: thumbnailBytes,
          isLoading: false,
        );
      }

      return {
        'mediaId': resolvedMediaId,
        'mediaUrl': mediaUrlPath,
        'thumbnailUrl':
            thumbnailUrlPath.isNotEmpty ? thumbnailUrlPath : mediaUrlPath,
        'mediaType': IsmChatMediaType.file.value,
        'nameWithExtension': nameWithExtension,
        'name': nameWithExtension,
        'mimeType': mimeTypeForAttachmentExtension(
          file.extension,
          mediaType: IsmChatMediaType.file,
        ),
        'extension': file.extension ?? 'pdf',
        'size': bytes.length,
        // 3 = doc. 0 is image and must not be sent for a document.
        'attachmentType': IsmChatMediaType.file.value,
      };
    } catch (e, st) {
      IsmChatLog.error(e, st);
      return null;
    }
  }

  /// Builds and uploads one picked PDF as a chat message.
  Future<void> _sendPickedDocumentFile({
    required String conversationId,
    required PlatformFile file,
  }) async {
    final bytes = file.bytes;
    final sizeMedia = kIsWeb
        ? IsmChatUtility.formatBytes(
            int.parse((bytes?.length ?? 0).toString()),
          )
        : await IsmChatUtility.fileToSize(File(file.path ?? ''));
    if (!sizeMedia.size()) {
      await IsmChatContextWidget.showDialogContext(
        content: IsmChatAlertDialogBox(
          title: IsmChatStrings.youCanNotSend,
          cancelLabel: IsmChatStrings.okay,
        ),
      );
      return;
    }

    final sentAt = DateTime.now().millisecondsSinceEpoch;
    final mediaId = sentAt.toString();
    final bytesForPdf = Uint8List.fromList(bytes ?? []);
    final document = kIsWeb
        ? await PdfDocument.openData(bytesForPdf)
        : await PdfDocument.openFile(file.path ?? '');
    final page = await document.getPage(1);
    final pdfImage = await page.render(
      width: page.width,
      height: page.height,
      backgroundColor: '#ffffff',
    );
    await page.close();
    await document.close();

    final thumbnailBytes = pdfImage?.bytes;
    final thumbnailNameWithExtension = pdfImage?.format.toString();
    final thumbnailMediaId = mediaId;
    final nameWithExtension = file.name;

    final documentMessage = IsmChatMessageModel(
      body: nameWithExtension,
      conversationId: conversationId,
      senderInfo: _controller.currentUser,
      customType: _controller.isreplying
          ? IsmChatCustomMessageType.reply
          : IsmChatCustomMessageType.file,
      attachments: [
        AttachmentModel(
          attachmentType: IsmChatMediaType.file,
          thumbnailUrl: pdfImage?.bytes.toString(),
          size: bytes?.length,
          name: nameWithExtension,
          mimeType: file.extension,
          mediaUrl: kIsWeb ? (bytes).toString() : file.path,
          mediaId: mediaId,
          extension: file.extension,
        )
      ],
      deliveredToAll: false,
      messageId: '',
      deviceId: IsmChatConfig.communicationConfig.projectConfig.deviceId,
      messageType: _controller.isreplying
          ? IsmChatMessageType.reply
          : IsmChatMessageType.normal,
      messagingDisabled: false,
      parentMessageId:
          _controller.isreplying ? _controller.replayMessage?.messageId : '',
      readByAll: false,
      sentAt: sentAt,
      sentByMe: true,
      isUploading: true,
      metaData: IsmChatMetaData(
        messageSentAt: sentAt,
        isDownloaded: true,
        replyMessage: _controller.isreplying
            ? IsmChatReplyMessageModel(
                forMessageType: IsmChatCustomMessageType.file,
                parentMessageMessageType: _controller.replayMessage?.customType,
                parentMessageInitiator: _controller.replayMessage?.sentByMe,
                parentMessageBody:
                    _controller.getMessageBody(_controller.replayMessage),
                parentMessageUserId:
                    _controller.replayMessage?.senderInfo?.userId,
                parentMessageUserName:
                    _controller.replayMessage?.senderInfo?.userName ?? '',
              )
            : null,
      ),
    );

    _controller.messages.add(documentMessage);
    unawaited(_controller.scrollDown());
    _controller.isreplying = false;

    if (!_controller.isBroadcast) {
      await IsmChatConfig.dbWrapper!
          .saveMessage(documentMessage, IsmChatDbBox.pending);
      if (kIsWeb &&
          IsmChatResponsive.isWeb(IsmChatConfig.kNavigatorKey.currentContext ??
              IsmChatConfig.context)) {
        _controller.updateLastMessagOnCurrentTime(documentMessage);
      }
    }

    final notificationTitle =
        IsmChatConfig.communicationConfig.userConfig.userName ??
            _controller.conversationController.userDetails?.userName ??
            '';
    // Note: ismPostMediaUrl is provided by send_message_media mixin
    await _controller.ismPostMediaUrl(
      imageAndFile: false,
      bytes: bytes ?? Uint8List(0),
      createdAt: sentAt,
      ismChatChatMessageModel: documentMessage,
      mediaId: mediaId,
      mediaType: IsmChatMediaType.file.value,
      nameWithExtension: nameWithExtension,
      notificationBody: IsmChatStrings.sentDoc,
      notificationTitle: notificationTitle,
      thumbnailNameWithExtension: thumbnailNameWithExtension,
      thumbnailMediaId: thumbnailMediaId,
      thumbnailBytes: thumbnailBytes,
      thumbanilMediaType: IsmChatMediaType.image.value,
    );
  }
}
