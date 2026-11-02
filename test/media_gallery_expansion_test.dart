import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

void main() {
  group('expandDocsGalleryItems', () {
    test('flattens multipleAttachments document list', () {
      final multi = IsmChatMessageModel(
        body: 'AttachmentMessage:Multiple',
        sentAt: 1,
        sentByMe: true,
        customType: IsmChatCustomMessageType.multipleAttachments,
        attachments: [
          AttachmentModel(
            attachmentType: IsmChatMediaType.file,
            mediaUrl: 'https://a/1.pdf',
            mediaId: '1',
            name: 'one.pdf',
          ),
          AttachmentModel(
            attachmentType: IsmChatMediaType.file,
            mediaUrl: 'https://a/2.pdf',
            mediaId: '2',
            name: 'two.pdf',
          ),
        ],
      );
      final single = IsmChatMessageModel(
        body: '',
        sentAt: 2,
        sentByMe: true,
        customType: IsmChatCustomMessageType.file,
        attachments: [
          AttachmentModel(
            attachmentType: IsmChatMediaType.file,
            mediaUrl: 'https://a/3.pdf',
            mediaId: '3',
            name: 'three.pdf',
          ),
        ],
      );

      final docs = expandDocsGalleryItems([multi, single]);
      expect(docs.length, 3);
      expect(
        docs.map((m) => m.attachments?.first.name).toList(),
        ['one.pdf', 'two.pdf', 'three.pdf'],
      );
    });
  });

  group('sortMessages with shared sentAt', () {
    test('keeps every gallery row when timestamps match', () {
      final parent = IsmChatMessageModel(
        messageId: 'msg-1',
        body: 'AttachmentMessage:Multiple',
        sentAt: 1700000000000,
        sentByMe: true,
        customType: IsmChatCustomMessageType.multipleAttachments,
        attachments: [
          AttachmentModel(
            attachmentType: IsmChatMediaType.image,
            mediaUrl: 'https://a/1.jpg',
            mediaId: '1',
          ),
          AttachmentModel(
            attachmentType: IsmChatMediaType.image,
            mediaUrl: 'https://a/2.jpg',
            mediaId: '2',
          ),
        ],
      );
      final gallery = expandMediaGalleryItems([parent]);
      expect(gallery.length, 2);

      final sorted =
          IsmChatCommonViewModel(IsmChatCommonRepository()).sortMessages(
        gallery,
      );
      final mediaRows = sorted
          .where((m) => m.customType != IsmChatCustomMessageType.date)
          .toList();
      expect(mediaRows.length, 2);
    });
  });

  group('expandMediaGalleryItems', () {
    test('flattens multipleAttachments media grid', () {
      final multi = IsmChatMessageModel(
        body: 'AttachmentMessage:Multiple',
        sentAt: 1,
        sentByMe: true,
        customType: IsmChatCustomMessageType.multipleAttachments,
        attachments: [
          AttachmentModel(
            attachmentType: IsmChatMediaType.image,
            mediaUrl: 'https://a/1.jpg',
            mediaId: '1',
          ),
          AttachmentModel(
            attachmentType: IsmChatMediaType.video,
            mediaUrl: 'https://a/2.mp4',
            mediaId: '2',
          ),
        ],
      );
      final single = IsmChatMessageModel(
        body: '',
        sentAt: 2,
        sentByMe: true,
        customType: IsmChatCustomMessageType.image,
        attachments: [
          AttachmentModel(
            attachmentType: IsmChatMediaType.image,
            mediaUrl: 'https://a/3.jpg',
            mediaId: '3',
          ),
        ],
      );

      final gallery = expandMediaGalleryItems([multi, single]);
      expect(gallery.length, 3);
      expect(
        gallery.map((m) => m.customType).toList(),
        [
          IsmChatCustomMessageType.image,
          IsmChatCustomMessageType.video,
          IsmChatCustomMessageType.image,
        ],
      );
    });
  });

  group('indexInMediaGallery', () {
    test('finds synthetic slice not present in messages list', () {
      final parent = IsmChatMessageModel(
        messageId: 'msg-1',
        body: 'AttachmentMessage:Multiple',
        sentAt: 10,
        sentByMe: true,
        customType: IsmChatCustomMessageType.multipleAttachments,
        attachments: [
          AttachmentModel(
            attachmentType: IsmChatMediaType.image,
            mediaUrl: 'https://a/1.jpg',
            mediaId: 'a',
          ),
          AttachmentModel(
            attachmentType: IsmChatMediaType.image,
            mediaUrl: 'https://a/2.jpg',
            mediaId: 'b',
          ),
        ],
      );
      final gallery = expandMediaGalleryItems([parent]);
      final slice = parent.syntheticMessagesForGrid[1];
      expect(indexInMediaGallery(gallery, slice), 1);
      expect(
        indexInMediaGallery(gallery, parent, attachmentIndex: 1),
        1,
      );
    });
  });

  group('multiple attachment wire', () {
    test('image plus video stays a media grid', () {
      final message = IsmChatMessageModel(
        body: 'AttachmentMessage:Multiple',
        sentAt: 1,
        sentByMe: true,
        customType: IsmChatCustomMessageType.multipleAttachments,
        attachments: [
          AttachmentModel(
            attachmentType: IsmChatMediaType.image,
            mediaId: '1',
          ),
          AttachmentModel(
            attachmentType: IsmChatMediaType.video,
            mediaId: '2',
          ),
        ],
      );

      expect(
        message.multipleAttachmentLayout,
        MultipleAttachmentLayout.mediaGrid,
      );
      expect(message.syntheticMessagesForGrid.length, 2);
    });

    test('caption in body is the visible caption', () {
      final message = IsmChatMessageModel(
        body: 'Look at these',
        sentAt: 1,
        sentByMe: true,
        customType: IsmChatCustomMessageType.multipleAttachments,
        attachments: [
          AttachmentModel(
            attachmentType: IsmChatMediaType.image,
            mediaId: '1',
          ),
          AttachmentModel(
            attachmentType: IsmChatMediaType.file,
            mediaId: '2',
          ),
        ],
      );

      expect(message.multipleAttachmentCaption, 'Look at these');
      expect(message.multipleAttachmentLayout, isNull);
      expect(message.syntheticMessagesForGrid.length, 1);
      expect(
        message.syntheticMessagesForGrid.first.customType,
        IsmChatCustomMessageType.image,
      );
    });

    test('outbound attachment body uses caption or empty', () {
      expect(
        IsmChatUtility.outboundAttachmentBody('  hi  '),
        'hi',
      );
      expect(IsmChatUtility.outboundAttachmentBody(''), isEmpty);
      expect(
        IsmChatUtility.outboundAttachmentBody(
          '',
          mediaType: IsmChatMediaType.gif,
        ),
        IsmChatStrings.gif,
      );
      expect(
        IsmChatUtility.outboundAttachmentBody(
          'note',
          mediaType: IsmChatMediaType.sticker,
        ),
        'note',
      );
      expect(
        IsmChatUtility.outboundAttachmentBody(
          null,
          mediaType: IsmChatMediaType.sticker,
        ),
        IsmChatStrings.sticker,
      );
      expect(
        IsmChatUtility.outboundAttachmentBody(
          '',
          mediaType: IsmChatMediaType.video,
        ),
        IsmChatStrings.video,
      );
      expect(
        IsmChatUtility.outboundAttachmentBody(
          null,
          mediaType: IsmChatMediaType.image,
        ),
        IsmChatStrings.image,
      );
      expect(
        IsmChatUtility.outboundAttachmentCaptionMeta('note'),
        'note',
      );
      expect(IsmChatUtility.outboundAttachmentCaptionMeta('  '), isNull);
    });

    test('placeholder body is not shown as a caption', () {
      final message = IsmChatMessageModel(
        body: 'AttachmentMessage:Multiple',
        sentAt: 1,
        sentByMe: true,
        customType: IsmChatCustomMessageType.multipleAttachments,
      );

      expect(message.multipleAttachmentCaption, isEmpty);
    });

    test('AttachmentMessage:Doc parses as a file and is what we send', () {
      expect(
        IsmChatCustomMessageType.fromString('AttachmentMessage:Doc'),
        IsmChatCustomMessageType.file,
      );
      expect(
        IsmChatCustomMessageType.fromString('AttachmentMessage:File'),
        IsmChatCustomMessageType.file,
      );
      expect(
        IsmChatCustomMessageType.file.value,
        'AttachmentMessage:Doc',
      );
    });
  });
}
