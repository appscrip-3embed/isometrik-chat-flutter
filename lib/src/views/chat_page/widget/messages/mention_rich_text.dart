import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Rich text for chat bodies with @mentions, URLs, phones, and emails.
///
/// Uses [TextSpan] for mentions (not [WidgetSpan]) so multiple mentions wrap
/// cleanly on mobile. Reuse in message bubbles, reply snippets, and composer.
class IsmChatMentionRichText extends StatelessWidget {
  const IsmChatMentionRichText({
    required this.body,
    required this.style,
    super.key,
    this.message,
    this.mentionedUsers,
    this.maxLines,
    this.overflow,
    this.enableMentionTap = true,
    this.textAlign,
  });

  final String body;
  final TextStyle style;

  /// When set, drives [MentionMessage.resolveMentionedUser] and mention taps.
  final IsmChatMessageModel? message;

  /// Used when [message] is null (e.g. reply parent text only).
  final List<UserDetails>? mentionedUsers;

  final int? maxLines;
  final TextOverflow? overflow;
  final bool enableMentionTap;
  final TextAlign? textAlign;

  List<LocalMentionAndLinkData> get _segments {
    if (message != null) {
      return message!.mentionListForBody(body);
    }
    return MentionMessage.mentionSegmentsForReplyBody(
      body,
      mentionedUsers: mentionedUsers,
    );
  }

  @override
  Widget build(BuildContext context) {
    // [RichText] (unlike [Text]) ignores [DefaultTextStyle]. Styles without a
    // color (e.g. the light thread theme's bodyStyle) would otherwise paint
    // plain segments white while only mentions get an explicit color.
    final resolvedStyle = DefaultTextStyle.of(context).style.merge(style);
    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(
        style: resolvedStyle,
        children: _segments
            .map((e) => _spanForSegment(e, resolvedStyle))
            .toList(),
      ),
      softWrap: true,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  InlineSpan _spanForSegment(LocalMentionAndLinkData e, TextStyle style) {
    if (!e.isLink) {
      return TextSpan(text: e.text, style: style);
    }

    final mentionStyle = ismChatMentionTextStyle(style);

    if (e.text.startsWith('@')) {
      return TextSpan(
        text: e.text,
        style: mentionStyle,
        recognizer: enableMentionTap
            ? (TapGestureRecognizer()
              ..onTap = () async {
                if (!IsmChatUtility.chatPageControllerRegistered) return;
                if (message == null) return;
                final mentioned =
                    message!.resolveMentionedUser(e.text.substring(1));
                if (mentioned == null) return;
                await IsmChatUtility.chatPageController
                    .onMentionLinkTapped(message!, e.text);
              })
            : null,
      );
    }

    return TextSpan(
      text: e.text,
      style: mentionStyle,
      recognizer: TapGestureRecognizer()
        ..onTap = () async {
          if (e.text.contains(RegExp(r'^\d{9,13}$'))) {
            await IsmChatContextWidget.showDialogContext(
              content: IsmChatAlertDialogBox(
                title: IsmChatStrings.thisPhoneNumberNotonChat,
                actionLabels: [
                  '${IsmChatStrings.dial} ${e.text}',
                  IsmChatStrings.addToContact,
                ],
                callbackActions: [
                  () {
                    IsmChatUtility.dialNumber(e.text);
                  },
                  () async {
                    await IsmChatUtility.openContactSaveScreen(
                      Contact(
                        phones: [Phone(number: e.text)],
                      ),
                    );
                  },
                ],
              ),
            );
          } else if (e.text.contains('@') && !e.text.startsWith('@')) {
            final emailUri = Uri(scheme: 'mailto', path: e.text);
            if (await canLaunchUrl(emailUri)) {
              await launchUrl(emailUri);
            }
          } else if (e.text.startsWith('http') || e.text.startsWith('www')) {
            final url = e.text.startsWith('www')
                ? 'https://${e.text}'
                : e.text;
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url));
            }
          }
        },
    );
  }

  /// Plain [TextSpan] list for [TextPainter] overflow checks (no gesture recognizers).
  static List<InlineSpan> measurementSpans(
    String body,
    TextStyle style,
    List<LocalMentionAndLinkData> segments,
  ) =>
      segments
          .map(
            (e) => TextSpan(
              text: e.text,
              style: e.isLink ? ismChatMentionTextStyle(style) : style,
            ),
          )
          .toList();
}