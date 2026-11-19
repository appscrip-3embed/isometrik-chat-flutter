import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  IsmChatStorageQuotaController registerQuota({bool canUpload = true}) {
    final controller = IsmChatStorageQuotaController(
      IsmChatStorageQuotaViewModel(
        IsmChatStorageQuotaRepository(apiWrapper: FakeChatApi().wrapper()),
      ),
    );
    Get.put<IsmChatStorageQuotaController>(controller, permanent: true);
    controller.usage = IsmChatStorageUsageModel(
      quotaEnabled: true,
      canUpload: canUpload,
      usedBytes: 60,
      quotaBytes: 100,
      remainingBytes: canUpload ? 40 : 0,
    );
    return controller;
  }

  group('IsmChatSameNameAttachmentUpload', () {
    test('non-duplicate presign PUTs and returns URLs', () async {
      var putCalled = false;
      final outcome = await IsmChatSameNameAttachmentUpload.resolveAndUpload(
        fileBytes: 4,
        isThumbnailPresign: false,
        presign: ({required bool forceUpload}) async => PresignedUrlModel(
          mediaUrl: 'https://cdn.test/new.jpg',
          mediaPresignedUrl: 'https://s3.test/put',
          mediaId: 'mid',
        ),
        putBytes: (url, bytes) async {
          putCalled = true;
          expect(url, 'https://s3.test/put');
          return 200;
        },
        mediaBytes: Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(putCalled, isTrue);
      expect(outcome?.presigned?.mediaUrl, 'https://cdn.test/new.jpg');
      expect(outcome?.forceUploadOnMessage, isFalse);
    });

    test('duplicate + reshare skips PUT', () async {
      registerQuota();
      var putCount = 0;
      final outcome = await IsmChatSameNameAttachmentUpload.resolveAndUpload(
        fileBytes: 10,
        isThumbnailPresign: false,
        presign: ({required bool forceUpload}) async {
          if (forceUpload) {
            fail('should not force-upload on reshare');
          }
          return PresignedUrlModel(
            duplicate: true,
            mediaUrl: 'https://cdn.test/older.jpg',
            thumbnailUrl: 'https://cdn.test/older-thumb.jpg',
            mediaId: 'mid',
          );
        },
        putBytes: (_, __) async {
          putCount++;
          return 200;
        },
        mediaBytes: Uint8List(10),
        duplicateChoicePrompt: (_) async => SameNameUploadChoice.reshare,
      );
      expect(putCount, 0);
      expect(outcome?.presigned?.mediaUrl, 'https://cdn.test/older.jpg');
      expect(outcome?.forceUploadOnMessage, isFalse);
    });

    test('duplicate + upload copy sets forceUploadOnMessage', () async {
      registerQuota();
      var putCount = 0;
      final outcome = await IsmChatSameNameAttachmentUpload.resolveAndUpload(
        fileBytes: 10,
        isThumbnailPresign: false,
        presign: ({required bool forceUpload}) async {
          if (!forceUpload) {
            return PresignedUrlModel(
              duplicate: true,
              mediaUrl: 'https://cdn.test/older.jpg',
              mediaId: 'mid',
            );
          }
          return PresignedUrlModel(
            mediaUrl: 'https://cdn.test/copy.jpg',
            mediaPresignedUrl: 'https://s3.test/put-copy',
            mediaId: 'mid',
          );
        },
        putBytes: (_, __) async {
          putCount++;
          return 200;
        },
        mediaBytes: Uint8List(10),
        duplicateChoicePrompt: (_) async => SameNameUploadChoice.uploadCopy,
      );
      expect(putCount, 1);
      expect(outcome?.presigned?.mediaUrl, 'https://cdn.test/copy.jpg');
      expect(outcome?.forceUploadOnMessage, isTrue);
    });
  });

  group('SameNameUploadOutcome', () {
    test('reshare uses existingMediaId on message', () {
      final outcome = SameNameUploadOutcome(
        presigned: PresignedUrlModel(
          duplicate: true,
          mediaId: 'client-id',
          existingMediaId: 'storage-row-id',
          mediaUrl: 'https://cdn.test/older.jpg',
        ),
      );
      expect(outcome.isReshareExistingFile, isTrue);
      expect(
        outcome.resolveOutgoingMediaId(clientMediaId: 'client-id'),
        'storage-row-id',
      );
    });

    test('upload copy uses presigned mediaId', () {
      final outcome = SameNameUploadOutcome(
        presigned: PresignedUrlModel(
          mediaId: 'client-id',
          mediaUrl: 'https://cdn.test/copy.jpg',
        ),
        forceUploadOnMessage: true,
      );
      expect(outcome.isReshareExistingFile, isFalse);
      expect(
        outcome.resolveOutgoingMediaId(clientMediaId: 'client-id'),
        'client-id',
      );
    });

    test('first upload falls back to client mediaId', () {
      final outcome = SameNameUploadOutcome(
        presigned: PresignedUrlModel(
          mediaUrl: 'https://cdn.test/new.jpg',
        ),
      );
      expect(
        outcome.resolveOutgoingMediaId(clientMediaId: 'generated'),
        'generated',
      );
    });

    test('reshare without existingMediaId returns null', () {
      final outcome = SameNameUploadOutcome(
        presigned: PresignedUrlModel(
          duplicate: true,
          mediaId: 'client-id',
          mediaUrl: 'https://cdn.test/older.jpg',
        ),
      );
      expect(outcome.resolveOutgoingMediaId(clientMediaId: 'client-id'), isNull);
    });
  });
}