import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

AttachmentModel _restrictedAttachment(IsmChatMediaType type) => AttachmentModel(
      name: 'secret.${type == IsmChatMediaType.video ? 'mp4' : 'png'}',
      size: 1000,
      mediaUrl: '',
      thumbnailUrl: '',
      attachmentType: type,
      restricted: true,
    );

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  testWidgets('restricted image message renders the "media unavailable" placeholder',
      (tester) async {
    await pumpChatHost(
      tester,
      child: IsmChatMessageWrapper(
        message(
          customType: IsmChatCustomMessageType.image,
          attachments: [_restrictedAttachment(IsmChatMediaType.image)],
        ),
      ),
    );

    expect(find.byType(IsmChatRestrictedMediaMessage), findsOneWidget);
    expect(find.byType(IsmChatImageMessage), findsNothing);
    expect(find.textContaining('Media unavailable'), findsOneWidget);
  });

  testWidgets('restricted message preserves its caption text', (tester) async {
    await pumpChatHost(
      tester,
      child: IsmChatMessageWrapper(
        message(
          customType: IsmChatCustomMessageType.video,
          attachments: [_restrictedAttachment(IsmChatMediaType.video)],
          metaData: IsmChatMetaData(caption: 'trip clip'),
        ),
      ),
    );

    expect(find.byType(IsmChatRestrictedMediaMessage), findsOneWidget);
    expect(find.textContaining('trip clip'), findsOneWidget);
  });

  testWidgets('restricted reply message also uses the placeholder',
      (tester) async {
    await pumpChatHost(
      tester,
      child: IsmChatMessageWrapper(
        message(
          customType: IsmChatCustomMessageType.reply,
          attachments: [_restrictedAttachment(IsmChatMediaType.image)],
        ),
      ),
    );

    expect(find.byType(IsmChatRestrictedMediaMessage), findsOneWidget);
    expect(find.byType(IsmChatReplyMessage), findsNothing);
  });

  testWidgets('a normal (non-restricted) image message is unaffected',
      (tester) async {
    await pumpChatHost(
      tester,
      child: IsmChatMessageWrapper(
        message(
          customType: IsmChatCustomMessageType.image,
          attachments: [
            AttachmentModel(
              name: 'ok.png',
              size: 1000,
              mediaUrl: 'https://cdn.test/ok.png',
              thumbnailUrl: 'https://cdn.test/ok-thumb.png',
              attachmentType: IsmChatMediaType.image,
            ),
          ],
        ),
      ),
    );

    expect(find.byType(IsmChatRestrictedMediaMessage), findsNothing);
    expect(find.byType(IsmChatImageMessage), findsOneWidget);
  });

  test('hasRestrictedMedia getter reflects attachment flags', () {
    final restricted = message(
      customType: IsmChatCustomMessageType.image,
      attachments: [_restrictedAttachment(IsmChatMediaType.image)],
    );
    final plain = message(
      customType: IsmChatCustomMessageType.text,
      body: 'hi',
    );
    expect(restricted.hasRestrictedMedia, isTrue);
    expect(plain.hasRestrictedMedia, isFalse);
  });
}
