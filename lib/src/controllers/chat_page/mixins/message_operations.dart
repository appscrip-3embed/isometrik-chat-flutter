part of '../chat_page_controller.dart';

/// Message operations mixin for IsmChatPageController.
///
/// This mixin handles message selection, overlay display, reply functionality,
/// media preview, and message information operations.
mixin IsmChatPageMessageOperationsMixin on GetxController {
  /// Gets the controller instance.
  IsmChatPageController get _controller => this as IsmChatPageController;

  /// Handles reply tap on a message.
  void onReplyTap(IsmChatMessageModel message) {
    _controller.isreplying = true;
    _controller.replayMessage = message;
    _controller.messageFocusNode.requestFocus();
  }

  /// Handles menu item selection for a message.
  Future<void> onMenuItemSelected(
    IsmChatFocusMenuType menuType,
    IsmChatMessageModel message,
    BuildContext context,
  ) async {
    switch (menuType) {
      case IsmChatFocusMenuType.info:
        await _controller.getMessageInformation(message);

        break;
      case IsmChatFocusMenuType.reply:
        _controller.onReplyTap(message);
        break;
      case IsmChatFocusMenuType.forward:
        _controller.conversationController.forwardedList.clear();
        // If host app provides custom forward handling, delegate and skip
        // opening SDK's default forward screen.
        if (IsmChatProperties.chatPageProperties.forwardToUserList != null) {
          final messagesToForward = _controller.selectedMessage.isNotEmpty
              ? List<IsmChatMessageModel>.from(_controller.selectedMessage)
              : _getGroupedMediaMessagesForSelection(message);
          IsmChatProperties.chatPageProperties.forwardToUserList!(
            context,
            messagesToForward,
            _controller.conversation,
          );
          break;
        }

        if (IsmChatResponsive.isWeb(
            IsmChatConfig.kNavigatorKey.currentContext ??
                IsmChatConfig.context)) {
          await IsmChatContextWidget.showDialogContext(
            content: IsmChatPageDailog(
              child: IsmChatForwardView(
                message: message,
                conversation: _controller.conversation!,
              ),
            ),
          );
        } else {
          await IsmChatRoute.goToRoute(IsmChatForwardView(
            message: message,
            conversation: _controller.conversation!,
          ));
        }

        break;
      case IsmChatFocusMenuType.copy:
        await Clipboard.setData(ClipboardData(text: message.body));
        IsmChatUtility.showToast('Message copied');
        break;
      case IsmChatFocusMenuType.delete:
        await _controller.showDialogForMessageDelete(message);
        break;
      case IsmChatFocusMenuType.save:
        await _controller.saveMedia(message);
        break;
      case IsmChatFocusMenuType.selectMessage:
        _controller.selectedMessage.clear();
        _controller.isMessageSeleted = true;
        final groupedMessages = _getGroupedMediaMessagesForSelection(message);
        for (final groupedMessage in groupedMessages) {
          _addSelectedMessageIfMissing(groupedMessage);
        }
        break;
    }
  }

  /// Handles message selection/deselection.
  void onMessageSelect(IsmChatMessageModel ismChatChatMessageModel) {
    if (_controller.isMessageSeleted) {
      final groupedMessages =
          _getGroupedMediaMessagesForSelection(ismChatChatMessageModel);
      final allGroupedSelected = groupedMessages.every(
        (groupedMessage) => _controller.selectedMessage.any((selectedMessage) =>
            _messageIdentity(selectedMessage) ==
            _messageIdentity(groupedMessage)),
      );

      if (allGroupedSelected) {
        for (final groupedMessage in groupedMessages) {
          _controller.selectedMessage.removeWhere(
            (message) =>
                _messageIdentity(message) == _messageIdentity(groupedMessage),
          );
        }
      } else {
        for (final groupedMessage in groupedMessages) {
          _addSelectedMessageIfMissing(groupedMessage);
        }
      }

      if (_controller.selectedMessage.isEmpty) {
        _controller.isMessageSeleted = false;
      }
    }
  }

  void _addSelectedMessageIfMissing(IsmChatMessageModel message) {
    final alreadySelected = _controller.selectedMessage.any(
      (selectedMessage) =>
          _messageIdentity(selectedMessage) == _messageIdentity(message),
    );
    if (!alreadySelected) {
      _controller.selectedMessage.add(message);
    }
  }

  List<IsmChatMessageModel> _getGroupedMediaMessagesForSelection(
    IsmChatMessageModel message,
  ) {
    final isImage = message.customType == IsmChatCustomMessageType.image;
    final isVideo = message.customType == IsmChatCustomMessageType.video;
    if (!isImage && !isVideo) {
      return [message];
    }

    final allMessages = _controller.messages
        .where((msg) => msg.customType != IsmChatCustomMessageType.date)
        .toList();
    if (allMessages.isEmpty) {
      return [message];
    }

    final currentIndex = allMessages.indexWhere(
      (msg) => _messageIdentity(msg) == _messageIdentity(message),
    );
    if (currentIndex == -1) {
      return [message];
    }

    final currentMessage = allMessages[currentIndex];
    final sentByMe = currentMessage.sentByMe;
    const timeWindow = 10000; // 10 seconds in milliseconds.
    final groupedMessages = <IsmChatMessageModel>[];

    var groupStartIndex = currentIndex;
    for (var i = currentIndex; i >= 0; i--) {
      final msg = allMessages[i];
      final msgIsImage = msg.customType == IsmChatCustomMessageType.image;
      final msgIsVideo = msg.customType == IsmChatCustomMessageType.video;
      if (!msgIsImage && !msgIsVideo) break;
      if (msg.sentByMe != sentByMe) break;

      final timeDiff = (msg.sentAt - currentMessage.sentAt).abs();
      if (timeDiff > timeWindow) break;
      groupStartIndex = i;
    }

    for (var i = groupStartIndex; i < allMessages.length; i++) {
      final msg = allMessages[i];
      final msgIsImage = msg.customType == IsmChatCustomMessageType.image;
      final msgIsVideo = msg.customType == IsmChatCustomMessageType.video;
      if (!msgIsImage && !msgIsVideo) break;
      if (msg.sentByMe != sentByMe) break;

      final timeDiff = (msg.sentAt - allMessages[groupStartIndex].sentAt).abs();
      if (timeDiff > timeWindow && groupedMessages.isNotEmpty) break;
      groupedMessages.add(msg);
    }

    return groupedMessages.length >= 2 ? groupedMessages : [message];
  }

  String _messageIdentity(IsmChatMessageModel message) {
    final messageId = message.messageId ?? '';
    if (messageId.isNotEmpty) {
      return 'id:$messageId';
    }

    final firstAttachment = message.attachments?.isNotEmpty == true
        ? message.attachments!.first
        : null;
    final mediaUrl = firstAttachment?.mediaUrl ?? '';
    final thumbnailUrl = firstAttachment?.thumbnailUrl ?? '';
    return 'tmp:${message.sentAt}:${message.sentByMe}:${message.customType?.value ?? -1}:$mediaUrl:$thumbnailUrl:${message.body}';
  }

  /// Long-press handler shared by message rows and inline media thumbnails.
  Future<void> onMessageLongPress(
    BuildContext context,
    IsmChatMessageModel message, {
    bool showMessageInCenter = false,
  }) async {
    if (showMessageInCenter) return;
    if (IsmChatProperties.chatPageProperties.shouldShowHoverHold
            ?.call(context, _controller.conversation, message) ??
        false) {
      return;
    }

    if (message.customType == IsmChatCustomMessageType.deletedForEveryone) {
      _controller.isMessageSeleted = true;
      _controller.selectedMessage.add(message);
      return;
    }

    if (IsmChatResponsive.isWeb(context)) return;

    if (!(_controller.conversation?.isChattingAllowed ?? false)) {
      _controller.showDialogCheckBlockUnBlock();
      return;
    }

    await _controller.showOverlay(context, message);
  }

  /// Shows overlay for message focus menu (mobile).
  Future<void> showOverlay(
    BuildContext context,
    IsmChatMessageModel message,
  ) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, secondary) {
          animation = Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
          );

          return IsmChatFocusMenu(
            message,
            animation: animation,
          );
        },
        fullscreenDialog: true,
        opaque: false,
        transitionDuration: IsmChatConstants.transitionDuration,
        reverseTransitionDuration: IsmChatConstants.transitionDuration,
      ),
    );
  }

  /// Shows overlay for message focus menu (web).
  Future<void> showOverlayWeb(
    BuildContext context,
    IsmChatMessageModel message,
    Animation<double> animation,
  ) async {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    // Get hight of Overlay widget which is rendor on message tap
    var overlayHeight = message.focusMenuList.length * IsmChatDimens.forty +
        (IsmChatProperties.chatPageProperties.features
                .contains(IsmChatFeature.reaction)
            ? IsmChatDimens.percentHeight(.1)
            : 0);

    var isOverFlowing =
        (overlayHeight + offset.dy) > (IsmChatDimens.percentHeight(1));
    var topPosition = offset.dy;
    if (isOverFlowing) {
      topPosition = (IsmChatDimens.percentHeight(1) - overlayHeight) -
          IsmChatDimens.twenty;
    }
    OverlayState? overlayState = Overlay.of(context);
    _controller.messageHoldOverlayEntry = OverlayEntry(
      maintainState: true,
      builder: (context) => Positioned(
        left: message.sentByMe ? null : offset.dx + size.width - 5,
        right: message.sentByMe ? 0 + size.width + 5 : null,
        top: topPosition.isNegative
            ? IsmChatProperties.chatPageProperties.header?.height?.call(
                    IsmChatConfig.kNavigatorKey.currentContext ??
                        IsmChatConfig.context,
                    IsmChatUtility.chatPageController.conversation!) ??
                IsmChatDimens.appBarHeight
            : topPosition,
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: animation,
            builder: (_, child) {
              animation = Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                ),
              );
              return IsmChatFocusMenu(
                message,
                animation: animation,
              );
            },
          ),
        ),
      ),
    );
    overlayState.insert(_controller.messageHoldOverlayEntry!);
  }

  /// Gets the display body text for a reply message.
  String getMessageBody(IsmChatMessageModel? replayMessage) {
    if (replayMessage?.isGifMessage == true) {
      return IsmChatStrings.gif;
    }
    if (replayMessage?.isStickerMessage == true) {
      return IsmChatStrings.sticker;
    }
    if (replayMessage?.customType == IsmChatCustomMessageType.location) {
      return IsmChatStrings.location;
    } else if (replayMessage?.customType == IsmChatCustomMessageType.contact) {
      return IsmChatStrings.contact;
    } else if (replayMessage?.customType ==
        IsmChatCustomMessageType.oneToOneCall) {
      return (replayMessage?.callDurations?.length != 1 ||
              replayMessage?.action == IsmChatActionEvents.meetingCreated.name)
          ? '${replayMessage?.meetingType == 0 ? 'Voice' : 'Video'} call'
          : 'Missed ${replayMessage?.meetingType == 0 ? 'voice' : 'video'} call';
    } else {
      final body = replayMessage?.body.trim() ?? '';
      if (body.isNotEmpty) {
        return body;
      }
      final caption = replayMessage?.metaData?.caption?.trim() ?? '';
      if (caption.isNotEmpty) {
        return caption;
      }
      return _replyPreviewBodyForEmptyAttachment(replayMessage);
    }
  }

  /// Reply strip label when the wire [body] is empty (attachment placeholders).
  String _replyPreviewBodyForEmptyAttachment(IsmChatMessageModel? message) {
    if (message == null) {
      return '';
    }
    if (message.isGifMessage) {
      return IsmChatStrings.gif;
    }
    if (message.isStickerMessage) {
      return IsmChatStrings.sticker;
    }
    switch (message.customType) {
      case IsmChatCustomMessageType.image:
        return IsmChatStrings.image;
      case IsmChatCustomMessageType.video:
        return IsmChatStrings.video;
      case IsmChatCustomMessageType.audio:
        return 'Audio';
      case IsmChatCustomMessageType.file:
        return IsmChatStrings.document;
      case IsmChatCustomMessageType.location:
        return IsmChatStrings.location;
      case IsmChatCustomMessageType.contact:
        return IsmChatStrings.contact;
      case IsmChatCustomMessageType.multipleAttachments:
        return message.multipleAttachmentsPreviewLabel;
      default:
        return '';
    }
  }

  /// Gets the parent message URL for display in reply preview.
  String? getParentMessageUrl(IsmChatMessageModel? replayMessage) {
    if (replayMessage == null) return null;
    final customType = replayMessage.customType;
    switch (customType) {
      case IsmChatCustomMessageType.audio:
      case IsmChatCustomMessageType.file:
      case IsmChatCustomMessageType.multipleAttachments:
        return replayMessage.attachments?.first.name;
      case IsmChatCustomMessageType.contact:
        return replayMessage.metaData?.contacts?.first.contactIdentifier;
      case IsmChatCustomMessageType.location:
      case IsmChatCustomMessageType.image:
        return replayMessage.attachments?.first.mediaUrl;
      case IsmChatCustomMessageType.video:
        return replayMessage.attachments?.first.thumbnailUrl;
      default:
        return replayMessage.body;
    }
  }

  /// Gets message information and displays it.
  Future<void> getMessageInformation(
    IsmChatMessageModel message,
  ) async {
    unawaited(Future.wait<dynamic>(
      [
        _controller.getMessageReadTime(message),
        _controller.getMessageDeliverTime(message),
      ],
    ));
    if (IsmChatResponsive.isWeb(
        IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context)) {
      _controller.conversationController.message = message;
      _controller.conversationController.isRenderChatPageaScreen =
          IsRenderChatPageScreen.messgaeInfoView;
    } else {
      await IsmChatRoute.goToRoute(IsmChatMessageInfo(
        message: message,
        isGroup: _controller.conversation?.isGroup ?? false,
      ));
    }
  }

  /// Opens a single file attachment (document row download / file message).
  Future<void> openFileAttachment(AttachmentModel attachment) async {
    var localPath = attachment.mediaUrl;
    if (localPath == null || localPath.isEmpty) {
      return;
    }
    try {
      if (!kIsWeb) {
        final path = await IsmChatUtility.makeDirectoryWithUrl(
          urlPath: attachment.mediaUrl ?? '',
          fileName: attachment.name ?? '',
        );

        if (path.path.isNotEmpty) {
          localPath = path.path;
        }
      }

      if (kIsWeb) {
        if (localPath.isValidUrl) {
          IsmChatBlob.fileDownloadWithUrl(localPath);
        } else {
          IsmChatBlob.fileDownloadWithBytes(
            localPath.strigToUnit8List,
            downloadName: attachment.name,
          );
        }
      } else {
        await OpenFilex.open(localPath);
      }
    } catch (e) {
      IsmChatLog.error('$e');
    }
  }

  bool _isMessageBlurredForMediaPreview(IsmChatMessageModel item) =>
      IsmChatProperties.chatPageProperties.isShowMessageBlur
              ?.call(
                IsmChatConfig.kNavigatorKey.currentContext ??
                    IsmChatConfig.context,
                item,
              )
              .shouldBlured ??
          false;

  /// All image/video items in the current chat for swipe preview (no audio).
  List<IsmChatMessageModel> _conversationImageVideoGallery() =>
      expandMediaGalleryItems(
        _controller.messages,
        includeAudio: false,
      ).where((item) => !_isMessageBlurredForMediaPreview(item)).toList();

  Future<void> _openGalleryForMessage(
    IsmChatMessageModel message, {
    int? attachmentIndex,
  }) async {
    final mediaList = _conversationImageVideoGallery();
    if (mediaList.isEmpty) {
      return;
    }
    final selectedIndex = indexInMediaGallery(
      mediaList,
      message,
      attachmentIndex: attachmentIndex,
    );
    if (selectedIndex < 0) {
      return;
    }
    final previewMeta = mediaList[selectedIndex];
    await _openMediaPreviewList(
      mediaList: mediaList,
      selectedIndex: selectedIndex,
      message: previewMeta,
    );
  }

  /// Media preview for tiles inside one [multipleAttachments] message.
  void tapForMediaPreviewAttachments(
    IsmChatMessageModel parent,
    int attachmentIndex,
  ) async {
    if (attachmentIndex < 0) {
      return;
    }
    await _openGalleryForMessage(
      parent,
      attachmentIndex: attachmentIndex,
    );
  }

  Future<void> _openMediaPreviewList({
    required List<IsmChatMessageModel> mediaList,
    required int selectedIndex,
    required IsmChatMessageModel message,
  }) async {
    if (IsmChatResponsive.isWeb(
        IsmChatConfig.kNavigatorKey.currentContext ?? IsmChatConfig.context)) {
      await IsmChatRoute.goToRoute(IsmWebMessageMediaPreview(
        previewData: {
          'mediaIndex': selectedIndex,
          'messageData': mediaList,
          'mediaUserName': message.chatName,
          'initiated': message.sentByMe,
          'mediaTime': message.sentAt,
        },
      ));
    } else {
      await IsmChatRoute.goToRoute(IsmMediaPreview(
        mediaIndex: selectedIndex,
        messageData: mediaList,
        mediaUserName: message.chatName,
        initiated: message.sentByMe,
        mediaTime: message.sentAt,
      ));
    }
  }

  /// Taps for media preview from a message.
  void tapForMediaPreview(IsmChatMessageModel message) async {
    if ([IsmChatCustomMessageType.image, IsmChatCustomMessageType.video]
        .contains(message.customType)) {
      await _openGalleryForMessage(message);
    } else if (message.customType == IsmChatCustomMessageType.file) {
      final attachment = message.attachments?.firstOrNull;
      if (attachment == null) {
        return;
      }
      await openFileAttachment(attachment);
    } else if (message.customType ==
        IsmChatCustomMessageType.multipleAttachments) {
      final layout = message.multipleAttachmentLayout;
      if (layout == MultipleAttachmentLayout.mediaGrid) {
        await _openGalleryForMessage(message, attachmentIndex: 0);
      } else if (layout == MultipleAttachmentLayout.documentList) {
        // Each document row handles its own tap; avoid opening the first file only.
        return;
      }
    } else if (message.customType == IsmChatCustomMessageType.audio) {
      await IsmChatContextWidget.showDialogContext(
        content: AudioPreview(
          message: message,
        ),
      );
    } else if (message.customType == IsmChatCustomMessageType.contact) {
      await IsmChatRoute.goToRoute(
        IsmChatContactsInfoView(
          contacts: message.contacts,
        ),
      );
    }
  }

  /// Taps for media preview from message metadata (reply).
  void tapForMediaPreviewWithMetaData(IsmChatMessageModel message) async {
    final parentType = message.metaData?.replyMessage?.parentMessageMessageType;
    if ([IsmChatCustomMessageType.image, IsmChatCustomMessageType.video]
            .contains(parentType) ||
        parentType == IsmChatCustomMessageType.multipleAttachments) {
      await _openGalleryForMessage(message);
    } else if (message.metaData?.replyMessage?.parentMessageMessageType ==
        IsmChatCustomMessageType.file) {
      var localPath = message.attachments?.first.mediaUrl;
      if (localPath == null) {
        return;
      }
      try {
        if (!kIsWeb) {
          final path = await IsmChatUtility.makeDirectoryWithUrl(
              urlPath: message.attachments?.first.mediaUrl ?? '',
              fileName: message.attachments?.first.name ?? '');

          if (path.path.isNotEmpty) {
            localPath = path.path;
          }
        }

        if (kIsWeb) {
          if (localPath.isValidUrl) {
            IsmChatBlob.fileDownloadWithUrl(localPath);
          } else {
            IsmChatBlob.fileDownloadWithBytes(
              localPath.strigToUnit8List,
              downloadName: message.attachments?.first.name,
            );
          }
        } else {
          await OpenFilex.open(localPath);
        }
      } catch (e) {
        IsmChatLog.error('$e');
      }
    } else if (message.customType == IsmChatCustomMessageType.audio) {
      await IsmChatContextWidget.showDialogContext(
        content: AudioPreview(
          message: message,
        ),
      );
    } else if (message.metaData?.replyMessage?.parentMessageMessageType ==
        IsmChatCustomMessageType.contact) {
      await IsmChatRoute.goToRoute(
        IsmChatContactsInfoView(
          contacts: message.contacts,
        ),
      );
    }
  }
}
