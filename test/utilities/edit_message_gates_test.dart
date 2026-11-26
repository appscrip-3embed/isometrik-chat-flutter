import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:isometrik_chat_flutter/src/res/properties/chat_properties.dart';

import '../helpers/fixtures.dart';

void main() {
  late IsmChatPageProperties _saved;

  setUp(() {
    _saved = IsmChatProperties.chatPageProperties;
    IsmChatProperties.chatPageProperties = IsmChatPageProperties(
      features: [...ismChatDefaultPageFeatures, IsmChatFeature.edit],
    );
  });

  tearDown(() {
    IsmChatProperties.chatPageProperties = _saved;
  });

  IsmChatMessageModel eligible({
    int? sentAt,
    bool sentByMe = true,
    String? messageId,
  }) =>
      message(
        sentAt: sentAt ?? DateTime.now().millisecondsSinceEpoch,
        sentByMe: sentByMe,
        messageId: messageId ?? 'msg-1',
      );

  test('edit in menu when eligible', () {
    final m = eligible();
    expect(m.canShowEditInFocusMenu, isTrue);
    expect(m.focusMenuList, contains(IsmChatFocusMenuType.edit));
  });

  test('hidden without IsmChatFeature.edit', () {
    IsmChatProperties.chatPageProperties = IsmChatPageProperties(
      features: ismChatDefaultPageFeatures,
    );
    final m = eligible();
    expect(m.canShowEditInFocusMenu, isFalse);
    expect(m.focusMenuList, isNot(contains(IsmChatFocusMenuType.edit)));
  });

  test('hidden for receiver and non-text', () {
    expect(eligible(sentByMe: false).canShowEditInFocusMenu, isFalse);
    expect(
      message(
        customType: IsmChatCustomMessageType.image,
        sentAt: DateTime.now().millisecondsSinceEpoch,
      ).canShowEditInFocusMenu,
      isFalse,
    );
  });

  test('hidden when deleted, broadcast meta, or missing id', () {
    expect(
      message(
        customType: IsmChatCustomMessageType.deletedForEveryone,
        sentAt: DateTime.now().millisecondsSinceEpoch,
      ).canShowEditInFocusMenu,
      isFalse,
    );
    expect(
      message(
        metaData: IsmChatMetaData(isBroadCastMessage: true),
        sentAt: DateTime.now().millisecondsSinceEpoch,
      ).canShowEditInFocusMenu,
      isFalse,
    );
    expect(
      message(messageId: '', sentAt: DateTime.now().millisecondsSinceEpoch)
          .canShowEditInFocusMenu,
      isFalse,
    );
  });

  test('hidden after 15 minutes', () {
    final oldSentAt = DateTime.now()
        .subtract(const Duration(minutes: 16))
        .millisecondsSinceEpoch;
    expect(eligible(sentAt: oldSentAt).canShowEditInFocusMenu, isFalse);
  });
}