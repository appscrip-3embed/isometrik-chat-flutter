import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

void main() {
  group('IsmChatImageAttachmentDimensions', () {
    test('fromBytes returns width and height', () {
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 800, height: 600)),
      );
      final dims = IsmChatImageAttachmentDimensions.fromBytes(bytes);
      expect(dims?.width, 800);
      expect(dims?.height, 600);
    });

    test('aspectRatioFromAttachment uses metadata when present', () {
      final attachment = AttachmentModel(
        mediaWidth: 400,
        mediaHeight: 200,
      );
      expect(
        IsmChatImageAttachmentDimensions.aspectRatioFromAttachment(attachment),
        2.0,
      );
    });

    test('aspectRatioFromAttachment decodes bytes when metadata missing', () {
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 300, height: 400)),
      );
      final attachment = AttachmentModel(bytes: bytes);
      expect(
        IsmChatImageAttachmentDimensions.aspectRatioFromAttachment(attachment),
        closeTo(0.75, 0.001),
      );
    });
  });
}