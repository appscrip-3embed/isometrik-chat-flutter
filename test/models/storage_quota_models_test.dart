import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

void main() {
  group('IsmChatStorageUsageModel', () {
    test('parses a quota-on body and derives helpers', () {
      final usage = IsmChatStorageUsageModel.fromMap(const {
        'quotaEnabled': true,
        'usedBytes': 734003200, // 700 MB
        'quotaBytes': 1073741824, // 1 GB
        'remainingBytes': 339738624,
        'tier': 'free',
        'canUpload': true,
      });

      expect(usage.quotaEnabled, isTrue);
      expect(usage.canUpload, isTrue);
      expect(usage.tier, IsmChatStorageQuotaTier.free);
      expect(usage.isOverLimit, isFalse);
      // 700MB / 1GB ≈ 0.68
      expect(usage.usedFraction, closeTo(0.6836, 0.001));
      expect(usage.canUploadBytes(300000000), isTrue);
      expect(usage.canUploadBytes(400000000), isFalse); // > remaining
    });

    test('parses maxFileSizeBytes and isWithinMaxFileSize when quota on', () {
      const max = 10485760; // 10 MB
      final usage = IsmChatStorageUsageModel.fromMap(const {
        'quotaEnabled': true,
        'canUpload': true,
        'maxFileSizeBytes': max,
      });

      expect(usage.maxFileSizeBytes, max);
      expect(usage.isWithinMaxFileSize(max), isTrue);
      expect(usage.isWithinMaxFileSize(max + 1), isFalse);
    });

    test('isWithinMaxFileSize ignored when quota off or max unset', () {
      final off = IsmChatStorageUsageModel.fromMap(const {
        'quotaEnabled': false,
        'maxFileSizeBytes': 100,
      });
      expect(off.isWithinMaxFileSize(1 << 40), isTrue);

      final noMax = IsmChatStorageUsageModel.fromMap(const {
        'quotaEnabled': true,
        'canUpload': true,
      });
      expect(noMax.isWithinMaxFileSize(1 << 40), isTrue);
    });

    test('quota-off body keeps uploads allowed and figures null', () {
      final usage = IsmChatStorageUsageModel.fromMap(const {
        'quotaEnabled': false,
        'usedBytes': null,
        'quotaBytes': null,
        'remainingBytes': null,
        'tier': null,
        'canUpload': true,
      });

      expect(usage.quotaEnabled, isFalse);
      expect(usage.tier, IsmChatStorageQuotaTier.free); // missing tier → free
      expect(usage.usedFraction, 0);
      expect(usage.isOverLimit, isFalse);
      // Quota off never blocks, regardless of size.
      expect(usage.canUploadBytes(1 << 40), isTrue);
    });

    test('at the limit is over-limit and blocks any upload', () {
      final usage = IsmChatStorageUsageModel.fromMap(const {
        'quotaEnabled': true,
        'usedBytes': 1073741824,
        'quotaBytes': 1073741824,
        'remainingBytes': 0,
        'tier': 'paid',
        'canUpload': false,
      });

      expect(usage.tier?.isPaid, isTrue);
      expect(usage.isOverLimit, isTrue);
      expect(usage.canUploadBytes(1), isFalse);
      expect(usage.usedFraction, 1.0);
    });

    test('missing canUpload defaults to true (never wrongly blocks)', () {
      final usage = IsmChatStorageUsageModel.fromMap(const {
        'quotaEnabled': true,
      });
      expect(usage.canUpload, isTrue);
    });

    test('shouldWarnNearQuota respects threshold and quota state', () {
      const quota = 100;
      final at89 = IsmChatStorageUsageModel.fromMap(const {
        'quotaEnabled': true,
        'usedBytes': 89,
        'quotaBytes': quota,
        'remainingBytes': 11,
        'canUpload': true,
      });
      expect(at89.shouldWarnNearQuota(threshold: 0.9), isFalse);

      final at90 = IsmChatStorageUsageModel.fromMap(const {
        'quotaEnabled': true,
        'usedBytes': 90,
        'quotaBytes': quota,
        'remainingBytes': 10,
        'canUpload': true,
      });
      expect(at90.shouldWarnNearQuota(threshold: 0.9), isTrue);

      final full = IsmChatStorageUsageModel.fromMap(const {
        'quotaEnabled': true,
        'usedBytes': quota,
        'quotaBytes': quota,
        'remainingBytes': 0,
        'canUpload': false,
      });
      expect(full.shouldWarnNearQuota(threshold: 0.9), isTrue);

      final off = IsmChatStorageUsageModel.fromMap(const {
        'quotaEnabled': false,
        'usedBytes': quota,
        'quotaBytes': quota,
      });
      expect(off.shouldWarnNearQuota(threshold: 0.9), isFalse);

      final zeroQuota = IsmChatStorageUsageModel.fromMap(const {
        'quotaEnabled': true,
        'usedBytes': 50,
        'quotaBytes': 0,
      });
      expect(zeroQuota.shouldWarnNearQuota(threshold: 0.9), isFalse);
    });

    test('copyWith / toMap round-trip', () {
      final usage = IsmChatStorageUsageModel.fromMap(const {
        'quotaEnabled': true,
        'usedBytes': 10,
        'quotaBytes': 100,
        'remainingBytes': 90,
        'tier': 'free',
        'canUpload': true,
      });
      final copy = usage.copyWith(usedBytes: 50, remainingBytes: 50);
      expect(copy.usedBytes, 50);
      expect(copy.remainingBytes, 50);
      expect(copy.quotaBytes, 100);
      expect(IsmChatStorageUsageModel.fromJson(copy.toJson()), copy);
    });
  });

  group('IsmChatQuotaMediaModel', () {
    test('parses a viewable image row', () {
      final media = IsmChatQuotaMediaModel.fromMap(const {
        'mediaId': 'media-1',
        'messageId': 'msg-1',
        'conversationId': 'conv-1',
        'attachmentType': 0,
        'name': 'Screenshot.png',
        'size': 245760,
        'mediaUrl': 'https://cdn.test/a.png',
        'thumbnailUrl': 'https://cdn.test/a-thumb.png',
        'restricted': false,
      });

      expect(media.attachmentType, IsmChatMediaType.image);
      expect(media.isViewable, isTrue);
      expect(media.restricted, isFalse);
      expect(media.size, 245760);
    });

    test('restricted row has null urls and is not viewable', () {
      final media = IsmChatQuotaMediaModel.fromMap(const {
        'mediaId': 'media-2',
        'messageId': 'msg-2',
        'conversationId': 'conv-1',
        'attachmentType': 1,
        'name': 'clip.mp4',
        'size': 104857600,
        'mediaUrl': null,
        'thumbnailUrl': null,
        'restricted': true,
      });

      expect(media.attachmentType, IsmChatMediaType.video);
      expect(media.mediaUrl, isNull);
      expect(media.thumbnailUrl, isNull);
      expect(media.restricted, isTrue);
      expect(media.isViewable, isFalse);
    });

    test('empty-string urls are treated as null', () {
      final media = IsmChatQuotaMediaModel.fromMap(const {
        'mediaId': 'm',
        'messageId': 'mm',
        'conversationId': 'c',
        'attachmentType': 3,
        'name': 'f.pdf',
        'size': 10,
        'mediaUrl': '   ',
        'thumbnailUrl': '',
      });
      expect(media.mediaUrl, isNull);
      expect(media.thumbnailUrl, isNull);
      expect(media.attachmentType, IsmChatMediaType.file);
    });
  });

  group('IsmChatQuotaMediaResponseModel', () {
    test('parses a list and missing media yields empty', () {
      final full = IsmChatQuotaMediaResponseModel.fromMap(const {
        'msg': 'ok',
        'quotaEnabled': true,
        'media': [
          {
            'mediaId': 'm1',
            'messageId': 'x',
            'conversationId': 'c',
            'attachmentType': 0,
            'name': 'a.png',
            'size': 1,
          }
        ],
      });
      expect(full.quotaEnabled, isTrue);
      expect(full.media, hasLength(1));

      final empty = IsmChatQuotaMediaResponseModel.fromMap(const {
        'quotaEnabled': false,
        'media': <dynamic>[],
      });
      expect(empty.media, isEmpty);
    });
  });

  group('IsmChatMediaDeleteResultModel', () {
    test('parses freed/used/quota and derives isUnderQuota', () {
      final result = IsmChatMediaDeleteResultModel.fromMap(const {
        'msg': 'Media deleted successfully.',
        'freedBytes': 245760,
        'usedBytes': 733757440,
        'quotaBytes': 1073741824,
      });
      expect(result.freedBytes, 245760);
      expect(result.isUnderQuota, isTrue);
    });

    test('freedBytes defaults to 0 and isUnderQuota null when unreported', () {
      final result = IsmChatMediaDeleteResultModel.fromMap(const {
        'msg': 'ok',
      });
      expect(result.freedBytes, 0);
      expect(result.isUnderQuota, isNull);
    });

    test('isUnderQuota false when still at/over limit', () {
      final result = IsmChatMediaDeleteResultModel.fromMap(const {
        'freedBytes': 0,
        'usedBytes': 100,
        'quotaBytes': 100,
      });
      expect(result.isUnderQuota, isFalse);
    });
  });
}
