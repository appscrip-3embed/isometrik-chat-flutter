// coverage:ignore-file
// GetX Bindings: DI wiring only.
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatCommonBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(
      IsmChatCommonController(
        IsmChatCommonViewModel(
          IsmChatCommonRepository(),
        ),
      ),
      permanent: true,
    );
    // Storage-quota controller is permanent so upload enforcement can read the
    // cached usage snapshot from anywhere in the chat flow. It does not fetch
    // on init — usage is loaded lazily on first check / when the screen opens.
    IsmChatStorageQuotaBinding().dependencies();
  }
}
