import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

class IsmChatApiWrapper {
  /// Creates the wrapper.
  ///
  /// Both parameters exist for test injection and are optional, so production
  /// code keeps calling `IsmChatApiWrapper()`:
  /// - `client`: an [http.Client] (e.g. `MockClient` from
  ///   `package:http/testing.dart`). When null a fresh [http.Client] is used
  ///   per request, matching the old top-level `http.get/post/...` behaviour.
  /// - `timeout`: request timeout. Tests shorten it to exercise the
  ///   timeout branch without waiting 60 seconds.
  IsmChatApiWrapper({
    http.Client? client,
    this.timeout = const Duration(seconds: 60),
  }) : _client = client;

  final http.Client? _client;

  /// Maximum time a single request may take before a timeout response
  /// (`errorCode: 1000`) is returned.
  final Duration timeout;

  /// Runs [request] with the injected client, or with a short-lived client
  /// that is closed afterwards (same as the top-level `http.*` helpers).
  Future<http.Response> _withClient(
    Future<http.Response> Function(http.Client client) request,
  ) async {
    final injected = _client;
    if (injected != null) return request(injected);
    final client = http.Client();
    try {
      return await request(client);
    } finally {
      client.close();
    }
  }

  // Future<IsmChatResponseModel> _handleNoInternet(bool showDailog) async {
  //   IsmChatLog.error('----- Internet not working -----');
  //   if (showDailog && Get.isDialogOpen == false) {
  //     await IsmChatUtility.showErrorDialog(IsmChatStrings.noInternet);
  //   }

  //   return const IsmChatResponseModel(
  //     data: IsmChatStrings.noInternet,
  //     errorCode: 1000,
  //     hasError: true,
  //   );
  // }

  Future<IsmChatResponseModel> get(
    String api, {
    bool showLoader = false,
    bool showDailog = true,
    required Map<String, String> headers,
  }) async {
    IsmChatLog('Request - GET $api \n$headers');

    // if (!(await IsmChatUtility.isNetworkAvailable)) {
    //   return await _handleNoInternet(showDailog);
    // }
    var uri = Uri.parse(api);
    if (showLoader) {
      IsmChatUtility.showLoader();
    }
    try {
      final response = await _withClient(
        (client) => client.get(uri, headers: headers),
      ).timeout(timeout);

      if (showLoader) {
        IsmChatUtility.closeLoader();
      }

      return _processResponse(response: response, apiUrl: uri.toString());
    } on TimeoutException catch (_) {
      if (showLoader) {
        IsmChatUtility.closeLoader();
      }
      return const IsmChatResponseModel(
        data: '{"message":"Request timed out"}',
        hasError: true,
        errorCode: 1000,
      );
    }
  }

  Future<IsmChatResponseModel> post(
    String api, {
    required dynamic payload,
    required Map<String, String> headers,
    bool showLoader = false,
    bool showDailog = true,
  }) async {
    IsmChatLog('Request - POST $api \n$payload \n$headers');
    // if (!(await IsmChatUtility.isNetworkAvailable)) {
    //   return await _handleNoInternet(showDailog);
    // }
    var uri = Uri.parse(api);
    if (showLoader) {
      IsmChatUtility.showLoader();
    }
    try {
      final response = await _withClient(
        (client) =>
            client.post(uri, body: jsonEncode(payload), headers: headers),
      ).timeout(timeout);

      if (showLoader) {
        IsmChatUtility.closeLoader();
      }
      return _processResponse(response: response, apiUrl: uri.toString());
    } on TimeoutException catch (_) {
      if (showLoader) {
        IsmChatUtility.closeLoader();
      }
      return const IsmChatResponseModel(
        data: '{"message":"Request timed out"}',
        hasError: true,
        errorCode: 1000,
      );
    }
  }

  Future<IsmChatResponseModel> put(
    String api, {
    required dynamic payload,
    required Map<String, String> headers,
    bool showLoader = false,
    bool forAwsUpload = false,
    bool showDailog = true,
  }) async {
    IsmChatLog('Request - PUT $api \n$payload \n$headers');
    // if (!(await IsmChatUtility.isNetworkAvailable)) {
    //   return await _handleNoInternet(showDailog);
    // }
    var uri = Uri.parse(api);
    if (showLoader) {
      IsmChatUtility.showLoader();
    }
    try {
      final response = await _withClient(
        (client) => client.put(
          uri,
          body: forAwsUpload ? payload : jsonEncode(payload),
          headers: headers,
        ),
      ).timeout(timeout);

      if (showLoader) {
        IsmChatUtility.closeLoader();
      }

      return _processResponse(response: response, apiUrl: uri.toString());
    } on TimeoutException catch (_) {
      if (showLoader) {
        IsmChatUtility.closeLoader();
      }
      return const IsmChatResponseModel(
        data: '{"message":"Request timed out"}',
        hasError: true,
        errorCode: 1000,
      );
    }
  }

  Future<IsmChatResponseModel> patch(
    String api, {
    required dynamic payload,
    required Map<String, String> headers,
    bool showLoader = false,
    bool showDailog = true,
  }) async {
    IsmChatLog('Request - PATCH $api \n$payload \n$headers');
    // if (!(await IsmChatUtility.isNetworkAvailable)) {
    //   return await _handleNoInternet(showDailog);
    // }
    var uri = Uri.parse(api);
    if (showLoader) {
      IsmChatUtility.showLoader();
    }
    try {
      final response = await _withClient(
        (client) => client.patch(
          uri,
          body: jsonEncode(payload),
          headers: headers,
        ),
      ).timeout(timeout);

      if (showLoader) {
        IsmChatUtility.closeLoader();
      }

      return _processResponse(response: response, apiUrl: uri.toString());
    } on TimeoutException catch (_) {
      if (showLoader) {
        IsmChatUtility.closeLoader();
      }
      return const IsmChatResponseModel(
        data: '{"message":"Request timed out"}',
        hasError: true,
        errorCode: 1000,
      );
    }
  }

  Future<IsmChatResponseModel> delete(
    String api, {
    required dynamic payload,
    required Map<String, String> headers,
    bool showLoader = false,
    bool showDailog = true,
  }) async {
    IsmChatLog('Request - DELETE $api \n$payload \n$headers');
    // if (!(await IsmChatUtility.isNetworkAvailable)) {
    //   return await _handleNoInternet(showDailog);
    // }
    var uri = Uri.parse(api);
    if (showLoader) {
      IsmChatUtility.showLoader();
    }
    try {
      final response = await _withClient(
        (client) => client.delete(
          uri,
          body: jsonEncode(payload),
          headers: headers,
        ),
      ).timeout(timeout);

      if (showLoader) {
        IsmChatUtility.closeLoader();
      }

      return _processResponse(response: response, apiUrl: uri.toString());
    } on TimeoutException catch (_) {
      if (showLoader) {
        IsmChatUtility.closeLoader();
      }
      return const IsmChatResponseModel(
        data: '{"message":"Request timed out"}',
        hasError: true,
        errorCode: 1000,
      );
    }
  }

  IsmChatResponseModel _processResponse({
    required http.Response response,
    required String apiUrl,
  }) {
    IsmChatLog.info(
      'Response - ${response.request?.method} ${response.statusCode} ${response.request?.url}\n${response.body}',
    );
    switch (response.statusCode) {
      case 204:
        return IsmChatResponseModel(
          data: '{}',
          hasError: false,
          errorCode: response.statusCode,
        );
      case 200:
      case 201:
      case 202:
      case 203:
      case 205:
      case 208:
        return IsmChatResponseModel(
          data: response.body,
          hasError: false,
          errorCode: response.statusCode,
        );
      case 400:
      case 401:
      case 404:
      case 406:
      case 409:
      case 422:
      case 500:
      case 503:
      case 522:
      default:
        final res = IsmChatResponseModel(
          data: response.body,
          hasError: true,
          errorCode: response.statusCode,
        );
        IsmChatConfig.chatInvalidate?.call(res, apiUrl);
        return res;
    }
  }
}
