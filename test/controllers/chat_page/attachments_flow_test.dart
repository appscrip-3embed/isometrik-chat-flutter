import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/test_bootstrap.dart';

Future<void> _seed(ChatTestContext ctx) async {
  ctx.page
    ..conversation = directConversation()
    ..currentUser = me();
  ctx.conversations.userDetails = me();
}

WebMediaModel _webMedia({
  String name = 'clip.gif',
  String extension = 'gif',
  bool isVideo = false,
}) =>
    WebMediaModel(
      platformFile: IsmchPlatformFile(
        name: name,
        extension: extension,
        bytes: Uint8List.fromList(const [1, 2, 3, 4]),
        size: 4,
        path: '',
      ),
      isVideo: isVideo,
      dataSize: '4 KB',
    );

void main() {
  chatTestWidgets('sendLocation posts a location attachment', (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seed(ctx);
    ctx.page.sendLocation(
      latitude: 12.97,
      longitude: 77.59,
      placeId: 'place-1',
      locationName: 'Office',
      locationSubName: 'MG Road',
      conversationId: kDirectConversationId,
      userId: kOpponentId,
    );
    await pumpUntil(
      tester,
      () => ctx.api.requestsTo('/chat/message', method: 'POST').isNotEmpty,
    );
    expect(
      ctx.page.messages.any(
        (m) => m.customType == IsmChatCustomMessageType.location,
      ),
      isTrue,
    );
    final req = ctx.api.requestsTo('/chat/message', method: 'POST').last;
    expect(req.json['customType'], IsmChatCustomMessageType.location.value);
    expect(req.json['attachments'], isNotEmpty);
    expect(req.json['attachments'].first['latitude'], 12.97);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('sendContact posts contact metadata', (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seed(ctx);
    ctx.page.sendContact(
      conversationId: kDirectConversationId,
      userId: kOpponentId,
      contacts: [
        Contact(
          id: 'c1',
          displayName: 'Alice',
          phones: [Phone(number: '+15550001')],
        ),
      ],
    );
    await pumpUntil(
      tester,
      () => ctx.api.requestsTo('/chat/message', method: 'POST').isNotEmpty,
    );
    expect(
      ctx.page.messages.any(
        (m) => m.customType == IsmChatCustomMessageType.contact,
      ),
      isTrue,
    );
    final meta = ctx.api
        .requestsTo('/chat/message', method: 'POST')
        .last
        .json['metaData'] as Map;
    expect(meta['contacts'], isNotEmpty);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('sendAudio uploads via presigned URL then sends',
      (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seed(ctx);
    final file = File(
      '${Directory.systemTemp.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a',
    )..writeAsBytesSync(const [1, 2, 3, 4, 5]);
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    ctx.page.sendAudio(
      path: file.path,
      conversationId: kDirectConversationId,
      userId: kOpponentId,
      duration: const Duration(seconds: 2),
    );
    await pumpUntil(
      tester,
      () => ctx.api.requestsTo('/chat/message', method: 'POST').isNotEmpty,
    );
    expect(ctx.api.requestsTo('/presignedurls', method: 'POST'), isNotEmpty);
    expect(
      ctx.api.requestsTo('/chat/message', method: 'POST').last.json['customType'],
      IsmChatCustomMessageType.audio.value,
    );
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('ismPostMediaUrl sends after a successful upload',
      (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seed(ctx);
    final msg = message(
      customType: IsmChatCustomMessageType.image,
      attachments: [attachment(IsmChatMediaType.image)],
      sentAt: 4242,
    )..messageId = '';
    ctx.page.messages.add(msg);
    await drive(
      tester,
      () => ctx.page.ismPostMediaUrl(
        ismChatChatMessageModel: msg,
        notificationBody: 'photo',
        notificationTitle: kMeName,
        nameWithExtension: 'a.jpg',
        createdAt: 4242,
        mediaType: IsmChatMediaType.image.value,
        bytes: Uint8List.fromList(const [1, 2, 3]),
        imageAndFile: true,
        mediaId: '4242',
      ),
    );
    expect(ctx.api.requestsTo('/presignedurls', method: 'POST'), isNotEmpty);
    expect(ctx.api.requestsTo('/chat/message', method: 'POST'), isNotEmpty);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('ismPostMediaUrl marks the bubble failed when upload fails',
      (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seed(ctx);
    ctx.api.on(
      'POST',
      '/presignedurls',
      const FakeResponse('{}', status: 500),
    );
    final msg = message(
      customType: IsmChatCustomMessageType.image,
      attachments: [attachment(IsmChatMediaType.image)],
      sentAt: 777,
    )..messageId = '';
    ctx.page.messages.add(msg);
    await drive(
      tester,
      () => ctx.page.ismPostMediaUrl(
        ismChatChatMessageModel: msg,
        notificationBody: 'photo',
        notificationTitle: kMeName,
        nameWithExtension: 'a.jpg',
        createdAt: 777,
        mediaType: IsmChatMediaType.image.value,
        bytes: Uint8List.fromList(const [1]),
        imageAndFile: true,
        mediaId: '777',
      ),
    );
    expect(
      ctx.api.requestsForPath('/chat/message', method: 'POST'),
      isEmpty,
    );
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('sendGiphyItem posts a gif sticker payload', (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seed(ctx);
    await drive(
      tester,
      () => ctx.page.sendGiphyItem(
        const IsmGiphyItem(
          id: 'gif-1',
          previewUrl: 'https://giphy.test/p.gif',
          sendUrl: 'https://giphy.test/s.gif',
          extension: 'gif',
          width: 100,
          height: 80,
        ),
        isSticker: false,
      ),
    );
    await pumpUntil(
      tester,
      () => ctx.api.requestsTo('/chat/message', method: 'POST').isNotEmpty,
    );
    final att = ctx.api
        .requestsTo('/chat/message', method: 'POST')
        .last
        .json['attachments'] as List;
    expect(att.first['attachmentSchemaType'], 'GifSticker');
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('sendGif with skipConversationCreate queues a visual message',
      (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seed(ctx);
    await drive(
      tester,
      () => ctx.page.sendGif(
        conversationId: kDirectConversationId,
        userId: kOpponentId,
        webMediaModel: _webMedia(),
        skipConversationCreate: true,
      ),
    );
    expect(
      ctx.page.messages.any((m) => m.body.toLowerCase().contains('gif')),
      isTrue,
    );
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('sendSticker builds a sticker message', (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seed(ctx);
    await drive(
      tester,
      () => ctx.page.sendSticker(
        conversationId: kDirectConversationId,
        userId: kOpponentId,
        webMediaModel: _webMedia(name: 's.webp', extension: 'webp'),
      ),
    );
    expect(ctx.page.messages, isNotEmpty);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('sendKeyboardInsertedContent sends a gif from IME bytes',
      (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: directConversation()),
    );
    await _seed(ctx);
    await drive(
      tester,
      () => ctx.page.sendKeyboardInsertedContent(
        KeyboardInsertedContent(
          mimeType: 'image/gif',
          uri: 'content://ime/gif',
          data: Uint8List.fromList(List<int>.filled(16, 1)),
        ),
      ),
    );
    expect(ctx.page.messages, isNotEmpty);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('sendAudio with empty path is a no-op', (tester, ctx) async {
    await _seed(ctx);
    ctx.page.sendAudio(
      path: '',
      conversationId: kDirectConversationId,
      userId: kOpponentId,
    );
    await settle(tester, rounds: 2);
    expect(ctx.api.requestsTo('/chat/message', method: 'POST'), isEmpty);
  }, setUpApi: (api) => api.registerSendDefaults());
}
