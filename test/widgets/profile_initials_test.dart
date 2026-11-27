import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/test_bootstrap.dart';
import '../helpers/ui_test_helpers.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  // Wide letters (M, W) overflowed most with the old fixed 20pt initials.
  const names = {'Rashmi Didi': 'RD', 'Mr. ajay': 'MA', 'Will Mark': 'WM'};
  for (final size in [24.0, 32.0, 48.0, 100.0]) {
    for (final MapEntry(key: name, value: letters) in names.entries) {
      testWidgets('"$name" initials fit inside a $size avatar',
          (tester) async {
        await pumpSdkScreen(
          tester,
          child: Center(
            child: IsmChatImage.profile('', name: name, dimensions: size),
          ),
        );

        _expectInitialsInside(tester, letters);
      });
    }
  }
}

void _expectInitialsInside(WidgetTester tester, String letters) {
  final initials = find.text(letters);
  expect(initials, findsOneWidget);
  final avatarRect = tester.getRect(find.byType(IsmChatImage));
  final textRect = tester.getRect(initials);
  expect(textRect.width, lessThanOrEqualTo(avatarRect.width * 0.8));
  expect(textRect.height, lessThanOrEqualTo(avatarRect.height * 0.8));
  expect(avatarRect.contains(textRect.center), isTrue);
}
