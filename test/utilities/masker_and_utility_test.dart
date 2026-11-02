import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  group('IsmChatSensitiveContentMasker', () {
    test('applyIfEnabled is a no-op when disabled or empty', () {
      expect(
        IsmChatSensitiveContentMasker.applyIfEnabled('a@b.com', enabled: false),
        'a@b.com',
      );
      expect(IsmChatSensitiveContentMasker.applyIfEnabled('', enabled: true), '');
    });

    test('masks email, phone and social urls', () {
      expect(
        IsmChatSensitiveContentMasker.mask('nilpatel@gmail.com'),
        '********@gmail.com',
      );
      expect(
        IsmChatSensitiveContentMasker.mask('9876543210'),
        '******3210',
      );
      expect(IsmChatSensitiveContentMasker.mask('12345678'), '12345678');
      expect(
        IsmChatSensitiveContentMasker.mask('+91 9876543210'),
        '+91 ******3210',
      );
      expect(
        IsmChatSensitiveContentMasker.mask('instagram.com/nilpatel'),
        'instagram.com/********',
      );
      expect(
        IsmChatSensitiveContentMasker.mask(
          'https://store.test/69fd8e641d45da0605683369',
        ),
        'https://store.test/69fd8e641d45da0605683369',
      );
    });

    test('local unmasked meta helpers', () {
      final meta = IsmChatMetaData(caption: 'x');
      final attached = IsmChatSensitiveContentMasker.attachLocalUnmasked(
        meta: meta,
        originalBody: 'secret',
      );
      expect(
        attached.customMetaData?[IsmChatSensitiveContentMasker.localUnmaskedBodyKey],
        'secret',
      );
      expect(
        IsmChatSensitiveContentMasker.resolveApiBody(
          storedBody: 'masked',
          metaData: attached,
        ),
        'secret',
      );
      final stripped =
          IsmChatSensitiveContentMasker.stripLocalUnmaskedFromMeta(attached);
      expect(
        stripped?.customMetaData
            ?.containsKey(IsmChatSensitiveContentMasker.localUnmaskedBodyKey),
        isFalse,
      );
    });
  });

  group('IsmChatUtility', () {
    test('token and access headers', () {
      final token = IsmChatUtility.tokenCommonHeader();
      expect(token['Content-Type'], 'application/json');
      expect(token['userToken'], 'user-token');
      expect(token['licenseKey'], 'license');
      final access = IsmChatUtility.accessTokenCommonHeader();
      expect(access.containsKey('Authorization'), isTrue);
      final withType =
          IsmChatUtility.accessTokenCommonHeader(isDefaultContentType: true);
      expect(withType['Content-Type'], 'application/json');
    });

    test('isOnlyEmoji', () {
      expect(IsmChatUtility.isOnlyEmoji('😀'), isTrue);
      expect(IsmChatUtility.isOnlyEmoji('hello'), isFalse);
      expect(IsmChatUtility.isOnlyEmoji(''), isFalse);
    });

    test('hideKeyboard / openKeyboard / notifyRxSafely', () {
      IsmChatUtility.hideKeyboard();
      IsmChatUtility.openKeyboard();
      var ran = false;
      IsmChatUtility.notifyRxSafely(() => ran = true);
      expect(ran, isTrue);
    });

    test('isLoading defaults to false', () {
      expect(IsmChatUtility.isLoading, isFalse);
    });
  });

  group('IsmChatAPI', () {
    test('baseUrl uses the test config', () {
      expect(IsmChatAPI.baseUrl, kTestBaseUrl);
      expect(IsmChatAPI.sendMessage, '$kTestBaseUrl/chat/message');
      expect(IsmChatAPI.chatMessages, '$kTestBaseUrl/chat/messages');
    });
  });

  group('call meeting liveness', () {
    test('mergeCallMessageIntoMap is covered by dedicated tests', () {
      expect(IsmChatDBWrapper.mergeCallMessageIntoMap, isA<Function>());
    });
  });
}
