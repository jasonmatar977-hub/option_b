import 'dart:math' as math;

import '../widgets/app_map.dart';
import 'google_places_service.dart';

class RouteEstimate {
  const RouteEstimate({
    required this.distanceText,
    required this.durationText,
    required this.distanceKm,
    required this.routePoints,
    this.isFallback = false,
  });

  final String distanceText;
  final String durationText;
  final double distanceKm;
  final List<DemoMapPoint> routePoints;
  final bool isFallback;
}

class DirectionsService {
  const DirectionsService({this.apiKey = kGoogleMapsApiKey});

  final String apiKey;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  Future<RouteEstimate> route({
    required DemoMapPoint pickup,
    required DemoMapPoint destination,
    double averageSpeedKmh = 28,
  }) async {
    return fallback(
      pickup: pickup,
      destination: destination,
      averageSpeedKmh: averageSpeedKmh,
    );
  }

  RouteEstimate fallback({
    required DemoMapPoint pickup,
    required DemoMapPoint destination,
    double averageSpeedKmh = 28,
  }) {
    final km = _haversineKm(pickup, destination).clamp(1.0, 45.0).toDouble();
    final minutes = ((km / averageSpeedKmh) * 60 + 5).round();
    return RouteEstimate(
      distanceText: '${km.toStringAsFixed(1)} km',
      durationText: '$minutes mins',
      distanceKm: km,
      routePoints: [pickup, destination],
      isFallback: true,
    );
  }

  static double _haversineKm(DemoMapPoint a, DemoMapPoint b) {
    const earthKm = 6371.0;
    final dLat = _degreesToRadians(b.latitude - a.latitude);
    final dLng = _degreesToRadians(b.longitude - a.longitude);
    final lat1 = _degreesToRadians(a.latitude);
    final lat2 = _degreesToRadians(b.latitude);
    final h = _sin2(dLat / 2) + _sin2(dLng / 2) * _cos(lat1) * _cos(lat2);
    return earthKm * 2 * _atan2(_sqrt(h), _sqrt(1 - h));
  }

  static double _degreesToRadians(double degrees) =>
      degrees * 0.017453292519943295;
}

double _sin2(double value) {
  final s = _sin(value);
  return s * s;
}

double _sin(double value) => _Math.sin(value);
double _cos(double value) => _Math.cos(value);
double _sqrt(double value) => _Math.sqrt(value);
double _atan2(double y, double x) => _Math.atan2(y, x);

class _Math {
  static double sin(double value) => math.sin(value);
  static double cos(double value) => math.cos(value);
  static double sqrt(double value) => math.sqrt(value);
  static double atan2(double y, double x) => math.atan2(y, x);
}

class DirectionsException implements Exception {
  const DirectionsException(this.message);

  final String message;

  @override
  String toString() => message;
}
