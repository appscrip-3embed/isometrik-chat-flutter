import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  group('IsmChatUtility.resolveOutboundPresignFileName', () {
    test('prefers non-empty picker name', () {
      expect(
        IsmChatUtility.resolveOutboundPresignFileName(
          pickerName: ' vacation.jpg ',
          path: '/tmp/uuid-cache.jpg',
        ),
        'vacation.jpg',
      );
    });

    test('falls back to path basename when picker name is empty', () {
      expect(
        IsmChatUtility.resolveOutboundPresignFileName(
          pickerName: '',
          path: '/var/mobile/Containers/vacation.jpg',
        ),
        'vacation.jpg',
      );
    });

    test('maps iOS image_picker uuid names to stable img_<hash> names', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final a = IsmChatUtility.resolveOutboundPresignFileName(
        pickerName:
            'image_picker_A3223233-4C73-4BE9-8FE9-1490D9CD896C-7025-000000BBB1ED060C.jpg',
        fileBytes: bytes,
      );
      final b = IsmChatUtility.resolveOutboundPresignFileName(
        pickerName:
            'image_picker_5099EF34-7668-4088-909B-18886FCB66DD-7025-000000BBC308EAC2.jpg',
        fileBytes: bytes,
      );
      expect(a, startsWith('img_'));
      expect(a, endsWith('.jpg'));
      expect(a, b);
    });

    test('uses media_<ext> when name and path are empty', () {
      expect(
        IsmChatUtility.resolveOutboundPresignFileName(
          extension: 'png',
        ),
        'media_png',
      );
      expect(
        IsmChatUtility.resolveOutboundPresignFileName(),
        'media',
      );
    });
  });
}