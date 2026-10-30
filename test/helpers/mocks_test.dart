import 'package:flutter_test/flutter_test.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks.dart';

void main() {
  setUpAll(registerChatFallbacks);

  test('registerChatFallbacks is idempotent', registerChatFallbacks);

  test('MockBroadcastRepository accepts any() on updateBroadcast params', () async {
    final repo = MockBroadcastRepository();
    when(
      () => repo.updateBroadcast(
        groupcastId: any(named: 'groupcastId'),
        isloading: any(named: 'isloading'),
        searchableTags: any(named: 'searchableTags'),
        metaData: any(named: 'metaData'),
        groupcastTitle: any(named: 'groupcastTitle'),
        groupcastImageUrl: any(named: 'groupcastImageUrl'),
        customType: any(named: 'customType'),
      ),
    ).thenAnswer(
      (_) async => const IsmChatResponseModel(
        data: '{}',
        hasError: false,
        errorCode: 200,
      ),
    );

    expect(
      await repo.updateBroadcast(groupcastId: 'g'),
      isA<IsmChatResponseModel>(),
    );
  });
}
