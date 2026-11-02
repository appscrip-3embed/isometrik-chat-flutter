import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

void main() {
  group('IsmChatMediaGridLayout', () {
    const gridWidth = 300.0;

    test('gridCellSize matches 2-column grid math', () {
      final cell = IsmChatMediaGridLayout.gridCellSize(gridWidth);
      const expectedWidth =
          (gridWidth - IsmChatMediaGridLayout.crossAxisSpacing) /
              IsmChatMediaGridLayout.crossAxisCount;
      expect(cell.width, expectedWidth);
      expect(
        cell.height,
        expectedWidth / IsmChatMediaGridLayout.baseAspectRatio,
      );
    });

    test('portrait still image locks cell height', () {
      const aspectRatio = 0.75;
      final cell = IsmChatMediaGridLayout.gridCellSize(gridWidth);
      final size = IsmChatMediaGridLayout.singleStillImageDisplaySize(
        gridWidth: gridWidth,
        aspectRatio: aspectRatio,
      );
      expect(size.height, cell.height);
      expect(size.width, closeTo(cell.height * aspectRatio, 0.001));
    });

    test('landscape still image locks cell width', () {
      const aspectRatio = 1.5;
      final cell = IsmChatMediaGridLayout.gridCellSize(gridWidth);
      final size = IsmChatMediaGridLayout.singleStillImageDisplaySize(
        gridWidth: gridWidth,
        aspectRatio: aspectRatio,
      );
      expect(size.width, cell.width);
      expect(size.height, closeTo(cell.width / aspectRatio, 0.001));
    });

    test('square still image uses portrait branch', () {
      const aspectRatio = 1.0;
      final cell = IsmChatMediaGridLayout.gridCellSize(gridWidth);
      final size = IsmChatMediaGridLayout.singleStillImageDisplaySize(
        gridWidth: gridWidth,
        aspectRatio: aspectRatio,
      );
      expect(size.height, cell.height);
      expect(size.width, cell.height);
    });

    test('childAspectRatioForDisplayCount', () {
      expect(
        IsmChatMediaGridLayout.childAspectRatioForDisplayCount(2),
        IsmChatMediaGridLayout.baseAspectRatio / 2,
      );
      expect(
        IsmChatMediaGridLayout.childAspectRatioForDisplayCount(4),
        IsmChatMediaGridLayout.baseAspectRatio,
      );
    });
  });
}
