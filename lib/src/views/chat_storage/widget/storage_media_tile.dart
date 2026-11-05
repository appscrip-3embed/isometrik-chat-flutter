import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// A single charged-media row in the "Manage Storage" list.
///
/// Shows a thumbnail (or a type icon when there is none or the file is
/// [IsmChatQuotaMediaModel.restricted]), the file name, its kind and size, and
/// a selection control in multi-select mode. Purely presentational — selection
/// state and actions are owned by the screen's controller.
class IsmChatStorageMediaTile extends StatelessWidget {
  const IsmChatStorageMediaTile({
    required this.media,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final IsmChatQuotaMediaModel media;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  IsmChatStorageManagementProperties get _props =>
      IsmChatProperties.storageManagementProperties;

  @override
  Widget build(BuildContext context) {
    final theme = IsmChatThemeResolver.storageFromConfig(context);
    final primary = IsmChatConfig.chatTheme.primaryColor ??
        IsmChatColors.primaryColorLight;
    final typeLabel = _props.resolveTypeLabelShort(media.attachmentType);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? primary.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            _thumbnail(primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.name.isEmpty ? typeLabel : media.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.mediaTitleStyle,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '$typeLabel · ${IsmChatUtility.formatBytesDecimal(media.size)}',
                        style: theme.mediaSubtitleStyle,
                      ),
                      if (media.restricted) ...[
                        const SizedBox(width: 8),
                        _restrictedChip(theme),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (selectionMode)
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: selected ? primary : IsmChatColors.greyColorLight,
              ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail(Color primary) {
    final showImage = media.isViewable &&
        (media.thumbnailUrl?.isNotEmpty ?? false) &&
        (media.attachmentType == IsmChatMediaType.image ||
            media.attachmentType == IsmChatMediaType.video);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 48,
        height: 48,
        child: showImage
            ? CachedNetworkImage(
                imageUrl: media.thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _iconBox(primary),
                errorWidget: (_, __, ___) => _iconBox(primary),
              )
            : _iconBox(primary),
      ),
    );
  }

  Widget _iconBox(Color primary) => Container(
        color: primary.withValues(alpha: 0.10),
        alignment: Alignment.center,
        child: Icon(_typeIcon, color: primary, size: 24),
      );

  Widget _restrictedChip(IsmChatStorageTheme theme) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.restrictedChipBackgroundColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _props.resolveRestrictedLabel(),
          style: theme.restrictedChipTextStyle,
        ),
      );

  IconData get _typeIcon {
    switch (media.attachmentType) {
      case IsmChatMediaType.image:
        return Icons.image_outlined;
      case IsmChatMediaType.video:
        return Icons.videocam_outlined;
      case IsmChatMediaType.audio:
        return Icons.audiotrack_outlined;
      case IsmChatMediaType.file:
        return Icons.insert_drive_file_outlined;
      case IsmChatMediaType.gif:
        return Icons.gif_box_outlined;
      case IsmChatMediaType.sticker:
        return Icons.emoji_emotions_outlined;
      case IsmChatMediaType.location:
        return Icons.location_on_outlined;
      case IsmChatMediaType.adminMessage:
        return Icons.attachment_outlined;
    }
  }
}
