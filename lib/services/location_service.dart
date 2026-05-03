import 'package:geolocator/geolocator.dart';

import '../widgets/app_map.dart';

enum DemoLocationStatus { allowed, permissionDenied, servicesDisabled, failed }

class DemoLocationResult {
  const DemoLocationResult({required this.status, this.point, this.message});

  final DemoLocationStatus status;
  final DemoMapPoint? point;
  final String? message;
}

class LocationService {
  static Future<DemoLocationResult> getCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return const DemoLocationResult(
          status: DemoLocationStatus.servicesDisabled,
          message: 'Enable location services or continue manually.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const DemoLocationResult(
          status: DemoLocationStatus.permissionDenied,
          message: 'Location permission denied. You can continue manually.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return DemoLocationResult(
        status: DemoLocationStatus.allowed,
        point: DemoMapPoint(position.latitude, position.longitude),
      );
    } catch (_) {
      return const DemoLocationResult(
        status: DemoLocationStatus.failed,
        message: 'Could not get GPS. You can continue with the demo location.',
      );
    }
  }
}
