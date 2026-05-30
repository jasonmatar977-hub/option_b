import 'dart:html' as html;

enum OmwNotificationPermissionStatus { unsupported, prompt, granted, denied }

class NotificationPermissionService {
  const NotificationPermissionService();

  static const _dismissedKey = 'omw_notification_permission_prompt_dismissed';

  bool get isSupported => html.Notification.supported;

  Future<OmwNotificationPermissionStatus> status() async {
    if (!isSupported) {
      return OmwNotificationPermissionStatus.unsupported;
    }
    return _statusFor(html.Notification.permission ?? 'default');
  }

  Future<OmwNotificationPermissionStatus> requestPermission() async {
    if (!isSupported) {
      return OmwNotificationPermissionStatus.unsupported;
    }
    final permission = await html.Notification.requestPermission();
    return _statusFor(permission);
  }

  Future<bool> wasPromptDismissed() async {
    return html.window.localStorage[_dismissedKey] == 'true';
  }

  Future<void> dismissPrompt() async {
    html.window.localStorage[_dismissedKey] = 'true';
  }

  OmwNotificationPermissionStatus _statusFor(String permission) {
    return switch (permission) {
      'granted' => OmwNotificationPermissionStatus.granted,
      'denied' => OmwNotificationPermissionStatus.denied,
      _ => OmwNotificationPermissionStatus.prompt,
    };
  }
}
