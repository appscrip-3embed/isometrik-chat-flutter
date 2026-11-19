## Unreleased

### Added

- **Slack-style message threads (opt-in).** `IsmChatConfig.threadsEnabled`
  (`IsmChat.i.initialize(threadsEnabled: true)` or
  `IsmChat.i.setThreadsEnabled(...)` at runtime) switches the chat to a
  threaded model: a thread panel per root message, an "N replies" footer, a
  "Reply in thread" focus-menu action, nested replies, "also send to channel",
  and realtime routing that keeps thread replies out of the channel list.
  Requires backend `chat-messages` v1.1.0+. Default `false` keeps the existing
  inline-reply experience unchanged. See `docs/THREADS.md`.
  - New: `IsmChatThreadCoordinator`, `IsmChatThreadRepository`,
    `IsmChatThreadViewModel`, `IsmChatThreadController`/`IsmChatThreadBinding`,
    `IsmChatThreadView`, `IsmChatThreadFooter`, `IsmChatThreadMessageTile`,
    `IsmChatThreadComposer`, `IsmChatThreadsToggleTile`,
    `IsmChatThreadTheme`, `IsmChatThreadProperties`, `IsmChatFeedType`,
    `IsmChatFeature.threadReply`, `IsmChatFocusMenuType.replyInThread`.
  - `IsmChatMessageModel` gained `threadRootId`, `replyCount` and
    `lastThreadReplyAt` (all server-set, `null` on legacy messages).
  - `IsmChat.i`: `threadsEnabled`, `setThreadsEnabled`, `openThread`,
    `openThreadRoot`, `getThreadReplies`, `getThreadReplyCount`,
    `sendThreadReply`.
  - **Attachments in threads.** The thread composer opens the channel's own
    attachment sheet; photos, videos, camera, voice notes, documents, location
    and contacts are posted as thread replies through the existing pipelines
    (uploads, progress, storage-quota gate and offline retry unchanged), via
    the new `IsmChatThreadSendTarget` + `IsmChatPageController.threadSendTarget`.
    Media replies render in the panel with the SDK's message widgets. Turn the
    paperclip off with `IsmChatThreadProperties(showAttachments: false)`.
  - **Offline thread replies.** Thread replies are queued in the pending box
    and retried on reconnect as thread replies (`showInConversation` is now
    preserved when re-sending any queued message, instead of being forced to
    `true`), and still-queued replies are merged back into the panel on reopen.

### Changed

- `IsmChatPageController.sendMessage` accepts an optional `localEcho`; media,
  audio, document, location and contact pipelines now add their local row via
  `addLocalOutgoingRow` and update it via `mutateLocalRow` / `localOutgoingRow`,
  so a row composed inside a thread is owned by the thread panel. Channel sends
  are unaffected.

## 0.0.1

- Initial folder structer for architecture
