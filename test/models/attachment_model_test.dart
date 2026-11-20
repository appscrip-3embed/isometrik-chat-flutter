import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';

void main() {
  group('AttachmentModel', () {
    test('image attachment round-trips through json', () {
      final original = attachment(IsmChatMediaType.image);
      final copy = AttachmentModel.fromJson(original.toJson());
      expect(copy.attachmentType, IsmChatMediaType.image);
      expect(copy.name, original.name);
      expect(copy.size, 1024);
      expect(copy.bytes, isNotEmpty);
    });

    test('fromMap uses nameWithExtension when name is absent', () {
      final parsed = AttachmentModel.fromMap({
        'nameWithExtension': 'quarterly-report.pdf',
        'mediaUrl': 'https://cdn.test/q.pdf',
        'attachmentType': IsmChatMediaType.file.value,
      });
      expect(parsed.name, 'quarterly-report.pdf');
    });

    test('resolvedFileName falls back to message body', () {
      final file = AttachmentModel(
        attachmentType: IsmChatMediaType.file,
        mediaUrl: 'https://cdn.test/x.pdf',
      );
      expect(
        file.resolvedFileName(messageBody: 'invoice.pdf'),
        'invoice.pdf',
      );
    });

    test('location attachment keeps coordinates', () {
      final loc = attachment(IsmChatMediaType.location);
      final copy = AttachmentModel.fromMap(loc.toMap());
      expect(copy.latitude, 12.97);
      expect(copy.longitude, 77.59);
      expect(copy.title, 'Office');
    });

    test('fromMap parses double size, width aliases and byte forms', () {
      // int.tryParse('12.7') returns null — double sizes are not truncated.
      final fromDouble = AttachmentModel.fromMap({'size': 12.7});
      expect(fromDouble.size, isNull);
      expect(AttachmentModel.fromMap({'size': 12}).size, 12);
      final fromWidth = AttachmentModel.fromMap({
        'width': '320',
        'height': 240.4,
        'attachmentType': IsmChatMediaType.video.value,
      });
      expect(fromWidth.mediaWidth, 320);
      expect(fromWidth.mediaHeight, 240);
      expect(fromWidth.attachmentType, IsmChatMediaType.video);

      final fromList = AttachmentModel.fromMap({
        'bytes': [1, 2, 3],
      });
      expect(fromList.bytes, Uint8List.fromList([1, 2, 3]));

      final fromBase64 = AttachmentModel.fromMap({
        'bytes': base64Encode([9, 8]),
      });
      expect(fromBase64.bytes, Uint8List.fromList([9, 8]));

      final fromLegacy = AttachmentModel.fromMap({'bytes': '[4, 5]'});
      expect(fromLegacy.bytes, isNotEmpty);

      expect(AttachmentModel.fromMap({'bytes': ''}).bytes, isEmpty);
      expect(AttachmentModel.fromMap({'bytes': 12}).bytes, isEmpty);
      expect(AttachmentModel.fromMap({'mediaWidth': 0}).mediaWidth, isNull);
      expect(AttachmentModel.fromMap({'mediaWidth': true}).mediaWidth, isNull);
    });

    test('copyWith, aspect ratio, equality and toOutgoingMap', () {
      final image = attachment(IsmChatMediaType.image).copyWith(
        mediaWidth: 200,
        mediaHeight: 100,
      );
      expect(image.mediaAspectRatio, 2);
      expect(image.copyWith().name, image.name);
      expect(image == image, isTrue);
      expect(image.hashCode, isA<int>());
      expect(image.toString(), contains('AttachmentModel('));

      final outgoing = image.toOutgoingMap();
      expect(outgoing.containsKey('bytes'), isFalse);
      expect(outgoing['attachmentType'], IsmChatMediaType.image.value);
      expect(outgoing.containsKey('forceUpload'), isFalse);

      final withForce = attachment(IsmChatMediaType.image)
          .copyWith(forceUpload: true)
          .toOutgoingMap();
      expect(withForce['forceUpload'], isTrue);

      final gif = AttachmentModel(
        attachmentType: IsmChatMediaType.gif,
        mediaUrl: 'https://cdn.test/a.gif',
        thumbnailUrl: 'https://cdn.test/a_thumb.gif',
        stillUrl: '',
        name: 'dance.gif',
        mediaWidth: 10,
        mediaHeight: 10,
      ).toOutgoingMap();
      expect(gif['attachmentSchemaType'], 'GifSticker');
      expect(gif['name'], 'dance.gif');
      expect(gif['mediaWidth'], 10);
    });
  });
}
