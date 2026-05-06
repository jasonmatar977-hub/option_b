bool optionBGmapsJsReady() => true;

String optionBGmapsStatusReason() => 'native map platform';

Future<void> optionBWaitForGmapsJsReady({
  Duration timeout = const Duration(seconds: 15),
}) async {}
