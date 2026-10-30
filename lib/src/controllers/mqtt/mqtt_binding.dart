// coverage:ignore-file
// GetX Bindings: DI wiring only.
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatMqttBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<IsmChatMqttController>(
      IsmChatMqttController(
        IsmChatMqttViewModel(
          IsmChatMqttRepository(),
        ),
      ),
      permanent: true,
    );
  }
}