import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/test_bootstrap.dart';

Future<void> _seedGroup(ChatTestContext ctx) async {
  ctx.page
    ..conversation = groupConversation()
    ..currentUser = me();
  ctx.conversations.userDetails = me();
}

void main() {
  chatTestWidgets('sends a group text with mentions', (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: groupConversation()),
    );
    await _seedGroup(ctx);
    ctx.page.groupMembers = groupConversation().members ?? [];
    ctx.page.userMentionedList.add(
      MentionModel(userId: kOpponentId, wordCount: 1, order: 0),
    );
    ctx.page.chatInputController.text = 'hey @Opponent';
    ctx.page.sendTextMessage(
      conversationId: kGroupConversationId,
      userId: kOpponentId,
    );
    await pumpUntil(
      tester,
      () => ctx.api.requestsTo('/chat/message', method: 'POST').isNotEmpty,
    );
    final req = ctx.api.requestsTo('/chat/message', method: 'POST').last;
    expect(req.json['conversationId'], kGroupConversationId);
    expect(req.json['mentionedUsers'], isNotEmpty);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('addMembers / removeMember refresh conversation details',
      (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: groupConversation()),
    );
    await _seedGroup(ctx);
    await drive(tester, () => ctx.page.addMembers(memberIds: ['user-new']));
    expect(
      ctx.api.requestsTo('/members', method: 'PUT').last.json['members'],
      ['user-new'],
    );
    await drive(tester, () => ctx.page.removeMember(kOpponentId));
    expect(ctx.api.requestsTo('/members', method: 'DELETE'), isNotEmpty);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('changeGroupTitle and changeGroupProfile', (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: groupConversation()),
    );
    await _seedGroup(ctx);
    ctx.page.messages.add(message(conversationId: kGroupConversationId));
    await drive(
      tester,
      () => ctx.page.changeGroupTitle(
        conversationTitle: 'Renamed',
        conversationId: kGroupConversationId,
        isLoading: false,
      ),
    );
    expect(ctx.page.conversation?.conversationTitle, 'Renamed');
    await drive(
      tester,
      () => ctx.page.changeGroupProfile(
        conversationImageUrl: 'https://img.test/new.png',
        conversationId: kGroupConversationId,
        isLoading: false,
      ),
    );
    expect(ctx.page.conversation?.conversationImageUrl,
        'https://img.test/new.png');
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('makeAdmin / removeAdmin / leaveConversation',
      (tester, ctx) async {
    await tester.runAsync(
      () => ctx.db!.saveConversation(conversation: groupConversation()),
    );
    await _seedGroup(ctx);
    await drive(tester, () => ctx.page.makeAdmin(kOpponentId, kOpponentName));
    expect(ctx.api.requestsTo('/admin', method: 'PUT'), isNotEmpty);
    await drive(
      tester,
      () => ctx.page.removeAdmin(kOpponentId, kOpponentName),
    );
    expect(ctx.api.requestsTo('/admin', method: 'DELETE'), isNotEmpty);
    expect(
      await drive(
        tester,
        () => ctx.page.leaveConversation(kGroupConversationId),
      ),
      isTrue,
    );
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('getEligibleMembers populates the list', (tester, ctx) async {
    await _seedGroup(ctx);
    await drive(
      tester,
      () => ctx.page.getEligibleMembers(conversationId: kGroupConversationId),
    );
    expect(ctx.page.groupEligibleUser, isNotEmpty);
    expect(
      ctx.page.groupEligibleUser.first.userDetails.userId,
      'user-eligible',
    );
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('message deliver and read-by lists', (tester, ctx) async {
    final delivered = await drive(
      tester,
      () => ctx.page.viewModel.getMessageDeliverTime(
        conversationId: kGroupConversationId,
        messageId: 'm1',
      ),
    );
    final read = await drive(
      tester,
      () => ctx.page.viewModel.getMessageReadTime(
        conversationId: kGroupConversationId,
        messageId: 'm1',
      ),
    );
    expect(delivered, isNotEmpty);
    expect(read, isNotEmpty);
  }, setUpApi: (api) => api.registerSendDefaults());
}
