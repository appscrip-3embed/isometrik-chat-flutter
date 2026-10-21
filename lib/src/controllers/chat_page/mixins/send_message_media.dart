part of '../chat_page_controller.dart';

/// Mixin for handling media message sending (images, videos) in the chat page controller.
///
/// This mixin provides functionality for sending media messages including images and videos.
/// It depends on:
/// - `createConversation()` from send_message_core mixin
/// - `sendMessage()` from send_message_core mixin
/// - `ismPostMediaUrl()` (defined in this mixin)
mixin IsmChatPageSendMessageMediaMixin {
  /// Gets the controller instance.
  IsmChatPageController get _controller => this as IsmChatPageController;

  /// Validates and sends media files (mobile).
  void sendMedia() async {
    if (_controller.isProcessingMedia || _controller.webMedia.isEmpty) {
      return;
    }
    var isMaxSize = false;
    for (var media in _controller.webMedia) {
      if (media.dataSize.split(' ').last == 'KB') {
        continue;
      }
      if (!media.dataSize.size()) {
        isMaxSize = true;
        break;
      }
    }
    if (isMaxSize == false) {
      IsmChatRoute.goBack<void>();
      sendPhotoAndVideo();
    } else {
      await IsmChatContextWidget.showDialogContext(
        content: IsmChatAlertDialogBox(
          title: IsmChatStrings.youCanNotSend,
          cancelLabel: IsmChatStrings.okay,
        ),
      );
    }
  }

  /// Validates and sends media files (web).
  void sendMediaWeb() async {
    if (_controller.isProcessingMedia || _controller.webMedia.isEmpty) {
      return;
    }
    var isMaxSize = false;
    _controller.showCloseLoaderForMoble();

    for (final x in _controller.webMedia) {
      if (!x.dataSize.size()) {
        isMaxSize = true;
        break;
      }
    }
    if (isMaxSize == false) {
      _controller.showCloseLoaderForMoble(showLoader: false);
      sendPhotoAndVideoForWeb();
    } else {
      IsmChatUtility.closeLoader();
      await IsmChatContextWidget.showDialogContext(
        content: IsmChatAlertDialogBox(
          title: IsmChatStrings.youCanNotSend,
          cancelLabel: IsmChatStrings.okay,
        ),
      );
    }
  }

  /// Sends photos and videos for web platform.
  void sendPhotoAndVideoForWeb() async {
    if (_controller.webMedia.isEmpty || _controller.isProcessingMedia) {
      return;
    }
    final mediaList = List<WebMediaModel>.from(_controller.webMedia);
    _controller.mediaProcessingGeneration++;
    _controller.isProcessingMedia = false;
    _controller.webMedia.clear();
    if (mediaList.isNotEmpty) {
      // Check if paid media handling is enabled and delegate
      Map<String, dynamic>? paidMediaMetaData;
      if (IsmChatProperties.chatPageProperties.enablePaidMediaHandling &&
          IsmChat.i.onPaidMediaSend != null) {
        final context =
            IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context;
        final result = await IsmChat.i.onPaidMediaSend!(
          context,
          _controller.conversation,
          mediaList,
        );
        if (result.handled) {
          _controller
            ..showCloseLoaderForMoble(showLoader: false)
            ..isCameraView = false;
          return;
        }
        paidMediaMetaData = result.metaData;
      }

      _controller.showCloseLoaderForMoble();

      await _sendMediaList(
        mediaList: mediaList,
        metaDataFromDelegate: paidMediaMetaData,
      );
      _controller
        ..showCloseLoaderForMoble(showLoader: false)
        ..isCameraView = false;
    }
  }

  /// Sends photos and videos for mobile platform.
  void sendPhotoAndVideo() async {
    if (_controller.webMedia.isEmpty || _controller.isProcessingMedia) {
      return;
    }
    final mediaList = List<WebMediaModel>.from(_controller.webMedia);
    _controller.mediaProcessingGeneration++;
    _controller.isProcessingMedia = false;
    _controller.webMedia.clear();
    if (mediaList.isNotEmpty) {
      // Check if paid media handling is enabled and delegate
      Map<String, dynamic>? paidMediaMetaData;
      if (IsmChatProperties.chatPageProperties.enablePaidMediaHandling &&
          IsmChat.i.onPaidMediaSend != null) {
        final context =
            IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context;
        final result = await IsmChat.i.onPaidMediaSend!(
          context,
          _controller.conversation,
          mediaList,
        );
        if (result.handled) {
          return;
        }
        paidMediaMetaData = result.metaData;
      }

      await _sendMediaList(
        mediaList: mediaList,
        metaDataFromDelegate: paidMediaMetaData,
      );
    }
  }

  /// Stages picked photos and videos, then uploads them.
  ///
  /// Web rule (`attachments.length === 1 ? customTypeFromMime : AttachmentMessage:Multiple`):
  /// two or more files are **one** message with `customType` `AttachmentMessage:Multiple`.
  /// Per-file type lives on each attachment (`mediaType` 0 image, 1 video). Do not split
  /// that batch into separate Image/Video messages — later changes should keep this helper.
  /// One file keeps Image, Video, or Gif. Replies stay one file per message because
  /// reply uses `AttachmentMessage:Reply`.
  Future<void> _sendMediaList({
    required List<WebMediaModel> mediaList,
    Map<String, dynamic>? metaDataFromDelegate,
  }) async {
    final conversationId = _controller.conversation?.conversationId ?? '';
    final userId = _controller.conversation?.opponentDetails?.userId ?? '';
    final resolvedConversationId = await _controller.createConversation(
      conversationId: conversationId,
      userId: userId,
    );

    if (mediaList.length > 1 && !_controller.isreplying) {
      await _sendMultipleMediaMessage(
        mediaList: mediaList,
        conversationId: resolvedConversationId,
        metaDataFromDelegate: metaDataFromDelegate,
      );
      return;
    }

    final batchSentAts = List.generate(
      mediaList.length,
      (_) => _controller.nextUniqueMediaSentAt(),
    );
    final batchMetaData = <String, dynamic>{
      ...?metaDataFromDelegate,
      'mediaBatchId': batchSentAts.first,
    };

    final pendingUploads = <Future<void> Function()>[];

    for (var i = 0; i < mediaList.length; i++) {
      final media = mediaList[i];
      final sentAt = batchSentAts[i];
      final mediaType = media.isVideo
          ? IsmChatCustomMessageType.video
          : IsmChatCustomMessageType.image;
      final isAllowed = await IsmChatProperties
          .chatPageProperties.messageAllowedConfig
          .shouldAllowOutboundSend(
        context:
            IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context,
        conversation: IsmChatUtility.chatPageController.conversation!,
        customType: mediaType,
        messageText: _controller.chatInputController.text.trim(),
      );
      if (!isAllowed) {
        continue;
      }

      if (media.isVideo) {
        await sendVideo(
          webMediaModel: media,
          conversationId: resolvedConversationId,
          userId: userId,
          metaDataFromDelegate: batchMetaData,
          preAssignedSentAt: sentAt,
          skipConversationCreate: true,
          deferUpload: true,
        );
        pendingUploads.add(
          () => _completeDeferredVideoUpload(
            sentAt: sentAt,
            webMediaModel: media,
            conversationId: resolvedConversationId,
          ),
        );
      } else if (_isGifExtension(media.platformFile.extension)) {
        await sendGif(
          conversationId: resolvedConversationId,
          userId: userId,
          webMediaModel: media,
          metaDataFromDelegate: batchMetaData,
          preAssignedSentAt: sentAt,
          skipConversationCreate: true,
          deferUpload: true,
        );
        pendingUploads.add(
          () => _completeDeferredVisualUpload(
            sentAt: sentAt,
            webMediaModel: media,
            notificationBody: IsmChatStrings.sentGif,
          ),
        );
      } else {
        await sendImage(
          conversationId: resolvedConversationId,
          userId: userId,
          webMediaModel: media,
          metaDataFromDelegate: batchMetaData,
          preAssignedSentAt: sentAt,
          skipConversationCreate: true,
          deferUpload: true,
        );
        pendingUploads.add(
          () => _completeDeferredImageUpload(
            sentAt: sentAt,
            webMediaModel: media,
          ),
        );
      }
    }

    _controller.isreplying = false;
    unawaited(_controller.scrollDown());

    _controller.activeBatchMediaUploads++;
    try {
      for (final upload in pendingUploads) {
        await upload();
      }
    } finally {
      _controller.activeBatchMediaUploads--;
      if (_controller.activeBatchMediaUploads < 0) {
        _controller.activeBatchMediaUploads = 0;
      }
      if (_controller.activeBatchMediaUploads == 0) {
        await _controller.getMessagesFromDB(resolvedConversationId);
      }
    }
  }

  /// One AttachmentMessage:Multiple for a photo/video/gif batch.
  ///
  /// Uploads each file with the same presign flow as ismPostMediaUrl, then
  /// calls sendMessage once. GIFs in the batch are images (mediaType 0);
  /// a single GIF still uses sendGif.
  Future<void> _sendMultipleMediaMessage({
    required List<WebMediaModel> mediaList,
    required String conversationId,
    Map<String, dynamic>? metaDataFromDelegate,
  }) async {
    final caption = _captionFromMediaList(mediaList);
    final isAllowed = await IsmChatProperties
        .chatPageProperties.messageAllowedConfig
        .shouldAllowOutboundSend(
      context:
          IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context,
      conversation: IsmChatUtility.chatPageController.conversation!,
      customType: IsmChatCustomMessageType.multipleAttachments,
      messageText: caption,
    );
    if (!isAllowed) {
      return;
    }

    final hadMediaCaption = mediaList.any(
      (media) => media.caption?.trim().isNotEmpty == true,
    );
    if (!hadMediaCaption && caption.isNotEmpty) {
      _controller.chatInputController.clear();
    }

    const multipleBody = 'AttachmentMessage:Multiple';
    final body = caption.isNotEmpty ? caption.trim() : multipleBody;
    final sentAt = _controller.nextUniqueMediaSentAt();
    final localAttachments = <AttachmentModel>[];
    for (var i = 0; i < mediaList.length; i++) {
      localAttachments.add(
        await _localAttachmentForPickedMedia(
          media: mediaList[i],
          sentAt: sentAt,
          index: i,
        ),
      );
    }

    final mediaMessage = IsmChatMessageModel(
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
        caption: IsmChatUtility.outboundAttachmentCaptionMeta(caption),
        customMetaData: metaDataFromDelegate,
      ),
    );

    _controller.messages.add(mediaMessage);
    unawaited(_controller.scrollDown());

    if (!_controller.isBroadcast) {
      await IsmChatConfig.dbWrapper!
          .saveMessage(mediaMessage, IsmChatDbBox.pending);
      if (kIsWeb &&
          IsmChatResponsive.isWeb(IsmChatConfig.kNavigatorKey.currentContext ??
              IsmChatConfig.context)) {
        _controller.updateLastMessagOnCurrentTime(mediaMessage);
      }
    }

    final notificationTitle =
        IsmChatConfig.communicationConfig.userConfig.userName ??
            _controller.conversationController.userDetails?.userName ??
            '';
    final outgoingAttachments = <Map<String, dynamic>>[];
    for (var i = 0; i < mediaList.length; i++) {
      final map = await _uploadPickedMediaAttachment(
        conversationId: conversationId,
        media: mediaList[i],
        local: localAttachments[i],
      );
      if (map == null) {
        _markUploadFailed(sentAt);
        return;
      }
      outgoingAttachments.add(map);
      _replaceMultipleAttachment(
        sentAt: sentAt,
        index: i,
        attachment: _attachmentFromOutgoingMap(
          map,
          fallback: localAttachments[i],
        ),
      );
    }

    await _controller.sendMessage(
      body: body,
      conversationId: conversationId,
      createdAt: sentAt,
      deviceId: mediaMessage.deviceId ?? '',
      messageType: mediaMessage.messageType?.value ?? 0,
      notificationBody: IsmChatStrings.sentImage,
      notificationTitle: notificationTitle,
      attachments: outgoingAttachments,
      customType: IsmChatCustomMessageType.multipleAttachments.value,
      metaData: mediaMessage.metaData,
      isBroadcast: _controller.isBroadcast,
    );
    _clearMessageUploadingState(sentAt);
  }

  /// First preview caption, otherwise text still in the composer.
  String _captionFromMediaList(List<WebMediaModel> mediaList) {
    for (final media in mediaList) {
      final resolved = IsmChatUtility.resolveOutboundMediaCaption(
        mediaCaption: media.caption,
      );
      if (resolved.isNotEmpty) {
        return resolved;
      }
    }
    return IsmChatUtility.resolveOutboundMediaCaption(
      composerText: _controller.chatInputController.text,
    );
  }

  void _clearComposerIfUsedAsMediaCaption({
    required String resolvedCaption,
    String? mediaCaption,
  }) {
    final hadMediaCaption = mediaCaption?.trim().isNotEmpty == true;
    if (!hadMediaCaption && resolvedCaption.isNotEmpty) {
      _controller.chatInputController.clear();
    }
  }

  /// Local row shown in the grid while this file is still uploading.
  ///
  /// GIFs picked with other files use image (mediaType 0). customType on
  /// the message stays AttachmentMessage:Multiple.
  Future<AttachmentModel> _localAttachmentForPickedMedia({
    required WebMediaModel media,
    required int sentAt,
    required int index,
  }) async {
    final extension = media.platformFile.extension;
    final mediaType =
        media.isVideo ? IsmChatMediaType.video : IsmChatMediaType.image;
    final bytes = media.platformFile.bytes ?? Uint8List(0);
    final name = media.platformFile.name ?? 'media_$index';
    final mediaId = '${sentAt}_$index';
    final localPath = media.isVideo
        ? (kIsWeb ? bytes.toString() : (media.platformFile.path ?? ''))
        : await _resolveLocalMediaPath(
            webMediaModel: media,
            bytes: bytes,
            nameWithExtension: name,
          );
    final thumbnailBytes = media.platformFile.thumbnailBytes;
    final thumbnailUrl =
        media.isVideo && thumbnailBytes != null && thumbnailBytes.isNotEmpty
            ? thumbnailBytes.toString()
            : localPath;

    return AttachmentModel(
      attachmentType: mediaType,
      thumbnailUrl: thumbnailUrl,
      size: media.platformFile.size,
      name: name,
      mimeType: mimeTypeForAttachmentExtension(
        extension,
        mediaType: mediaType,
      ),
      mediaUrl: localPath,
      mediaId: mediaId,
      bytes: bytes,
      extension: extension,
    );
  }

  /// Presign + upload for one file in a multi-attachment message.
  ///
  /// Same steps as ismPostMediaUrl (presigned URL, then the file bytes, then
  /// a video thumbnail). Does not call sendMessage.
  Future<Map<String, dynamic>?> _uploadPickedMediaAttachment({
    required String conversationId,
    required WebMediaModel media,
    required AttachmentModel local,
  }) async {
    try {
      final bytes = await _bytesForOutgoingMedia(media);
      if (bytes.isEmpty) {
        return null;
      }
      final mediaType = local.attachmentType ?? IsmChatMediaType.image;
      final nameWithExtension = local.name ?? '';
      final mediaId = local.mediaId ?? '';
      final needsThumbnail = mediaType == IsmChatMediaType.video;

      PresignedUrlModel? presignedUrlModel;
      if (_controller.isBroadcast) {
        presignedUrlModel = await _controller.commonController.getPresignedUrl(
          isLoading: false,
          mediaExtension: local.extension ?? '',
          userIdentifier:
              IsmChatConfig.communicationConfig.userConfig.userEmail ?? '',
          bytes: bytes,
        );
      } else {
        presignedUrlModel = await _controller.commonController.postMediaUrl(
          conversationId: conversationId,
          nameWithExtension: nameWithExtension,
          mediaType: mediaType.value,
          mediaId: mediaId,
          bytes: bytes,
          isLoading: false,
        );
      }

      final mediaUrlPath = presignedUrlModel?.mediaUrl ?? '';
      final resolvedMediaId =
          _controller.isBroadcast ? mediaId : presignedUrlModel?.mediaId ?? '';
      if (mediaUrlPath.isEmpty) {
        return null;
      }

      var thumbnailUrlPath = mediaUrlPath;
      if (needsThumbnail) {
        final thumbnailBytes =
            media.platformFile.thumbnailBytes ?? Uint8List(0);
        PresignedUrlModel? thumbPresigned;
        if (_controller.isBroadcast) {
          thumbPresigned = await _controller.commonController.getPresignedUrl(
            isLoading: false,
            mediaExtension: 'png',
            userIdentifier:
                IsmChatConfig.communicationConfig.userConfig.userEmail ?? '',
            bytes: thumbnailBytes,
          );
          thumbnailUrlPath = thumbPresigned?.mediaUrl ?? mediaUrlPath;
        } else {
          thumbPresigned = await _controller.commonController.postMediaUrl(
            conversationId: conversationId,
            nameWithExtension: '$mediaId.png',
            mediaType: IsmChatMediaType.image.value,
            mediaId: mediaId,
            bytes: thumbnailBytes,
            isLoading: false,
            isUpdateThumbnail: true,
          );
          thumbnailUrlPath = thumbPresigned?.thumbnailUrl ?? '';
          if (thumbnailUrlPath.isEmpty) {
            thumbnailUrlPath = mediaUrlPath;
          }
        }
      }

      return AttachmentModel(
        thumbnailUrl: thumbnailUrlPath,
        size: local.size,
        name: local.name,
        mimeType: local.mimeType,
        mediaUrl: mediaUrlPath,
        mediaId: resolvedMediaId,
        extension: local.extension,
        attachmentType: mediaType,
        stillUrl: thumbnailUrlPath,
      ).toOutgoingMap();
    } catch (e, st) {
      IsmChatLog.error(e, st);
      return null;
    }
  }

  /// Keeps local preview fields when the upload map omits them.
  AttachmentModel _attachmentFromOutgoingMap(
    Map<String, dynamic> map, {
    required AttachmentModel fallback,
  }) {
    final parsed = AttachmentModel.fromMap(map);
    return parsed.copyWith(
      bytes: fallback.bytes,
      mimeType: (parsed.mimeType?.isNotEmpty == true)
          ? parsed.mimeType
          : fallback.mimeType,
      extension: (parsed.extension?.isNotEmpty == true)
          ? parsed.extension
          : fallback.extension,
      name: (parsed.name?.isNotEmpty == true) ? parsed.name : fallback.name,
      attachmentType: parsed.attachmentType ?? fallback.attachmentType,
    );
  }

  void _replaceMultipleAttachment({
    required int sentAt,
    required int index,
    required AttachmentModel attachment,
  }) {
    final messageIndex = _controller.messages.indexWhere(
      (message) => message.sentAt == sentAt,
    );
    if (messageIndex == -1) {
      return;
    }
    final current = _controller.messages[messageIndex];
    final list = List<AttachmentModel>.from(current.attachments ?? const []);
    if (index < 0 || index >= list.length) {
      return;
    }
    list[index] = attachment;
    current.attachments = list;
    _controller.messages[messageIndex] = current;
    if (_controller.messages is RxList<IsmChatMessageModel>) {
      (_controller.messages as RxList<IsmChatMessageModel>).refresh();
    }
    _controller.update();
  }

  /// Sends a video message.
  ///
  /// [conversationId] - ID of the conversation
  /// [userId] - ID of the user
  /// [webMediaModel] - Web media model containing video data
  ///
  /// Note: This method requires `createConversation` and `ismPostMediaUrl`
  /// to be available through other mixins on the controller.
  Future<void> sendVideo({
    required String conversationId,
    required String userId,
    required WebMediaModel webMediaModel,
    Map<String, dynamic>? metaDataFromDelegate,
    int? preAssignedSentAt,
    bool skipConversationCreate = false,
    bool deferUpload = false,
  }) async {
    if (!skipConversationCreate) {
      conversationId = await _controller.createConversation(
        conversationId: conversationId,
        userId: userId,
      );
    }
    final sentAt = preAssignedSentAt ?? _controller.nextUniqueMediaSentAt();
    final thumbnailBytes = webMediaModel.platformFile.thumbnailBytes;
    final nameWithExtension = webMediaModel.platformFile.name;
    final mediaId = '$sentAt';
    final extension = webMediaModel.platformFile.extension;
    final localPath = webMediaModel.platformFile.path ?? '';
    final caption = IsmChatUtility.resolveOutboundMediaCaption(
      mediaCaption: webMediaModel.caption,
      composerText: _controller.chatInputController.text,
    );
    _clearComposerIfUsedAsMediaCaption(
      resolvedCaption: caption,
      mediaCaption: webMediaModel.caption,
    );
    final body = IsmChatUtility.outboundAttachmentBody(caption);

    final videoMessage = IsmChatMessageModel(
      body: body,
      conversationId: conversationId,
      senderInfo: _controller.currentUser,
      customType: _controller.isreplying
          ? IsmChatCustomMessageType.reply
          : IsmChatCustomMessageType.video,
      attachments: [
        AttachmentModel(
          attachmentType: IsmChatMediaType.video,
          thumbnailUrl: thumbnailBytes.toString(),
          size: webMediaModel.platformFile.size ?? 0,
          name: nameWithExtension,
          mimeType: extension,
          mediaUrl:
              kIsWeb ? webMediaModel.platformFile.bytes.toString() : localPath,
          mediaId: mediaId,
          extension: extension,
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
        caption: IsmChatUtility.outboundAttachmentCaptionMeta(caption),
        customMetaData: metaDataFromDelegate,
        replyMessage: _controller.isreplying
            ? IsmChatReplyMessageModel(
                forMessageType: IsmChatCustomMessageType.video,
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

    _controller.messages.add(videoMessage);
    if (!deferUpload) {
      unawaited(_controller.scrollDown());
      _controller.isreplying = false;
    }

    if (!_controller.isBroadcast) {
      await IsmChatConfig.dbWrapper!
          .saveMessage(videoMessage, IsmChatDbBox.pending);

      if (kIsWeb &&
          IsmChatResponsive.isWeb(IsmChatConfig.kNavigatorKey.currentContext ??
              IsmChatConfig.context)) {
        _controller.updateLastMessagOnCurrentTime(videoMessage);
      }
    }

    if (deferUpload) {
      return;
    }

    await _completeDeferredVideoUpload(
      sentAt: sentAt,
      webMediaModel: webMediaModel,
      conversationId: conversationId,
    );
  }

  Future<void> _completeDeferredVideoUpload({
    required int sentAt,
    required WebMediaModel webMediaModel,
    required String conversationId,
  }) async {
    final bytes = await _bytesForOutgoingMedia(webMediaModel);

    final index = _controller.messages.indexWhere(
      (message) => message.sentAt == sentAt,
    );
    if (index == -1) {
      return;
    }
    final videoMessage = _controller.messages[index];
    final thumbnailBytes = webMediaModel.platformFile.thumbnailBytes;
    final thumbnailNameWithExtension = '$sentAt.png';
    final thumbnailMediaId = '$sentAt';
    final nameWithExtension = webMediaModel.platformFile.name;
    final mediaId = '$sentAt';

    final notificationTitle =
        IsmChatConfig.communicationConfig.userConfig.userName ??
            _controller.conversationController.userDetails?.userName ??
            '';
    await _controller.ismPostMediaUrl(
      imageAndFile: false,
      bytes: bytes,
      createdAt: sentAt,
      ismChatChatMessageModel: videoMessage,
      mediaId: mediaId,
      mediaType: IsmChatMediaType.video.value,
      nameWithExtension: nameWithExtension ?? '',
      notificationBody: IsmChatStrings.video,
      thumbnailNameWithExtension: thumbnailNameWithExtension,
      thumbnailMediaId: thumbnailMediaId,
      thumbnailBytes: thumbnailBytes,
      thumbanilMediaType: IsmChatMediaType.image.value,
      notificationTitle: notificationTitle,
    );
  }

  /// Sends an image message.
  ///
  /// [conversationId] - ID of the conversation
  /// [userId] - ID of the user
  /// [webMediaModel] - Web media model containing image data
  ///
  /// Note: This method requires `createConversation` and `ismPostMediaUrl`
  /// to be available through other mixins on the controller.
  Future<void> sendImage({
    required String conversationId,
    required String userId,
    required WebMediaModel webMediaModel,
    Map<String, dynamic>? metaDataFromDelegate,
    int? preAssignedSentAt,
    bool skipConversationCreate = false,
    bool deferUpload = false,
  }) async {
    if (!skipConversationCreate) {
      conversationId = await _controller.createConversation(
          conversationId: conversationId, userId: userId);
    }
    final sentAt = preAssignedSentAt ?? _controller.nextUniqueMediaSentAt();
    final nameWithExtension = webMediaModel.platformFile.name;
    final mediaId = sentAt.toString();
    final extension = webMediaModel.platformFile.extension;
    final caption = IsmChatUtility.resolveOutboundMediaCaption(
      mediaCaption: webMediaModel.caption,
      composerText: _controller.chatInputController.text,
    );
    _clearComposerIfUsedAsMediaCaption(
      resolvedCaption: caption,
      mediaCaption: webMediaModel.caption,
    );
    final body = IsmChatUtility.outboundAttachmentBody(caption);
    final imageMessage = IsmChatMessageModel(
      body: body,
      conversationId: conversationId,
      senderInfo: _controller.currentUser,
      customType: _controller.isreplying
          ? IsmChatCustomMessageType.reply
          : IsmChatCustomMessageType.image,
      attachments: [
        AttachmentModel(
          attachmentType: IsmChatMediaType.image,
          thumbnailUrl: webMediaModel.platformFile.path,
          size: webMediaModel.platformFile.size,
          name: nameWithExtension,
          mimeType: extension,
          mediaUrl: webMediaModel.platformFile.path,
          mediaId: mediaId,
          bytes: webMediaModel.platformFile.bytes,
          extension: extension,
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
        caption: IsmChatUtility.outboundAttachmentCaptionMeta(caption),
        customMetaData: metaDataFromDelegate,
        replyMessage: _controller.isreplying
            ? IsmChatReplyMessageModel(
                forMessageType: IsmChatCustomMessageType.image,
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

    _controller.messages.add(imageMessage);
    if (!deferUpload) {
      unawaited(_controller.scrollDown());
      _controller.isreplying = false;
    }

    if (!_controller.isBroadcast) {
      await IsmChatConfig.dbWrapper!
          .saveMessage(imageMessage, IsmChatDbBox.pending);

      if (kIsWeb &&
          IsmChatResponsive.isWeb(IsmChatConfig.kNavigatorKey.currentContext ??
              IsmChatConfig.context)) {
        _controller.updateLastMessagOnCurrentTime(imageMessage);
      }
    }

    if (deferUpload) {
      return;
    }

    await _completeDeferredImageUpload(
      sentAt: sentAt,
      webMediaModel: webMediaModel,
    );
  }

  Future<void> _completeDeferredImageUpload({
    required int sentAt,
    required WebMediaModel webMediaModel,
  }) async {
    final index = _controller.messages.indexWhere(
      (message) => message.sentAt == sentAt,
    );
    if (index == -1) {
      return;
    }
    final imageMessage = _controller.messages[index];
    final bytes = webMediaModel.platformFile.bytes;
    final nameWithExtension = webMediaModel.platformFile.name;
    final mediaId = sentAt.toString();
    final notificationTitle =
        IsmChatConfig.communicationConfig.userConfig.userName ??
            _controller.conversationController.userDetails?.userName ??
            '';
    await _controller.ismPostMediaUrl(
      bytes: bytes ?? Uint8List(0),
      createdAt: sentAt,
      ismChatChatMessageModel: imageMessage,
      mediaId: mediaId,
      mediaType: IsmChatMediaType.image.value,
      nameWithExtension: nameWithExtension ?? '',
      notificationBody: IsmChatStrings.sentImage,
      imageAndFile: true,
      notificationTitle: notificationTitle,
    );
  }

  /// Sends a message with a remote media URL (image, GIF, sticker).
  ///
  /// Pass [mediaWidth]/[mediaHeight] when known (e.g. Giphy) so the chat
  /// bubble can reserve the correct aspect ratio before the GIF finishes
  /// decoding — avoids expand-then-shrink on Android.
  Future<void> sendMessageWithMediaUrl({
    required String conversationId,
    required String userId,
    required String mediaUrl,
    required IsmChatMediaType mediaType,
    required String body,
    required String notificationBody,
    required String nameWithExtension,
    required String mediaId,
    String? caption,
    String? extension,
    String? stillUrl,
    int? size,
    int? mediaWidth,
    int? mediaHeight,
    bool sendPushNotification = true,
    List<String>? searchableTags,
  }) async {
    final chatConversationResponse =
        await IsmChatConfig.dbWrapper!.getConversation(conversationId);
    if (chatConversationResponse == null && !_controller.isBroadcast) {
      _controller.conversation =
          await _controller.commonController.createConversation(
        conversation: _controller.conversation!,
        userId: [userId],
        metaData: _controller.conversation?.metaData,
        searchableTags: [
          IsmChatConfig.communicationConfig.userConfig.userName ??
              _controller.conversationController.userDetails?.userName ??
              '',
          _controller.conversation?.chatName ?? ''
        ],
      );
      conversationId = _controller.conversation?.conversationId ?? '';
      unawaited(
        _controller.getConverstaionDetails(),
      );
    }

    final sentAt = DateTime.now().millisecondsSinceEpoch;
    final resolvedExtension = extension ??
        (nameWithExtension.contains('.')
            ? nameWithExtension.split('.').last
            : 'gif');
    final wireBody = IsmChatUtility.outboundAttachmentBody(caption);
    final mediaMessage = IsmChatMessageModel(
      body: wireBody,
      conversationId: conversationId,
      senderInfo: _controller.currentUser,
      customType: _controller.isreplying
          ? IsmChatCustomMessageType.reply
          : IsmChatCustomMessageType.image,
      attachments: [
        AttachmentModel(
          attachmentType: mediaType,
          thumbnailUrl: mediaUrl,
          size: size ?? 0,
          name: nameWithExtension,
          mimeType: resolvedExtension,
          mediaUrl: mediaUrl,
          mediaId: mediaId,
          extension: resolvedExtension,
          stillUrl: stillUrl ?? mediaUrl,
          mediaWidth: mediaWidth,
          mediaHeight: mediaHeight,
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
      isUploading: false,
      metaData: IsmChatMetaData(
        messageSentAt: sentAt,
        isDownloaded: true,
        caption: IsmChatUtility.outboundAttachmentCaptionMeta(caption),
        replyMessage: _controller.isreplying
            ? IsmChatReplyMessageModel(
                forMessageType: IsmChatCustomMessageType.image,
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

    _controller.messages.add(mediaMessage);
    unawaited(_controller.scrollDown());
    _controller.isreplying = false;
    if (!_controller.isBroadcast) {
      await IsmChatConfig.dbWrapper!
          .saveMessage(mediaMessage, IsmChatDbBox.pending);

      if (kIsWeb &&
          IsmChatResponsive.isWeb(IsmChatConfig.kNavigatorKey.currentContext ??
              IsmChatConfig.context)) {
        _controller.updateLastMessagOnCurrentTime(mediaMessage);
      }
    }

    final notificationTitle =
        IsmChatConfig.communicationConfig.userConfig.userName ??
            _controller.conversationController.userDetails?.userName ??
            '';
    final attachment =
        mediaMessage.attachments?.first.toOutgoingMap() ?? <String, dynamic>{};

    await _controller.sendMessage(
      metaData: mediaMessage.metaData,
      deviceId: mediaMessage.deviceId ?? '',
      body: wireBody,
      customType: _resolveOutgoingCustomType(mediaMessage),
      createdAt: mediaMessage.sentAt,
      conversationId: mediaMessage.conversationId ?? '',
      messageType: mediaMessage.messageType?.value ?? 0,
      notificationBody: notificationBody,
      notificationTitle: notificationTitle,
      attachments: [attachment],
      isBroadcast: _controller.isBroadcast,
      parentMessageId: mediaMessage.parentMessageId,
      sendPushNotification: sendPushNotification,
      searchableTags: searchableTags ??
          _gifStickerSearchableTags(mediaType, nameWithExtension),
    );
  }

  /// Sends a message with an image URL.
  ///
  /// [conversationId] - ID of the conversation
  /// [userId] - ID of the user
  /// [imageUrl] - URL of the image to send
  /// [caption] - Optional caption for the image
  /// [sendPushNotification] - Whether to send push notification
  ///
  /// Note: This method requires `sendMessage` to be available through
  /// send_message_core mixin on the controller.
  Future<void> sendMessageWithImageUrl({
    required String conversationId,
    required String userId,
    required String imageUrl,
    String? caption,
    bool sendPushNotification = false,
  }) async {
    final nameWithExtension = imageUrl.split('/').last;
    var mediaId = nameWithExtension.replaceAll(RegExp(r'[^0-9]'), '');
    if (mediaId.isEmpty) {
      mediaId = DateTime.now().millisecondsSinceEpoch.toString();
    }
    final extension = nameWithExtension.split('.').last;
    int? size;
    try {
      final bytes = await IsmChatUtility.getUint8ListFromUrl(imageUrl);
      size = bytes.length;
    } catch (_) {
      size = 0;
    }

    await sendMessageWithMediaUrl(
      conversationId: conversationId,
      userId: userId,
      mediaUrl: imageUrl,
      mediaType: IsmChatMediaType.image,
      body: IsmChatUtility.outboundAttachmentBody(caption),
      notificationBody: IsmChatStrings.sentImage,
      nameWithExtension: nameWithExtension,
      mediaId: mediaId,
      caption: caption,
      extension: extension,
      size: size,
      sendPushNotification: sendPushNotification,
    );
  }

  /// Posts media URL to the server and sends the message.
  ///
  /// This method handles uploading media files and sending the message with
  /// the uploaded media URL. It supports both regular conversations and broadcasts.
  ///
  /// Note: This method requires `sendMessage` to be available through
  /// send_message_core mixin on the controller.
  Future<void> ismPostMediaUrl({
    required IsmChatMessageModel ismChatChatMessageModel,
    required String notificationBody,
    required String notificationTitle,
    required String nameWithExtension,
    required int createdAt,
    required int mediaType,
    required Uint8List bytes,
    required bool? imageAndFile,
    required String mediaId,
    String? thumbnailNameWithExtension,
    String? thumbnailMediaId,
    int? thumbanilMediaType,
    Uint8List? thumbnailBytes,
    bool isLoading = false,
  }) async {
    try {
      PresignedUrlModel? presignedUrlModel;
      if (_controller.isBroadcast) {
        presignedUrlModel = await _controller.commonController.getPresignedUrl(
          isLoading: isLoading,
          mediaExtension:
              ismChatChatMessageModel.attachments?.first.extension ?? '',
          userIdentifier:
              IsmChatConfig.communicationConfig.userConfig.userEmail ?? '',
          bytes: bytes,
        );
      } else {
        presignedUrlModel = await _controller.commonController.postMediaUrl(
          conversationId: ismChatChatMessageModel.conversationId ?? '',
          nameWithExtension: nameWithExtension,
          mediaType: mediaType,
          mediaId: mediaId,
          bytes: bytes,
          isLoading: isLoading,
        );
      }
      var mediaUrlPath = '';
      var thumbnailUrlPath = '';
      mediaUrlPath = presignedUrlModel?.mediaUrl ?? '';
      mediaId =
          _controller.isBroadcast ? mediaId : presignedUrlModel?.mediaId ?? '';
      if (!(imageAndFile ?? false)) {
        PresignedUrlModel? presignedUrlModel;
        if (_controller.isBroadcast) {
          presignedUrlModel =
              await _controller.commonController.getPresignedUrl(
            isLoading: isLoading,
            mediaExtension: thumbnailNameWithExtension?.split('.').last ?? '',
            userIdentifier:
                IsmChatConfig.communicationConfig.userConfig.userEmail ?? '',
            // Thumbnail upload must use the thumbnail bytes, not the original file bytes.
            bytes: thumbnailBytes ?? Uint8List(0),
          );
        } else {
          presignedUrlModel = await _controller.commonController.postMediaUrl(
            conversationId: ismChatChatMessageModel.conversationId ?? '',
            nameWithExtension: thumbnailNameWithExtension ?? '',
            mediaType: thumbanilMediaType ?? 0,
            mediaId: thumbnailMediaId ?? '',
            isLoading: isLoading,
            bytes: thumbnailBytes ?? Uint8List(0),
            isUpdateThumbnail: true,
          );
        }
        thumbnailUrlPath = _controller.isBroadcast
            ? presignedUrlModel?.mediaUrl ?? ''
            : presignedUrlModel?.thumbnailUrl ?? '';
      }
      if (mediaUrlPath.isNotEmpty) {
        _updateUploadingMessageMediaUrl(
          createdAt: createdAt,
          mediaUrl: mediaUrlPath,
          thumbnailUrl:
              !(imageAndFile ?? false) ? thumbnailUrlPath : mediaUrlPath,
        );
        final uploadedAttachment = AttachmentModel(
          thumbnailUrl:
              !(imageAndFile ?? false) ? thumbnailUrlPath : mediaUrlPath,
          size: ismChatChatMessageModel.attachments?.first.size ?? 0,
          name: ismChatChatMessageModel.attachments?.first.name,
          mimeType: ismChatChatMessageModel.attachments?.first.mimeType,
          mediaUrl: mediaUrlPath,
          mediaId: mediaId,
          extension: ismChatChatMessageModel.attachments?.first.extension,
          attachmentType:
              ismChatChatMessageModel.attachments?.first.attachmentType,
          stillUrl: mediaUrlPath,
        );
        final attachment = <Map<String, dynamic>>[
          uploadedAttachment.toOutgoingMap(),
        ];

        final attachmentType = uploadedAttachment.attachmentType;
        final attachmentName = uploadedAttachment.name ?? '';

        // Note: sendMessage is provided by send_message_core mixin
        await _controller.sendMessage(
          body: ismChatChatMessageModel.body,
          conversationId: ismChatChatMessageModel.conversationId ?? '',
          createdAt: createdAt,
          deviceId: ismChatChatMessageModel.deviceId ?? '',
          messageType: ismChatChatMessageModel.messageType?.value ?? 0,
          notificationBody: notificationBody,
          notificationTitle: notificationTitle,
          attachments: attachment,
          customType: _resolveOutgoingCustomType(ismChatChatMessageModel),
          metaData: ismChatChatMessageModel.metaData,
          isBroadcast: _controller.isBroadcast,
          parentMessageId: ismChatChatMessageModel.parentMessageId,
          searchableTags: _gifStickerSearchableTags(
            attachmentType,
            attachmentName,
          ),
        );
        _clearMessageUploadingState(createdAt);
      } else {
        IsmChatLog.error(
          'ismPostMediaUrl: presigned upload failed — sendMessage skipped. '
          'presignedMediaType=$mediaType '
          'attachmentType=${ismChatChatMessageModel.attachments?.first.attachmentType?.value}',
        );
        _markUploadFailed(createdAt);
      }
    } catch (e, st) {
      IsmChatLog.error(e, st);
      _markUploadFailed(createdAt);
    }
  }

  void _updateUploadingMessageMediaUrl({
    required int createdAt,
    required String mediaUrl,
    required String thumbnailUrl,
  }) {
    final index = _controller.messages.indexWhere(
      (message) =>
          message.sentAt == createdAt && message.messageId?.isEmpty == true,
    );
    if (index == -1) {
      return;
    }
    final current = _controller.messages[index];
    final attachment = current.attachments?.firstOrNull;
    if (attachment == null) {
      return;
    }
    current.attachments = [
      attachment.copyWith(
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : mediaUrl,
        stillUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : mediaUrl,
      ),
    ];
    current.isUploading = false;
    _controller.messages[index] = current;
    if (_controller.messages is RxList<IsmChatMessageModel>) {
      (_controller.messages as RxList<IsmChatMessageModel>).refresh();
    }
    _controller.update();
  }

  void _clearMessageUploadingState(int createdAt) {
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

  bool _isGifExtension(String? extension) => extension?.toLowerCase() == 'gif';

  Future<String> _resolveLocalMediaPath({
    required WebMediaModel webMediaModel,
    required Uint8List bytes,
    required String nameWithExtension,
  }) async {
    final existingPath = webMediaModel.platformFile.path ?? '';
    if (existingPath.isNotEmpty) {
      return existingPath;
    }
    if (bytes.isEmpty) {
      return '';
    }
    if (kIsWeb) {
      return bytes.toString();
    }
    try {
      final dir = await getTemporaryDirectory();
      final safeName =
          nameWithExtension.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e, st) {
      IsmChatLog.error(e, st);
      return '';
    }
  }

  List<String>? _gifStickerSearchableTags(
    IsmChatMediaType? mediaType,
    String name,
  ) {
    if (mediaType == IsmChatMediaType.gif) {
      return ['/@gif', name];
    }
    if (mediaType == IsmChatMediaType.sticker) {
      return ['/@sticker', name];
    }
    return null;
  }

  String _resolveOutgoingCustomType(IsmChatMessageModel message) {
    if (message.messageType == IsmChatMessageType.reply) {
      return IsmChatCustomMessageType.reply.value;
    }
    final attachmentType = message.attachments?.firstOrNull?.attachmentType;
    if (attachmentType == IsmChatMediaType.gif ||
        attachmentType == IsmChatMediaType.sticker) {
      return attachmentType!.attachmentMessageCustomType;
    }
    return message.customType?.value ?? '';
  }

  /// Sends a GIF picked from gallery or another local source.
  Future<void> sendGif({
    required String conversationId,
    required String userId,
    required WebMediaModel webMediaModel,
    Map<String, dynamic>? metaDataFromDelegate,
    int? preAssignedSentAt,
    bool skipConversationCreate = false,
    bool deferUpload = false,
  }) =>
      _sendVisualAttachment(
        conversationId: conversationId,
        userId: userId,
        webMediaModel: webMediaModel,
        mediaType: IsmChatMediaType.gif,
        notificationBody: IsmChatStrings.sentGif,
        metaDataFromDelegate: metaDataFromDelegate,
        preAssignedSentAt: preAssignedSentAt,
        skipConversationCreate: skipConversationCreate,
        deferUpload: deferUpload,
      );

  /// Handles GIFs / images inserted from the soft keyboard (Gboard, OEM GIF
  /// tray, etc.) via Android's commitContent / IME rich-content API.
  ///
  /// Reuse this from any composer [TextField]/[TextFormField] by wiring
  /// [ContentInsertionConfiguration.onContentInserted] to this method. Without
  /// that configuration Android shows "This app does not support GIFs here".
  Future<void> sendKeyboardInsertedContent(
    KeyboardInsertedContent content,
  ) async {
    if (!(_controller.conversation?.isChattingAllowed == true)) {
      _controller.showDialogCheckBlockUnBlock();
      return;
    }

    final chatContext =
        IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context;
    if (!(await IsmChatProperties.chatPageProperties.isSendMediaAllowed
            ?.call(chatContext, _controller.conversation) ??
        true)) {
      return;
    }

    final bytes = content.data;
    if (bytes == null || bytes.isEmpty) {
      IsmChatLog.error(
        'Keyboard inserted content had no bytes '
        '(mimeType=${content.mimeType}, uri=${content.uri})',
      );
      IsmChatUtility.showToast('Unable to send media');
      return;
    }

    final extension = _extensionFromMimeType(content.mimeType);
    final isGif = _isGifExtension(extension);
    // Resolve context again after awaits — navigator key may have changed.
    // Reuse shouldAllowOutboundSend so onBeforeSendMessage (not only legacy
    // isMessgeAllowed) gates keyboard-inserted images/GIFs too.
    final allowedContext =
        IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context;
    final allowed = await IsmChatProperties
        .chatPageProperties.messageAllowedConfig
        .shouldAllowOutboundSend(
      context: allowedContext,
      conversation: _controller.conversation,
      customType: IsmChatCustomMessageType.image,
      messageText: '',
    );
    if (!allowed) {
      return;
    }

    final dataSize = IsmChatUtility.formatBytes(bytes.length);
    if (!dataSize.size()) {
      await IsmChatContextWidget.showDialogContext(
        content: IsmChatAlertDialogBox(
          title: IsmChatStrings.youCanNotSend,
          cancelLabel: IsmChatStrings.okay,
        ),
      );
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nameWithExtension = 'keyboard_$timestamp.$extension';
    final webMediaModel = WebMediaModel(
      isVideo: false,
      dataSize: dataSize,
      platformFile: IsmchPlatformFile(
        name: nameWithExtension,
        size: bytes.length,
        bytes: bytes,
        extension: extension,
      ),
    );

    try {
      final conversationId = _controller.conversation?.conversationId ?? '';
      final userId = _controller.conversation?.opponentDetails?.userId ?? '';
      if (isGif) {
        await sendGif(
          conversationId: conversationId,
          userId: userId,
          webMediaModel: webMediaModel,
        );
      } else {
        await sendImage(
          conversationId: conversationId,
          userId: userId,
          webMediaModel: webMediaModel,
        );
      }
    } catch (e, st) {
      IsmChatLog.error(e, st);
      IsmChatUtility.showToast('Unable to send media');
    }
  }

  /// Maps common keyboard MIME types to a file extension.
  /// Keep in sync with [kDefaultContentInsertionMimeTypes] plus image/webp.
  String _extensionFromMimeType(String mimeType) {
    final normalized = mimeType.toLowerCase().trim();
    switch (normalized) {
      case 'image/gif':
        return 'gif';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      default:
        // Fall back to subtype when present (e.g. image/heic -> heic).
        final slash = normalized.indexOf('/');
        if (slash != -1 && slash < normalized.length - 1) {
          return normalized.substring(slash + 1);
        }
        return 'png';
    }
  }

  /// Sends a sticker picked from Giphy or another source.
  Future<void> sendSticker({
    required String conversationId,
    required String userId,
    required WebMediaModel webMediaModel,
    Map<String, dynamic>? metaDataFromDelegate,
  }) =>
      _sendVisualAttachment(
        conversationId: conversationId,
        userId: userId,
        webMediaModel: webMediaModel,
        mediaType: IsmChatMediaType.sticker,
        notificationBody: IsmChatStrings.sentSticker,
        metaDataFromDelegate: metaDataFromDelegate,
      );

  /// Sends a Giphy GIF or sticker using its CDN URL (GifSticker API schema).
  Future<void> sendGiphyItem(
    IsmGiphyItem item, {
    required bool isSticker,
  }) async {
    if (!(_controller.conversation?.isChattingAllowed == true)) {
      _controller.showDialogCheckBlockUnBlock();
      return;
    }
    final allowed = await IsmChatProperties
        .chatPageProperties.messageAllowedConfig
        .shouldAllowOutboundSend(
      context:
          IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context,
      conversation: _controller.conversation,
      customType: IsmChatCustomMessageType.image,
      messageText: '',
    );
    if (!allowed) {
      return;
    }

    final extension = item.extension.isNotEmpty ? item.extension : 'gif';
    final mediaType =
        isSticker ? IsmChatMediaType.sticker : IsmChatMediaType.gif;
    final giphyPath = isSticker ? 'stickers' : 'gifs';
    final displayName =
        'GPHMedia(${isSticker ? 'sticker' : 'gif'}) for ${item.id} --> https://giphy.com/$giphyPath/${item.id}';
    final stillUrl =
        item.previewUrl.isNotEmpty ? item.previewUrl : item.sendUrl;

    try {
      await sendMessageWithMediaUrl(
        conversationId: _controller.conversation?.conversationId ?? '',
        userId: _controller.conversation?.opponentDetails?.userId ?? '',
        mediaUrl: item.sendUrl,
        stillUrl: stillUrl,
        mediaType: mediaType,
        body: '',
        notificationBody:
            isSticker ? IsmChatStrings.sentSticker : IsmChatStrings.sentGif,
        nameWithExtension: displayName,
        mediaId: item.id,
        extension: extension,
        // Reserve correct bubble size before the animated GIF finishes loading.
        mediaWidth: item.width,
        mediaHeight: item.height,
        searchableTags: [
          isSticker ? '/@sticker' : '/@gif',
          displayName,
        ],
      );
    } catch (e, st) {
      IsmChatLog.error(e, st);
      IsmChatUtility.showToast('Unable to send media');
    }
  }

  Future<void> _sendVisualAttachment({
    required String conversationId,
    required String userId,
    required WebMediaModel webMediaModel,
    required IsmChatMediaType mediaType,
    required String notificationBody,
    Map<String, dynamic>? metaDataFromDelegate,
    int? preAssignedSentAt,
    bool skipConversationCreate = false,
    bool deferUpload = false,
  }) async {
    if (!skipConversationCreate) {
      conversationId = await _controller.createConversation(
        conversationId: conversationId,
        userId: userId,
      );
    }
    final sentAt = preAssignedSentAt ?? _controller.nextUniqueMediaSentAt();
    final bytes = webMediaModel.platformFile.bytes ?? Uint8List(0);
    final nameWithExtension = webMediaModel.platformFile.name;
    final mediaId = sentAt.toString();
    final extension = webMediaModel.platformFile.extension;
    final localMediaPath = await _resolveLocalMediaPath(
      webMediaModel: webMediaModel,
      bytes: bytes,
      nameWithExtension: nameWithExtension ?? 'media.gif',
    );
    final forMessageType = mediaType == IsmChatMediaType.sticker
        ? IsmChatCustomMessageType.image
        : IsmChatCustomMessageType.image;
    final caption = IsmChatUtility.resolveOutboundMediaCaption(
      mediaCaption: webMediaModel.caption,
      composerText: _controller.chatInputController.text,
    );
    _clearComposerIfUsedAsMediaCaption(
      resolvedCaption: caption,
      mediaCaption: webMediaModel.caption,
    );
    final body = IsmChatUtility.outboundAttachmentBody(caption);

    final visualMessage = IsmChatMessageModel(
      body: body,
      conversationId: conversationId,
      senderInfo: _controller.currentUser,
      customType: _controller.isreplying
          ? IsmChatCustomMessageType.reply
          : IsmChatCustomMessageType.image,
      attachments: [
        AttachmentModel(
          attachmentType: mediaType,
          thumbnailUrl: localMediaPath,
          size: webMediaModel.platformFile.size,
          name: nameWithExtension,
          mimeType: extension,
          mediaUrl: localMediaPath,
          mediaId: mediaId,
          bytes: bytes,
          extension: extension,
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
        caption: IsmChatUtility.outboundAttachmentCaptionMeta(caption),
        customMetaData: metaDataFromDelegate,
        replyMessage: _controller.isreplying
            ? IsmChatReplyMessageModel(
                forMessageType: forMessageType,
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

    _controller.messages.add(visualMessage);
    if (!deferUpload) {
      unawaited(_controller.scrollDown());
      _controller.isreplying = false;
    }

    if (!_controller.isBroadcast) {
      await IsmChatConfig.dbWrapper!
          .saveMessage(visualMessage, IsmChatDbBox.pending);

      if (kIsWeb &&
          IsmChatResponsive.isWeb(IsmChatConfig.kNavigatorKey.currentContext ??
              IsmChatConfig.context)) {
        _controller.updateLastMessagOnCurrentTime(visualMessage);
      }
    }

    if (deferUpload) {
      return;
    }

    await _completeDeferredVisualUpload(
      sentAt: sentAt,
      webMediaModel: webMediaModel,
      notificationBody: notificationBody,
    );
  }

  Future<void> _completeDeferredVisualUpload({
    required int sentAt,
    required WebMediaModel webMediaModel,
    required String notificationBody,
  }) async {
    final index = _controller.messages.indexWhere(
      (message) => message.sentAt == sentAt,
    );
    if (index == -1) {
      return;
    }
    final visualMessage = _controller.messages[index];
    final bytes = webMediaModel.platformFile.bytes ?? Uint8List(0);
    final nameWithExtension = webMediaModel.platformFile.name;
    final mediaId = sentAt.toString();
    final notificationTitle =
        IsmChatConfig.communicationConfig.userConfig.userName ??
            _controller.conversationController.userDetails?.userName ??
            '';
    await _controller.ismPostMediaUrl(
      bytes: bytes,
      createdAt: sentAt,
      ismChatChatMessageModel: visualMessage,
      mediaId: mediaId,
      mediaType: IsmChatMediaType.image.value,
      nameWithExtension: nameWithExtension ?? '',
      notificationBody: notificationBody,
      imageAndFile: true,
      notificationTitle: notificationTitle,
    );
  }

  void _markUploadFailed(int createdAt) {
    _clearMessageUploadingState(createdAt);
    final index = _controller.messages.indexWhere(
      (message) => message.sentAt == createdAt,
    );
    if (index == -1) {
      return;
    }
    final current = _controller.messages[index];
    current
      ..isInvalidMessage = true
      ..messageId = '';
    _controller.messages[index] = current;
    if (_controller.messages is RxList<IsmChatMessageModel>) {
      (_controller.messages as RxList<IsmChatMessageModel>).refresh();
    }
    _controller.update();
  }
}

VideoQuality? _resolveVideoCompressionQuality() {
  final config =
      IsmChatProperties.chatPageProperties.attachmentConfig?.videoCompression;
  final IsmChatVideoCompressionSettings settings;
  if (Platform.isIOS) {
    settings = config?.ios ?? const IsmChatVideoCompressionSettings();
  } else if (Platform.isAndroid) {
    settings = config?.android ?? const IsmChatVideoCompressionSettings();
  } else {
    return null;
  }
  if (!settings.enabled) {
    return null;
  }
  return _mapVideoCompressionQuality(settings.quality);
}

VideoQuality _mapVideoCompressionQuality(
  IsmChatVideoCompressionQuality quality,
) {
  switch (quality) {
    case IsmChatVideoCompressionQuality.defaultQuality:
      return VideoQuality.DefaultQuality;
    case IsmChatVideoCompressionQuality.lowQuality:
      return VideoQuality.LowQuality;
    case IsmChatVideoCompressionQuality.mediumQuality:
      return VideoQuality.MediumQuality;
    case IsmChatVideoCompressionQuality.highestQuality:
      return VideoQuality.HighestQuality;
    case IsmChatVideoCompressionQuality.res640x480:
      return VideoQuality.Res640x480Quality;
    case IsmChatVideoCompressionQuality.res960x540:
      return VideoQuality.Res960x540Quality;
    case IsmChatVideoCompressionQuality.res1280x720:
      return VideoQuality.Res1280x720Quality;
    case IsmChatVideoCompressionQuality.res1920x1080:
      return VideoQuality.Res1920x1080Quality;
  }
}

/// Bytes uploaded for one picked file. Videos reuse the same compression
/// path as a single video send. Images fall back to the file on disk when
/// the picker did not keep bytes in memory.
Future<Uint8List> _bytesForOutgoingMedia(WebMediaModel webMediaModel) async {
  if (webMediaModel.isVideo) {
    return _compressedOrRawVideoBytes(webMediaModel);
  }
  final cached = webMediaModel.platformFile.bytes;
  if (cached != null && cached.isNotEmpty) {
    return cached;
  }
  final path = webMediaModel.platformFile.path;
  if (!kIsWeb && path != null && path.isNotEmpty) {
    return File(path).readAsBytes();
  }
  return cached ?? Uint8List(0);
}

Future<Uint8List> _compressedOrRawVideoBytes(
    WebMediaModel webMediaModel) async {
  if (IsmChatResponsive.isMobile(
          IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context) &
      !kIsWeb) {
    final compressionQuality = _resolveVideoCompressionQuality();
    if (compressionQuality != null) {
      final mediaInfo = await VideoCompress.compressVideo(
        webMediaModel.platformFile.path ?? '',
        quality: compressionQuality,
        deleteOrigin: false,
      );
      if (mediaInfo != null) {
        final compressed = await mediaInfo.file?.readAsBytes();
        if (compressed != null && compressed.isNotEmpty) {
          return compressed;
        }
      }
    }
    return (await _readVideoBytes(webMediaModel)) ?? Uint8List(0);
  }
  return webMediaModel.platformFile.bytes ?? Uint8List(0);
}

/// `mimeType` stored on each attachment. Web reads this next to `mediaType`
/// (0 image, 1 video, 2 audio, 3 doc). Reuse this instead of sending the
/// bare extension.
String mimeTypeForAttachmentExtension(
  String? extension, {
  required IsmChatMediaType mediaType,
}) {
  final ext = (extension ?? '').toLowerCase().replaceAll('.', '');
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'heic':
    case 'heif':
      return 'image/heic';
    case 'mp4':
      return mediaType == IsmChatMediaType.audio ? 'audio/mp4' : 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'webm':
      return 'video/webm';
    case 'mkv':
      return 'video/x-matroska';
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
    case 'aac':
      return 'audio/mp4';
    case 'wav':
      return 'audio/wav';
    case 'pdf':
      return 'application/pdf';
    default:
      switch (mediaType) {
        case IsmChatMediaType.video:
          return 'video/mp4';
        case IsmChatMediaType.audio:
          return 'audio/mpeg';
        case IsmChatMediaType.file:
          return 'application/pdf';
        default:
          return 'image/jpeg';
      }
  }
}

Future<Uint8List?> _readVideoBytes(WebMediaModel webMediaModel) async {
  final cachedBytes = webMediaModel.platformFile.bytes;
  if (cachedBytes != null && cachedBytes.isNotEmpty) {
    return cachedBytes;
  }
  final path = webMediaModel.platformFile.path;
  if (path != null && path.isNotEmpty) {
    return File(path).readAsBytes();
  }
  return cachedBytes;
}
