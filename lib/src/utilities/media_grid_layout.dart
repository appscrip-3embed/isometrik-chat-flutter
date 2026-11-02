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
}
