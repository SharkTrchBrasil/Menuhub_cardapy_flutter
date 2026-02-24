import 'package:web/web.dart' as web;
import 'package:uuid/uuid.dart';

class SessionHelper {
  static const _key = 'sessionId';

  static String getOrCreateSessionId() {
    final storage = web.window.localStorage;
    final existingId = storage.getItem(_key);
    if (existingId == null) {
      final id = const Uuid().v4();
      storage.setItem(_key, id);
      return id;
    }
    return existingId;
  }
}
