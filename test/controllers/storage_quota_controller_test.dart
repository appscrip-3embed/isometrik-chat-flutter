import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_bootstrap.dart';

IsmChatStorageQuotaController _controllerFor(FakeChatApi api) =>
    IsmChatStorageQuotaController(
      IsmChatStorageQuotaViewModel(
        IsmChatStorageQuotaRepository(apiWrapper: api.wrapper()),
      ),
    );

Map<String, dynamic> _mediaRow(String id, {int size = 100}) => {
      'mediaId': id,
      'messageId': 'msg-$id',
      'conversationId': 'conv-1',
      'attachmentType': 0,
      'name': '$id.png',
      'size': size,
    };

void main() {
  group('IsmChatStorageQuotaController.applyUsageFigures', () {
    test('updates used/remaining and re-enables canUpload when under quota', () {
      final controller = _controllerFor(FakeChatApi())
        ..usage = const IsmChatStorageUsageModel(
          quotaEnabled: true,
          canUpload: false, // was full
          usedBytes: 100,
          quotaBytes: 100,
          remainingBytes: 0,
          tier: IsmChatStorageQuotaTier.free,
        )
        ..applyUsageFigures(usedBytes: 60, quotaBytes: 100);

      expect(controller.usage!.usedBytes, 60);
      expect(controller.usage!.remainingBytes, 40);
      expect(controller.usage!.canUpload, isTrue); // 60 < 100
      expect(controller.usage!.quotaBytes, 100);
    });

    test('keeps canUpload false when still at/over the allowance', () {
      final controller = _controllerFor(FakeChatApi())
        ..usage = const IsmChatStorageUsageModel(
          quotaEnabled: true,
          canUpload: false,
          usedBytes: 100,
          quotaBytes: 100,
          remainingBytes: 0,
        )
        ..applyUsageFigures(usedBytes: 100, quotaBytes: 100);
      expect(controller.usage!.canUpload, isFalse);
      expect(controller.usage!.remainingBytes, 0);
    });

    test('is a no-op when usage has not loaded', () {
      final controller = _controllerFor(FakeChatApi())
        ..applyUsageFigures(usedBytes: 10, quotaBytes: 100);
      expect(controller.usage, isNull);
    });

    test('clamps remaining to 0 when used exceeds quota (downgrade)', () {
      final controller = _controllerFor(FakeChatApi())
        ..usage = const IsmChatStorageUsageModel(
          quotaEnabled: true,
          canUpload: false,
          usedBytes: 50,
          quotaBytes: 100,
          remainingBytes: 50,
        )
        ..applyUsageFigures(usedBytes: 150, quotaBytes: 100);
      expect(controller.usage!.remainingBytes, 0);
      expect(controller.usage!.canUpload, isFalse);
    });
  });

  // Pagination reconciliation after a delete needs the pumped host (deleteMedia
  // shows a toast/loader), so it runs as a widget flow test.
  chatTestWidgets(
    'skip cursor is pulled back after a mid-scroll delete (no page gap)',
    (tester, ctx) async {
      ctx.api
        ..on(
          'GET',
          '/chat/quota/storage/media',
          FakeResponse.json({
            'quotaEnabled': true,
            'media': [for (var i = 0; i < 20; i++) _mediaRow('m$i')],
          }),
        )
        ..on(
          'DELETE',
          '/chat/quota/media',
          FakeResponse.json(const {
            'freedBytes': 200,
            'usedBytes': 90,
            'quotaBytes': 100,
          }),
        );

      final controller = _controllerFor(ctx.api);

      await tester.runAsync(() async {
        // First full page → cursor advances to 20.
        await controller.loadMedia(reset: true);
        expect(controller.media, hasLength(20));
        // Delete two loaded rows → cursor should pull back to 18.
        await controller.deleteMedia(['m0', 'm1']);
        expect(controller.media, hasLength(18));
        // Next page must resume at 18, not 20 (otherwise m18/m19 are skipped).
        await controller.loadMore();
      });
      // Flush the Fluttertoast timer from deleteMedia.
      await tester.pump(const Duration(seconds: 1));

      final mediaGets =
          ctx.api.requestsTo('/chat/quota/storage/media', method: 'GET');
      expect(mediaGets.last.url.queryParameters['skip'], '18');
    },
    useDatabase: false,
  );

  chatTestWidgets(
    'deleting selected media frees bytes and updates cached usage',
    (tester, ctx) async {
      ctx.api
        ..on(
          'GET',
          '/chat/quota/storage/usage',
          FakeResponse.json(const {
            'quotaEnabled': true,
            'usedBytes': 100,
            'quotaBytes': 100,
            'remainingBytes': 0,
            'tier': 'free',
            'canUpload': false,
          }),
        )
        ..on(
          'GET',
          '/chat/quota/storage/media',
          FakeResponse.json({
            'quotaEnabled': true,
            'media': [_mediaRow('m0'), _mediaRow('m1')],
          }),
        )
        ..on(
          'DELETE',
          '/chat/quota/media',
          FakeResponse.json(const {
            'freedBytes': 40,
            'usedBytes': 60,
            'quotaBytes': 100,
          }),
        );

      final controller = _controllerFor(ctx.api);

      await tester.runAsync(() async {
        await controller.initialize();
        expect(controller.canUpload, isFalse); // started full
        controller
          ..enterSelectionMode('m0')
          ..toggleSelection('m1');
        await controller.deleteSelected();
      });
      await tester.pump(const Duration(seconds: 1));

      expect(controller.usage!.usedBytes, 60);
      expect(controller.usage!.remainingBytes, 40);
      expect(controller.canUpload, isTrue); // re-enabled after freeing space
      expect(controller.selectedMediaIds, isEmpty);
    },
    useDatabase: false,
  );
}
