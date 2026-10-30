# Chat SDK tests

## Layout

| Folder | What it covers |
| --- | --- |
| `helpers/` | Shared bootstrap, fake HTTP backend, fixtures, mocks (reuse these) |
| `models/` | `fromMap` / `toMap` / `copyWith` / equality for models |
| `data/` | `IsmChatApiWrapper` (status codes, timeout, loader) and `IsmChatDBWrapper` |
| `repositories/` | Every repository method, success + error + exception paths |
| `view_models/` | Business rules on top of repositories |
| `controllers/` | End-to-end flows: 1-to-1, group, attachments, reactions, broadcast, MQTT events |
| `utilities/` | Extensions, utility helpers, masker, enums |
| `widgets/` | Key widgets only (message bubbles per attachment type, input field) |

## Reusable helpers

- `helpers/test_bootstrap.dart`
  - `configureChatSdk()` fills `IsmChatConfig` like `IsmChat.i.initialize`
    (no MQTT). Use in `setUp` of plain unit tests.
  - `openTestDatabase()` opens a real Hive DB in a temp dir
    (via `IsmChatDBWrapper.create(name, directoryPath)`).
  - `chatTestWidgets(...)` is the entry point for flow tests: config + host
    app + DB + `FakeChatApi` + all three controllers, cleaned up afterwards.
  - `settle`, `pumpUntil`, `drive`: Hive file IO does not progress inside
    `testWidgets`' fake-async zone on its own. Wrap any controller call that
    touches the DB in `drive(tester, () => ...)`.
  - `resetChatSdk()` clears GetX and config. Always call it in `tearDown`.
- `helpers/fake_api.dart`: `FakeChatApi` is an in-memory HTTP backend.
  Register routes with `on('GET', '/chat/messages', FakeResponse.json(...))`,
  then assert on `requests` / `requestsTo(...)`. Pass `api.wrapper()` to any
  repository (`IsmChatPageRepository(apiWrapper: api.wrapper())`).
- `helpers/fixtures.dart`: `directConversation()`, `groupConversation()`,
  `message(...)`, `reaction()`, `attachment(type)`, `attachmentMessages()`, `messageJson()`,
  `conversationJson()`. Change model construction here, not in tests.
- `helpers/mocks.dart`: mocktail mocks for repositories and view models,
  for branch tests that need a repository to return `null` etc.

## Testability hooks in `lib/`

These optional constructor parameters exist only for tests and default to
production behaviour:

- `IsmChatApiWrapper({http.Client? client, Duration timeout})`
- `IsmChat*Repository({IsmChatApiWrapper? apiWrapper})`, for all five repositories
- `IsmChatDBWrapper.create([String? databaseName, String? directoryPath])`

## Running

```bash
flutter test                 # all tests
tool/coverage.sh             # tests + business-logic coverage gate
```

`tool/coverage.sh` holds models, data, repositories, view models, controllers,
utilities and services to 100% line coverage. UI (`lib/src/views`,
`lib/src/widgets`) is out of scope. Platform-plugin glue (camera, pickers,
record, contacts, MQTT sockets, dialogs) and remaining unreachable branches
are marked `// coverage:ignore-file` with a short reason so the gate stays
honest about what the VM runner can execute.

```bash
tool/coverage.sh          # fail if in-scope coverage is below 100%
MIN=90 tool/coverage.sh   # custom threshold
```
