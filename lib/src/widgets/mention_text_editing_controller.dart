import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Composer controller that paints completed `@mentions` with the same style
/// as message bubbles ([ismChatMentionTextStyle]) while the user types.
///
/// Only the rendering changes: [text] is untouched, so send, edit and mention
/// resolution keep working on the plain string. [membersProvider] is read on
/// every build so the list can load after the controller is created.
class IsmChatMentionTextEditingController extends TextEditingController {
  IsmChatMentionTextEditingController({
    required this.membersProvider,
    super.text,
  });

  /// Group members whose names count as mentions (empty → no highlighting).
  final List<UserDetails> Function() membersProvider;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final members = _safeMembers();
    final ranges = composerMentionRanges(text, members);
    if (ranges.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final base = style ?? const TextStyle();
    final mentionStyle = ismChatMentionTextStyle(base);
    final composing = withComposing &&
            value.isComposingRangeValid &&
            !value.composing.isCollapsed
        ? value.composing
        : null;

    // Split points: mention edges plus the IME composing edges, so the
    // composing underline still shows on top of the mention color.
    final cuts = <int>{0, text.length};
    for (final r in ranges) {
      cuts
        ..add(r.start)
        ..add(r.end);
    }
    if (composing != null) {
      cuts
        ..add(composing.start)
        ..add(composing.end);
    }
    final points = cuts.where((e) => e >= 0 && e <= text.length).toList()
      ..sort();

    final children = <TextSpan>[];
    for (var k = 0; k < points.length - 1; k++) {
      final start = points[k];
      final end = points[k + 1];
      if (start == end) continue;
      final inMention = ranges.any((r) => start >= r.start && end <= r.end);
      var spanStyle = inMention ? mentionStyle : base;
      if (composing != null &&
          start >= composing.start &&
          end <= composing.end) {
        spanStyle = spanStyle.merge(
          const TextStyle(decoration: TextDecoration.underline),
        );
      }
      children.add(TextSpan(text: text.substring(start, end), style: spanStyle));
    }
    return TextSpan(style: base, children: children);
  }

  List<UserDetails> _safeMembers() {
    try {
      return membersProvider();
    } catch (_) {
      return const <UserDetails>[];
    }
  }
}
