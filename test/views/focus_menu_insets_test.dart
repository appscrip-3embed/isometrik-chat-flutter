import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/test_bootstrap.dart';
import '../helpers/ui_test_helpers.dart';

const double _statusBar = 24;
const double _navBar = 48;
const double _screenHeight = 800;

/// Android insets: [paddingBottom] 0 mimics edge-to-edge devices that report
/// no bottom padding while the nav bar still covers [_navBar] px.
void _androidInsets(WidgetTester tester, {required double paddingBottom}) {
  tester.view.padding =
      FakeViewPadding(top: _statusBar, bottom: paddingBottom);
  tester.view.viewPadding =
      const FakeViewPadding(top: _statusBar, bottom: _navBar);
}

Future<void> _openMenuAndCheck(
  WidgetTester tester,
  ChatTestContext ctx, {
  required String body,
  required double paddingBottom,
}) async {
  _androidInsets(tester, paddingBottom: paddingBottom);
  await mountChatPageForUi(tester, ctx, messageBody: body);
  final context = IsmChatConfig.kNavigatorKey.currentContext!;
  final routeFuture = ctx.page.onMessageLongPress(
    context,
    ctx.page.messages.first,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  final menu = find
      .descendant(
        of: find.byType(IsmChatFocusMenu),
        matching: find.byType(ListView),
      )
      .evaluate()
      .map((e) => tester.getRect(find.byWidget(e.widget)))
      .firstWhere(
        (r) => (r.width - IsmChatDimens.oneHundredSeventy).abs() < 1,
      );
  expect(menu.bottom, lessThanOrEqualTo(_screenHeight - _navBar));

  final reactions = find.byType(ReactionGrid);
  if (reactions.evaluate().isNotEmpty) {
    final r = tester.getRect(reactions);
    expect(r.top, greaterThanOrEqualTo(_statusBar));
  }

  Navigator.of(context).pop();
  await routeFuture;
}

void main() {
  final tall = List.filled(60, 'line').join('\n');

  chatTestWidgets('tall message, edge-to-edge (padding.bottom = 0)',
      (tester, ctx) async {
    await _openMenuAndCheck(tester, ctx, body: tall, paddingBottom: 0);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('tall message, nav bar reported in padding',
      (tester, ctx) async {
    await _openMenuAndCheck(tester, ctx, body: tall, paddingBottom: _navBar);
  }, setUpApi: (api) => api.registerSendDefaults());

  chatTestWidgets('short message, edge-to-edge (padding.bottom = 0)',
      (tester, ctx) async {
    await _openMenuAndCheck(tester, ctx, body: 'hi', paddingBottom: 0);
  }, setUpApi: (api) => api.registerSendDefaults());
}
