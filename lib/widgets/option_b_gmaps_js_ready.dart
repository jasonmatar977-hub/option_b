import 'option_b_gmaps_js_ready_stub.dart'
    if (dart.library.html) 'option_b_gmaps_js_ready_web.dart' as gmaps_js;

bool optionBGmapsJsReady() => gmaps_js.optionBGmapsJsReady();

Future<void> optionBWaitForGmapsJsReady({
  Duration timeout = const Duration(seconds: 8),
}) =>
    gmaps_js.optionBWaitForGmapsJsReady(timeout: timeout);
