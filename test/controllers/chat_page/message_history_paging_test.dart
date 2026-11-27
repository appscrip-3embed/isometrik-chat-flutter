import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/test_bootstrap.dart';

/// Open-chat and scroll-up paging query params when Hive has thin vs full history.
void main() {
  Future<void> seedDbConversation(
    ChatTestContext ctx, {
    required Map<String, IsmChatMessageModel> messages,
  }) async {
    final conversation = directConversation(messages: messages);
    await ctx.db!.saveConversation(conversation: conversation);
    ctx.page
      ..conversation = conversation
      ..currentUser = me();
  }

  group('message history paging', () {
    chatTestWidgets(
      'thin cache → open sync omits lastMessageTimestamp',
      (tester, ctx) async {
        final only = message(sentAt: 9000, messageId: 'only-one');
        await tester.runAsync(
          () => seedDbConversation(ctx, messages: {only.key: only}),
        );
        ctx.api.on(
          'GET',
          '/chat/messages',
          FakeResponse.json({
            'messages': [
              messageJson(messageId: 'only-one', sentAt: 9000),
              messageJson(messageId: 'older-1', sentAt: 8000),
            ],
          }),
        );

        await drive(tester, () => ctx.page.getMessagesFromDB(kDirectConversationId));
        await drive(tester, ctx.page.getMessagesFromAPI);

        final query =
            ctx.api.requestsTo('/chat/messages').last.url.queryParameters;
        expect(query['skip'], '0');
        expect(query.containsKey('lastMessageTimestamp'), isFalse);
      },
      setUpApi: (api) => api.registerSendDefaults(),
    );

    chatTestWidgets(
      'full cache → open sync still uses lastMessageTimestamp',
      (tester, ctx) async {
        final map = <String, IsmChatMessageModel>{};
        for (var i = 0; i < IsmChatPageController.messagesApiPageLimit; i++) {
          final m = message(sentAt: 1000 + i, messageId: 'msg-$i');
          map[m.key] = m;
        }
        await tester.runAsync(() => seedDbConversation(ctx, messages: map));
        ctx.api.on(
          'GET',
          '/chat/messages',
          FakeResponse.json({'messages': [messageJson(sentAt: 9999)]}),
        );

        await drive(tester, () => ctx.page.getMessagesFromDB(kDirectConversationId));
        await drive(tester, ctx.page.getMessagesFromAPI);

        final query =
            ctx.api.requestsTo('/chat/messages').last.url.queryParameters;
        expect(query['skip'], '0');
        expect(query.containsKey('lastMessageTimestamp'), isTrue);
      },
      setUpApi: (api) => api.registerSendDefaults(),
    );

    chatTestWidgets(
      'scroll pagination uses skip from real count and no timestamp',
      (tester, ctx) async {
        final only = message(sentAt: 5000, messageId: 'paginate-seed');
        await tester.runAsync(
          () => seedDbConversation(ctx, messages: {only.key: only}),
        );
        await drive(tester, () => ctx.page.getMessagesFromDB(kDirectConversationId));
        final expectedSkip = ctx.page.realMessageCountForPaging();

        ctx.api.on(
          'GET',
          '/chat/messages',
          FakeResponse.json({
            'messages': [messageJson(messageId: 'older', sentAt: 4000)],
          }),
        );
        await drive(
          tester,
          () => ctx.page.getMessagesFromAPI(forPagination: true),
        );

        final query =
            ctx.api.requestsTo('/chat/messages').last.url.queryParameters;
        expect(query['skip'], '$expectedSkip');
        expect(query.containsKey('lastMessageTimestamp'), isFalse);
      },
      setUpApi: (api) => api.registerSendDefaults(),
    );

    chatTestWidgets(
      'skip advances by raw API rows, including rows filtered client-side',
      (tester, ctx) async {
        final seed = message(sentAt: 90000, messageId: 'seed');
        await tester.runAsync(
          () => seedDbConversation(ctx, messages: {seed.key: seed}),
        );
        await drive(tester, () => ctx.page.getMessagesFromDB(kDirectConversationId));

        // Full first page: 15 real + 5 reaction events (dropped by the VM).
        const limit = IsmChatPageController.messagesApiPageLimit;
        ctx.api.on(
          'GET',
          '/chat/messages',
          FakeResponse.json({
            'messages': [
              for (var i = 0; i < 15; i++)
                messageJson(messageId: 'real-$i', sentAt: 80000 - i),
              for (var i = 0; i < 5; i++)
                messageJson(
                  messageId: 'react-$i',
                  sentAt: 70000 - i,
                  action: IsmChatActionEvents.reactionAdd.name,
                ),
            ],
          }),
        );
        await drive(tester, ctx.page.getMessagesFromAPI);
        expect(ctx.page.hasReachedOldestMessage, isFalse);

        final before = ctx.api.requestsTo('/chat/messages').length;
        await drive(
          tester,
          () => ctx.page.getMessagesFromAPI(forPagination: true),
        );
        // First older request (the stub repeats rows, so follow-ups may run).
        final query = ctx.api
            .requestsTo('/chat/messages')[before]
            .url
            .queryParameters;
        expect(query['skip'], '$limit');
      },
      setUpApi: (api) => api.registerSendDefaults(),
    );

    chatTestWidgets(
      'short page marks history exhausted and stops older requests',
      (tester, ctx) async {
        final seed = message(sentAt: 5000, messageId: 'short-seed');
        await tester.runAsync(
          () => seedDbConversation(ctx, messages: {seed.key: seed}),
        );
        await drive(tester, () => ctx.page.getMessagesFromDB(kDirectConversationId));
        ctx.api.on(
          'GET',
          '/chat/messages',
          FakeResponse.json({
            'messages': [messageJson(messageId: 'short-seed', sentAt: 5000)],
          }),
        );
        await drive(tester, ctx.page.getMessagesFromAPI);
        expect(ctx.page.hasReachedOldestMessage, isTrue);

        final before = ctx.api.requestsTo('/chat/messages').length;
        await drive(
          tester,
          () => ctx.page.getMessagesFromAPI(forPagination: true),
        );
        expect(ctx.api.requestsTo('/chat/messages').length, before);
      },
      setUpApi: (api) => api.registerSendDefaults(),
    );

    chatTestWidgets(
      'full forward sync (possible gap) pages down from the newest page',
      (tester, ctx) async {
        const limit = IsmChatPageController.messagesApiPageLimit;
        final map = <String, IsmChatMessageModel>{};
        for (var i = 0; i < limit; i++) {
          final m = message(sentAt: 1000 + i, messageId: 'old-$i');
          map[m.key] = m;
        }
        await tester.runAsync(() => seedDbConversation(ctx, messages: map));
        await drive(tester, () => ctx.page.getMessagesFromDB(kDirectConversationId));

        // A whole page newer than the cache, newest first like the real API.
        ctx.api.on(
          'GET',
          '/chat/messages',
          FakeResponse.json({
            'messages': [
              for (var i = 0; i < limit; i++)
                messageJson(messageId: 'new-$i', sentAt: 90000 - i),
            ],
          }),
        );
        await drive(tester, ctx.page.getMessagesFromAPI);

        ctx.api.on(
          'GET',
          '/chat/messages',
          FakeResponse.json({
            'messages': [messageJson(messageId: 'gap-0', sentAt: 50000)],
          }),
        );
        await drive(
          tester,
          () => ctx.page.getMessagesFromAPI(forPagination: true),
        );
        final query =
            ctx.api.requestsTo('/chat/messages').last.url.queryParameters;
        // Not 40 (cache + page): rows between the page and the cache would be
        // skipped.
        expect(query['skip'], '$limit');
      },
      setUpApi: (api) => api.registerSendDefaults(),
    );

    chatTestWidgets(
      'all-duplicate older page keeps paging, bounded',
      (tester, ctx) async {
        const limit = IsmChatPageController.messagesApiPageLimit;
        final map = <String, IsmChatMessageModel>{};
        for (var i = 0; i < limit; i++) {
          final m = message(sentAt: 1000 + i, messageId: 'dup-$i');
          map[m.key] = m;
        }
        await tester.runAsync(() => seedDbConversation(ctx, messages: map));
        await drive(tester, () => ctx.page.getMessagesFromDB(kDirectConversationId));

        // Every page returns rows already cached.
        ctx.api.on(
          'GET',
          '/chat/messages',
          FakeResponse.json({
            'messages': [
              for (var i = limit - 1; i >= 0; i--)
                messageJson(messageId: 'dup-$i', sentAt: 1000 + i),
            ],
          }),
        );
        final before = ctx.api.requestsTo('/chat/messages').length;
        await drive(
          tester,
          () => ctx.page.getMessagesFromAPI(forPagination: true),
        );
        final requests =
            ctx.api.requestsTo('/chat/messages').skip(before).toList();
        // First request + 5 follow-ups, each one page further back.
        expect(requests.length, 6);
        expect(
          requests.map((r) => r.url.queryParameters['skip']),
          [for (var i = 1; i <= 6; i++) '${limit * i}'],
        );
      },
      setUpApi: (api) => api.registerSendDefaults(),
    );
  });
}