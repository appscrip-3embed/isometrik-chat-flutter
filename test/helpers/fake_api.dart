import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

/// A canned HTTP response used by [FakeChatApi].
class FakeResponse {
  const FakeResponse(this.body, {this.status = 200, this.delay});

  /// Encodes [json] as the response body.
  FakeResponse.json(Object? json, {this.status = 200, this.delay})
      : body = jsonEncode(json);

  final String body;
  final int status;

  /// Optional artificial latency. Use with a short
  /// `IsmChatApiWrapper(timeout: ...)` to exercise the timeout branch.
  final Duration? delay;
}

/// One HTTP request captured by [FakeChatApi].
class RecordedRequest {
  RecordedRequest(this.method, this.url, this.body, this.headers);

  final String method;
  final Uri url;
  final String body;
  final Map<String, String> headers;

  /// Request body decoded as JSON (`null` for empty bodies).
  dynamic get json => body.isEmpty ? null : jsonDecode(body);
}

/// In-memory HTTP backend for the chat SDK.
///
/// **Reuse:** every repository / view-model / controller test talks to the
/// real [IsmChatApiWrapper] through this fake, so request URLs, payloads,
/// headers and response parsing are all exercised. Register routes with [on];
/// the first route whose method matches and whose `pathContains` is found in
/// the URL wins (routes registered later take precedence, so a test can
/// override a default route).
///
/// ```dart
/// final api = FakeChatApi()
///   ..on('GET', '/chat/messages', FakeResponse.json({'messages': []}));
/// final repo = IsmChatPageRepository(apiWrapper: api.wrapper());
/// ```
class FakeChatApi {
  FakeChatApi({this.fallback = const FakeResponse('{}')});

  /// Response for requests that match no route.
  FakeResponse fallback;

  final List<_Route> _routes = [];

  /// Every request received, in order.
  final List<RecordedRequest> requests = [];

  /// Registers [response] for requests with [method] (`GET`, `POST`, ...,
  /// or `*` for any) whose URL contains [pathContains].
  void on(String method, String pathContains, FakeResponse response) =>
      _routes.insert(0, _Route(method, pathContains, (_) => response));

  /// Like [on] but computes the response from the request.
  void onDynamic(
    String method,
    String pathContains,
    FakeResponse Function(RecordedRequest request) handler,
  ) =>
      _routes.insert(0, _Route(method, pathContains, handler));

  /// Makes the matching route throw (e.g. `SocketException`), which drives
  /// the `catch` branch of repositories.
  void throwOn(String method, String pathContains, Object error) =>
      _routes.insert(
        0,
        _Route(method, pathContains, (_) => throw error),
      );

  /// Requests whose URL contains [pathContains].
  List<RecordedRequest> requestsTo(String pathContains, {String? method}) =>
      requests
          .where((r) =>
              r.url.toString().contains(pathContains) &&
              (method == null || r.method == method))
          .toList();

  /// Requests whose path equals or ends with [path] (avoids `/chat/message`
  /// matching `/chat/messages/presignedurls`).
  List<RecordedRequest> requestsForPath(String path, {String? method}) =>
      requests
          .where((r) =>
              (r.url.path == path || r.url.path.endsWith(path)) &&
              (method == null || r.method == method))
          .toList();

  /// The `http.Client` backed by this fake.
  http.Client get client => MockClient((request) async {
        final recorded = RecordedRequest(
          request.method,
          request.url,
          request.body,
          request.headers,
        );
        requests.add(recorded);
        final route = _routes.firstWhere(
          (r) =>
              (r.method == '*' || r.method == request.method) &&
              request.url.toString().contains(r.pathContains),
          orElse: () => _Route('*', '', (_) => fallback),
        );
        final response = route.handler(recorded);
        if (response.delay != null) {
          await Future<void>.delayed(response.delay!);
        }
        return http.Response(response.body, response.status,
            request: request);
      });

  /// A real [IsmChatApiWrapper] wired to this fake.
  IsmChatApiWrapper wrapper({Duration timeout = const Duration(seconds: 5)}) =>
      IsmChatApiWrapper(client: client, timeout: timeout);

  /// Registers the canned responses that the send / group / media flows need.
  ///
  /// **Reuse:** call this from a flow test's `setUpApi` (or after constructing
  /// the fake). Later [on] calls still override these defaults.
  void registerSendDefaults({
    String messageId = 'server-msg',
    String conversationId = 'conv-created',
    String groupcastId = 'gcast-1',
  }) {
    on('POST', '/chat/message/forward', FakeResponse.json({'ok': true}));
    on('POST', '/chat/message', FakeResponse.json({'messageId': messageId}));
    on('POST', '/chat/conversation',
        FakeResponse.json({'conversationId': conversationId}));
    on(
      'POST',
      '/presignedurls',
      FakeResponse.json({
        'presignedUrls': [
          {
            'mediaUrl': 'https://cdn.test/media.bin',
            'mediaPresignedUrl': 'https://chat.test/upload',
            'thumbnailUrl': 'https://cdn.test/thumb.png',
            'thumbnailPresignedUrl': 'https://chat.test/upload-thumb',
            'mediaId': 'media-1',
            'ttl': 60,
          }
        ]
      }),
    );
    on('PUT', '/upload', const FakeResponse('{}'));
    on('PUT', '/upload-thumb', const FakeResponse('{}'));
    on('POST', '/chat/reaction', FakeResponse.json({'ok': true}));
    on('DELETE', '/chat/reaction', FakeResponse.json({'ok': true}));
    on('GET', '/chat/reaction', FakeResponse.json({
      'reactions': [
        {
          'userId': 'user-opponent',
          'userName': 'Opponent',
          'userIdentifier': 'user-opponent@test.com',
          'userProfileImageUrl': '',
        }
      ]
    }));
    on('PUT', '/chat/indicator', FakeResponse.json({'ok': true}));
    on('POST', '/chat/indicator', FakeResponse.json({'ok': true}));
    on('PATCH', '/chat/conversation', FakeResponse.json({'ok': true}));
    on('PUT', '/chat/conversation', FakeResponse.json({'ok': true}));
    on('DELETE', '/chat/conversation', FakeResponse.json({'ok': true}));
    on('POST', '/chat/user', FakeResponse.json({'ok': true}));
    on('GET', '/chat/conversation/details', FakeResponse.json({
      'conversationDetails': {
        'conversationId': conversationId,
        'isGroup': true,
        'conversationTitle': 'Test Group',
        'membersCount': 3,
        'members': <dynamic>[],
      }
    }));
    on('GET', '/eligible/members', FakeResponse.json({
      'conversationEligibleMembers': [
        {
          'userId': 'user-eligible',
          'userName': 'Eligible',
          'userIdentifier': 'eligible@test.com',
          'userProfileImageUrl': '',
        }
      ]
    }));
    on('GET', '/status', FakeResponse.json({
      'users': [
        {
          'userId': 'user-opponent',
          'userName': 'Opponent',
          'userIdentifier': 'user-opponent@test.com',
          'userProfileImageUrl': '',
        }
      ]
    }));
    on('GET', '/messages/status', FakeResponse.json({
      'messages': [
        {
          'messageId': messageId,
          'deliveredToAll': true,
          'readByAll': false,
        }
      ]
    }));
    on('POST', '/chat/groupcast',
        FakeResponse.json({'groupcastId': groupcastId}));
    on('POST', '/groupcast/message', FakeResponse.json({'ok': true}));
    on('GET', '/chat/messages', FakeResponse.json({'messages': <dynamic>[]}));
    on('GET', '/chat/conversations',
        FakeResponse.json({'conversations': <dynamic>[]}));
    on('GET', '/chat/user/details', FakeResponse.json({
      'userId': 'user-me',
      'userName': 'Me Tester',
      'userIdentifier': 'me@test.com',
      'userProfileImageUrl': '',
      'metaData': {'firstName': 'Me', 'lastName': 'Tester'},
    }));
  }
}

class _Route {
  _Route(this.method, this.pathContains, this.handler);
  final String method;
  final String pathContains;
  final FakeResponse Function(RecordedRequest request) handler;
}
