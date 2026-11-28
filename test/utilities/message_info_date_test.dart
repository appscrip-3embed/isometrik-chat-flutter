import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(() {
    IsmChatConfig.isMonthFirst = null;
    resetChatSdk();
  });

  int at(DateTime d) => d.millisecondsSinceEpoch;

  group('messageInfoDate', () {
    test('0 / -1 are empty', () {
      expect(0.messageInfoDate, '');
      expect((-1).messageInfoDate, '');
    });

    test('today and yesterday are relative words', () {
      final now = DateTime.now();
      final noonToday = DateTime(now.year, now.month, now.day, 12);
      final noonYesterday = noonToday.subtract(const Duration(days: 1));
      expect(at(noonToday).messageInfoDate, IsmChatStrings.today.toLowerCase());
      expect(
        at(noonYesterday).messageInfoDate,
        IsmChatStrings.yesterday.toLowerCase(),
      );
    });

    test('older dates are dd/MM/yy, or MM/dd/yy when month first', () {
      final old = DateTime(2024, 3, 9, 10, 14);
      expect(at(old).messageInfoDate, '09/03/24');
      IsmChatConfig.isMonthFirst = true;
      expect(at(old).messageInfoDate, '03/09/24');
    });

    test('time part is the jm time string', () {
      final old = DateTime(2024, 3, 9, 22, 5);
      expect(at(old).toTimeString, DateFormat.jm().format(old));
    });
  });
}
