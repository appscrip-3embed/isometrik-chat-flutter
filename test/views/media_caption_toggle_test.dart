import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';
import '../helpers/ui_test_helpers.dart';

/// Long media captions collapse to 3 lines; Show more / Show less toggles them.
void main() {
  for (final type in [
    IsmChatCustomMessageType.image,
    IsmChatCustomMessageType.video,
    IsmChatCustomMessageType.multipleAttachments,
  ]) {
    chatTestWidgets('$type caption Show more / Show less', (tester, ctx) async {
      await mountChatPageForUi(tester, ctx);
      final isGrid = type == IsmChatCustomMessageType.multipleAttachments;
      seedChatPageForUi(
        ctx.page,
        conversations: ctx.conversations,
        messages: [
          message(
            customType: type,
            metaData: IsmChatMetaData(caption: 'word ' * 80),
            attachments: isGrid
                ? List.generate(
                    3,
                    (_) => AttachmentModel(
                      mediaUrl: '',
                      thumbnailUrl: '',
                      attachmentType: IsmChatMediaType.image,
                    ),
                  )
                : [AttachmentModel(mediaUrl: '', thumbnailUrl: '')],
          ),
        ],
      );
      await tester.pump();

      final caption = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().startsWith('word word'),
      );
      final collapsed = tester.getSize(caption.first).height;

      await tester.tap(find.text('Show more'));
      await tester.pump();
      expect(find.text('Show less'), findsOneWidget);
      expect(tester.getSize(caption.first).height, greaterThan(collapsed));

      await tester.tap(find.text('Show less'));
      await tester.pump();
      expect(find.text('Show more'), findsOneWidget);
      expect(tester.getSize(caption.first).height, collapsed);
    }, setUpApi: (api) => api.registerSendDefaults());
  }
}
