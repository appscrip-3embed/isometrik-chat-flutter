import 'dart:ui' show Size;

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

    group('chatMediaFrameSize (mobile)', () {
      const screenWidth = 400.0;
      // 3/4 of the screen minus the reduction: 300 - 30 = 270.
      const frameWidth = screenWidth * .75 -
          IsmChatMediaGridLayout.mobileMediaWidthReduction;

      Size frame(double? aspectRatio) =>
          IsmChatMediaGridLayout.chatMediaFrameSize(
            screenWidth: screenWidth,
            isWeb: false,
            aspectRatio: aspectRatio,
          );

      test('width is 3/4 of the screen minus the reduction', () {
        for (final ar in [null, 0.3, 0.75, 1.0, 1.5, 4.0]) {
          expect(frame(ar).width, frameWidth, reason: 'aspectRatio $ar');
        }
      });

      test('in-range ratios keep their true shape', () {
        expect(frame(1.0).height, frameWidth);
        expect(frame(1.5).height, closeTo(frameWidth / 1.5, 0.001));
        expect(frame(0.75).height, closeTo(frameWidth / 0.75, 0.001));
      });

      test('tall portrait is capped at 3:4', () {
        final size = frame(9 / 16);
        expect(size.height, closeTo(frameWidth * 4 / 3, 0.001));
        expect(
          size.height,
          IsmChatMediaGridLayout.chatMediaMaxHeight(screenWidth, isWeb: false),
        );
      });

      test('wide panorama is capped at 16:9', () {
        expect(frame(3).height, closeTo(frameWidth * 9 / 16, 0.001));
      });

      test('unknown ratio falls back to square', () {
        expect(frame(null), const Size(frameWidth, frameWidth));
      });

      test('web keeps the fit-inside-a-box frame', () {
        final size = IsmChatMediaGridLayout.chatMediaFrameSize(
          screenWidth: 1200,
          isWeb: true,
          aspectRatio: 9 / 16,
        );
        expect(size.height, IsmChatMediaGridLayout.webMediaMaxHeight);
        expect(size.width, closeTo(250 * 9 / 16, 0.001));
      });
    });

    group('constrainedMediaDisplaySize', () {
      const maxWidth = 240.0;
      const maxHeight = 240.0;

      test('unknown aspect ratio uses 1:1 square within max box', () {
        final size = IsmChatMediaGridLayout.constrainedMediaDisplaySize(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
        expect(size.width, maxHeight);
        expect(size.height, maxHeight);
      });

      test('portrait clamps height to maxHeight', () {
        const aspectRatio = 0.75;
        final size = IsmChatMediaGridLayout.constrainedMediaDisplaySize(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          aspectRatio: aspectRatio,
        );
        expect(size.height, maxHeight);
        expect(size.width, closeTo(maxHeight * aspectRatio, 0.001));
      });

      test('landscape fills maxWidth when height fits', () {
        const aspectRatio = 1.5;
        final size = IsmChatMediaGridLayout.constrainedMediaDisplaySize(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          aspectRatio: aspectRatio,
        );
        expect(size.width, maxWidth);
        expect(size.height, closeTo(maxWidth / aspectRatio, 0.001));
      });

      test('tall image height never exceeds maxHeight', () {
        final size = IsmChatMediaGridLayout.constrainedMediaDisplaySize(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          aspectRatio: 0.5,
        );
        expect(size.height, lessThanOrEqualTo(maxHeight));
        expect(size.width, lessThanOrEqualTo(maxWidth));
      });
    });
  });
}
