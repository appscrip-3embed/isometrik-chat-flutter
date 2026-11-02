import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  testWidgets('IsmChatInputField accepts typed text', (tester) async {
    final controller = TextEditingController();
    await pumpChatHost(
      tester,
      child: IsmChatInputField(
        controller: controller,
        hint: 'Type a message',
        autofocus: false,
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'hello');
    expect(controller.text, 'hello');
  });

  testWidgets('IsmChatTextMessage renders the body in RichText', (tester) async {
    await pumpChatHost(
      tester,
      child: IsmChatTextMessage(message(body: 'bubble-text')),
    );
    expect(find.byType(IsmChatTextMessage), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('bubble-text'),
      ),
      findsWidgets,
    );
  });

  testWidgets('contact bubble shows the contact name', (tester) async {
    await pumpChatHost(
      tester,
      child: IsmChatContactMessage(
        message(
          body: IsmChatStrings.contact,
          customType: IsmChatCustomMessageType.contact,
          metaData: IsmChatMetaData(
            contacts: [
              IsmChatContactMetaDatModel(contactName: 'Alice'),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(IsmChatContactMessage), findsOneWidget);
    expect(find.textContaining('Alice'), findsWidgets);
  });

  chatTestWidgets('IsmChatAttachmentCard builds a grid', (tester, ctx) async {
    final context = IsmChatConfig.kNavigatorKey.currentContext!;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const IsmChatAttachmentCard(),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('each attachment type has a bubble widget constructor',
      (tester, ctx) async {
    final msgs = attachmentMessages();
    expect(
      IsmChatImageMessage(msgs[IsmChatCustomMessageType.image]!),
      isA<Widget>(),
    );
    expect(
      IsmChatVideoMessage(msgs[IsmChatCustomMessageType.video]!),
      isA<Widget>(),
    );
    expect(
      IsmChatAudioMessage(msgs[IsmChatCustomMessageType.audio]!),
      isA<Widget>(),
    );
    expect(
      IsmChatFileMessage(msgs[IsmChatCustomMessageType.file]!),
      isA<Widget>(),
    );
    expect(
      IsmChatLocationMessage(msgs[IsmChatCustomMessageType.location]!),
      isA<Widget>(),
    );
    expect(
      IsmChatContactMessage(msgs[IsmChatCustomMessageType.contact]!),
      isA<Widget>(),
    );
  }, setUpApi: (api) => api.registerSendDefaults());
}
