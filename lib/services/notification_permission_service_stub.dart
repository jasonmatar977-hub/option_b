enum OmwNotificationPermissionStatus { unsupported, prompt, granted, denied }

class NotificationPermissionService {
  const NotificationPermissionService();

  bool get isSupported => false;

  Future<OmwNotificationPermissionStatus> status() async {
    return OmwNotificationPermissionStatus.unsupported;
  }

  Future<OmwNotificationPermissionStatus> requestPermission() async {
    return OmwNotificationPermissionStatus.unsupported;
  }

  Future<bool> wasPromptDismissed() async => false;

  Future<void> dismissPrompt() async {}
}
