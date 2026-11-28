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

  /// Mobile image / GIF / video / grid width as a fraction of the screen
  /// (WhatsApp-style), before [mobileMediaWidthReduction] is taken off.
  static const double mobileMediaWidthFactor = .75;

  /// Logical px taken off the 3/4 width, so mobile media is
  /// `screenWidth * mobileMediaWidthFactor - mobileMediaWidthReduction` wide.
  static const double mobileMediaWidthReduction = 30;

  /// Tallest mobile frame (width / height). Taller portraits are center-cropped
  /// to 3:4 so one photo cannot fill the whole screen.
  static const double minMobileMediaAspectRatio = 3 / 4;

  /// Widest mobile frame (width / height). Wider panoramas are center-cropped
  /// to 16:9 so the bubble never collapses into a thin strip.
  static const double maxMobileMediaAspectRatio = 16 / 9;

  /// Web keeps the older fit-inside-a-box behavior.
  static const double webMediaMaxHeight = 250;

  /// Same max inner width as [IsmChatImageMessage] still/GIF bubbles.
  static double chatMediaBubbleMaxWidth(
    double screenWidth, {
    required bool isWeb,
  }) =>
      isWeb
          ? screenWidth * .35
          : screenWidth * mobileMediaWidthFactor - mobileMediaWidthReduction;

  /// Tallest frame [chatMediaFrameSize] can return.
  static double chatMediaMaxHeight(
    double screenWidth, {
    required bool isWeb,
  }) =>
      isWeb
          ? webMediaMaxHeight
          : chatMediaBubbleMaxWidth(screenWidth, isWeb: false) /
              minMobileMediaAspectRatio;

  /// Frame for a single still image, GIF or video-thumbnail bubble.
  ///
  /// Mobile: fixed width ([chatMediaBubbleMaxWidth]: 3/4 of the screen minus
  /// [mobileMediaWidthReduction]); height
  /// follows [aspectRatio] clamped to 3:4…16:9 and the media is drawn with
  /// `BoxFit.cover`, so out-of-range media is center-cropped.
  /// Web: fits [aspectRatio] inside the old max width × [webMediaMaxHeight].
  static Size chatMediaFrameSize({
    required double screenWidth,
    required bool isWeb,
    double? aspectRatio,
  }) {
    final width = chatMediaBubbleMaxWidth(screenWidth, isWeb: isWeb);
    if (isWeb) {
      return constrainedMediaDisplaySize(
        maxWidth: width,
        maxHeight: webMediaMaxHeight,
        aspectRatio: aspectRatio,
      );
    }
    final ar = (aspectRatio != null && aspectRatio > 0) ? aspectRatio : 1.0;
    final clamped =
        ar.clamp(minMobileMediaAspectRatio, maxMobileMediaAspectRatio);
    return Size(width, width / clamped);
  }

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
