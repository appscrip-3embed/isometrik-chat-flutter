import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/test_bootstrap.dart';

AttachmentModel _imageAttachment({required String url}) => AttachmentModel(
      attachmentType: IsmChatMediaType.image,
      mediaUrl: url,
      thumbnailUrl: '$url-thumb',
      stillUrl: '',
      name: 'photo.jpg',
    );

AttachmentModel _gifAttachment({required String url}) => AttachmentModel(
      attachmentType: IsmChatMediaType.gif,
      mediaUrl: url,
      thumbnailUrl: '$url-thumb',
      stillUrl: '',
      name: 'anim.gif',
    );

void main() {
  chatTestWidgets(
    'onMessageSelect selects only one of two nearby GIF rows',
    (tester, ctx) async {
      final gifA = message(
        messageId: 'gif-a',
        customType: IsmChatCustomMessageType.image,
        sentAt: 5000,
        attachments: [_gifAttachment(url: 'https://cdn/g1.gif')],
      );
      final gifB = message(
        messageId: 'gif-b',
        customType: IsmChatCustomMessageType.image,
        sentAt: 6000,
        attachments: [_gifAttachment(url: 'https://cdn/g2.gif')],
      );
      ctx.page.messages = [gifA, gifB];
      ctx.page.isMessageSeleted = true;

      ctx.page.onMessageSelect(gifA);

      expect(ctx.page.selectedMessage.length, 1);
      expect(ctx.page.selectedMessage.first.messageId, 'gif-a');
    },
    setUpApi: (api) => api.registerSendDefaults(),
  );

  chatTestWidgets(
    'onMessageSelect batches grid-eligible images in the same time window',
    (tester, ctx) async {
      final photoA = message(
        messageId: 'img-a',
        customType: IsmChatCustomMessageType.image,
        sentAt: 10000,
        attachments: [_imageAttachment(url: 'https://cdn/p1.jpg')],
      );
      final photoB = message(
        messageId: 'img-b',
        customType: IsmChatCustomMessageType.image,
        sentAt: 10500,
        attachments: [_imageAttachment(url: 'https://cdn/p2.jpg')],
      );
      ctx.page.messages = [photoA, photoB];
      ctx.page.isMessageSeleted = true;

      ctx.page.onMessageSelect(photoB);

      expect(ctx.page.selectedMessage.length, 2);
      expect(
        ctx.page.selectedMessage.map((m) => m.messageId).toList(),
        containsAll(['img-a', 'img-b']),
      );
    },
    setUpApi: (api) => api.registerSendDefaults(),
  );

  chatTestWidgets(
    'onMessageSelect batches images with the same mediaBatchId',
    (tester, ctx) async {
      const batchId = 424242;
      final photoA = message(
        messageId: 'batch-a',
        customType: IsmChatCustomMessageType.image,
        sentAt: 20000,
        metaData: IsmChatMetaData(
          customMetaData: {'mediaBatchId': batchId},
        ),
        attachments: [_imageAttachment(url: 'https://cdn/b1.jpg')],
      );
      final photoB = message(
        messageId: 'batch-b',
        customType: IsmChatCustomMessageType.image,
        sentAt: 50000,
        metaData: IsmChatMetaData(
          customMetaData: {'mediaBatchId': batchId},
        ),
        attachments: [_imageAttachment(url: 'https://cdn/b2.jpg')],
      );
      ctx.page.messages = [photoA, photoB];
      ctx.page.isMessageSeleted = true;

      ctx.page.onMessageSelect(photoA);

      expect(ctx.page.selectedMessage.length, 2);
    },
    setUpApi: (api) => api.registerSendDefaults(),
  );

  test('focusMenuAnchor resolves grid host and multi-attachment parent', () {
    final photoA = message(
      messageId: 'focus-a',
      customType: IsmChatCustomMessageType.image,
      sentAt: 40000,
      attachments: [_imageAttachment(url: 'https://cdn/fa.jpg')],
    );
    final photoB = message(
      messageId: 'focus-b',
      customType: IsmChatCustomMessageType.image,
      sentAt: 40100,
      attachments: [_imageAttachment(url: 'https://cdn/fb.jpg')],
    );
    final chronologic = [photoA, photoB];

    expect(
      IsmChatMediaGridGrouping.focusMenuAnchor(chronologic, photoB).messageId,
      'focus-a',
    );

    final multiParent = message(
      messageId: 'multi-host',
      customType: IsmChatCustomMessageType.multipleAttachments,
      sentAt: 50000,
      attachments: [
        _imageAttachment(url: 'https://cdn/m1.jpg'),
        _imageAttachment(url: 'https://cdn/m2.jpg'),
      ],
    );
    final gridSlice = multiParent.syntheticMessagesForGrid.last;
    final timeline = [multiParent];

    expect(
      IsmChatMediaGridGrouping.focusMenuAnchor(timeline, gridSlice).messageId,
      'multi-host',
    );
  });

  test('collectActionableGroup matches delete dialog grouping (two GIFs → 1)', () {
    final gifA = message(
      messageId: 'del-gif-a',
      customType: IsmChatCustomMessageType.image,
      sentAt: 7000,
      attachments: [_gifAttachment(url: 'https://cdn/dg1.gif')],
    );
    final gifB = message(
      messageId: 'del-gif-b',
      customType: IsmChatCustomMessageType.image,
      sentAt: 7500,
      attachments: [_gifAttachment(url: 'https://cdn/dg2.gif')],
    );
    final chronologic = [gifA, gifB];

    final group = IsmChatMediaGridGrouping.collectActionableGroup(
      chronologic,
      gifA,
    );

    expect(group.length, 1);
    expect(group.single.messageId, 'del-gif-a');
  });

  chatTestWidgets(
    'isMessageInSelection highlights grid host when a peer is selected',
    (tester, ctx) async {
      final photoA = message(
        messageId: 'host-a',
        customType: IsmChatCustomMessageType.image,
        sentAt: 30000,
        attachments: [_imageAttachment(url: 'https://cdn/h1.jpg')],
      );
      final photoB = message(
        messageId: 'host-b',
        customType: IsmChatCustomMessageType.image,
        sentAt: 30200,
        attachments: [_imageAttachment(url: 'https://cdn/h2.jpg')],
      );
      ctx.page.messages = [photoA, photoB];
      ctx.page.isMessageSeleted = true;
      ctx.page.selectedMessage = [photoB];

      expect(ctx.page.isMessageInSelection(photoA), isTrue);
    },
    setUpApi: (api) => api.registerSendDefaults(),
  );
}