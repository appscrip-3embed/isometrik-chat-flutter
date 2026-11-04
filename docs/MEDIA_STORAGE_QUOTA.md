# Media Storage Quota

Per-user media storage quotas (WhatsApp / Teams style). Each user gets a storage
allowance; when they fill it, **new media uploads** are blocked with an
"out of space" prompt while **sending and receiving text is never blocked**.

The feature is **dormant until an admin turns quota on for the project**. Until
then the SDK behaves exactly as before: `quotaEnabled` is `false`, uploads are
not gated, and the storage screen shows a neutral "not limited" state.

Everything is **server-authoritative** — the SDK never computes usage on-device.

---

## What the SDK gives you

| Surface | What it is |
| --- | --- |
| `IsmChat.i` storage methods | Read usage, list media, delete media — build your own UI. |
| `IsmChat.i.openStorageManagement()` | A ready-made, themeable "Manage Storage" screen. |
| Upload enforcement | Pre-checks quota before upload and surfaces the server's "quota exceeded" rejection. |
| Restricted media | Fetched attachments flagged `restricted` render a "media unavailable" placeholder instead of a broken image. |

No wiring is required for enforcement or restricted-media rendering — both are
built into the existing send/fetch paths. You only call the APIs below if you
want your own storage UI, or use `openStorageManagement()` for the built-in one.

---

## Public API (`IsmChat.i`)

```dart
// 1. Usage (server-authoritative). Cached after the first read.
final usage = await IsmChat.i.getStorageUsage();           // cached if present
final fresh = await IsmChat.i.getStorageUsage(forceRefresh: true);
if (usage?.quotaEnabled == true) {
  print('${usage!.usedBytes} / ${usage.quotaBytes} '
        '(${usage.remainingBytes} free, tier ${usage.tier})');
  print('canUpload: ${usage.canUpload}');                  // false when full
}

// 2. List the user's charged media (newest first). Page with limit (1..20)/skip.
final page = await IsmChat.i.getStorageMedia(skip: 0, limit: 20);
final oneConversation =
    await IsmChat.i.getStorageMedia(conversationId: convId, limit: 20);
// Stop paging when `page.media` is empty or shorter than `limit`.

// 3. Delete selected media (for everyone) and free the bytes.
final result = await IsmChat.i.deleteStorageMedia([mediaId1, mediaId2]);
print('freed ${result?.freedBytes}, now ${result?.usedBytes}/${result?.quotaBytes}');

// 4. Delete every file this user sent in one conversation (for everyone).
await IsmChat.i.deleteConversationStorageMedia(convId);

// 5. Open the built-in Manage Storage screen (optionally scoped).
await IsmChat.i.openStorageManagement();
await IsmChat.i.openStorageManagement(conversationId: convId);
```

> **Delete is "for everyone."** Deleting media removes the whole message that
> owns it for every member of the conversation (text on that message is removed
> too). This matches the sender-owns storage model.

---

## Models

### `IsmChatStorageUsageModel`
`quotaEnabled`, `canUpload`, `usedBytes?`, `quotaBytes?`, `remainingBytes?`,
`tier?` (`IsmChatStorageQuotaTier.free | paid`). Helpers:
`usedFraction` (0..1 for a progress bar), `isOverLimit`, `canUploadBytes(size)`.
When quota is off, the byte fields and `tier` are `null` and `canUpload` is `true`.

### `IsmChatQuotaMediaModel`
One charged media row: `mediaId`, `messageId`, `conversationId`,
`attachmentType` (`IsmChatMediaType`), `name`, `size`, `mediaUrl?`,
`thumbnailUrl?`, `restricted`. Helper: `isViewable`. A `restricted` row is past
the allowance — show it so the user can delete it, but don't open its media.

### `IsmChatMediaDeleteResultModel`
`freedBytes`, `usedBytes?`, `quotaBytes?`, `msg?`. Helper: `isUnderQuota`.
`freedBytes` can be `0` when another copy of the same file keeps the bytes alive.

---

## Upload enforcement (built in)

- **Before upload**, the SDK checks the picked batch against `remainingBytes`
  and shows an "out of space" prompt (with a "Manage storage" action) when it
  won't fit. The prompt never blocks text.
- **On send**, if the server still rejects for quota (`HTTP 403`,
  `errorCode: 6`), the SDK surfaces the same prompt and refreshes usage.

To run the pre-check yourself (e.g. a custom composer), use the guard:

```dart
final ok = await IsmChatStorageQuotaGuard.ensureCanUpload(
  totalBytes: file.lengthInBytes,
  showPrompt: true,
);
if (!ok) return; // prompt already shown
```

---

## Restricting the UI's look

The Manage Storage screen and placeholders use the SDK theme
(`IsmChatConfig.chatTheme.primaryColor`, light/dark `cardColor`, etc.), so they
inherit your existing `IsmChatThemeData`. Teams that want a fully custom screen
can skip `openStorageManagement()` and build their own against the `IsmChat.i`
methods above.

---

## Try it in the example app

Run the `example/` app and tap **Manage storage** in the conversation-list
header to open the built-in screen against your project.

---

## Keeping usage in sync

Cached usage is refreshed automatically:

- after a storage-screen delete (`deleteStorageMedia` / `deleteConversationStorageMedia`);
- after a **chat message delete** when quota is on — the freed bytes in the
  delete response are applied to the cached usage, so the meter and upload
  gate stay correct without a manual refresh;
- the paging cursor is pulled back when rows are deleted mid-scroll, so the
  next page never skips unseen media.

For anything else, call `IsmChat.i.getStorageUsage(forceRefresh: true)`.

## Notes / limitations

- Media list is **newest-first** from the server; the built-in screen offers a
  client-side "largest first" re-sort and type filter over loaded rows.
- Only media **sent after quota charging started** is listed and counted; older
  attachments are untouched.
- Thumbnails, stickers, GIFs, location and system messages are not charged.
