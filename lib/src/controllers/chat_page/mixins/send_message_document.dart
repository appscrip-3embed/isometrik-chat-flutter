part of '../chat_page_controller.dart';

/// Mixin for handling document message sending in the chat page controller.
///
/// This mixin provides functionality for sending document (PDF) messages and
/// routes image/video picks from the document file picker through the gallery
/// media send path.
/// It depends on:
/// - `createConversation()` from send_message_core mixin
/// - `ismPostMediaUrl()` from send_message_media mixin
/// - `webMediaModelFromPlatformFile()` from media_operations mixin
mixin IsmChatPageSendMessageDocumentMixin {
  /// Gets the controller instance.
  IsmChatPageController get _controller => this as IsmChatPageController;

  /// Opens the document attachment file picker and sends each selection.
  ///
  /// PDFs use the file/document pipeline; images and videos are delegated to
  /// [IsmChatPageSendMessageMediaMixin] (`sendImage` / `sendGif` / `sendVideo`).
  void sendDocument({
    required String conversationId,
    required String userId,
  }) async {
    // Resolve the conversation before the file picker. Reuse this pattern in
    // other attachment send paths: never send against the inbound/stale id if
    // creation fails or returns ''.
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
      withData: true,
    );

    if (result?.files.isNotEmpty ?? false) {
      for (final file in result!.files) {
        await _dispatchPickedAttachmentFile(
          conversationId: resolvedConversationId,
          userId: userId,
          file: file,
        );
      }
    }
  }

  String _pickedFileExtension(PlatformFile file) {
    final fromPicker = file.extension?.toLowerCase().trim();
    if (fromPicker != null && fromPicker.isNotEmpty) {
      return fromPicker;
    }
    final name = file.name;
    if (name.contains('.')) {
      return name.split('.').last.toLowerCase();
    }
    return '';
  }

  Future<void> _dispatchPickedAttachmentFile({
    required String conversationId,
    required String userId,
    required PlatformFile file,
  }) async {
    final context =
        IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context;
    final messageText = _controller.chatInputController.text.trim();
    final ext = _pickedFileExtension(file);

    if (IsmChatConstants.imageExtensions.contains(ext)) {
      final allowed = await IsmChatProperties
          .chatPageProperties.messageAllowedConfig
          .shouldAllowOutboundSend(
        context: context,
        conversation: _controller.conversation,
        customType: IsmChatCustomMessageType.image,
        messageText: messageText,
      );
      if (!allowed) {
        return;
      }
      final webMediaModel =
          await _controller.webMediaModelFromPlatformFile(file);
      if (webMediaModel == null) {
        return;
      }
      if (ext == 'gif') {
        await _controller.sendGif(
          conversationId: conversationId,
          userId: userId,
          webMediaModel: webMediaModel,
          skipConversationCreate: true,
        );
      } else {
        await _controller.sendImage(
          conversationId: conversationId,
          userId: userId,
          webMediaModel: webMediaModel,
          skipConversationCreate: true,
        );
      }
      return;
    }

    if (IsmChatConstants.videoExtensions.contains(ext)) {
      final allowed = await IsmChatProperties
          .chatPageProperties.messageAllowedConfig
          .shouldAllowOutboundSend(
        context: context,
        conversation: _controller.conversation,
        customType: IsmChatCustomMessageType.video,
        messageText: messageText,
      );
      if (!allowed) {
        return;
      }
      final webMediaModel =
          await _controller.webMediaModelFromPlatformFile(file);
      if (webMediaModel == null) {
        return;
      }
      await _controller.sendVideo(
        conversationId: conversationId,
        userId: userId,
        webMediaModel: webMediaModel,
        skipConversationCreate: true,
      );
      return;
    }

    if (ext == 'pdf') {
      final allowed = await IsmChatProperties
          .chatPageProperties.messageAllowedConfig
          .shouldAllowOutboundSend(
        context: context,
        conversation: _controller.conversation,
        customType: IsmChatCustomMessageType.file,
        messageText: messageText,
      );
      if (!allowed) {
        return;
      }
      await _sendPickedDocumentFile(
        conversationId: conversationId,
        file: file,
      );
      return;
    }

    IsmChatUtility.showToast(IsmChatStrings.youCanNotSend);
  }

  /// Builds and uploads one picked PDF as a chat message.
  Future<void> _sendPickedDocumentFile({
    required String conversationId,
    required PlatformFile file,
  }) async {
    if (_pickedFileExtension(file) != 'pdf') {
      IsmChatLog.error(
        '_sendPickedDocumentFile called for non-PDF: ${file.name}',
      );
      return;
    }

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
      body: IsmChatStrings.document,
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
