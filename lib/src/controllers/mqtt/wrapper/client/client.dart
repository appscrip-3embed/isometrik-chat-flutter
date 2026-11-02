// coverage:ignore-file
// Unreachable under VM tests: UI, platform plugins, or MQTT broker I/O.
export 'mobile_client.dart' if (dart.library.html) 'web_client.dart';
