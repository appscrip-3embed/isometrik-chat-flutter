// coverage:ignore-file
// GetX Bindings: DI wiring only.
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// Wires the storage-quota controller stack.
///
/// Idempotent: safe to call before pushing the storage screen even when the
/// controller is already registered permanently by [IsmChatCommonBinding].
class IsmChatStorageQuotaBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<IsmChatStorageQuotaController>()) {
      Get.put<IsmChatStorageQuotaController>(
        IsmChatStorageQuotaController(
          IsmChatStorageQuotaViewModel(
            IsmChatStorageQuotaRepository(),
          ),
        ),
        permanent: true,
      );
    }
  }
}
