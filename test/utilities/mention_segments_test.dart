import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/test_bootstrap.dart';

/// Regression tests for @mention span parsing ([ismChatMentionSegmentsForBody]).
///
/// Reuse [UserDetails] + [wordCount]/[order] the same way the send path and API do.
UserDetails _wireMentionOnly({
  required String id,
  required int wordCount,
  required int order,
}) =>
    UserDetails(
      userProfileImageUrl: '',
      userName: '',
      userIdentifier: '',
      userId: id,
      wordCount: wordCount,
      order: order,
    );

UserDetails _mentionedUser({
  required String id,
  required String userName,
  String? firstName,
  String? lastName,
  required int wordCount,
  required int order,
}) =>
    UserDetails(
      userProfileImageUrl: '',
      userName: userName,
      userIdentifier: '$id@test.com',
      userId: id,
      wordCount: wordCount,
      order: order,
      metaData: IsmChatMetaData(firstName: firstName, lastName: lastName),
    );

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  group('ismChatMentionSegmentsForBody', () {
    test('covers full three-word display label when wordCount is 3', () {
      final mentioned = _mentionedUser(
        id: 'u1',
        userName: 'adv_handle',
        firstName: 'Adv.',
        lastName: 'rounit signha',
        wordCount: 3,
        order: 0,
      );
      const body = '@Adv. rounit signha hello';
      final segments = ismChatMentionSegmentsForBody(
        body,
        [mentioned],
        authoritativeMentionedUsers: [mentioned],
      );
      final mentions = segments
          .where((s) => s.isLink && s.text.startsWith('@'))
          .map((s) => s.text)
          .toList();

      expect(mentions, ['@Adv. rounit signha']);
    });

    test('highlights two multi-word mentions in one message', () {
      final first = _mentionedUser(
        id: 'u1',
        userName: 'user_one',
        firstName: 'User',
        lastName: 'One',
        wordCount: 2,
        order: 0,
      );
      final second = _mentionedUser(
        id: 'u2',
        userName: 'user_two',
        firstName: 'User',
        lastName: 'Two',
        wordCount: 2,
        order: 1,
      );
      const body = '@User One and @User Two';
      final segments = ismChatMentionSegmentsForBody(
        body,
        [first, second],
        authoritativeMentionedUsers: [first, second],
      );
      final mentions = segments
          .where((s) => s.isLink && s.text.startsWith('@'))
          .map((s) => s.text)
          .toList();

      expect(mentions, ['@User One', '@User Two']);
    });

    test('matches inserted display label even when userName differs', () {
      final mentioned = _mentionedUser(
        id: 'u1',
        userName: 'short',
        firstName: 'Adv.',
        lastName: 'rounit signha',
        wordCount: 3,
        order: 0,
      );
      const body = '@Adv. rounit signha';
      final segments = ismChatMentionSegmentsForBody(
        body,
        [mentioned],
        authoritativeMentionedUsers: [mentioned],
      );
      final mentionText = segments
          .firstWhere((s) => s.isLink && s.text.startsWith('@'))
          .text;

      expect(mentionText, '@Adv. rounit signha');
    });

    test('authoritative: two mentions separated by plain text', () {
      final first = _mentionedUser(
        id: 'u1',
        userName: 'user_one',
        firstName: 'User',
        lastName: 'One',
        wordCount: 2,
        order: 0,
      );
      final second = _mentionedUser(
        id: 'u2',
        userName: 'user_two',
        firstName: 'User',
        lastName: 'Two',
        wordCount: 2,
        order: 1,
      );
      const body = '@User One please @User Two';
      final segments = ismChatMentionSegmentsForBody(
        body,
        [first, second],
        authoritativeMentionedUsers: [first, second],
      );
      final mentions = segments
          .where((s) => s.isLink && s.text.startsWith('@'))
          .map((s) => s.text)
          .toList();

      expect(mentions, ['@User One', '@User Two']);
    });

    test('authoritative: email @ does not consume mention order slot', () {
      final first = _mentionedUser(
        id: 'u1',
        userName: 'user_one',
        firstName: 'User',
        lastName: 'One',
        wordCount: 2,
        order: 0,
      );
      final second = _mentionedUser(
        id: 'u2',
        userName: 'user_two',
        firstName: 'User',
        lastName: 'Two',
        wordCount: 2,
        order: 1,
      );
      const body = 'email user@domain.com and @User Two';
      final segments = ismChatMentionSegmentsForBody(
        body,
        [first, second],
        authoritativeMentionedUsers: [first, second],
      );
      final mentions = segments
          .where((s) => s.isLink && s.text.startsWith('@'))
          .map((s) => s.text)
          .toList();

      expect(mentions, ['@User Two']);
    });

    test('authoritative: stray @ before real mention keeps full display name', () {
      final mentioned = _mentionedUser(
        id: 'u1',
        userName: 'user_one',
        firstName: 'User',
        lastName: 'One',
        wordCount: 2,
        order: 0,
      );
      const body = '@oops then @User One';
      final segments = ismChatMentionSegmentsForBody(
        body,
        [mentioned],
        authoritativeMentionedUsers: [mentioned],
      );
      final mentions = segments
          .where((s) => s.isLink && s.text.startsWith('@'))
          .map((s) => s.text)
          .toList();

      expect(mentions, ['@User One']);
    });

  test('receiver: wire payload wordCount without display names', () {
      final karim = _wireMentionOnly(id: 'u-karim', wordCount: 1, order: 0);
      final akhlad = _wireMentionOnly(id: 'u-akhlad', wordCount: 3, order: 1);
      const body = '@Karim @Mr. akhlad Siddique hi';
      final segments = ismChatMentionSegmentsForBody(
        body,
        const [],
        authoritativeMentionedUsers: [karim, akhlad],
      );
      final mentions = segments
          .where((s) => s.isLink && s.text.startsWith('@'))
          .map((s) => s.text)
          .toList();

      expect(mentions, ['@Karim', '@Mr. akhlad Siddique']);
    });

    test('receiver: signed-in user in mention list preserves order', () {
      final karim = _wireMentionOnly(id: 'u-karim', wordCount: 1, order: 0);
      final me = _wireMentionOnly(id: kMeId, wordCount: 2, order: 1);
      final bob = _wireMentionOnly(id: 'u-bob', wordCount: 1, order: 2);
      const body = '@Karim @Me Tester @Bob';
      final segments = ismChatMentionSegmentsForBody(
        body,
        const [],
        authoritativeMentionedUsers: [karim, me, bob],
      );
      final mentions = segments
          .where((s) => s.isLink && s.text.startsWith('@'))
          .map((s) => s.text)
          .toList();

      expect(mentions, ['@Karim', '@Me Tester', '@Bob']);
    });

    test('receiver: enriches wire rows from group member candidates', () {
      final karimMember = _mentionedUser(
        id: 'u-karim',
        userName: 'karim_h',
        firstName: 'Karim',
        lastName: '',
        wordCount: 1,
        order: 0,
      );
      final wireKarim = _wireMentionOnly(id: 'u-karim', wordCount: 1, order: 0);
      const body = '@Karim hello';
      final segments = ismChatMentionSegmentsForBody(
        body,
        [karimMember],
        authoritativeMentionedUsers: [wireKarim],
      );
      final mentionText = segments
          .firstWhere((s) => s.isLink && s.text.startsWith('@'))
          .text;

      expect(mentionText, '@Karim');
    });

    test('sender: short userName prefix does not beat wordCount span', () {
      final mentioned = UserDetails(
        userProfileImageUrl: '',
        userName: 'rasika',
        userIdentifier: 'r@test.com',
        userId: 'u-rasika',
        wordCount: 3,
        order: 0,
        metaData: IsmChatMetaData(
          firstName: 'Rasika',
          lastName: 'Flutter User',
        ),
      );
      const body = '@Rasika Flutter User';
      final segments = ismChatMentionSegmentsForBody(
        body,
        [mentioned],
        authoritativeMentionedUsers: [mentioned],
      );
      final mentionText = segments
          .firstWhere((s) => s.isLink && s.text.startsWith('@'))
          .text;

      expect(mentionText, '@Rasika Flutter User');
    });

    test('receiver: understates wordCount when member has longer display name', () {
      final wire = _wireMentionOnly(id: 'u-rasika', wordCount: 1, order: 0);
      final member = _mentionedUser(
        id: 'u-rasika',
        userName: 'rasika',
        firstName: 'Rasika',
        lastName: 'Flutter User',
        wordCount: 1,
        order: 0,
      );
      const body = '@Rasika Flutter User';
      final segments = ismChatMentionSegmentsForBody(
        body,
        [member],
        authoritativeMentionedUsers: [wire],
      );
      final mentionText = segments
          .firstWhere((s) => s.isLink && s.text.startsWith('@'))
          .text;

      expect(mentionText, '@Rasika Flutter User');
    });

    test('receiver: extra @ beyond mentionedUsers entries still highlights', () {
      final wire = _wireMentionOnly(id: 'u-rasika', wordCount: 1, order: 0);
      final handleMember = UserDetails(
        userProfileImageUrl: '',
        userName: 'rasika123',
        userIdentifier: 'r@test.com',
        userId: 'u-handle',
      );
      const body = '@rasika123';
      final segments = ismChatMentionSegmentsForBody(
        body,
        [handleMember],
        authoritativeMentionedUsers: [wire],
      );
      final mentions = segments
          .where((s) => s.isLink && s.text.startsWith('@'))
          .map((s) => s.text)
          .toList();

      expect(mentions, ['@rasika123']);
    });

    test('receiver: masked phone mention token highlights', () {
      final wire = _wireMentionOnly(id: 'u-phone', wordCount: 1, order: 0);
      const body = '@+6399******71';
      final segments = ismChatMentionSegmentsForBody(
        body,
        const [],
        authoritativeMentionedUsers: [wire],
      );
      final mentionText = segments
          .firstWhere((s) => s.isLink && s.text.startsWith('@'))
          .text;

      expect(mentionText, '@+6399******71');
    });

    test('receiver: mqtt-style body with four mentions and three wire rows', () {
      final wires = [
        _wireMentionOnly(id: 'u-awan', wordCount: 3, order: 0),
        _wireMentionOnly(id: 'u-rasika', wordCount: 1, order: 1),
        _wireMentionOnly(id: 'u-phone', wordCount: 1, order: 2),
      ];
      final members = [
        _mentionedUser(
          id: 'u-awan',
          userName: 'awan',
          firstName: 'Awan',
          lastName: 'hold hai',
          wordCount: 3,
          order: 0,
        ),
        _mentionedUser(
          id: 'u-rasika',
          userName: 'rasika',
          firstName: 'Rasika',
          lastName: 'Flutter User',
          wordCount: 3,
          order: 1,
        ),
        UserDetails(
          userProfileImageUrl: '',
          userName: 'rasika123',
          userIdentifier: 'r2@test.com',
          userId: 'u-handle',
        ),
      ];
      const body =
          '@Awan hold hai @Rasika Flutter User @+6399******71 @rasika123';
      final segments = ismChatMentionSegmentsForBody(
        body,
        members,
        authoritativeMentionedUsers: wires,
      );
      final mentions = segments
          .where((s) => s.isLink && s.text.startsWith('@'))
          .map((s) => s.text)
          .toList();

      expect(mentions, [
        '@Awan hold hai',
        '@Rasika Flutter User',
        '@+6399******71',
        '@rasika123',
      ]);
    });

    test('receiver: many multi-word handles in one body', () {
      final mentions = [
        _wireMentionOnly(id: 'u1', wordCount: 1, order: 0),
        _wireMentionOnly(id: 'u2', wordCount: 3, order: 1),
        _wireMentionOnly(id: 'u3', wordCount: 3, order: 2),
        _wireMentionOnly(id: 'u4', wordCount: 1, order: 3),
      ];
      const body =
          '@Karim @Mr. Rohit Marthak @Mr. appscrip test @Karthik hi';
      final segments = ismChatMentionSegmentsForBody(
        body,
        const [],
        authoritativeMentionedUsers: mentions,
      );
      final mentionTexts = segments
          .where((s) => s.isLink && s.text.startsWith('@'))
          .map((s) => s.text)
          .toList();

      expect(mentionTexts, [
        '@Karim',
        '@Mr. Rohit Marthak',
        '@Mr. appscrip test',
        '@Karthik',
      ]);
      final combined =
          segments.map((s) => s.text).join();
      expect(combined, body);
    });
  });

  group('messageBodyHasComposerMention', () {
    test('detects leading and spaced mentions, not email local-part', () {
      expect(messageBodyHasComposerMention('@Karim'), isTrue);
      expect(messageBodyHasComposerMention('hi @Bob'), isTrue);
      expect(messageBodyHasComposerMention('user@domain.com'), isFalse);
    });
  });

  group('mentionUserIdsInComposerText', () {
    test('returns ids for each distinct mention in composer', () {
      final first = _mentionedUser(
        id: 'u1',
        userName: 'user_one',
        firstName: 'User',
        lastName: 'One',
        wordCount: 2,
        order: 0,
      );
      final second = _mentionedUser(
        id: 'u2',
        userName: 'user_two',
        firstName: 'User',
        lastName: 'Two',
        wordCount: 2,
        order: 1,
      );
      const body = '@User One and @User Two ';
      final ids = mentionUserIdsInComposerText(body, [first, second]);

      expect(ids, {'u1', 'u2'});
    });

    test('dedupes the same user mentioned only once', () {
      final user = _mentionedUser(
        id: 'u1',
        userName: 'user_one',
        firstName: 'User',
        lastName: 'One',
        wordCount: 2,
        order: 0,
      );
      const body = '@User One hello';
      final ids = mentionUserIdsInComposerText(body, [user]);

      expect(ids, {'u1'});
    });
  });

  group('composer mention helpers', () {
    UserDetails member(String id, String userName,
            {String? firstName, String? lastName}) =>
        UserDetails(
          userProfileImageUrl: '',
          userName: userName,
          userIdentifier: '$id@test.com',
          userId: id,
          metaData: IsmChatMetaData(firstName: firstName, lastName: lastName),
        );

    test('display name collapses padding around "Mr." titles', () {
      final ajay = member('u1', 'ajay', firstName: 'Mr. ', lastName: ' Ajay');
      expect(ajay.displayName, 'Mr. Ajay');
      expect(mentionLabelForUser(ajay), 'Mr. Ajay');
      expect(
        insertMentionIntoComposerText('hi @mr', mentionLabelForUser(ajay)),
        'hi @Mr. Ajay ',
      );
    });

    test('suggestions show only while typing an @ token', () {
      final members = [member('u1', 'ajay'), member('u2', 'bob')];
      expect(mentionSuggestionsForComposer('hello', members), isNull);
      expect(
        mentionSuggestionsForComposer('hello @aj', members)!
            .map((e) => e.userId),
        ['u1'],
      );
    });

    test('resolveComposerMentions returns order and label word count', () {
      final members = [
        member('u1', 'ajay', firstName: 'Mr.', lastName: 'Ajay'),
        member('u2', 'bob'),
      ];
      final mentions =
          resolveComposerMentions('@Mr. Ajay and @bob hello', members);
      expect(mentions.map((e) => e.userId), ['u1', 'u2']);
      expect(mentions.first.wordCount, 2);
      expect(mentions.map((e) => e.order), [0, 1]);
    });
  });
}

