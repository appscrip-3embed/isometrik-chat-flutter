// coverage:ignore-file
// GetX Bindings: DI wiring only.
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Wires the thread controller stack ([IsmChatThreadController]).
///
/// Idempotent and lazy: the controller only exists once a thread is actually
/// opened, so integrations with [IsmChatConfig.threadsEnabled] off never pay
/// for it. [IsmChatThreadView] calls this in `initState`; host apps that drive
/// threads themselves can call it before `Get.find`.
class IsmChatThreadBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<IsmChatThreadController>()) {
      Get.put<IsmChatThreadController>(
        IsmChatThreadController(
          IsmChatThreadViewModel(
            IsmChatThreadRepository(),
          ),
        ),
      );
    }
  }
}
