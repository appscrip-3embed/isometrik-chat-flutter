import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Message Info page opened from a message's focus menu.
///
/// Layout follows WhatsApp: the message on the chat wallpaper, then
/// "Read by" / "Delivered to" sections (group) or a Read / Delivered card
/// (1:1). Surfaces and text use [IsmChatThemeResolver.groupInfoFromConfig],
/// ticks use [IsmChatPageTheme.messageStatusTheme], and rows honour
/// [IsmChatPageProperties.messageInfoAcknowldge].
class IsmChatMessageInfo extends StatelessWidget {
  const IsmChatMessageInfo(
      {super.key, required this.message, required this.isGroup});

  final IsmChatMessageModel message;
  final bool isGroup;

  bool get _isPlayable =>
      message.customType == IsmChatCustomMessageType.audio ||
      message.customType == IsmChatCustomMessageType.video;

  @override
  Widget build(BuildContext context) {
    final theme = IsmChatThemeResolver.groupInfoFromConfig(context);
    return GetBuilder<IsmChatPageController>(
      tag: IsmChat.i.chatPageTag,
      builder: (chatController) => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          systemOverlayStyle:
              IsmChatConfig.chatTheme.chatPageHeaderTheme?.systemUiOverlayStyle ??
                  SystemUiOverlayStyle(
                    statusBarBrightness: Brightness.dark,
                    statusBarIconBrightness: Brightness.light,
                    statusBarColor: IsmChatConfig.chatTheme.primaryColor ??
                        IsmChatColors.primaryColorLight,
                  ),
          elevation: 0,
          leading: IconButton(
            onPressed: IsmChatResponsive.isWeb(context)
                ? () {
                    IsmChatUtility
                            .conversationController.isRenderChatPageaScreen =
                        IsRenderChatPageScreen.none;
                  }
                : IsmChatRoute.goBack,
            icon: Icon(
              IsmChatResponsive.isWeb(context)
                  ? Icons.close_rounded
                  : Icons.arrow_back_rounded,
              color: IsmChatConfig.chatTheme.chatPageHeaderTheme?.iconColor ??
                  IsmChatColors.whiteColor,
            ),
          ),
          backgroundColor:
              IsmChatConfig.chatTheme.chatPageHeaderTheme?.backgroundColor ??
                  IsmChatConfig.chatTheme.primaryColor,
          titleSpacing: 1,
          title: Text(IsmChatStrings.messageInfo,
              style: IsmChatConfig.chatTheme.chatPageHeaderTheme?.titleStyle ??
                  IsmChatStyles.w600White18),
          centerTitle: true,
        ),
        // Bottom inset for Android/iOS system nav bar (edge-to-edge).
        body: SafeArea(
          top: false,
          maintainBottomViewPadding: true,
          child: SingleChildScrollView(
            // Let content define its own height so nothing gets clipped
            // and the scroll extent matches the real content.
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MessagePreview(
                  message: message,
                  isGroup: isGroup,
                  controller: chatController,
                  dividerColor: theme.dividerColor,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    IsmChatDimens.sixteen,
                    0,
                    IsmChatDimens.sixteen,
                    IsmChatDimens.twentyFour,
                  ),
                  child: Obx(
                    () => isGroup
                        ? _groupStatus(chatController, theme)
                        : _directStatus(chatController, theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).withUnfocusGestureDetctor(context),
    );
  }

  /// "Read by" (everyone who read) + "Delivered to" (received, not read yet).
  Widget _groupStatus(
    IsmChatPageController chatController,
    IsmChatGroupInfoTheme theme,
  ) {
    final read = chatController.readMessageMembers.toList();
    final delivered = chatController.deliverdMessageMembers.toList();
    final readIds = {for (final user in read) user.userId};
    final deliveredAt = {
      for (final user in delivered) user.userId: user.timestamp ?? 0,
    };
    final deliveredOnly =
        delivered.where((user) => !readIds.contains(user.userId)).toList();

    final membersCount = chatController.conversation?.membersCount ?? 0;
    final expectedRecipients = membersCount > 0 ? membersCount - 1 : 0;
    final everyoneRead = expectedRecipients > 0
        ? read.length >= expectedRecipients
        : read.isNotEmpty;

    final readLabel = _isPlayable ? IsmChatStrings.played : IsmChatStrings.read;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusSection(
          title: _isPlayable ? IsmChatStrings.playedby : IsmChatStrings.readby,
          isRead: true,
          theme: theme,
          dividerIndent: _AckUserTile.dividerIndent,
          children: [
            for (final user in read)
              _AckUserTile(
                key: ValueKey('read-${user.userId}'),
                user: user,
                theme: theme,
                readLabel: readLabel,
                deliveredAt: deliveredAt[user.userId],
              ),
          ],
        ),
        if (deliveredOnly.isNotEmpty || !everyoneRead)
          _StatusSection(
            title: IsmChatStrings.deliveredTo,
            isRead: false,
            theme: theme,
            dividerIndent: _AckUserTile.dividerIndent,
            children: [
              for (final user in deliveredOnly)
                _AckUserTile(
                  key: ValueKey('delivered-${user.userId}'),
                  user: user,
                  theme: theme,
                ),
            ],
          ),
      ],
    );
  }

  /// 1:1 chat: one card with the Read and Delivered times.
  Widget _directStatus(
    IsmChatPageController chatController,
    IsmChatGroupInfoTheme theme,
  ) {
    final read = chatController.readMessageMembers.toList();
    final delivered = chatController.deliverdMessageMembers.toList();
    return Padding(
      padding: EdgeInsets.only(top: IsmChatDimens.twentyFour),
      child: _SectionCard(
        theme: theme,
        dividerIndent: _DirectStatusRow.dividerIndent,
        children: [
          _DirectStatusRow(
            label: _isPlayable ? IsmChatStrings.played : IsmChatStrings.read,
            isRead: true,
            timestamp: read.isEmpty ? 0 : read.first.timestamp ?? 0,
            theme: theme,
          ),
          _DirectStatusRow(
            label: IsmChatStrings.delivered,
            isRead: false,
            timestamp: delivered.isEmpty ? 0 : delivered.first.timestamp ?? 0,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

/// Section header + empty ("○○○") card, shown while nobody is in a list yet.
class MessageReadDelivered extends StatelessWidget {
  const MessageReadDelivered({
    super.key,
    required this.title,
    this.isRead = false,
  });

  final String title;
  final bool isRead;

  @override
  Widget build(BuildContext context) => _StatusSection(
        title: title,
        isRead: isRead,
        theme: IsmChatThemeResolver.groupInfoFromConfig(context),
        children: const [],
      );
}

/// The message as it appears in the chat: date chip + bubble on the chat
/// wallpaper, closed off by a hairline.
class _MessagePreview extends StatelessWidget {
  const _MessagePreview({
    required this.message,
    required this.isGroup,
    required this.controller,
    required this.dividerColor,
  });

  final IsmChatMessageModel message;
  final bool isGroup;
  final IsmChatPageController controller;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final pageTheme = IsmChatConfig.chatTheme.chatPageTheme;
    final hasWallpaper = IsmChatWallpaper.hasWallpaper(controller);
    // Same layering as [IsmChatPageView]: wallpaper, else page colour + decoration.
    return DecoratedBox(
      decoration: IsmChatWallpaper.decoration(
        controller,
        fallbackColor: pageTheme?.backgroundColor ?? IsmChatColors.whiteColor,
      ),
      child: DecoratedBox(
        decoration: hasWallpaper
            ? const BoxDecoration()
            : pageTheme?.pageDecoration ?? const BoxDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: IsmChatDimens.edgeInsets16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: pageTheme?.centerMessageTheme?.backgroundColor ??
                            IsmChatConfig.chatTheme.backgroundColor,
                        borderRadius:
                            BorderRadius.circular(IsmChatDimens.eight),
                      ),
                      padding: IsmChatDimens.edgeInsets8_4,
                      child: Text(
                        message.sentAt.toMessageDateString(),
                        style: pageTheme?.centerMessageTheme?.textStyle ??
                            IsmChatStyles.w500Black12.copyWith(
                              color: IsmChatConfig.chatTheme.primaryColor,
                            ),
                      ),
                    ),
                  ),
                  IsmChatDimens.boxHeight16,
                  Obx(() => Align(
                        alignment: message.sentByMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: MessageBubble(
                          message: _withLiveStatus(),
                          showMessageInCenter: false,
                        ),
                      )),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: dividerColor),
          ],
        ),
      ),
    );
  }

  /// Bubble ticks reflect the fetched read / delivered lists, not just the
  /// flags the message had when the page opened.
  IsmChatMessageModel _withLiveStatus() {
    final deliveredCount = controller.deliverdMessageMembers.length;
    final readCount = controller.readMessageMembers.length;
    final membersCount = controller.conversation?.membersCount ?? 0;
    final expectedRecipients =
        isGroup ? (membersCount > 0 ? membersCount - 1 : 0) : 1;

    var deliveredToAll = message.deliveredToAll ?? false;
    var readByAll = message.readByAll ?? false;

    if (isGroup) {
      if (expectedRecipients > 0 && deliveredCount > 0) {
        deliveredToAll = deliveredCount >= expectedRecipients;
      }
      if (expectedRecipients > 0 && readCount > 0) {
        readByAll = readCount >= expectedRecipients;
        if (readByAll) {
          deliveredToAll = true;
        }
      }
    } else {
      if (deliveredCount > 0) {
        deliveredToAll = true;
      }
      if (readCount > 0) {
        readByAll = true;
        deliveredToAll = true;
      }
    }

    return message.copyWith(
      deliveredToAll: deliveredToAll,
      readByAll: readByAll,
    );
  }
}

/// Double tick + UPPERCASE title, then a card of [children] (or "○○○").
class _StatusSection extends StatelessWidget {
  const _StatusSection({
    required this.title,
    required this.isRead,
    required this.theme,
    required this.children,
    this.dividerIndent = 0,
  });

  final String title;
  final bool isRead;
  final IsmChatGroupInfoTheme theme;
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              IsmChatDimens.sixteen,
              IsmChatDimens.twentyFour,
              IsmChatDimens.sixteen,
              IsmChatDimens.eight,
            ),
            child: Row(
              children: [
                _StatusTick(isRead: isRead),
                IsmChatDimens.boxWidth8,
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: theme.captionTextStyle.copyWith(letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            theme: theme,
            dividerIndent: dividerIndent,
            children:
                children.isEmpty ? [_AckPlaceholder(theme: theme)] : children,
          ),
        ],
      );
}

/// Rounded surface with hairline dividers between rows (none after the last).
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.theme,
    required this.children,
    this.dividerIndent = 0,
  });

  final IsmChatGroupInfoTheme theme;
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) => Material(
        color: theme.surfaceBackgroundColor,
        borderRadius: BorderRadius.circular(IsmChatDimens.sixteen),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: dividerIndent,
                  endIndent: IsmChatDimens.sixteen,
                  color: theme.dividerColor,
                ),
              children[i],
            ],
          ],
        ),
      );
}

/// Read / unread double tick in the chat's message-status colours.
class _StatusTick extends StatelessWidget {
  const _StatusTick({required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final statusTheme =
        IsmChatConfig.chatTheme.chatPageTheme?.messageStatusTheme;
    return Icon(
      Icons.done_all_rounded,
      size: statusTheme?.checkSize ?? IsmChatDimens.sixteen,
      color: isRead
          ? statusTheme?.readCheckColor ?? Colors.blue
          : statusTheme?.unreadCheckColor ?? Colors.grey,
    );
  }
}

/// "today  7:36 PM" / "22/11/26  10:14 AM", or "—" when unknown.
class _AckTimestamp extends StatelessWidget {
  const _AckTimestamp({
    required this.timestamp,
    required this.theme,
    this.timeStyle,
  });

  final int timestamp;
  final IsmChatGroupInfoTheme theme;

  /// Style of the time part; [IsmChatGroupInfoTheme.metaTextStyle] when null.
  final TextStyle? timeStyle;

  @override
  Widget build(BuildContext context) {
    if (timestamp <= 0) {
      return Text('—', style: theme.captionTextStyle);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(timestamp.messageInfoDate, style: theme.captionTextStyle),
        IsmChatDimens.boxWidth8,
        Text(
          timestamp.toTimeString,
          style: timeStyle ?? theme.metaTextStyle,
        ),
      ],
    );
  }
}

/// One member in "Read by" / "Delivered to".
///
/// A "Read by" row with a known delivered time expands on tap to show both
/// the Read and Delivered times.
class _AckUserTile extends StatefulWidget {
  const _AckUserTile({
    super.key,
    required this.user,
    required this.theme,
    this.readLabel,
    this.deliveredAt,
  });

  static double get avatarSize => IsmChatDimens.thirtyTwo;

  /// Divider starts under the name, past the avatar.
  static double get dividerIndent =>
      IsmChatDimens.sixteen + avatarSize + IsmChatDimens.twelve;

  final UserDetails user;
  final IsmChatGroupInfoTheme theme;

  /// "Read" / "Played"; set only for rows in the read section.
  final String? readLabel;

  /// Delivered time for a read row, from the delivered list.
  final int? deliveredAt;

  @override
  State<_AckUserTile> createState() => _AckUserTileState();
}

class _AckUserTileState extends State<_AckUserTile> {
  bool _expanded = false;

  bool get _canExpand =>
      widget.readLabel != null && (widget.deliveredAt ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final ack = IsmChatProperties.chatPageProperties.messageInfoAcknowldge;
    final user = widget.user;
    final theme = widget.theme;
    final timestamp = user.timestamp ?? 0;

    final avatar = ack?.profileImageBuilder?.call(context, user) ??
        IsmChatImage.profile(
          ack?.profileImageUrl?.call(context, user) ?? user.profileUrl,
          name: user.userName,
          dimensions: _AckUserTile.avatarSize,
        );
    final title = ack?.titleBuilder?.call(context, user) ??
        Text(
          ack?.title?.call(context, user) ?? user.userName,
          style: theme.listTileTitleTextStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
    final customTrailing = ack?.trailing?.call(context, user);
    final trailing = ack?.trailingBuilder?.call(context, user) ??
        (customTrailing != null
            ? Text(customTrailing, style: theme.metaTextStyle)
            : _AckTimestamp(timestamp: timestamp, theme: theme));

    return InkWell(
      onTap: _canExpand ? () => setState(() => _expanded = !_expanded) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: IsmChatDimens.sixteen,
          vertical: IsmChatDimens.six,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                avatar,
                IsmChatDimens.boxWidth12,
                Expanded(child: title),
                if (!_expanded) ...[
                  IsmChatDimens.boxWidth8,
                  trailing,
                ],
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: EdgeInsets.only(
                        left: _AckUserTile.avatarSize + IsmChatDimens.twelve,
                        top: IsmChatDimens.eight,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LabeledTimestamp(
                            label: widget.readLabel ?? IsmChatStrings.read,
                            timestamp: timestamp,
                            theme: theme,
                          ),
                          IsmChatDimens.boxHeight8,
                          _LabeledTimestamp(
                            label: IsmChatStrings.delivered,
                            timestamp: widget.deliveredAt ?? 0,
                            theme: theme,
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Read          22/11/26  10:14 AM" row inside an expanded member.
class _LabeledTimestamp extends StatelessWidget {
  const _LabeledTimestamp({
    required this.label,
    required this.timestamp,
    required this.theme,
  });

  final String label;
  final int timestamp;
  final IsmChatGroupInfoTheme theme;

  @override
  Widget build(BuildContext context) {
    // Detail lines under the name: regular weight, subtitle size.
    final style = theme.listTileSubtitleTextStyle
        .copyWith(fontWeight: FontWeight.w400);
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        _AckTimestamp(timestamp: timestamp, theme: theme, timeStyle: style),
      ],
    );
  }
}

/// 1:1 row: tick + "Read" / "Delivered" + time (or "—").
class _DirectStatusRow extends StatelessWidget {
  const _DirectStatusRow({
    required this.label,
    required this.isRead,
    required this.timestamp,
    required this.theme,
  });

  /// Divider starts under the label, past the tick.
  static double get dividerIndent =>
      IsmChatDimens.sixteen + IsmChatDimens.sixteen + IsmChatDimens.twelve;

  final String label;
  final bool isRead;
  final int timestamp;
  final IsmChatGroupInfoTheme theme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: IsmChatDimens.sixteen,
          vertical: IsmChatDimens.twelve,
        ),
        child: Row(
          children: [
            _StatusTick(isRead: isRead),
            IsmChatDimens.boxWidth12,
            Expanded(
              child: Text(label, style: theme.listTileTitleTextStyle),
            ),
            _AckTimestamp(timestamp: timestamp, theme: theme),
          ],
        ),
      );
}

/// "○○○" shown in a section nobody is in yet (or while loading).
class _AckPlaceholder extends StatelessWidget {
  const _AckPlaceholder({required this.theme});

  final IsmChatGroupInfoTheme theme;

  @override
  Widget build(BuildContext context) {
    final color = theme.captionTextStyle.color ?? Colors.grey;
    return SizedBox(
      height: IsmChatDimens.fifty,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: IsmChatDimens.eight,
                height: IsmChatDimens.eight,
                margin: EdgeInsets.symmetric(horizontal: IsmChatDimens.three),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
