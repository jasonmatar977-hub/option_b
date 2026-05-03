import 'dart:async';

import 'dart:js_interop';

@JS('google')
external JSObject? get _google;

extension type _GoogleMapsRoot(JSObject _) implements JSObject {
  external JSObject? get maps;
}

bool optionBGmapsJsReady() {
  try {
    final g = _google;
    if (g == null) return false;
    return _GoogleMapsRoot(g).maps != null;
  } catch (_) {
    return false;
  }
}

Future<void> optionBWaitForGmapsJsReady({
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (optionBGmapsJsReady()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
