import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../config/app_config.dart';

const String _googleMapsApiKey = AppConfig.googleMapsApiKey;

bool _scriptLoadStarted = false;
String _statusReason = 'JS not ready';

@JS('google')
external JSObject? get _google;

extension type _GoogleMapsRoot(JSObject _) implements JSObject {
  external JSObject? get maps;
}

extension type _GoogleMapsNamespace(JSObject _) implements JSObject {
  @JS('MapTypeId')
  external JSObject? get mapTypeId;
}

extension type _GoogleMapsMapTypeId(JSObject _) implements JSObject {
  @JS('ROADMAP')
  external JSAny? get roadmap;
}

bool optionBGmapsJsReady() {
  try {
    final g = _google;
    if (g == null) {
      _statusReason = 'JS not ready';
      return false;
    }
    final maps = _GoogleMapsRoot(g).maps;
    if (maps == null) {
      _statusReason = 'JS not ready';
      return false;
    }
    final mapTypeId = _GoogleMapsNamespace(maps).mapTypeId;
    if (mapTypeId == null) {
      _statusReason = 'MapTypeId not ready';
      return false;
    }
    final roadMap = _GoogleMapsMapTypeId(mapTypeId).roadmap;
    if (roadMap == null) {
      _statusReason = 'ROADMAP not ready';
      return false;
    }
    _statusReason = 'ready';
    return true;
  } catch (_) {
    _statusReason = 'JS incomplete';
    return false;
  }
}

String optionBGmapsStatusReason() => _statusReason;

Future<void> optionBWaitForGmapsJsReady({
  Duration timeout = const Duration(seconds: 15),
}) => _waitForGoogleMaps(timeout: timeout);

Future<void> _waitForGoogleMaps({required Duration timeout}) async {
  if (optionBGmapsJsReady()) {
    _statusReason = 'ready';
    return;
  }
  _loadGoogleMapsScriptFromDartDefine();
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (optionBGmapsJsReady()) {
      _statusReason = 'ready';
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  if (_statusReason == 'loading') {
    _statusReason = 'JS not ready';
  }
}

void _loadGoogleMapsScriptFromDartDefine() {
  if (_googleMapsApiKey.trim().isEmpty) {
    _statusReason = 'missing key';
    return;
  }
  if (_scriptLoadStarted) {
    if (_statusReason != 'ready') {
      _statusReason = 'loading';
    }
    return;
  }
  final placeholder = web.document.querySelector(
    'script[src*="maps.googleapis.com/maps/api/js"][src*="YOUR_GOOGLE_MAPS_API_KEY"]',
  );
  placeholder?.remove();

  final existingMapsScript = web.document.querySelector(
    'script[src*="maps.googleapis.com/maps/api/js"]',
  );
  if (existingMapsScript != null) {
    _scriptLoadStarted = true;
    _statusReason = 'loading';
    return;
  }
  final script = web.HTMLScriptElement()
    ..src =
        'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeComponent(_googleMapsApiKey)}&libraries=places&loading=async'
    ..async = true
    ..defer = true;
  script.setAttribute('data-option-b-gmaps', 'true');
  _scriptLoadStarted = true;
  _statusReason = 'loading';
  web.document.head?.append(script);
}
