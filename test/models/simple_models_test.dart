import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

/// Round-trip / copyWith / equality tests for the smaller models.
void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  group('IsmChatResponseModel', () {
    test('fromMap / toMap / copyWith / equality', () {
      const model = IsmChatResponseModel(
        data: '{"ok":true}',
        hasError: false,
        errorCode: 200,
      );
      final copy = IsmChatResponseModel.fromJson(model.toJson());
      expect(copy, model);
      expect(copy.hashCode, model.hashCode);
      expect(model.copyWith(hasError: true).hasError, isTrue);
      expect(model == model, isTrue);
      expect(model.toString(), contains('errorCode: 200'));
    });

    test('message factory encodes success and error', () {
      final ok = IsmChatResponseModel.message('done', isSuccess: true);
      expect(ok.hasError, isFalse);
      expect(ok.apiErrorMessage(), 'done');
      final err = IsmChatResponseModel.message('boom');
      expect(err.hasError, isTrue);
      expect(err.errorCode, 1000);
    });

    test('apiErrorMessage reads nested and raw bodies', () {
      expect(
        const IsmChatResponseModel(
          data: '{"error":{"message":"nested"}}',
          hasError: true,
          errorCode: 400,
        ).apiErrorMessage(),
        'nested',
      );
      expect(
        const IsmChatResponseModel(
          data: '{"errorMessage":"em"}',
          hasError: true,
          errorCode: 400,
        ).apiErrorMessage(),
        'em',
      );
      expect(
        const IsmChatResponseModel(
          data: '{"detail":"d"}',
          hasError: true,
          errorCode: 400,
        ).apiErrorMessage(),
        'd',
      );
      expect(
        const IsmChatResponseModel(
          data: '{"data":{"message":"inner"}}',
          hasError: true,
          errorCode: 400,
        ).apiErrorMessage(),
        'inner',
      );
      expect(
        const IsmChatResponseModel(
          data: '"plain"',
          hasError: true,
          errorCode: 400,
        ).apiErrorMessage(),
        'plain',
      );
      expect(
        const IsmChatResponseModel(
          data: 'raw text',
          hasError: true,
          errorCode: 400,
        ).apiErrorMessage(),
        'raw text',
      );
      expect(
        const IsmChatResponseModel(data: '', hasError: true, errorCode: 400)
            .apiErrorMessage(fallback: 'fb'),
        'fb',
      );
      expect(
        const IsmChatResponseModel(
          data: '<html>page</html>',
          hasError: true,
          errorCode: 400,
        ).apiErrorMessage(fallback: 'fb'),
        'fb',
      );
    });

    test('ModelWrapper holds data and status', () {
      const wrapper = ModelWrapper<String>(data: 'x', statusCode: 200);
      expect(wrapper.data, 'x');
      expect(wrapper.statusCode, 200);
    });
  });

  group('PresignedUrlModel', () {
    test('map / json / copyWith / equality', () {
      final model = PresignedUrlModel(
        ttl: 60,
        thumbnailUrl: 't',
        thumbnailPresignedUrl: 'tp',
        mediaUrl: 'm',
        mediaPresignedUrl: 'mp',
        mediaId: 'id',
        presignedUrl: 'p',
        msg: 'ok',
      );
      expect(PresignedUrlModel.fromJson(model.toJson()), model);
      expect(model.copyWith(mediaId: 'x').mediaId, 'x');
      expect(model == model, isTrue);
      expect(model.hashCode, isA<int>());
      expect(model.toString(), contains('mediaId: id'));
      expect(PresignedUrlModel.fromMap({}).mediaUrl, isNull);
    });
  });

  group('MessageStatusModel', () {
    test('map / json / copyWith / equality', () {
      final model = MessageStatusModel(
        deliveredToAll: true,
        messageId: 'm1',
        readByAll: false,
      );
      expect(MessageStatusModel.fromJson(model.toJson()), model);
      expect(model.copyWith(readByAll: true).readByAll, isTrue);
      expect(model == model, isTrue);
      expect(model.hashCode, isA<int>());
      expect(model.toString(), contains('messageId: m1'));
    });
  });

  group('Reaction', () {
    test('map / json / copyWith / equality', () {
      final model = Reaction(
        reactionType: IsmChatEmoji.yes,
        messageId: 'm',
        conversationId: 'c',
      );
      expect(Reaction.fromJson(model.toJson()), model);
      expect(model.copyWith(messageId: 'x').messageId, 'x');
      expect(model == model, isTrue);
      expect(model.hashCode, isA<int>());
      expect(model.toString(), contains('messageId: m'));
    });
  });

  group('IsmChatContactMetaDatModel', () {
    test('map / json / copyWith / equality', () {
      final model = IsmChatContactMetaDatModel(
        contactName: 'Alice',
        contactImageUrl: 'img',
        contactIdentifier: '+1',
        contactId: 'c1',
      );
      expect(IsmChatContactMetaDatModel.fromJson(model.toJson()), model);
      expect(model.copyWith(contactName: 'Bob').contactName, 'Bob');
      expect(model == model, isTrue);
      expect(model.hashCode, isA<int>());
    });
  });

  group('IsmChatReplyMessageModel', () {
    test('map / json / copyWith', () {
      final model = IsmChatReplyMessageModel(
        parentMessageBody: 'hi',
        parentMessageInitiator: true,
        parentMessageUserId: kMeId,
        parentMessageUserName: kMeName,
        parentMessageMessageType: IsmChatCustomMessageType.text,
        forMessageType: IsmChatCustomMessageType.reply,
        parentMessageAttachmentUrl: 'https://x',
        parentMessageAttachmentDuration: 3,
      );
      final copy = IsmChatReplyMessageModel.fromJson(model.toJson());
      expect(copy.parentMessageBody, 'hi');
      expect(copy.parentMessageMessageType, IsmChatCustomMessageType.text);
      expect(copy.copyWith(parentMessageBody: 'x').parentMessageBody, 'x');
      expect(IsmChatReplyMessageModel.fromMap({}).parentMessageBody, '');
    });
  });

  group('IsmChatUserListModel', () {
    test('map / json / copyWith / equality', () {
      final model = IsmChatUserListModel(users: [user()], pageToken: 'next');
      expect(IsmChatUserListModel.fromJson(model.toJson()).pageToken, 'next');
      expect(model.copyWith(pageToken: '').pageToken, '');
      expect(model == model, isTrue);
      expect(model.hashCode, isA<int>());
    });
  });

  group('UserDetails', () {
    test('fromMap fills defaults and displayName prefers first+last', () {
      final details = UserDetails.fromMap({
        'userId': 'u1',
        'userName': 'nick',
        'userIdentifier': 'u1@test.com',
        'userProfileImageUrl': 'p',
        'online': true,
        'isAdmin': true,
        'metaData': {'firstName': 'Ada', 'lastName': 'Lovelace'},
      });
      expect(details.displayName, 'Ada Lovelace');
      expect(details.isAdmin, isTrue);
      expect(details.pushNotification, isTrue);
      final roundTrip = UserDetails.fromJson(details.toJson());
      expect(roundTrip.userId, 'u1');
      expect(details.copyWith(userName: 'x').userName, 'x');
    });

    test('displayName falls back to userName', () {
      expect(user(name: 'Only').displayName, 'Only');
    });
  });

  group('IsmGiphyItem', () {
    test('fromMap reads send and preview urls', () {
      final item = IsmGiphyItem.fromMap({
        'id': 'g1',
        'images': {
          'original': {
            'url': 'https://giphy.test/send.gif',
            'width': '100',
            'height': '80',
          },
          'preview_gif': {
            'url': 'https://giphy.test/preview.gif',
            'width': 50,
            'height': 40,
          },
        },
      });
      expect(item.id, 'g1');
      expect(item.hasSendableUrl, isTrue);
      expect(item.extension, 'gif');
      expect(item.width, 100);
    });

    test('empty map has no sendable url', () {
      final item = IsmGiphyItem.fromMap({});
      expect(item.hasSendableUrl, isFalse);
      expect(item.width, isNull);
    });
  });

  group('IsmchPlatformFile / WebMediaModel', () {
    test('copyWith preserves and overrides fields', () {
      final file = IsmchPlatformFile(
        path: '/tmp/a.gif',
        name: 'a.gif',
        bytes: Uint8List.fromList(const [1]),
        size: 1,
        extension: 'gif',
      );
      expect(file.copyWith(name: 'b.gif').name, 'b.gif');
      expect(file.toMap()['name'], 'a.gif');
      final media = WebMediaModel(
        platformFile: file,
        isVideo: false,
        dataSize: '1 KB',
        caption: 'cap',
        duration: const Duration(seconds: 2),
      );
      expect(media.copyWith(isVideo: true).isVideo, isTrue);
      expect(media.copyWith(caption: 'x').caption, 'x');
    });
  });

  group('IsmChatBottomSheetAttachmentModel', () {
    test('holds type and labels', () {
      const model = IsmChatBottomSheetAttachmentModel(
        attachmentType: IsmChatAttachmentType.gallery,
        icon: Icons.image,
        label: 'Gallery',
        backgroundColor: Colors.blue,
      );
      expect(model.attachmentType, IsmChatAttachmentType.gallery);
      expect(model.label, 'Gallery');
    });
  });
}
