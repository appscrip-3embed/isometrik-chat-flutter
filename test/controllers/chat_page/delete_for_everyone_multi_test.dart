import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/test_bootstrap.dart';

void main() {
  chatTestWidgets(
    'deleteMessageForEveryone deletes each selected id and updates cache',
    (tester, ctx) async {
      final text = message(
        messageId: 'text-1',
        customType: IsmChatCustomMessageType.text,
        sentAt: 1000,
        body: 'hi',
      );
      final audio = message(
        messageId: 'audio-1',
        customType: IsmChatCustomMessageType.audio,
        sentAt: 2000,
        attachments: [
          AttachmentModel(
            attachmentType: IsmChatMediaType.audio,
            mediaUrl: 'https://cdn.test/a.mp3',
          ),
        ],
      );
      await tester.runAsync(
        () => ctx.db!.saveConversation(
          conversation: directConversation(
            messages: {
              text.key: text,
              audio.key: audio,
            },
          ),
        ),
      );
      ctx.page.conversation = directConversation();

      await drive(
        tester,
        () => ctx.page.viewModel.deleteMessageForEveryone({
          'k0': text,
          'k1': audio,
        }),
      );

      expect(ctx.api.requestsTo('/everyone', method: 'DELETE'), hasLength(2));
    },
    setUpApi: (api) {
      api.registerSendDefaults();
      api.on('DELETE', '/everyone', FakeResponse.json({'ok': true}));
    },
  );

  chatTestWidgets(
    'deleteMessageForEveryone skips tombstones but deletes eligible rows',
    (tester, ctx) async {
      final live = message(
        messageId: 'live-1',
        customType: IsmChatCustomMessageType.text,
        sentAt: 3000,
      );
      final tombstone = message(
        messageId: 'gone-1',
        customType: IsmChatCustomMessageType.deletedForEveryone,
        sentAt: 4000,
      );
      await tester.runAsync(
        () => ctx.db!.saveConversation(
          conversation: directConversation(
            messages: {
              live.key: live,
              tombstone.key: tombstone,
            },
          ),
        ),
      );
      ctx.page.conversation = directConversation();

      await drive(
        tester,
        () => ctx.page.viewModel.deleteMessageForEveryone({
          'a': live,
          'b': tombstone,
        }),
      );

      expect(ctx.api.requestsTo('/everyone', method: 'DELETE'), hasLength(1));
    },
    setUpApi: (api) {
      api.registerSendDefaults();
      api.on('DELETE', '/everyone', FakeResponse.json({'ok': true}));
    },
  );

  test('isEligibleForDeleteForEveryone gates tombstones and empty ids', () {
    expect(
      message(messageId: 'x').isEligibleForDeleteForEveryone,
      isTrue,
    );
    expect(
      message(
        messageId: 'gone',
        customType: IsmChatCustomMessageType.deletedForEveryone,
      ).isEligibleForDeleteForEveryone,
      isFalse,
    );
    expect(
      message(messageId: '').isEligibleForDeleteForEveryone,
      isFalse,
    );
  });
}