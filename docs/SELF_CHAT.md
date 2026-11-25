# Self chat

WhatsApp / Teams-style **message yourself**: one private conversation per user,
flagged on the API as `selfChat: true`.

## Host integration

Feature is **off by default**. Turn it on with conversation properties:

```dart
IsmChatConversationProperties(
  enableSelfChat: true,
  showCreateChatIcon: true,
  onCreateTap: () {},
  // optional: enableGroupChat: true, // adds "Message yourself" to the create sheet
),
```

Programmatic open (still respects `enableSelfChat`):

```dart
await IsmChat.i.openSelfChat();
```

### When the conversation is created

- If the user **already has** a self chat (list or local DB), `openSelfChat()` opens it by `conversationId` (history loads as usual).
- If **not**, the SDK opens an in-memory placeholder ([`IsmChatConversationModel.selfChatPlaceholder`](lib/src/models/chat_conversation_model.dart)) with an empty `conversationId` — same idea as picking someone new in 1:1 chat.
- The **`POST /chat/conversation`** with `selfChat: true` runs on **first send** (text, media, etc.) via the chat page `createConversation()` path, not when the user opens “Message yourself”.

When `enableSelfChat` is `false`:

- No bottom-sheet / FAB entry points
- `openSelfChat()` is a no-op
- Self-chat rows from the API are hidden in the SDK list

## API summary

Full backend contract: see project attachment `SELF_CHAT_API.md`.

| Action | Detail |
|--------|--------|
| Create / reopen | `POST /chat/conversation` with `selfChat: true`, `conversationType: 0`, `isGroup: false`, event flags required; `members` ignored |
| List / details | Response may include `selfChat: true`; treat missing as `false` |
| Display | Use SDK `chatName` / `profileUrl` — do not read `opponentDetails` or `conversationTitle` |

## SDK behavior

- **`IsmChatSelfChatLabels`** — display name `{userName} (You)` and profile from `IsmChatUserConfig`
- **`IsmChatConversationModel.isSelfChat`** — parsed from API / DB
- **`createSelfChat`** — `IsmChatCommonController` → `POST` with `selfChat: true` (first send or direct API call)
- **`selfChatPlaceholder`** — stub conversation until first send
- List sorting does not treat self chat as “deleted user” (empty `opponentDetails`)
- Block / unblock is hidden and disabled for self chat (header ⋮ menu, conversation info, and `blockUser` / `unblockUser` APIs)