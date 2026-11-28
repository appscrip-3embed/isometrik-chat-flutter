import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

void main() {
  group('IsmChatMediaImageProvider', () {
    test('fromUrl returns null for empty / nullish strings', () {
      expect(IsmChatMediaImageProvider.fromUrl(''), isNull);
      expect(IsmChatMediaImageProvider.fromUrl('   '), isNull);
      expect(IsmChatMediaImageProvider.fromUrl('null'), isNull);
    });

    test('fromAttachment prefers bytes over URLs', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final provider = IsmChatMediaImageProvider.fromAttachment(
        AttachmentModel(
          mediaUrl: 'https://cdn.example/photo.jpg',
          bytes: bytes,
        ),
      );
      expect(provider, isA<MemoryImage>());
    });

    test('fromAttachment falls back to thumbnail when mediaUrl empty', () {
      final provider = IsmChatMediaImageProvider.fromAttachment(
        AttachmentModel(
          mediaUrl: '',
          thumbnailUrl: 'https://cdn.example/thumb.jpg',
        ),
      );
      expect(provider, isNotNull);
      expect(provider, isA<ImageProvider>());
    });

    test('displayUrlForMessage prefers thumbnail for video', () {
      expect(
        IsmChatMediaImageProvider.displayUrlForMessage(
          IsmChatMessageModel(
            body: '',
            sentAt: 1,
            sentByMe: true,
            customType: IsmChatCustomMessageType.video,
            attachments: [
              AttachmentModel(
                mediaUrl: 'https://cdn.example/video.mp4',
                thumbnailUrl: 'https://cdn.example/thumb.jpg',
              ),
            ],
          ),
        ),
        'https://cdn.example/thumb.jpg',
      );
    });

    test('displayUrlForMessage uses mediaUrl for images', () {
      expect(
        IsmChatMediaImageProvider.displayUrlForMessage(
          IsmChatMessageModel(
            body: '',
            sentAt: 1,
            sentByMe: true,
            customType: IsmChatCustomMessageType.image,
            attachments: [
              AttachmentModel(
                mediaUrl: 'https://cdn.example/photo.jpg',
                thumbnailUrl: 'https://cdn.example/thumb.jpg',
              ),
            ],
          ),
        ),
        'https://cdn.example/photo.jpg',
      );
    });
  });
}
