import 'package:flutter/foundation.dart';

import 'entities/session.dart';

class SessionStore extends ChangeNotifier {
  Session? _session;

  Session? get session => _session;
  String? get token => _session?.token;
  bool get isAuthenticated => _session != null;

  void set(Session session) {
    _session = session;
    notifyListeners();
  }

  void clear() {
    if (_session == null) return;
    _session = null;
    notifyListeners();
  }
}
