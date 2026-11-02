import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:isometrik_chat_flutter/isometrik_chat_flutter.dart';

import 'fake_api.dart';

/// Shared bootstrap for every SDK test.
///
/// **Reuse:** call [configureChatSdk] in `setUp` for pure unit tests, and
/// additionally [pumpChatHost] inside `testWidgets` when the code under test
/// reads `IsmChatConfig.kNavigatorKey.currentContext` (dialogs, loaders,
/// responsive checks). Always call [resetChatSdk] in `tearDown` because
/// `IsmChatConfig` and GetX are global singletons.

/// Logged-in user used by all fixtures.
const kMeId = 'user-me';
const kMeName = 'Me Tester';

/// The other participant in 1-to-1 fixtures.
const kOpponentId = 'user-opponent';
const kOpponentName = 'Opponent';

/// Fixed base URL. `IsmChatAPI` caches its static URLs on first access, so
/// every test must use the same value.
const kTestBaseUrl = 'https://chat.test';

/// Project config shared by all tests.
const kProjectConfig = IsmChatProjectConfig(
  accountId: 'acc',
  appSecret: 'app-secret',
  userSecret: 'user-secret',
  keySetId: 'key-set',
  licenseKey: 'license',
  projectId: 'project',
  deviceId: 'device-1',
  chatApisBaseUrl: kTestBaseUrl,
  googleApiKey: 'maps-key',
);

/// Fills `IsmChatConfig` the same way `IsmChat.i.initialize` does, without
/// MQTT, notifications or a real database.
void configureChatSdk({
  bool useDatabase = false,
  bool messageEncrypted = false,
  bool maskSensitiveContent = false,
}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  mockPlatformChannels();
  IsmChatConfig.communicationConfig = IsmChatCommunicationConfig(
    userConfig: const IsmChatUserConfig(
      userToken: 'user-token',
      userId: kMeId,
      userName: kMeName,
      userEmail: 'me@test.com',
      userProfile: 'https://img.test/me.png',
    ),
    projectConfig: kProjectConfig,
  );
  IsmChatConfig.kNavigatorKey = GlobalKey<NavigatorState>();
  IsmChatConfig.useDatabase = useDatabase;
  IsmChatConfig.shouldSetupMqtt = false;
  IsmChatConfig.shouldPendingMessageSend = true;
  IsmChatConfig.messageEncrypted = messageEncrypted;
  IsmChatConfig.maskSensitiveContent = maskSensitiveContent;
  IsmChatConfig.sendPaidWalletMessage = null;
  IsmChatConfig.paidWalletModel = null;
  IsmChatConfig.paidWalletMessageApiResponse = null;
  IsmChatConfig.chatInvalidate = null;
  IsmChatConfig.notificationBody = null;
  IsmChatConfig.onConversationCreated = null;
  IsmChatConfig.dbWrapper = null;
  IsmChatConfig.configInitilized = true;
}

/// Opens a Hive-backed [IsmChatDBWrapper] in a fresh temporary directory and
/// installs it as `IsmChatConfig.dbWrapper`.
Future<IsmChatDBWrapper> openTestDatabase() async {
  final dir = await Directory.systemTemp.createTemp('ism_chat_test_');
  final db = await IsmChatDBWrapper.create(
    'db_${DateTime.now().microsecondsSinceEpoch}',
    dir.path,
  );
  IsmChatConfig.dbWrapper = db;
  return db;
}

/// Pumps a minimal `GetMaterialApp` so `IsmChatConfig.kNavigatorKey` and
/// `IsmChatConfig.context` point at a live navigator.
///
/// [size] controls `IsmChatResponsive.isWeb` (width >= 1100 is "web").
Future<void> pumpChatHost(
  WidgetTester tester, {
  Size size = const Size(400, 800),
  Widget? child,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // SDK styles use flutter_screenutil (`.sp`, `.w`), which must be
  // initialised above the app exactly like the example app does.
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 745),
      builder: (_, __) => GetMaterialApp(
        navigatorKey: IsmChatConfig.kNavigatorKey,
        home: Builder(
          builder: (context) {
            IsmChatConfig.context = context;
            return Scaffold(body: child ?? const SizedBox());
          },
        ),
      ),
    ),
  );
}

/// Registers the common, conversations and chat-page controllers with real
/// view models and repositories that talk to [api].
///
/// `Get.put` runs each controller's `onInit`; the conversations controller's
/// bootstrap (user details, conversation list) is answered by [api], so
/// register those routes first if a test depends on them.
({
  IsmChatCommonController common,
  IsmChatConversationsController conversations,
  IsmChatPageController page,
}) registerChatControllers(FakeChatApi api) {
  final wrapper = api.wrapper();
  final common = Get.put(
    IsmChatCommonController(
      IsmChatCommonViewModel(IsmChatCommonRepository(apiWrapper: wrapper)),
    ),
  );
  final conversations = Get.put(
    IsmChatConversationsController(
      IsmChatConversationsViewModel(
        IsmChatConversationsRepository(apiWrapper: wrapper),
      ),
    ),
    tag: IsmChat.i.chatListPageTag,
  );
  final page = Get.put(
    IsmChatPageController(
      IsmChatPageViewModel(IsmChatPageRepository(apiWrapper: wrapper)),
    ),
    tag: IsmChat.i.chatPageTag,
  );
  return (common: common, conversations: conversations, page: page);
}

/// Lets real async work (Hive file IO, `MockClient` futures) finish inside a
/// `testWidgets` fake-async zone, then flushes frames and fake timers.
///
/// Call after triggering any controller action that awaits the database or
/// network; [rounds] repeats the real-time wait for longer chains. Hive file
/// IO needs several real event-loop turns per operation, hence the default.
Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Settles until [condition] is true (or fails after [maxRounds]).
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxRounds = 60,
}) async {
  for (var i = 0; i < maxRounds; i++) {
    if (condition()) return;
    await settle(tester, rounds: 1);
  }
  fail('pumpUntil: condition not met after $maxRounds rounds');
}

/// Starts [action] in the fake-async zone and settles until it completes.
/// Use for controller methods that await Hive and HTTP.
Future<T> drive<T>(WidgetTester tester, Future<T> Function() action) async {
  var done = false;
  late T result;
  Object? error;
  StackTrace? stack;
  action().then((value) {
    result = value;
    done = true;
  }, onError: (Object e, StackTrace st) {
    error = e;
    stack = st;
    done = true;
  });
  await pumpUntil(tester, () => done);
  if (error != null) Error.throwWithStackTrace(error!, stack!);
  return result;
}

/// Everything a flow test needs, created by [chatTestWidgets].
class ChatTestContext {
  ChatTestContext(this.api, this.common, this.conversations, this.page,
      this.db);

  final FakeChatApi api;
  final IsmChatCommonController common;
  final IsmChatConversationsController conversations;
  final IsmChatPageController page;
  final IsmChatDBWrapper? db;
}

/// `testWidgets` with the full SDK wired up: config, host app, optional
/// Hive database, a [FakeChatApi] and all three controllers.
///
/// Controllers start periodic timers (MQTT health check), so they are
/// deleted at the end of [body] — inside the test, before flutter_test
/// verifies that no timers are pending.
///
/// Use [setUpApi] to register routes that the controllers' `onInit` hits.
void chatTestWidgets(
  String description,
  Future<void> Function(WidgetTester tester, ChatTestContext ctx) body, {
  Size size = const Size(400, 800),
  bool useDatabase = true,
  bool messageEncrypted = false,
  void Function(FakeChatApi api)? setUpApi,
}) {
  testWidgets(description, (tester) async {
    configureChatSdk(
      useDatabase: useDatabase,
      messageEncrypted: messageEncrypted,
    );
    IsmChatDBWrapper? db;
    if (useDatabase) {
      db = await tester.runAsync(openTestDatabase);
    }
    await pumpChatHost(tester, size: size);
    final api = FakeChatApi();
    setUpApi?.call(api);
    // Register + onInit in the real async zone so Hive / MockClient / asset
    // loading can complete. Fake-async would stall those futures.
    late final IsmChatCommonController common;
    late final IsmChatConversationsController conversations;
    late final IsmChatPageController page;
    await tester.runAsync(() async {
      final controllers = registerChatControllers(api);
      common = controllers.common;
      conversations = controllers.conversations;
      page = controllers.page;
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (!conversations.intilizedContrller &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      // Tests can still run if onInit never finished (e.g. a plugin hung).
      conversations.intilizedContrller = true;
    });
    try {
      await body(
        tester,
        ChatTestContext(api, common, conversations, page, db),
      );
    } finally {
      conversations.stopMqttHealthCheckForChatList();
      await tester.runAsync(resetChatSdk);
      await tester.pumpWidget(const SizedBox());
      // Fluttertoast schedules a 1s timer; typing indicators use 2s.
      await tester.pump(const Duration(seconds: 2));
    }
  });
}

/// Clears GetX and the global config between tests.
Future<void> resetChatSdk() async {
  try {
    final db = IsmChatConfig.dbWrapper;
    if (db != null) {
      db.collection.close();
    }
  } catch (_) {
    // Box already closed or never opened.
  }
  await Get.deleteAll(force: true);
  Get.reset();
  IsmChatConfig.dbWrapper = null;
  IsmChat.i.chatPageTag = null;
  IsmChat.i.chatListPageTag = null;
}

/// Answers platform-plugin channels used incidentally by the code under test
/// (connectivity, path_provider, audio, etc.) so they do not throw
/// `MissingPluginException`.
void mockPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => call.method == 'check' ? <String>['wifi'] : null,
  );
  messenger.setMockStreamHandler(
    const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
    MockStreamHandler.inline(onListen: (_, sink) {}),
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => Directory.systemTemp.path,
  );
  for (final name in const [
    'fluttertoast',
    'PonnamKarthik/fluttertoast',
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
    'com.llfbandit.record/messages',
    'video_compress',
    'flutter.baseflow.com/permissions/methods',
    'plugins.flutter.io/url_launcher',
    'flutter.baseflow.com/geolocator',
    'dev.fluttercommunity.plus/share',
    'plugins.flutter.io/image_picker',
  ]) {
    messenger.setMockMethodCallHandler(
      MethodChannel(name),
      (call) async => null,
    );
  }
}
