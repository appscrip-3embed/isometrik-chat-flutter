import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  group('IsmChatStorageQuotaRepository', () {
    late FakeChatApi api;
    late IsmChatStorageQuotaRepository repo;

    setUp(() {
      api = FakeChatApi();
      repo = IsmChatStorageQuotaRepository(apiWrapper: api.wrapper());
    });

    test('getStorageUsage parses the usage body', () async {
      api.on(
        'GET',
        '/chat/quota/storage/usage',
        FakeResponse.json(const {
          'quotaEnabled': true,
          'usedBytes': 10,
          'quotaBytes': 100,
          'remainingBytes': 90,
          'tier': 'free',
          'canUpload': true,
        }),
      );
      final usage = await repo.getStorageUsage();
      expect(usage, isNotNull);
      expect(usage!.quotaEnabled, isTrue);
      expect(usage.remainingBytes, 90);
      // Uses the standard user auth headers.
      final req = api.requestsTo('/chat/quota/storage/usage').last;
      expect(req.headers['userToken'], isNotNull);
      expect(req.headers['licenseKey'], isNotNull);
    });

    test('getStorageUsage returns null on server error', () async {
      api.on('GET', '/chat/quota/storage/usage',
          const FakeResponse('{}', status: 500));
      expect(await repo.getStorageUsage(), isNull);
    });

    test('getStorageMedia sends limit/skip and optional conversationId',
        () async {
      api.on(
        'GET',
        '/chat/quota/storage/media',
        FakeResponse.json(const {
          'quotaEnabled': true,
          'media': [
            {
              'mediaId': 'm1',
              'messageId': 'x',
              'conversationId': 'conv-1',
              'attachmentType': 0,
              'name': 'a.png',
              'size': 1,
            }
          ],
        }),
      );

      final all = await repo.getStorageMedia(limit: 20, skip: 0);
      expect(all?.media, hasLength(1));
      final first = api.requestsTo('/chat/quota/storage/media').last;
      expect(first.url.queryParameters['limit'], '20');
      expect(first.url.queryParameters['skip'], '0');
      expect(first.url.queryParameters.containsKey('conversationId'), isFalse);

      await repo.getStorageMedia(conversationId: 'conv-1', skip: 20);
      final scoped = api.requestsTo('/chat/quota/storage/media').last;
      expect(scoped.url.queryParameters['conversationId'], 'conv-1');
      expect(scoped.url.queryParameters['skip'], '20');
    });

    test('deleteMedia posts mediaIds and parses the freed result', () async {
      api.on(
        'DELETE',
        '/chat/quota/media',
        FakeResponse.json(const {
          'msg': 'Media deleted successfully.',
          'freedBytes': 245760,
          'usedBytes': 733757440,
          'quotaBytes': 1073741824,
        }),
      );
      final outcome = await repo.deleteMedia(mediaIds: ['m1', 'm2']);
      expect(outcome.result, isNotNull);
      expect(outcome.result!.freedBytes, 245760);
      final req = api.requestsForPath('/chat/quota/media', method: 'DELETE').last;
      expect(req.json, {
        'mediaIds': ['m1', 'm2']
      });
    });

    test('deleteMedia surfaces the response on quota-off 404', () async {
      api.on(
        'DELETE',
        '/chat/quota/media',
        FakeResponse.json(const {'error': 'Media quota is not enabled.'},
            status: 404),
      );
      final outcome = await repo.deleteMedia(mediaIds: ['m1']);
      expect(outcome.result, isNull);
      expect(outcome.response.hasError, isTrue);
      expect(
        outcome.response.apiErrorMessage(),
        'Media quota is not enabled.',
      );
    });

    test('deleteConversationMedia hits the scoped path and parses result',
        () async {
      api.on(
        'DELETE',
        '/chat/quota/storage/conversation/conv-1/media',
        FakeResponse.json(const {
          'msg': 'Conversation media deleted successfully.',
          'freedBytes': 1048576,
          'usedBytes': 732708864,
          'quotaBytes': 1073741824,
        }),
      );
      final outcome =
          await repo.deleteConversationMedia(conversationId: 'conv-1');
      expect(outcome.result?.freedBytes, 1048576);
      expect(
        api
            .requestsTo('/chat/quota/storage/conversation/conv-1/media',
                method: 'DELETE')
            .isNotEmpty,
        isTrue,
      );
    });
  });
}
