import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Guards the host-facing theme contract while in-chat screens are restyled:
/// old constructors still compile, host instances win verbatim, and SDK
/// defaults follow the host's primary colour and font.

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 745),
      builder: (_, __) => MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return captured;
}

void _useTheme(IsmChatThemeData theme, {Brightness mode = Brightness.light}) {
  IsmChatConfig.chatBrightness = mode;
  if (mode == Brightness.dark) {
    IsmChatConfig.chatDarkTheme = theme;
  } else {
    IsmChatConfig.chatLightTheme = theme;
  }
}

const _style = TextStyle(fontSize: 14);
const _brand = Color(0xFF1E6FD9);

void main() {
  tearDown(() {
    IsmChatConfig.chatBrightness = null;
    IsmChatConfig.fontFamily = null;
  });

  testWidgets('per-screen themes still construct with their original params',
      (tester) async {
    await _pumpContext(tester);

    const media = IsmChatMediaTheme(
      scaffoldBackgroundColor: Colors.white,
      appBarBackgroundColor: Colors.white,
      appBarIconColor: Colors.black,
      previewBackgroundColor: Colors.white,
      previewTitleTextStyle: _style,
      previewSubtitleTextStyle: _style,
      tabBarContainerColor: Colors.grey,
      tabSelectedBackgroundColor: Colors.white,
      tabUnselectedBackgroundColor: Colors.grey,
      tabSelectedTextStyle: _style,
      tabUnselectedTextStyle: _style,
      sectionTitleTextStyle: _style,
      docTitleTextStyle: _style,
      docSubtitleTextStyle: _style,
      docTrailingTextStyle: _style,
      emptyStateTextStyle: _style,
      dividerColor: Colors.grey,
    );
    const group = IsmChatGroupInfoTheme(
      scaffoldBackgroundColor: Colors.white,
      surfaceBackgroundColor: Colors.white,
      primaryTitleTextStyle: _style,
      secondaryTextStyle: _style,
      captionTextStyle: _style,
      metaTextStyle: _style,
      sectionTitleTextStyle: _style,
      bodyTextStyle: _style,
      listTileTitleTextStyle: _style,
      listTileSubtitleTextStyle: _style,
      actionIconColor: Colors.grey,
      menuIconColor: Colors.black,
      inputTextStyle: _style,
      searchFillColor: Colors.white,
      searchHintTextStyle: _style,
      searchIconColor: Colors.grey,
      adminBadgeTextStyle: _style,
      dividerColor: Colors.grey,
    );
    const contact = IsmChatContactInfoTheme(
      scaffoldBackgroundColor: Colors.white,
      cardBackgroundColor: Colors.white,
      nameTextStyle: _style,
      identifierTextStyle: _style,
      addButtonBackgroundColor: Colors.blue,
      addButtonTextStyle: _style,
      actionIconColor: Colors.blue,
      actionLabelTextStyle: _style,
      dividerColor: Colors.grey,
    );
    const profile = IsmChatProfileTheme(
      scaffoldBackgroundColor: Colors.white,
      cardBackgroundColor: Colors.white,
      sectionTitleStyle: _style,
      primaryTextStyle: _style,
      secondaryTextStyle: _style,
      inputTextStyle: _style,
      inputHintStyle: _style,
      iconColor: Colors.grey,
      editButtonBackgroundColor: Colors.white,
      editButtonBorderColor: Colors.grey,
      editButtonIconColor: Colors.grey,
      listTileTitleStyle: _style,
      listTileSubtitleStyle: _style,
      emptyStateTextStyle: _style,
    );
    const reaction = IsmChatReactionTheme(
      backgroundColor: Colors.white,
      countTextStyle: _style,
      tabLabelTextStyle: _style,
      tabCountTextStyle: _style,
      listTileTitleTextStyle: _style,
      listTileSubtitleTextStyle: _style,
    );

    // New fields are optional and stay null for legacy call sites.
    expect(media.cardBackgroundColor, isNull);
    expect(group.destructiveColor, isNull);
    expect(contact.dividerColor, Colors.grey);
    expect(profile.iconColor, Colors.grey);
    expect(reaction.boxShadow, isNull);
  });

  testWidgets('resolvers return the host instance unchanged', (tester) async {
    final context = await _pumpContext(tester);
    final media = IsmChatMediaTheme.light().copyWith(dividerColor: Colors.red);
    final group = IsmChatGroupInfoTheme.light().copyWith(
      surfaceBackgroundColor: Colors.amber,
    );
    final contact = IsmChatContactInfoTheme.light().copyWith(
      cardBackgroundColor: Colors.teal,
    );
    final reaction = IsmChatReactionTheme.light();
    final profile = IsmChatProfileTheme.light();
    _useTheme(
      IsmChatThemeData(
        primaryColor: _brand,
        profileTheme: profile,
        chatPageTheme: IsmChatPageTheme(
          mediaTheme: media,
          groupInfoTheme: group,
          contactInfoTheme: contact,
          reactionTheme: reaction,
        ),
      ),
    );

    expect(identical(IsmChatThemeResolver.mediaFromConfig(context), media),
        isTrue);
    expect(
        identical(IsmChatThemeResolver.groupInfoFromConfig(context), group),
        isTrue);
    expect(
        identical(IsmChatThemeResolver.contactInfoFromConfig(context), contact),
        isTrue);
    expect(
        identical(IsmChatThemeResolver.reactionFromConfig(context), reaction),
        isTrue);
    expect(identical(IsmChatThemeResolver.profileFromConfig(context), profile),
        isTrue);
  });

  testWidgets('SDK defaults follow the host primary colour', (tester) async {
    final context = await _pumpContext(tester);
    _useTheme(IsmChatThemeData(primaryColor: _brand));

    final tokens = IsmChatDesignTokens.of(context);
    expect(tokens.accent, _brand);
    expect(IsmChatGroupInfoTheme.light().adminBadgeTextStyle.color, _brand);
    expect(IsmChatContactInfoTheme.light().addButtonBackgroundColor, _brand);
    expect(IsmChatContactInfoTheme.light().actionIconColor, _brand);
    // No header theme → media app bar matches the chat header (primary).
    expect(IsmChatMediaTheme.light().appBarBackgroundColor, _brand);
  });

  testWidgets('dark mode lifts a dark brand colour to stay readable',
      (tester) async {
    final context = await _pumpContext(tester);
    const navy = Color(0xFF1A237E);
    _useTheme(IsmChatThemeData(primaryColor: navy), mode: Brightness.dark);

    final tokens = IsmChatDesignTokens.of(context);
    expect(tokens.isDark, isTrue);
    expect(
      IsmChatDesignTokens.contrastRatio(tokens.accent, tokens.surface),
      greaterThanOrEqualTo(3),
    );
    final before = HSLColor.fromColor(navy).hue;
    final after = HSLColor.fromColor(tokens.accent).hue;
    expect((before - after).abs(), lessThan(2));
  });

  testWidgets('token text colours meet 4.5:1 in both modes', (tester) async {
    await _pumpContext(tester);
    for (final mode in Brightness.values) {
      final t = IsmChatDesignTokens.forBrightness(mode, accent: _brand);
      for (final bg in [t.surface, t.canvas]) {
        expect(IsmChatDesignTokens.contrastRatio(t.textPrimary, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$mode primary on $bg');
        expect(IsmChatDesignTokens.contrastRatio(t.textSecondary, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$mode secondary on $bg');
      }
    }
  });

  testWidgets('defaults carry the host font family', (tester) async {
    await _pumpContext(tester);
    IsmChatConfig.fontFamily = 'HostSans';

    expect(IsmChatContactInfoTheme.light().nameTextStyle.fontFamily,
        'HostSans');
    expect(IsmChatGroupInfoTheme.dark().listTileTitleTextStyle.fontFamily,
        'HostSans');
    expect(IsmChatMediaTheme.light().docTitleTextStyle.fontFamily, 'HostSans');
  });

  testWidgets('copyWith changes only the given fields', (tester) async {
    await _pumpContext(tester);
    final base = IsmChatMediaTheme.light();
    final copy = base.copyWith(scaffoldBackgroundColor: Colors.pink);

    expect(copy.scaffoldBackgroundColor, Colors.pink);
    expect(copy.dividerColor, base.dividerColor);
    expect(copy.docTitleTextStyle, base.docTitleTextStyle);
    expect(copy.cardBackgroundColor, base.cardBackgroundColor);
  });
}
