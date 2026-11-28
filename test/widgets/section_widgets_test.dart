import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 745),
        builder: (_, __) => MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );

void main() {
  testWidgets('section card puts dividers only between rows', (tester) async {
    await _pump(
      tester,
      const IsmChatSectionCard(
        children: [Text('one'), Text('two'), Text('three')],
      ),
    );

    expect(find.text('one'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('section header upper-cases its title', (tester) async {
    await _pump(tester, const IsmChatSectionHeader(title: 'Participants'));

    expect(find.text('PARTICIPANTS'), findsOneWidget);
  });

  testWidgets('settings tile shows value, chevron and handles taps',
      (tester) async {
    var taps = 0;
    await _pump(
      tester,
      IsmChatSettingsTile(
        title: 'Media, links and docs',
        icon: Icons.photo_library_outlined,
        value: '24',
        showChevron: true,
        onTap: () => taps++,
      ),
    );

    expect(find.text('24'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    await tester.tap(find.text('Media, links and docs'));
    expect(taps, 1);
  });

  testWidgets('host leading widget is rendered as-is, not boxed',
      (tester) async {
    const hostIcon = Icon(Icons.star, key: ValueKey('host-icon'));
    await _pump(
      tester,
      const IsmChatSettingsTile(
        title: 'Clear chat',
        leading: hostIcon,
        icon: Icons.clear_all_rounded,
      ),
    );

    expect(find.byKey(const ValueKey('host-icon')), findsOneWidget);
    // The SDK default icon is not drawn when the host supplies one.
    expect(find.byIcon(Icons.clear_all_rounded), findsNothing);
  });

  testWidgets('destructive tile paints the title in the destructive colour',
      (tester) async {
    await _pump(
      tester,
      const IsmChatSettingsTile(
        title: 'Exit group',
        destructive: true,
        destructiveColor: Color(0xFFAA0000),
      ),
    );

    final text = tester.widget<Text>(find.text('Exit group'));
    expect(text.style?.color, const Color(0xFFAA0000));
  });

  testWidgets('segmented tabs switch the controller on tap', (tester) async {
    final controller = TabController(length: 3, vsync: const TestVSync());
    addTearDown(controller.dispose);
    await _pump(
      tester,
      IsmChatSegmentedTabs(
        controller: controller,
        labels: const ['Media', 'Links', 'Docs'],
      ),
    );

    await tester.tap(find.text('Docs'));
    await tester.pumpAndSettle();
    expect(controller.index, 2);
  });

  testWidgets('empty state shows title and subtitle', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 745),
        builder: (_, __) => const MaterialApp(
          home: Scaffold(
            body: IsmChatEmptyState(
              icon: Icons.photo_library_outlined,
              title: 'No media',
              subtitle: 'Photos and videos you share appear here',
            ),
          ),
        ),
      ),
    );

    expect(find.text('No media'), findsOneWidget);
    expect(find.text('Photos and videos you share appear here'), findsOneWidget);
  });
}
