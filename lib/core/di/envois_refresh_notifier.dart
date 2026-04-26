import 'package:flutter/foundation.dart';

class EnvoisRefreshNotifier extends ChangeNotifier {
  void requestRefresh() => notifyListeners();
}
