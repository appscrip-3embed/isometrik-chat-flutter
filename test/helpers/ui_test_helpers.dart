import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import 'fake_api.dart';
import 'fixtures.dart';
import 'test_bootstrap.dart';

IsmChatConversationProperties? _savedConversationProperties;
IsmChatPageProperties? _savedPageProperties;

/// Avoids [CachedNetworkImage] / sqflite in widget tests (VM has no DB factory).
Widget testConversationProfileImage(
  BuildContext context,
  IsmChatConversationModel? conversation,
  String profileUrl,
) =>
    SizedBox(
      width: 48,
      height: 48,
      child: ColoredBox(
        color: Colors.grey.shade300,
        child: Center(
          child: Text(
            (conversation?.chatName.isNotEmpty ?? false)
                ? conversation!.chatName[0]
                : 'U',
          ),
        ),
      ),
    );

/// Stub network-backed avatars in list rows and chat headers during UI tests.
void applyUiTestPropertyOverrides() {
  _savedConversationProperties = IsmChatProperties.conversationProperties;
  _savedPageProperties = IsmChatProperties.chatPageProperties;

  IsmChatProperties.conversationProperties = IsmChatConversationProperties(
    cardElementBuilders: IsmChatCardProperties(
      profileImageBuilder: testConversationProfileImage,
    ),
    allowedConversations: _savedConversationProperties!.allowedConversations,
    conversationPosition: _savedConversationProperties!.conversationPosition,
  );

  IsmChatProperties.chatPageProperties = IsmChatPageProperties(
    header: IsmChatPageHeaderProperties(
      profileImageBuilder: testConversationProfileImage,
    ),
    attachments: _savedPageProperties!.attachments,
    features: _savedPageProperties!.features,
    messageStatus: _savedPageProperties!.messageStatus,
  );
}

void restoreUiTestPropertyOverrides() {
  if (_savedConversationProperties != null) {
    IsmChatProperties.conversationProperties = _savedConversationProperties!;
    _savedConversationProperties = null;
  }
  if (_savedPageProperties != null) {
    IsmChatProperties.chatPageProperties = _savedPageProperties!;
    _savedPageProperties = null;
  }
}

/// Registers MQTT so header subtitle Obx (typing) does not throw in full-page UI tests.
void registerMqttForUiTests(FakeChatApi api) {
  if (Get.isRegistered<IsmChatMqttController>()) return;
  Get.put(
    IsmChatMqttController(
      IsmChatMqttViewModel(IsmChatMqttRepository(apiWrapper: api.wrapper())),
    ),
  );
}

/// Shared helpers for SDK UI widget / screen tests.
///
/// **Reuse:** prefer [seedChatPageForUi] and [seedConversationListForUi] over
/// hand-setting controller fields so a lifecycle change only needs fixing here.
/// Use [pumpSdkScreen] when mounting full views that need the same host app as
/// [pumpChatHost] (ScreenUtil + GetMaterialApp + navigator key).

/// Registers a non-empty conversation list for controllers that fetch on init.
void registerConversationListApi(
  FakeChatApi api, {
  List<Map<String, dynamic>>? conversations,
}) {
  api.on(
    'GET',
    '/chat/conversations',
    FakeResponse.json({
      'conversations': conversations ??
          [
            conversationJson(),
            conversationJson(
              conversationId: 'c2',
              isGroup: true,
              title: 'Group UI Test',
            ),
          ],
    }),
  );
}

/// Puts the chat page controller into a state where [IsmChatPageView] can render
/// messages instead of the loading / empty placeholders.
void seedChatPageForUi(
  IsmChatPageController page, {
  IsmChatConversationsController? conversations,
  IsmChatConversationModel? conversation,
  List<IsmChatMessageModel>? messages,
}) {
  final conv = conversation ?? directConversation();
  page
    ..conversation = conv
    ..currentUser = me()
    ..isMessagesLoading = false
    ..messages = messages ?? [message(body: 'ui-smoke-message')]
    ..update();
  if (conversations != null) {
    conversations
      ..currentConversation = conv
      ..currentConversationId = conv.conversationId ?? kDirectConversationId;
  }
}

/// Fills the conversations list so [IsmChatConversations] / [IsmChatConversationList]
/// show rows instead of loading or empty states.
void seedConversationListForUi(
  IsmChatConversationsController conversations, {
  List<IsmChatConversationModel>? items,
}) {
  conversations.conversations
    ..clear()
    ..addAll(
      items ??
          [
            directConversation(),
            groupConversation(title: 'Group UI Test'),
          ],
    );
  conversations.isConversationsLoading = false;
  conversations.intilizedContrller = true;
  conversations.update();
}

/// Opens [IsmChatPageView] after [startInit] finishes, then re-seeds messages
/// (init clears the in-memory list while loading from DB/API).
Future<void> mountChatPageForUi(
  WidgetTester tester,
  ChatTestContext ctx, {
  String messageBody = 'on-screen-message',
}) async {
  final conv = directConversation();
  await tester.runAsync(() async {
    await ctx.db!.saveConversation(conversation: conv);
    await ctx.db!.saveMessage(message(body: messageBody));
  });
  ctx.conversations
    ..currentConversation = conv
    ..currentConversationId = kDirectConversationId;
  ctx.api.on(
    'GET',
    '/chat/messages',
    FakeResponse.json({
      'messages': [messageJson(body: messageBody)],
    }),
  );
  await pumpSdkScreen(
    tester,
    child: const IsmChatPageView(),
  );
  await pumpUntil(tester, () => !ctx.page.isMessagesLoading);
  seedChatPageForUi(
    ctx.page,
    conversations: ctx.conversations,
    conversation: conv,
    messages: [message(body: messageBody)],
  );
  await settle(tester);
}

/// Replaces the host widget under test while keeping global SDK config intact.
Future<void> pumpSdkScreen(
  WidgetTester tester, {
  required Widget child,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 745),
      builder: (_, __) => GetMaterialApp(
        navigatorKey: IsmChatConfig.kNavigatorKey,
        home: Builder(
          builder: (context) {
            IsmChatConfig.context = context;
            return child;
          },
        ),
      ),
    ),
  );
  await settle(tester);
}
