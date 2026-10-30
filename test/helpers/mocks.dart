import 'package:flutter/foundation.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'fixtures.dart' as chat_fixtures;

/// mocktail doubles for the SDK's data layer.
///
/// **When to use which:**
/// - Testing a repository or a full controller flow → use the real classes
///   with `FakeChatApi` (see `fake_api.dart`) so HTTP parsing is covered.
/// - Testing a view model or controller branch in isolation (e.g. "what if
///   the repository returns null") → use these mocks and `when(...)`.
///
/// Call [registerChatFallbacks] once in `setUpAll` before using `any()` with
/// SDK model types.

class MockApiWrapper extends Mock implements IsmChatApiWrapper {}

class MockChatPageRepository extends Mock implements IsmChatPageRepository {}

class MockConversationsRepository extends Mock
    implements IsmChatConversationsRepository {}

class MockBroadcastRepository extends Mock
    implements IsmChatBroadcastRepository {}

class MockCommonRepository extends Mock implements IsmChatCommonRepository {}

class MockMqttRepository extends Mock implements IsmChatMqttRepository {}

class MockChatPageViewModel extends Mock implements IsmChatPageViewModel {}

class MockConversationsViewModel extends Mock
    implements IsmChatConversationsViewModel {}

class MockBroadcastViewModel extends Mock implements IsmChatBroadcastViewModel {}

class MockMqttViewModel extends Mock implements IsmChatMqttViewModel {}

class MockCommonViewModel extends Mock implements IsmChatCommonViewModel {}

bool _chatFallbacksRegistered = false;

/// Resets the idempotent guard (for tests that re-run registration logic).
@visibleForTesting
void resetChatFallbacksRegistration() {
  _chatFallbacksRegistered = false;
}

/// Registers fallback values so `any()` works for SDK model parameters.
///
/// Pass a **value only** — [registerFallbackValue] does not take type arguments
/// (e.g. `registerFallbackValue(message())`, not `<IsmChatMessageModel>`).
void registerChatFallbacks() {
  if (_chatFallbacksRegistered) {
    return;
  }
  _chatFallbacksRegistered = true;

  registerFallbackValue(chat_fixtures.message());
  registerFallbackValue(chat_fixtures.directConversation());
  registerFallbackValue(chat_fixtures.reaction());
  registerFallbackValue(IsmChatMetaData());
  // Broadcast / map payloads when stubbing with `any(named: ...)`.
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(<String, String>{});
  registerFallbackValue(<String>[]);
}
