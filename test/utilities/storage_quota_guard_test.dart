import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  IsmChatStorageQuotaController registerController() {
    final controller = IsmChatStorageQuotaController(
      IsmChatStorageQuotaViewModel(
        IsmChatStorageQuotaRepository(apiWrapper: FakeChatApi().wrapper()),
      ),
    );
    Get.put<IsmChatStorageQuotaController>(controller, permanent: true);
    return controller;
  }

  IsmChatResponseModel response(
    Map<String, dynamic> body, {
    bool hasError = false,
    int errorCode = 200,
  }) =>
      IsmChatResponseModel(
        data: jsonEncode(body),
        hasError: hasError,
        errorCode: errorCode,
      );

  group('isQuotaError', () {
    test('true only for the storage-quota error code (6)', () {
      expect(
        IsmChatStorageQuotaGuard.isQuotaError(
          response(const {'errorCode': 6, 'error': 'Storage quota exceeded.'},
              hasError: true, errorCode: 403),
        ),
        isTrue,
      );
      // A different 403 (e.g. blocked) is not a quota error.
      expect(
        IsmChatStorageQuotaGuard.isQuotaError(
          response(const {'errorCode': 3, 'error': 'Blocked.'},
              hasError: true, errorCode: 403),
        ),
        isFalse,
      );
      // A success response is never a quota error.
      expect(
        IsmChatStorageQuotaGuard.isQuotaError(
          response(const {'messageId': 'x'}),
        ),
        isFalse,
      );
    });
  });

  group('syncUsageFromResponse', () {
    test('updates cached usage from a delete response with figures', () {
      final controller = registerController()
        ..usage = const IsmChatStorageUsageModel(
          quotaEnabled: true,
          canUpload: false,
          usedBytes: 100,
          quotaBytes: 100,
          remainingBytes: 0,
        );

      IsmChatStorageQuotaGuard.syncUsageFromResponse(
        response(const {
          'msg': 'Message deleted successfully.',
          'freedBytes': 40,
          'usedBytes': 60,
          'quotaBytes': 100,
        }),
      );

      expect(controller.usage!.usedBytes, 60);
      expect(controller.usage!.remainingBytes, 40);
      expect(controller.usage!.canUpload, isTrue);
    });

    test('is a no-op when the response carries no quota figures', () {
      final controller = registerController()
        ..usage = const IsmChatStorageUsageModel(
          quotaEnabled: true,
          canUpload: false,
          usedBytes: 100,
          quotaBytes: 100,
          remainingBytes: 0,
        );

      // Quota-off delete-message response: just a message, no figures.
      IsmChatStorageQuotaGuard.syncUsageFromResponse(
        response(const {'msg': 'Message deleted successfully.'}),
      );

      expect(controller.usage!.usedBytes, 100); // unchanged
      expect(controller.usage!.canUpload, isFalse);
    });

    test('is a no-op on an error response', () {
      final controller = registerController()
        ..usage = const IsmChatStorageUsageModel(
          quotaEnabled: true,
          canUpload: true,
          usedBytes: 10,
          quotaBytes: 100,
          remainingBytes: 90,
        );

      IsmChatStorageQuotaGuard.syncUsageFromResponse(
        response(const {'usedBytes': 999, 'quotaBytes': 100},
            hasError: true, errorCode: 500),
      );

      expect(controller.usage!.usedBytes, 10); // unchanged
    });
  });

  group('canUpload pre-check', () {
    test('allows when the SDK is dormant (no controller registered)', () async {
      // No controller in GetX.
      expect(await IsmChatStorageQuotaGuard.canUpload(totalBytes: 1 << 30),
          isTrue);
    });

    test('allows when quota is off', () async {
      registerController().usage = const IsmChatStorageUsageModel(
        quotaEnabled: false,
        canUpload: true,
      );
      expect(await IsmChatStorageQuotaGuard.canUpload(totalBytes: 1 << 40),
          isTrue);
    });

    test('blocks a file larger than the remaining allowance', () async {
      registerController().usage = const IsmChatStorageUsageModel(
        quotaEnabled: true,
        canUpload: true,
        usedBytes: 60,
        quotaBytes: 100,
        remainingBytes: 40,
      );
      expect(await IsmChatStorageQuotaGuard.canUpload(totalBytes: 30), isTrue);
      expect(await IsmChatStorageQuotaGuard.canUpload(totalBytes: 50), isFalse);
    });
  });
}
