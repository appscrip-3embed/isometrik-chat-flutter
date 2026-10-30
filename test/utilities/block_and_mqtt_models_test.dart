import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:isometrik_chat_flutter/src/controllers/mqtt/mqtt_helper.dart';
import 'package:isometrik_chat_flutter/src/services/giphy_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  group('IsmChatBlockUnblockCoordinator', () {
    test('classifies block/unblock actions and banner rows', () {
      expect(
        IsmChatBlockUnblockCoordinator.isBlockAction(
          IsmChatActionEvents.userBlock,
        ),
        isTrue,
      );
      expect(
        IsmChatBlockUnblockCoordinator.isBlockAction(
          IsmChatActionEvents.userBlockConversation,
        ),
        isTrue,
      );
      expect(
        IsmChatBlockUnblockCoordinator.isUnblockAction(
          IsmChatActionEvents.userUnblock,
        ),
        isTrue,
      );
      expect(
        IsmChatBlockUnblockCoordinator.isBannerMessage(
          message(customType: IsmChatCustomMessageType.block),
        ),
        isTrue,
      );
      expect(
        IsmChatBlockUnblockCoordinator.isConversationBlocked(
          directConversation(messagingDisabled: true),
        ),
        isTrue,
      );
      expect(
        IsmChatBlockUnblockCoordinator.isConversationBlocked(
          directConversation(),
        ),
        isFalse,
      );

      final list = [
        message(customType: IsmChatCustomMessageType.block, sentAt: 1),
        message(body: 'keep', sentAt: 2),
      ];
      IsmChatBlockUnblockCoordinator.removeBannerRowsFromList(list);
      expect(list, hasLength(1));

      final map = IsmChatBlockUnblockCoordinator.removeBannerRowsFromMap({
        '1': message(customType: IsmChatCustomMessageType.unblock, sentAt: 1),
        '2': message(body: 'keep', sentAt: 2),
      });
      expect(map.keys, ['2']);
    });
  });

  group('MQTT wrapper models', () {
    test('ServerConfig / ProjectConfig / WebSocketConfig / MqttConfig', () {
      const server = ServerConfig(hostName: 'mqtt.test', port: 8883);
      expect(ServerConfig.fromJson(server.toJson()).hostName, 'mqtt.test');
      expect(server.copyWith(port: 1883).port, 1883);
      expect(server == server, isTrue);

      final project = ProjectConfig(
        deviceId: 'd',
        userIdentifier: 'u',
        username: 'user',
        password: 'pass',
      );
      expect(ProjectConfig.fromJson(project.toJson()).username, 'user');
      expect(project.copyWith(username: 'x').username, 'x');

      final ws = WebSocketConfig(
        useWebsocket: true,
        websocketProtocols: const ['mqtt'],
      );
      expect(WebSocketConfig.fromJson(ws.toJson()).useWebsocket, isTrue);
      expect(ws.copyWith(useWebsocket: false).useWebsocket, isFalse);

      final mqtt = MqttConfig(
        serverConfig: server,
        projectConfig: project,
        webSocketConfig: ws,
      );
      expect(MqttConfig.fromJson(mqtt.toJson()).secure, isFalse);
      expect(mqtt.copyWith(secure: true).secure, isTrue);

      final client = MqttHelperClient()..setup(mqtt);
      expect(client.client.server, 'mqtt.test');
    });
  });

  group('IsmGiphyService', () {
    test('empty key or query returns no items', () async {
      expect(
        await IsmGiphyService.search(
          apiKey: '',
          query: 'cat',
          stickers: false,
        ),
        isEmpty,
      );
      expect(
        await IsmGiphyService.search(
          apiKey: 'k',
          query: '  ',
          stickers: true,
        ),
        isEmpty,
      );
      expect(
        await IsmGiphyService.trending(apiKey: '', stickers: false),
        isEmpty,
      );
    });
  });
}
