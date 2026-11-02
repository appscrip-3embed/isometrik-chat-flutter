import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_bootstrap.dart';

/// Covers every HTTP verb, every status-code branch of `_processResponse`,
/// the timeout branch and the loader branch of [IsmChatApiWrapper].
void main() {
  setUp(configureChatSdk);
  tearDown(resetChatSdk);

  const url = '$kTestBaseUrl/endpoint';
  const headers = {'k': 'v'};

  Future<IsmChatResponseModel> call(
    IsmChatApiWrapper wrapper,
    String verb, {
    bool showLoader = false,
    bool forAwsUpload = false,
  }) =>
      switch (verb) {
        'GET' => wrapper.get(url, headers: headers, showLoader: showLoader),
        'POST' => wrapper.post(url,
            payload: {'a': 1}, headers: headers, showLoader: showLoader),
        'PUT' => wrapper.put(url,
            payload: forAwsUpload ? 'raw-bytes' : {'a': 1},
            headers: headers,
            showLoader: showLoader,
            forAwsUpload: forAwsUpload),
        'PATCH' => wrapper.patch(url,
            payload: {'a': 1}, headers: headers, showLoader: showLoader),
        'DELETE' => wrapper.delete(url,
            payload: {'a': 1}, headers: headers, showLoader: showLoader),
        _ => throw ArgumentError(verb),
      };

  const verbs = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

  group('success responses', () {
    for (final verb in verbs) {
      test('$verb 200 returns body without error', () async {
        final api = FakeChatApi()
          ..on(verb, '/endpoint', FakeResponse.json({'ok': true}));
        final res = await call(api.wrapper(), verb);
        expect(res.hasError, isFalse);
        expect(res.errorCode, 200);
        expect(res.data, '{"ok":true}');
        expect(api.requests.single.method, verb);
        expect(api.requests.single.headers['k'], 'v');
        if (verb != 'GET') {
          expect(api.requests.single.json, {'a': 1});
        }
      });
    }

    for (final status in [201, 202, 203, 205, 208]) {
      test('status $status is treated as success', () async {
        final api = FakeChatApi()
          ..on('GET', '/endpoint', FakeResponse('body', status: status));
        final res = await call(api.wrapper(), 'GET');
        expect(res.hasError, isFalse);
        expect(res.data, 'body');
      });
    }

    test('204 returns empty json object', () async {
      final api = FakeChatApi()
        ..on('GET', '/endpoint', const FakeResponse('', status: 204));
      final res = await call(api.wrapper(), 'GET');
      expect(res.hasError, isFalse);
      expect(res.data, '{}');
      expect(res.errorCode, 204);
    });

    test('PUT forAwsUpload sends the raw payload (not JSON encoded)',
        () async {
      final api = FakeChatApi();
      await call(api.wrapper(), 'PUT', forAwsUpload: true);
      expect(api.requests.single.body, 'raw-bytes');
    });
  });

  group('error responses', () {
    for (final status in [400, 401, 404, 406, 409, 422, 500, 503, 522, 418]) {
      test('status $status sets hasError and calls chatInvalidate', () async {
        IsmChatResponseModel? invalidated;
        String? invalidatedUrl;
        IsmChatConfig.chatInvalidate = (res, apiUrl) {
          invalidated = res;
          invalidatedUrl = apiUrl;
        };
        final api = FakeChatApi()
          ..on('GET', '/endpoint',
              FakeResponse('{"error":"x"}', status: status));
        final res = await call(api.wrapper(), 'GET');
        expect(res.hasError, isTrue);
        expect(res.errorCode, status);
        expect(invalidated?.errorCode, status);
        expect(invalidatedUrl, url);
      });
    }
  });

  group('timeout', () {
    for (final verb in verbs) {
      test('$verb returns errorCode 1000 when the request times out',
          () async {
        final api = FakeChatApi()
          ..on(
            verb,
            '/endpoint',
            const FakeResponse('{}', delay: Duration(milliseconds: 200)),
          );
        final res = await call(
          api.wrapper(timeout: const Duration(milliseconds: 10)),
          verb,
        );
        expect(res.hasError, isTrue);
        expect(res.errorCode, 1000);
        expect(res.data, contains('timed out'));
      });
    }
  });

  group('loader', () {
    for (final verb in verbs) {
      testWidgets('$verb shows and closes the loader', (tester) async {
        await pumpChatHost(tester);
        final api = FakeChatApi();
        await tester.runAsync(() => call(api.wrapper(), verb, showLoader: true));
        await tester.pumpAndSettle();
        expect(IsmChatUtility.isLoading, isFalse);
      });

      testWidgets('$verb closes the loader on timeout', (tester) async {
        await pumpChatHost(tester);
        final api = FakeChatApi()
          ..on(verb, '/endpoint',
              const FakeResponse('{}', delay: Duration(milliseconds: 100)));
        final res = await tester.runAsync(() => call(
              api.wrapper(timeout: const Duration(milliseconds: 5)),
              verb,
              showLoader: true,
            ));
        await tester.pumpAndSettle();
        expect(res?.errorCode, 1000);
        expect(IsmChatUtility.isLoading, isFalse);
      });
    }
  });

  test('default wrapper creates (and closes) its own client per request',
      () async {
    // `http.Client()` resolves to the zone client inside `runWithClient`,
    // which lets us observe the no-injection path without real network.
    final api = FakeChatApi()
      ..on('GET', '/endpoint', FakeResponse.json({'zone': true}));
    final wrapper = IsmChatApiWrapper();
    expect(wrapper.timeout, const Duration(seconds: 60));
    final res = await http.runWithClient(
      () => wrapper.get(url, headers: headers),
      () => api.client,
    );
    expect(res.data, '{"zone":true}');
  });
}
