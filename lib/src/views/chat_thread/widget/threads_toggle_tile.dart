import 'package:flutter/material.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Drop-in switch that turns the Slack-style thread interface on and off.
///
/// Place it wherever your app keeps chat settings (a settings screen, a chat
/// list menu, a debug panel). Flipping it calls
/// `IsmChat.i.setThreadsEnabled`, which updates [IsmChatConfig.threadsEnabled]
/// and reloads the open chat so the timeline re-fetches with (or without)
/// `feedType=main` — no restart needed.
///
/// ```dart
/// IsmChatThreadsToggleTile(
///   onChanged: (enabled) => debugPrint('threads: $enabled'),
/// )
/// ```
///
/// Hosts that already have their own switch can skip this widget entirely and
/// call `IsmChat.i.setThreadsEnabled(value)` directly.
class IsmChatThreadsToggleTile extends StatefulWidget {
  const IsmChatThreadsToggleTile({
    this.title,
    this.subtitle,
    this.onChanged,
    this.contentPadding,
    super.key,
  });

  /// Defaults to [IsmChatStrings.threadsLabel].
  final String? title;

  /// Defaults to [IsmChatStrings.threadsToggleSubtitle]; pass `''` to hide.
  final String? subtitle;

  /// Called after the SDK applied the new value.
  final ValueChanged<bool>? onChanged;

  final EdgeInsetsGeometry? contentPadding;

  @override
  State<IsmChatThreadsToggleTile> createState() =>
      _IsmChatThreadsToggleTileState();
}

class _IsmChatThreadsToggleTileState extends State<IsmChatThreadsToggleTile> {
  Future<void> _apply(bool value) async {
    await IsmChat.i.setThreadsEnabled(value);
    if (!mounted) return;
    setState(() {});
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.subtitle ?? IsmChatStrings.threadsToggleSubtitle;
    return SwitchListTile.adaptive(
      key: const Key('ism-threads-toggle'),
      value: IsmChatConfig.threadsEnabled,
      contentPadding: widget.contentPadding,
      title: Text(widget.title ?? IsmChatStrings.threadsLabel),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onChanged: _apply,
    );
  }
}
