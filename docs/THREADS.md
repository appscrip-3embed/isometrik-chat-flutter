# Slack-Style Message Threads

Replies grouped under a root message, in their own thread panel, with a
"N replies" badge in the channel — the Slack model, on top of the existing
Isometrik chat.

The feature is **off by default**. With `IsmChatConfig.threadsEnabled == false`
the SDK behaves exactly as it always has: replies are inline quotes in the
timeline, message fetches carry no `feedType`, no thread UI exists, and nothing
in the realtime path changes. Turning it on switches the whole experience over —
in one flag, at init or at runtime.

Requires backend **`chat-messages` v1.1.0+** (`threadRootId`, `replyCount`,
`feedType`). See `THREADING_API_HANDOFF.md` for the server contract.

---

## Turning it on

```dart
// At init:
await IsmChat.i.initialize(
  communicationConfig: config,
  kNavigatorKey: navigatorKey,
  threadsEnabled: true,
);

// Or at runtime (a settings switch, a remote flag, an A/B test):
await IsmChat.i.setThreadsEnabled(true);
print(IsmChat.i.threadsEnabled); // true
```

`setThreadsEnabled` re-reads the open conversation, so the timeline is
immediately re-fetched with (or without) the threaded filter — no restart, no
cache clearing.

The SDK also ships a drop-in switch you can place anywhere (settings screen,
chat-list menu, debug panel):

```dart
IsmChatThreadsToggleTile(
  onChanged: (enabled) => analytics.log('threads', enabled),
)
```

The `example/` app has it under the **tune** icon in the conversation-list
header, as a bottom sheet.

---

## What changes when it is on

| Surface | Threads off (default) | Threads on |
| --- | --- | --- |
| Channel fetch | `GET /chat/messages?conversationId=…` | same + `feedType=main` |
| Thread-only replies | render inline in the timeline | hidden from the timeline, shown in the thread panel |
| Root message | plain bubble | bubble + tappable **"N replies"** footer |
| Focus menu (long-press) | Reply, Forward, … | the same, plus **Reply in thread** |
| Thread composer | n/a | same chrome as the channel field (`textFiledTheme` insets/decoration, emoji prefix, in-field attach, mic/send, full [IsmChatComposerEmojiBoard] with GIF/sticker when configured); hold-to-record when [IsmChatFeature.audioMessage] is on |
| Message reactions | channel bubbles | same chips and focus-menu picker (long-press; right-click on web) on root and replies; the open panel stays in sync with the channel and local DB |
| Incoming reply (MQTT) | appended to the channel | routed to the open thread; only the root's badge moves in the channel |
| Offline send | queued in the pending box, retried on reconnect | identical — a queued thread reply is retried **as a thread reply** |
| Conversation preview | last message, whatever it is | last **channel** message (thread replies do not replace the snippet) |
| Unread badge | counts every message | unchanged — still counts thread replies |
| Deleting a root with replies | n/a | server rejects it (`errorCode: 4`); the SDK shows "thread has replies" |

Inline quoting is **not** replaced: "Reply" still quotes a message in the
channel. Threads add a second, separate way to answer.

---

## Data model

Three server-maintained fields arrive on `IsmChatMessageModel`:

| Field | On | Meaning |
| --- | --- | --- |
| `threadRootId` | every reply (`messageType: 2`) | the thread's root message id — use this, not `parentMessageId`, to load a thread |
| `replyCount` | root messages | number of replies in that thread |
| `lastThreadReplyAt` | root messages | timestamp (ms) of the newest reply |

`parentMessageId` keeps its meaning: the **immediate** parent. A reply to a
reply therefore has `parentMessageId == <that reply>` and
`threadRootId == <the root>`, which is how nested replies stay in one thread.

Convenience getters (they classify the message and work regardless of the flag;
only `showThreadFooter` is gated by it):

```dart
message.isThreadReply;      // messageType 2 + threadRootId
message.isThreadOnlyReply;  // …and showInConversation == false
message.threadId;           // threadRootId, or own id when it is the root
message.threadReplyCount;   // replyCount ?? 0
message.showThreadFooter;   // should the channel show "N replies"?
```

### "Also send to channel"

Slack's checkbox is `showInConversation` on the reply:

- `false` (default) — thread panel only.
- `true` — the reply shows in **both** the thread and the channel timeline.

The thread composer shows the checkbox; hide it with
`IsmChatThreadProperties(showAlsoSendToChannel: false)` to make every reply
thread-only.

On the channel, those rows show **replied to a thread: …** directly above the
bubble (same alignment, minimal gap so it is obvious which message it refers
to; subject truncated to 10 characters). The long-press
menu says **View thread** instead of **Reply in thread**; it still opens the
same thread panel.

Inside [IsmChatThreadView], long-press on the root or any reply does **not**
include **Reply**, **Reply in thread**, or **View thread** — answer with the
composer (or tap a text reply to set a reply-to target; that stays in the same
thread). The reply strip above the thread
field reuses [IsmChatComposerReplyBar] from the channel composer (sender,
caption, image/video thumb).

---

## Public API (`IsmChat.i`)

```dart
// Feature switch
IsmChat.i.threadsEnabled;                       // bool
await IsmChat.i.setThreadsEnabled(true);

// Open the built-in panel (route on mobile, dialog on web)
await IsmChat.i.openThread(message);
IsmChat.i.openThreadRoot;                       // root of the open panel, or null

// Headless: build your own thread UI
final replies = await IsmChat.i.getThreadReplies(
  conversationId: message.conversationId!,
  threadRootId: message.messageId!,             // or reply.threadRootId
  limit: 20,
  skip: 0,                                      // oldest-first, page with skip
);
final count = await IsmChat.i.getThreadReplyCount(
  conversationId: message.conversationId!,
  threadRootId: message.messageId!,
);

// Send a reply (parent may be the root or another reply)
await IsmChat.i.sendThreadReply(parent: message, text: 'On it');
await IsmChat.i.sendThreadReply(
  parent: message,
  text: 'FYI everyone',
  alsoSendToChannel: true,
);
```

With threads off, the reads return empty/`null` and the sends return `false`
without touching the network — safe to call behind your own feature flag.

---

## Customising the UI

### Copy and widgets — `IsmChatProperties.threadProperties`

```dart
IsmChatProperties.threadProperties = IsmChatThreadProperties(
  title: 'Thread',                       // panel app-bar title
  composerHintText: 'Reply…',
  showAlsoSendToChannel: true,
  alsoSendToChannelLabel: 'Also send to #general',
  replyFooterBuilder: (context, message, replyCount) =>
      MyThreadBadge(message, replyCount),   // replaces "N replies"
  rootMessageBuilder: (context, root) => MyRootCard(root),
  replyTileBuilder: (context, reply) => MyReplyRow(reply),
  emptyPlaceholder: const Text('Be the first to reply'),
  onThreadOpened: (root) => analytics.log('thread_open', root.messageId),
);
```

A `replyFooterBuilder` owns its tap handling — call
`IsmChat.i.openThread(message)` (or your own screen) from it.

### Styling — `IsmChatThemeData.threadTheme`

```dart
IsmChatConfig.chatLightTheme = IsmChatThemeData(
  primaryColor: yourPrimary,
  threadTheme: IsmChatThreadTheme.light(),  // or a fully custom instance
);
```

Omit `threadTheme` for SDK light/dark defaults
([`IsmChatThemeResolver.threadFromConfig`](../lib/src/res/theme/chat_theme_resolver.dart)).
The panel's app bar uses your existing `IsmChatHeaderTheme`.

### Hiding the entry points

Drop `IsmChatFeature.threadReply` from `IsmChatPageProperties.features` to hide
the "Reply in thread" action and the "N replies" footer while keeping the data
rules (useful when you drive threads entirely from your own UI):

```dart
IsmChatProperties.chatPageProperties = IsmChatPageProperties(
  features: IsmChatFeature.values
      .where((f) => f != IsmChatFeature.threadReply)
      .toList(),
);
```

---

## How it is wired

```
IsmChatConfig.threadsEnabled
        │
        ▼
IsmChatThreadCoordinator ──── pure rules: classify, filter, count, ids, delete code
        │                     (every decision lives here — nothing else branches)
        ├── IsmChatPageViewModel / IsmChatPageRepository → feedType=main, DB filter
        ├── get_message.filterMessages                   → timeline filter
        ├── MQTT message_handlers                        → route replies, badge only
        └── IsmChatThreadController ← IsmChatThreadViewModel ← IsmChatThreadRepository
                    │                   (GET feedType=thread, count, POST messageType 2)
                    ├── IsmChatThreadView  (root card + replies + composer)
                    └── IsmChatThreadFooter ("N replies" in the channel)
```

| File | Role |
| --- | --- |
| [`thread_coordinator.dart`](../lib/src/utilities/thread_coordinator.dart) | All threading rules, as pure functions |
| [`chat_thread_repository.dart`](../lib/src/repositories/chat_thread_repository.dart) | `feedType=thread` fetch, thread count, reply send |
| [`chat_thread_view_model.dart`](../lib/src/view_models/chat_thread_view_model.dart) | Response hygiene + send mapping |
| [`chat_thread_controller.dart`](../lib/src/controllers/chat_thread/chat_thread_controller.dart) | Panel state: replies, paging, optimistic send, realtime merge |
| [`chat_thread_view.dart`](../lib/src/views/chat_thread/chat_thread_view.dart) | The thread panel |
| [`thread_footer.dart`](../lib/src/views/chat_thread/widget/thread_footer.dart) | "N replies" row under a root bubble |
| [`threads_toggle_tile.dart`](../lib/src/views/chat_thread/widget/threads_toggle_tile.dart) | Drop-in on/off switch |
| [`thread_send_target.dart`](../lib/src/models/thread_send_target.dart) | Where an attachment send composed in a thread should land |
| [`delegate_threads.dart`](../lib/delegate/delegate_threads.dart) / [`threads_operations.dart`](../lib/mixins/threads_operations.dart) | `IsmChat.i` surface |

**Local database.** Replies *fetched* for the panel are kept in memory only —
the panel reads the API, so the cached conversation does not grow. Replies
*you send* follow the normal pending → main path (that is what makes the
offline queue and upload progress work), and the root's `replyCount` /
`lastThreadReplyAt` are written to the cached conversation so the badge
survives a reopen. Either way the channel list, previews and unread counts
behave exactly as they do today, because the timeline filters thread-only rows
by `threadRootId` + `showInConversation`.

---

## Realtime

Incoming messages are classified by `showInConversation` + `threadRootId`:

| Event | SDK behaviour |
| --- | --- |
| Reply with `showInConversation: false` | appended to the open panel; root `replyCount` bumped in the list **and** in the cached conversation; **not** added to the channel list; conversation preview untouched; unread still incremented |
| Reply with `showInConversation: true` | normal channel message **and** part of the thread |
| Anything else | unchanged |

Out-of-order arrivals cannot rewind `lastThreadReplyAt`, and an echo of your
own reply replaces the optimistic row instead of duplicating it.

---

## Deleting

- **Deleting a reply** works normally; the server lowers the root's
  `replyCount`, and the SDK mirrors that locally (open panel + cached root).
- **Deleting a root that still has replies** is refused by the server with
  `errorCode: 4`. The SDK surfaces
  `IsmChatStrings.threadRootDeleteBlocked` ("This message can't be deleted
  because its thread has replies."). Delete the replies first, or hide the
  action for roots where `message.threadReplyCount > 0`.

---

## Attachments in a thread

The thread composer matches [IsmChatMessageField] visually and opens the **same**
attachment sheet as the channel. Hold-to-record uses the channel's
`recordVoice` / `sendAudio` paths with thread-local UI state so web split-view
does not toggle the channel composer. Replies still travel through the **same**
pipelines — so
uploads, presigned URLs, compression, progress, the storage-quota gate and the
offline queue all behave exactly as they do in the channel.

How it works: while the panel is on screen it publishes an
[`IsmChatThreadSendTarget`](../lib/src/models/thread_send_target.dart) to
`IsmChatPageController.threadSendTarget`. Every send pipeline stamps that target
onto the local row it builds
([`IsmChatThreadCoordinator.stampThreadTarget`](../lib/src/utilities/thread_coordinator.dart)),
so the row, the copy saved to the pending box and the API request can never
disagree. The request then goes out as `messageType: 2` + `parentMessageId` +
`showInConversation`, and the row is shown in the panel instead of the channel.

```dart
// Host code can target a thread explicitly, e.g. from a custom composer:
IsmChatUtility.chatPageController.threadSendTarget =
    IsmChatThreadSendTarget.forThread(root: rootMessage);
// …trigger any normal send (media, document, location, …) …
IsmChatUtility.chatPageController.threadSendTarget = null;
```

Media replies render in the panel with the SDK's own message widgets, so a
photo looks like a photo and a voice note plays. Switch the paperclip off with
`IsmChatThreadProperties(showAttachments: false)` to make threads text-only.

Closing the panel clears the target, so a later channel send is a plain channel
message again.

## Offline sends

Thread replies are queued exactly like channel messages:

- the reply is written to the pending box before the request goes out;
- if it never reaches the server, the row stays in the panel, the composer says
  it is queued ([`IsmChatStrings.threadReplyQueued`]), and
  `sendPendingMessgae` retries it on reconnect **as a thread reply** (the
  stored `showInConversation` is what makes that work);
- if the server rejects it, the queued copy is dropped so it is not retried
  forever, and the reason is shown;
- reopening a thread merges still-queued replies into the panel, because the
  server does not have them yet.

Because of that queue, a locally-sent thread reply is also stored in the cached
conversation like any message. The channel timeline filters it out by
`threadRootId` + `showInConversation`, and it never becomes the conversation's
preview. Replies **fetched** for the panel are not cached — the panel reads the
API.

## Reactions in the thread panel

When [IsmChatFeature.reaction] is on and the chat page is mounted,
[IsmChatThreadMessageTile] shows the same reaction chips as [MessageCard] and
opens the channel focus menu on long-press (right-click on web), including
[ReactionGrid]. Row state is kept in sync through
[IsmChatThreadController.applyMessageUpdate] when you add or remove a reaction,
when MQTT delivers someone else's reaction, and when `getMessagesFromDB`
refreshes the channel timeline — so the panel does not need to be reopened.

Media rows and the reaction picker still require [IsmChatPageController] to be
registered (same as thread attachment previews). Custom rows from
`replyTileBuilder` / `rootMessageBuilder` must wire reactions themselves.

## Limitations

- **Message search stays on the main timeline** when threads are on, so a hit
  can always be scrolled to in the channel.
- Copy and delete from the thread panel rows still use the channel focus menu or
  your own `replyTileBuilder` / `rootMessageBuilder` if you replace SDK rows.

---

## Tests

| File | Covers |
| --- | --- |
| [`test/utilities/thread_coordinator_test.dart`](../test/utilities/thread_coordinator_test.dart) | Every rule, with the flag on and off |
| [`test/repositories/chat_thread_repository_test.dart`](../test/repositories/chat_thread_repository_test.dart) | Request URLs, query params, send payloads, error bodies |
| [`test/controllers/thread_controller_test.dart`](../test/controllers/thread_controller_test.dart) | Panel state: open, page, optimistic send, realtime, delete |
| [`test/controllers/thread_flow_test.dart`](../test/controllers/thread_flow_test.dart) | End-to-end on the real chat page + database + MQTT, both flag states |
| [`test/widgets/thread_widgets_test.dart`](../test/widgets/thread_widgets_test.dart) | Footer, reply tile, panel, composer, toggle tile |

```bash
flutter test test/utilities/thread_coordinator_test.dart \
             test/repositories/chat_thread_repository_test.dart \
             test/controllers/thread_controller_test.dart \
             test/controllers/thread_flow_test.dart \
             test/widgets/thread_widgets_test.dart
```
