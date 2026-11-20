import 'dart:ui' show Size;

/// Shared layout math for [IsmChatMediaGridMessage] and standalone still images.
///
/// Keep grid tile size and single-image framing in sync by importing this helper
/// from both surfaces — do not duplicate constants elsewhere.
class IsmChatMediaGridLayout {
  IsmChatMediaGridLayout._();

  /// Columns in the chat media grid (WhatsApp-style).
  static const int crossAxisCount = 2;

  /// Spacing between grid columns and rows.
  static const double crossAxisSpacing = 2;

  /// [SliverGridDelegateWithFixedCrossAxisCount.childAspectRatio] for a 2×2 grid.
  static const double baseAspectRatio = 0.85;

  /// Same max inner width as [IsmChatImageMessage] still/GIF bubbles.
  static double chatMediaBubbleMaxWidth(
    double screenWidth, {
    required bool isWeb,
  }) =>
      isWeb ? screenWidth * .35 : screenWidth * .6;

  /// Multi-attachment grid width — same as single-image bubble for consistent size.
  static double multipleAttachmentGridWidth(
    double screenWidth, {
    required bool isWeb,
  }) =>
      chatMediaBubbleMaxWidth(screenWidth, isWeb: isWeb);

  /// One tile in the 2×2 grid at [gridWidth] (full inner bubble width).
  static Size gridCellSize(double gridWidth) {
    final cellWidth =
        (gridWidth - crossAxisSpacing) / crossAxisCount;
    final cellHeight = cellWidth / baseAspectRatio;
    return Size(cellWidth, cellHeight);
  }

  /// Standalone still image frame aligned to a grid tile.
  ///
  /// [aspectRatio] is width / height (see [AttachmentModel.mediaAspectRatio]).
  /// Portrait/square: fixed cell height, width from ratio.
  /// Landscape: fixed cell width, height from ratio.
  static Size singleStillImageDisplaySize({
    required double gridWidth,
    required double aspectRatio,
  }) {
    assert(aspectRatio > 0);
    final cell = gridCellSize(gridWidth);
    if (aspectRatio <= 1) {
      final height = cell.height;
      final width = height * aspectRatio;
      return Size(width, height);
    }
    final width = cell.width;
    final height = width / aspectRatio;
    return Size(width, height);
  }

  /// Grid delegate aspect ratio for 2 tiles in one row vs multi-row layouts.
  static double childAspectRatioForDisplayCount(int displayCount) =>
      displayCount == 2 ? baseAspectRatio / 2 : baseAspectRatio;

  /// Fits [aspectRatio] (width / height) inside [maxWidth] × [maxHeight].
  ///
  /// Used by [IsmChatImageMessage] and related surfaces so GIF/still bubbles
  /// reserve the same frame before decode (avoids expand-then-shrink on send).
  /// [aspectRatio] null or invalid → 1:1 fallback.
  static Size constrainedMediaDisplaySize({
    required double maxWidth,
    required double maxHeight,
    double? aspectRatio,
  }) {
    final ar = (aspectRatio != null && aspectRatio > 0) ? aspectRatio : 1.0;
    var width = maxWidth;
    var height = width / ar;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * ar;
    }
    return Size(width, height);
  }
}
